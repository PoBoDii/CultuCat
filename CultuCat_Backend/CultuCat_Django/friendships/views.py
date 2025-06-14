from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone
from django.db.models import Q

from accounts.models import Users
from .models import FriendshipRequest, Friendship

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_friendship_request(request):
    """
    Enviar una solicitud de amistad a otro usuario.
    
    Requiere: username en el cuerpo de la petición
    Devuelve: Confirmación de la solicitud enviada
    """
    try:
        # Obtener el usuario actual
        user_orderer = Users.objects.get(user=request.user)
        username_ordered = request.data.get('username')
        
        if not username_ordered:
            return Response({'error': 'El nombre de usuario es obligatorio'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el usuario destinatario existe
        try:
            user_ordered = Users.objects.get(user__username=username_ordered)
        except Users.DoesNotExist:
            return Response({'error': f'No existe un usuario con nombre "{username_ordered}"'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que no es el mismo usuario        
        if user_orderer == user_ordered:
            return Response({'error': 'No puedes enviarte una solicitud de amistad a ti mismo'}, 
                          status=status.HTTP_400_BAD_REQUEST)

        # Verificar si hay un bloqueo en cualquier dirección
        block_exists = Friendship.objects.filter(
            ((Q(user1=user_orderer) & Q(user2=user_ordered)) | 
            (Q(user1=user_ordered) & Q(user2=user_orderer))),
            is_friend=False
        ).exists()

        if block_exists:
            return Response({'error': 'No puedes enviar una solicitud de amistad a este usuario'}, 
                          status=status.HTTP_403_FORBIDDEN)
                          
        # Verificar si ya son amigos
        # Usamos exists() para verificar si hay al menos una relación de amistad sin necesidad de recuperar campos
        friendship_exists = Friendship.objects.filter(
            (Q(user1=user_orderer) & Q(user2=user_ordered)) | 
            (Q(user1=user_ordered) & Q(user2=user_orderer)),
            is_friend=True
        ).exists()
        
        if friendship_exists:
            return Response({
                'message': f'Ya eres amigo de {username_ordered}'
            }, status=status.HTTP_200_OK)
            
        # Verificar si ya tiene una solicitud pendiente enviada
        existing_request = FriendshipRequest.objects.filter(
            user_orderer=user_orderer, 
            user_ordered=user_ordered, 
            status='Pendiente'
        ).first()
        if existing_request:
            # Cancelar la solicitud si ya existe
            existing_request.delete()
            return Response({
                'message': f'Has cancelado tu solicitud de amistad a {username_ordered}'
            }, status=status.HTTP_200_OK)
            
        # Verificar si existe una solicitud pendiente recibida (aceptarla automáticamente)
        existing_received_request = FriendshipRequest.objects.filter(
            user_orderer=user_ordered, 
            user_ordered=user_orderer, 
            status='Pendiente'
        ).first()
        
        if existing_received_request:
            # Actualizar estado de la solicitud
            existing_received_request.status = 'Aceptado'
            existing_received_request.response_date = timezone.now()
            existing_received_request.save()
            
            # Crear relación de amistad manteniendo el orden original de la solicitud
            Friendship.objects.create(
                user1=existing_received_request.user_orderer,
                user2=existing_received_request.user_ordered,
                is_friend=True,
                request=existing_received_request
            )
            
            return Response({
                'message': f'Has aceptado la solicitud de amistad de {username_ordered} y ahora son amigos'
            }, status=status.HTTP_201_CREATED)
            
        # Si no existe una solicitud previa, crear una nueva
        friendship_request = FriendshipRequest.objects.create(
            user_orderer=user_orderer,
            user_ordered=user_ordered,
            status='Pendiente'
        )
        
        return Response({
            'message': f'Solicitud de amistad enviada a {username_ordered}'
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        return Response({'error': f'Error al enviar la solicitud: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_my_friendship_requests(request):
    """
    Listar todas las solicitudes de amistad pendientes para el usuario actual.
    
    Devuelve: Lista de solicitudes pendientes de amistad
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Obtener solicitudes pendientes
        requests = FriendshipRequest.objects.filter(
            user_ordered=user_profile,
            status='Pendiente'
        ).select_related('user_orderer', 'user_orderer__user')
        
        requests_data = []
        for friendship_req in requests:
            requests_data.append({
                'id': friendship_req.id,
                'username': friendship_req.user_orderer.user.username,
                'request_date': friendship_req.request_date.strftime("%Y-%m-%d %H:%M:%S")
            })
        
        return Response({
            'message': f'Tienes {len(requests_data)} solicitudes pendientes',
            'requests': requests_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar solicitudes: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_my_sent_friendship_requests(request):
    """
    Listar todas las solicitudes de amistad enviadas por el usuario actual que están pendientes.
    
    Devuelve: Lista de solicitudes enviadas pendientes
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Obtener solicitudes enviadas pendientes
        requests = FriendshipRequest.objects.filter(
            user_orderer=user_profile,
            status='Pendiente'
        ).select_related('user_ordered', 'user_ordered__user')
        
        requests_data = []
        for friendship_req in requests:
            requests_data.append({
                'id': friendship_req.id,
                'username': friendship_req.user_ordered.user.username,
                'request_date': friendship_req.request_date.strftime("%Y-%m-%d %H:%M:%S")
            })
        
        return Response({
            'message': f'Has enviado {len(requests_data)} solicitudes pendientes',
            'requests': requests_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar solicitudes enviadas: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def respond_to_friendship_request(request):
    """
    Aceptar o rechazar una solicitud de amistad.
    
    Requiere: request_id y action ('accept' o 'reject') en el cuerpo de la petición
    Devuelve: Confirmación de la acción realizada
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        request_id = request.data.get('request')
        action = request.data.get('action')
        
        if not request_id or not action:
            return Response({'error': 'El ID de la solicitud y la acción son obligatorios'}, 
                            status=status.HTTP_400_BAD_REQUEST)
            
        if action not in ['accept', 'reject']:
            return Response({'error': 'La acción debe ser "accept" o "reject"'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Obtener la solicitud - ahora buscamos donde el usuario actual es el user_ordered
        try:
            friendship_request = FriendshipRequest.objects.get(
                id=request_id, 
                user_ordered=user_profile,  # El usuario actual debe ser quien recibe la solicitud
                status='Pendiente'
            )
        except FriendshipRequest.DoesNotExist:
            return Response({'error': 'Solicitud no encontrada o ya procesada'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Procesar la solicitud
        now = timezone.now()
        if action == 'accept':
            # Actualizar el estado de la solicitud
            friendship_request.status = 'Aceptado'
            friendship_request.response_date = now
            friendship_request.save()
            
            # Crear relación de amistad manteniendo el orden original de la solicitud
            Friendship.objects.create(
                user1=friendship_request.user_orderer,
                user2=friendship_request.user_ordered,
                is_friend=True,
                request=friendship_request
            )
            
            return Response({
                'message': f'Has aceptado la solicitud de amistad de {friendship_request.user_orderer.user.username}'
            }, status=status.HTTP_200_OK)
        else:
            # Rechazar la solicitud
            friendship_request.status = 'Rechazado'
            friendship_request.response_date = now
            friendship_request.save()
            
            return Response({
                'message': f'Has rechazado la solicitud de amistad de {friendship_request.user_orderer.user.username}'
            }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al responder a la solicitud: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_my_friends(request):
    """
    Listar todos los amigos del usuario actual.
    
    Devuelve: Lista de amigos
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Buscar en ambas direcciones de la relación de amistad
        # Usamos select_related para evitar consultas adicionales a la base de datos
        # Explicitly define which fields to retrieve to avoid 'id' field issues
        user1_friendships = Friendship.objects.filter(
            user1=user_profile,
            is_friend=True
        ).select_related('user2', 'user2__user').only('user1', 'user2', 'is_friend')
        
        user2_friendships = Friendship.objects.filter(
            user2=user_profile,
            is_friend=True
        ).select_related('user1', 'user1__user').only('user1', 'user2', 'is_friend')
        
        friends_data = []
        
        # Procesamos amigos desde la posición user1
        for friendship in user1_friendships:
            friend = friendship.user2
            friends_data.append({
                'username': friend.user.username,
                'user_id': friend.user.id,
            })
        
        # Procesamos amigos desde la posición user2
        for friendship in user2_friendships:
            friend = friendship.user1
            friends_data.append({
                'username': friend.user.username,
                'user_id': friend.user.id,
            })
        
        return Response({
            'message': f'Tienes {len(friends_data)} amigos',
            'friends': friends_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar amigos: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def remove_friend(request):
    """
    Eliminar a un usuario de la lista de amigos.
    
    Requiere: username en el cuerpo de la petición
    Devuelve: Confirmación de la eliminación
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        username_to_remove = request.data.get('username')
        
        if not username_to_remove:
            return Response({'error': 'El nombre de usuario es obligatorio'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el usuario a eliminar existe
        try:
            user_to_remove = Users.objects.get(user__username=username_to_remove)
        except Users.DoesNotExist:
            return Response({'error': f'No existe un usuario con nombre "{username_to_remove}"'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Buscar la relación de amistad
        friendship = Friendship.objects.filter(
            (Q(user1=user_profile) & Q(user2=user_to_remove)) | 
            (Q(user1=user_to_remove) & Q(user2=user_profile)),
            is_friend=True
        ).first()
        
        if not friendship:
            return Response({'error': f'No eres amigo de {username_to_remove}'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Eliminar la relación de amistad
        friendship.delete()
        
        return Response({
            'message': f'Has eliminado a {username_to_remove} de tu lista de amigos'
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al eliminar amigo: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def block_user(request):
    """
    Bloquear a un usuario. Esto creará una relación de Friendship con is_friend=False
    y eliminará cualquier amistad o solicitud pendiente existente.
    
    Requiere: username en el cuerpo de la petición
    Devuelve: Confirmación del bloqueo
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        username_to_block = request.data.get('username')
        
        if not username_to_block:
            return Response({'error': 'El nombre de usuario es obligatorio'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el usuario a bloquear existe
        try:
            user_to_block = Users.objects.get(user__username=username_to_block)
        except Users.DoesNotExist:
            return Response({'error': f'No existe un usuario con nombre "{username_to_block}"'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que no se está intentando bloquear a sí mismo
        if user_profile == user_to_block:
            return Response({'error': 'No puedes bloquearte a ti mismo'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        # Eliminar cualquier relación de amistad existente
        Friendship.objects.filter(
            (Q(user1=user_profile) & Q(user2=user_to_block)) | 
            (Q(user1=user_to_block) & Q(user2=user_profile))
        ).delete()
        
        # Eliminar cualquier solicitud de amistad pendiente
        FriendshipRequest.objects.filter(
            (Q(user_orderer=user_profile) & Q(user_ordered=user_to_block)) |
            (Q(user_orderer=user_to_block) & Q(user_ordered=user_profile)),
            status='Pendiente'
        ).delete()
        
        # Crear la relación de bloqueo (is_friend=False)
        # El usuario que bloquea siempre será user1
        Friendship.objects.create(
            user1=user_profile,
            user2=user_to_block,
            is_friend=False
        )
        
        return Response({
            'message': f'Has bloqueado a {username_to_block}'
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al bloquear usuario: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_friends(request):
    user = request.user
    # Buscar amistades donde el usuario es user1 o user2
    friendships = Friendship.objects.filter(
        Q(user1=user, is_friend=True) | Q(user2=user, is_friend=True)
    )
    
    # Obtener la lista de amigos
    friends = []
    for friendship in friendships:
        friend = friendship.user2 if friendship.user1 == user else friendship.user1
        friends.append({
            'username': friend.username,
            'email': friend.email,
            # Añade aquí otros campos que necesites
        })
    
    return Response(friends, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_friendship(request, username):
    try:
        user = request.user
        other_user = Users.objects.get(username=username)
        
        # Buscar amistad en ambas direcciones
        friendship = Friendship.objects.filter(
            (Q(user1=user, user2=other_user) | Q(user1=other_user, user2=user)),
            is_friend=True
        ).first()
        
        if friendship:
            return Response({'are_friends': True}, status=status.HTTP_200_OK)
        return Response({'are_friends': False}, status=status.HTTP_200_OK)
        
    except Users.DoesNotExist:
        return Response({'error': 'Usuario no encontrado'}, status=status.HTTP_404_NOT_FOUND)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_friendship_status(request):
    """
    Obtener el estado de amistad (amigo, bloqueado o ninguno) entre el usuario actual y otro usuario.
    
    Requiere: username en los parámetros de la URL
    Devuelve: Estado de la relación entre los usuarios
    """
    try:
        # Obtener el usuario actual
        current_user = Users.objects.get(user=request.user)
        username = request.GET.get('username')
        
        if not username:
            return Response({'error': 'El nombre de usuario es obligatorio'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el usuario objetivo existe
        try:
            target_user = Users.objects.get(user__username=username)
        except Users.DoesNotExist:
            return Response({'error': f'No existe un usuario con nombre "{username}"'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Buscar la relación de amistad o bloqueo
        friendship = Friendship.objects.filter(
            (Q(user1=current_user) & Q(user2=target_user)) | 
            (Q(user1=target_user) & Q(user2=current_user))
        ).first()
        
        if not friendship:
            return Response({
                'status': 'no_relation',
                'message': f'No existe relación con el usuario {username}'
            }, status=status.HTTP_200_OK)
        
        # Verificar el tipo de relación
        if friendship.is_friend:
            return Response({
                'status': 'friends',
                'message': f'Eres amigo de {username}',
                'friendship': {
                    'user1': friendship.user1.user.username,
                    'user2': friendship.user2.user.username,
                    'since': friendship.request.request_date.strftime("%Y-%m-%d %H:%M:%S") if friendship.request else None
                }
            }, status=status.HTTP_200_OK)
        else:
            # Verificar quién bloqueó a quién
            if friendship.user1 == current_user:
                return Response({
                    'status': 'blocked',
                    'message': f'Has bloqueado a {username}',
                    'friendship': {
                        'blocker': current_user.user.username,
                        'blocked': target_user.user.username
                    }
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    'status': 'blocked_by',
                    'message': f'Has sido bloqueado por {username}',
                    'friendship': {
                        'blocker': target_user.user.username,
                        'blocked': current_user.user.username
                    }
                }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al obtener el estado de amistad: {str(e)}'}, 
                      status=status.HTTP_500_INTERNAL_SERVER_ERROR)
