from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q
from django.utils import timezone
from django.db import connection
from django.db.models import F

from groups.models import Group, GroupRequest
from participants.models import Participant
from groupchats.models import GroupChat
from chats.models import Chat
from accounts.models import Users
from chat_messages.models import Message
from datetimes.models import DateTime

#Notificaciones
from django.db import connection
from utils.notificaciones import send_fcm_data_message, send_fcm_notification


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_group(request):
    """
    Crear un nuevo grupo. El usuario que lo crea se convierte en creador.
    
    Requiere: name en el cuerpo de la petición
    Opcional: groupphoto_id en el cuerpo de la petición
    Devuelve: Detalles del grupo creado
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Obtener datos del cuerpo de la petición
        name = request.data.get('name')
        groupphoto_id = request.data.get('groupphoto_id')
        
        if not name:
            return Response({'error': 'El nombre del grupo es obligatorio'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Crear chat genérico
        chat = Chat.objects.create(type='GroupChat')
        
        # Crear group chat asociado
        group_chat = GroupChat.objects.create(id=chat)
        
        # Crear grupo
        group = Group.objects.create(
            name=name,
            groupphoto_id=groupphoto_id,
            idchat=group_chat
        )
        
        # Añadir al creador como participante con rol de creador
        Participant.objects.create(
            idgroup=group,
            username=user_profile,
            rol=Participant.Role.CREATOR
        )
        
        return Response({
            'message': 'Grupo creado exitosamente',
            'group': {
                'id': group.id,
                'name': group.name,
                'chat_id': group.idchat.id.id,
                'created_by': request.user.username
            }
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        return Response({'error': f'Error al crear el grupo: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def join_group(request):
    """
    Enviar una solicitud para unirse a un grupo existente.
    Un administrador o el creador deberá aprobar la solicitud.
    
    Requiere: group_id en el cuerpo de la petición
    Devuelve: Confirmación de la solicitud enviada
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        group_id = request.data.get('group_id')
        
        if not group_id:
            return Response({'error': 'El ID del grupo es obligatorio'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el grupo existe
        try:
            group = Group.objects.get(id=group_id)
        except Group.DoesNotExist:
            return Response({'error': f'No existe un grupo con ID {group_id}'}, status=status.HTTP_404_NOT_FOUND)
        
        # Verificar si ya es miembro
        existing_membership = Participant.objects.filter(idgroup=group, username=user_profile).first()
        if existing_membership:
            return Response({
                'message': f'Ya eres parte del grupo "{group.name}" con rol de {existing_membership.rol}'
            }, status=status.HTTP_200_OK)
        
        # Verificar si ya tiene una solicitud pendiente
        existing_request = GroupRequest.objects.filter(
            idgroup=group, 
            username=user_profile, 
            status=GroupRequest.Status.PENDING,
            is_invitation=False
        ).first()
        
        if existing_request:
            return Response({
                'message': f'Ya tienes una solicitud pendiente para unirte al grupo "{group.name}"'
            }, status=status.HTTP_200_OK)
            
        # Verificar si tiene una invitación pendiente (en ese caso, aceptarla directamente)
        invitation = GroupRequest.objects.filter(
            idgroup=group, 
            username=user_profile, 
            status=GroupRequest.Status.PENDING,
            is_invitation=True
        ).first()
        
        if invitation:
            # Actualizar estado de la invitación
            invitation.status = GroupRequest.Status.ACCEPTED
            invitation.response_date = timezone.now()
            invitation.save()
            
            # Añadir al usuario como miembro directamente
            Participant.objects.create(
                idgroup=group,
                username=user_profile,
                rol=Participant.Role.MEMBER
            )
            
            return Response({
                'message': f'Has aceptado la invitación y te has unido al grupo "{group.name}"',
                'group': {
                    'id': group.id,
                    'name': group.name,
                    'chat_id': group.idchat.id.id,
                    'your_role': Participant.Role.MEMBER
                }
            }, status=status.HTTP_201_CREATED)
        
        # Crear una nueva solicitud
        GroupRequest.objects.create(
            idgroup=group,
            username=user_profile,
            status=GroupRequest.Status.PENDING,
            is_invitation=False
        )
        
        return Response({
            'message': f'Se ha enviado tu solicitud para unirte al grupo "{group.name}". Espera la aprobación del administrador.',
            'status': 'pending',
            'group': {
                'id': group.id,
                'name': group.name
            }
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        return Response({'error': f'Error al enviar la solicitud: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def search_groups(request):
    """
    Buscar grupos por nombre.
    
    Requiere: query en parámetros de URL
    Devuelve: Lista de grupos que coinciden con la búsqueda
    """
    try:
        query = request.query_params.get('query', '')
        
        if not query:
            return Response({'error': 'El parámetro de búsqueda es obligatorio'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Buscar grupos que contengan la cadena de búsqueda en su nombre
        # Ordenados por relevancia (exact match first, then contains)
        groups = Group.objects.filter(
            Q(name__iexact=query) | Q(name__icontains=query)
        ).distinct()
        
        # Ordenar para que los resultados exactos aparezcan primero
        # Esto no se puede hacer directamente con ORM, así que ordenamos en Python
        results = []
        
        for group in groups:
            # Determinar si el usuario actual es miembro
            user_profile = Users.objects.get(user=request.user)
            is_member = Participant.objects.filter(idgroup=group, username=user_profile).exists()
            
            # Añadir al resultado con puntuación de relevancia
            result = {
                'id': group.id,
                'name': group.name,
                'is_member': is_member,
                # La puntuación es más alta si el nombre coincide exactamente
                'relevance': 100 if group.name.lower() == query.lower() else 50
            }
            results.append(result)
        
        # Ordenar por relevancia (mayor a menor)
        results.sort(key=lambda x: x['relevance'], reverse=True)
        
        # Eliminar el campo de relevancia antes de devolver los resultados
        for result in results:
            del result['relevance']
        
        return Response({
            'message': f'Se encontraron {len(results)} grupos',
            'groups': results
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al buscar grupos: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_group_messages(request, group_id):
    """
    Obtener mensajes de un grupo.
    
    Requiere: group_id en la URL
    Devuelve: Lista de mensajes del grupo
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Verificar que el grupo existe
        try:
            group = Group.objects.get(id=group_id)
        except Group.DoesNotExist:
            return Response({'error': f'No existe un grupo con ID {group_id}'}, status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que el usuario es miembro del grupo
        is_member = Participant.objects.filter(idgroup=group, username=user_profile).exists()
        if not is_member:
            return Response({'error': 'No eres miembro de este grupo'}, status=status.HTTP_403_FORBIDDEN)
        
        # Obtener mensajes del grupo
        chat_id = group.idchat.id.id  # ID del chat asociado al grupo
        
        # Usar SQL directo para obtener mensajes ordenados por fecha y hora
        with connection.cursor() as cursor:
            cursor.execute('''
                SELECT m.date, m.time, u.username, m.text
                FROM message m
                JOIN auth_user u ON m.username = u.username
                WHERE m.idchat = %s
                ORDER BY m.date, m.time
            ''', [chat_id])
            
            columns = [col[0] for col in cursor.description]
            messages = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        # Formatear fechas para JSON
        for msg in messages:
            if msg['date']:
                msg['date'] = str(msg['date'])
            if msg['time']:
                msg['time'] = str(msg['time'])
        
        if not messages:
            return Response({
                'message': 'No hay mensajes en este grupo todavía',
                'group_name': group.name,
                'messages': []
            }, status=status.HTTP_200_OK)
        
        return Response({
            'message': f'Se encontraron {len(messages)} mensajes',
            'group_name': group.name,
            'messages': messages
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al obtener mensajes del grupo: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_group_message(request):
    """
    Enviar un mensaje a un grupo.
    
    Requiere: group_id y message en el cuerpo de la petición
    Devuelve: Confirmación del mensaje enviado
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        group_id = request.data.get('group_id')
        text = request.data.get('message')
        
        if not group_id or not text:
            return Response({'error': 'El ID del grupo y el mensaje son obligatorios'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el grupo existe
        try:
            group = Group.objects.get(id=group_id)
        except Group.DoesNotExist:
            return Response({'error': f'No existe un grupo con ID {group_id}'}, status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que el usuario es miembro del grupo
        is_member = Participant.objects.filter(idgroup=group, username=user_profile).exists()
        if not is_member:
            return Response({'error': 'No eres miembro de este grupo'}, status=status.HTTP_403_FORBIDDEN)
        
        # Obtener fecha y hora actuales
        now = timezone.now()
        date = now.date()
        time = now.time().replace(microsecond=0)
        
        # Asegurar que existe el registro DateTime correspondiente
        dt, _ = DateTime.objects.get_or_create(date=date, time=time)
        
        # ID del chat asociado al grupo
        chat_id = group.idchat.id.id
        
        # Guardar el mensaje usando SQL directo
        with connection.cursor() as cursor:
            cursor.execute("""
                INSERT INTO message (date, time, username, idchat, text, filepath)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, [date, time, user_profile.user.username, chat_id, text, None])
        
        
        # Obtener todos los miembros del grupo excepto el remitente
        participants = Participant.objects.filter(idgroup=group).exclude(username=user_profile).select_related('username')

        for participant in participants:
            receiver = participant.username  # Users object

            if receiver.fcm_token:
                print("Enviando notificación a " + receiver.user.username + " con token: " + receiver.fcm_token + " al grupo " + str(chat_id));
                # Revisar si la app está en primer plano (desde request opcional)
                if request.data.get("is_foreground") == "true":
                    send_fcm_data_message(
                        token=receiver.fcm_token,
                        data={
                            'type': 'new_group_message',
                            'group_id': str(group.id),
                            'group_name': group.name,
                            'chat_id': str(chat_id),
                            'sender_username': request.user.username,
                            'text': text,
                        }
                    )
                else:
                    send_fcm_notification(
                        token=receiver.fcm_token,
                        title=f"Nuevo mensaje en {group.name}",
                        body=f"{request.user.username}: {text}",
                        data={
                            'type': 'new_group_message',
                            'group_id': str(group.id),
                            'group_name': group.name,
                            'chat_id': str(chat_id),
                            'sender_username': request.user.username,
                            'text': text,
                        }
                    )
            
            
            
            
        return Response({
            'message': 'Mensaje enviado correctamente',
            'details': {
                'group_name': group.name,
                'senderUsername': request.user.username,
                'text': text,
                'date': str(date),
                'time': str(time),
            }
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        return Response({'error': f'Error al enviar mensaje: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_my_groups(request):
    """
    Listar los grupos del usuario ordenados por último mensaje.
    
    Devuelve: Lista de grupos del usuario con sus últimos mensajes
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Obtener participaciones del usuario en grupos
        participations = Participant.objects.filter(username=user_profile)
        
        if not participations:
            return Response({
                'message': 'No perteneces a ningún grupo',
                'groups': []
            }, status=status.HTTP_200_OK)
        
        # Obtener detalles de los grupos
        groups_data = []
        
        for participation in participations:
            group = participation.idgroup
            
            # Obtener el último mensaje del grupo usando SQL directo
            with connection.cursor() as cursor:
                cursor.execute('''
                    SELECT m.date, m.time, u.username, m.text
                    FROM message m
                    JOIN auth_user u ON m.username = u.username
                    WHERE m.idchat = %s
                    ORDER BY m.date DESC, m.time DESC
                    LIMIT 1
                ''', [group.idchat.id.id])
                
                last_message_row = cursor.fetchone()
                
                if last_message_row:
                    last_message = {
                        'date': str(last_message_row[0]),
                        'time': str(last_message_row[1]),
                        'username': last_message_row[2],
                        'text': last_message_row[3]
                    }
                    # Formato combinado para ordenación
                    last_activity = f"{last_message_row[0]} {last_message_row[1]}"
                else:
                    last_message = None
                    # Si no hay mensajes, usar una fecha antigua para ordenación
                    last_activity = "1970-01-01 00:00:00"
            
            groups_data.append({
                'id': group.id,
                'name': group.name,
                'role': participation.rol,
                'last_message': last_message,
                'last_activity': last_activity  # Campo temporal para ordenación
            })
        
        # Ordenar por actividad reciente (último mensaje)
        groups_data.sort(key=lambda x: x['last_activity'], reverse=True)
        
        # Eliminar el campo temporal de ordenación
        for group_data in groups_data:
            del group_data['last_activity']
        
        return Response({
            'message': f'Se encontraron {len(groups_data)} grupos',
            'groups': groups_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar grupos: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_group_requests(request, group_id):
    """
    Listar todas las solicitudes pendientes para unirse a un grupo.
    Solo accesible para administradores y creadores del grupo.
    
    Requiere: group_id en la URL
    Devuelve: Lista de solicitudes pendientes
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Verificar que el grupo existe
        try:
            group = Group.objects.get(id=group_id)
        except Group.DoesNotExist:
            return Response({'error': f'No existe un grupo con ID {group_id}'}, status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que el usuario es administrador o creador del grupo
        user_participation = Participant.objects.filter(idgroup=group, username=user_profile).first()
        if not user_participation or user_participation.rol not in [Participant.Role.ADMIN, Participant.Role.CREATOR]:
            return Response({'error': 'Solo los administradores y creadores pueden ver las solicitudes pendientes'}, 
                          status=status.HTTP_403_FORBIDDEN)
        
        # Obtener solicitudes pendientes (no invitaciones)
        requests = GroupRequest.objects.filter(
            idgroup=group,
            status=GroupRequest.Status.PENDING,
            is_invitation=False
        ).values('id', 'username__user__username', 'request_date')
        
        # Formatear fechas para JSON
        requests_data = []
        for req in requests:
            req_data = {
                'id': req['id'],
                'username': req['username__user__username'],
                'request_date': req['request_date'].strftime("%Y-%m-%d %H:%M:%S")
            }
            requests_data.append(req_data)
        
        return Response({
            'message': f'Se encontraron {len(requests_data)} solicitudes pendientes',
            'group_name': group.name,
            'requests': requests_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar solicitudes: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def handle_group_request(request):
    """
    Aceptar o rechazar una solicitud para unirse a un grupo.
    Solo accesible para administradores y creadores del grupo.
    
    Requiere: request_id y action ('accept' o 'reject') en el cuerpo de la petición
    Devuelve: Confirmación de la acción realizada
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        request_id = request.data.get('request_id')
        action = request.data.get('action')
        
        if not request_id or not action:
            return Response({'error': 'El ID de la solicitud y la acción son obligatorios'}, 
                            status=status.HTTP_400_BAD_REQUEST)
            
        if action not in ['accept', 'reject']:
            return Response({'error': 'La acción debe ser "accept" o "reject"'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Obtener la solicitud
        try:
            group_request = GroupRequest.objects.get(id=request_id, status=GroupRequest.Status.PENDING)
        except GroupRequest.DoesNotExist:
            return Response({'error': 'Solicitud no encontrada o ya procesada'}, status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que el usuario es administrador o creador del grupo
        group = group_request.idgroup
        user_participation = Participant.objects.filter(idgroup=group, username=user_profile).first()
        if not user_participation or user_participation.rol not in [Participant.Role.ADMIN, Participant.Role.CREATOR]:
            return Response({'error': 'Solo los administradores y creadores pueden procesar solicitudes'}, 
                          status=status.HTTP_403_FORBIDDEN)
        
        # Procesar la solicitud
        now = timezone.now()
        if action == 'accept':
            # Actualizar el estado de la solicitud
            group_request.status = GroupRequest.Status.ACCEPTED
            group_request.responded_by = user_profile
            group_request.response_date = now
            group_request.save()
            
            # Añadir al usuario como miembro
            Participant.objects.create(
                idgroup=group,
                username=group_request.username,
                rol=Participant.Role.MEMBER
            )
            
            return Response({
                'message': f'Has aceptado la solicitud de {group_request.username.user.username}',
                'group_name': group.name
            }, status=status.HTTP_200_OK)
        else:
            # Rechazar la solicitud
            group_request.status = GroupRequest.Status.REJECTED
            group_request.responded_by = user_profile
            group_request.response_date = now
            group_request.save()
            
            return Response({
                'message': f'Has rechazado la solicitud de {group_request.username.user.username}',
                'group_name': group.name
            }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al procesar la solicitud: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def invite_to_group(request):
    """
    Invitar a un usuario a unirse a un grupo.
    Solo accesible para administradores y creadores del grupo.
    
    Requiere: group_id y username en el cuerpo de la petición
    Devuelve: Confirmación de la invitación enviada
    """
    try:
        inviter = Users.objects.get(user=request.user)
        group_id = request.data.get('group_id')
        username = request.data.get('username')
        
        if not group_id or not username:
            return Response({'error': 'El ID del grupo y el nombre de usuario son obligatorios'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar que el grupo existe
        try:
            group = Group.objects.get(id=group_id)
        except Group.DoesNotExist:
            return Response({'error': f'No existe un grupo con ID {group_id}'}, status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que el invitador es administrador o creador del grupo
        inviter_participation = Participant.objects.filter(idgroup=group, username=inviter).first()
        if not inviter_participation or inviter_participation.rol not in [Participant.Role.ADMIN, Participant.Role.CREATOR]:
            return Response({'error': 'Solo los administradores y creadores pueden enviar invitaciones'}, 
                          status=status.HTTP_403_FORBIDDEN)
        
        # Verificar que el usuario invitado existe
        try:
            invited_user = Users.objects.get(user__username=username)
        except Users.DoesNotExist:
            return Response({'error': f'No existe un usuario con nombre "{username}"'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Verificar que el usuario no es ya miembro del grupo
        existing_membership = Participant.objects.filter(idgroup=group, username=invited_user).exists()
        if existing_membership:
            return Response({'error': f'El usuario {username} ya es miembro del grupo'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        # Verificar si ya tiene una invitación pendiente
        existing_invitation = GroupRequest.objects.filter(
            idgroup=group, 
            username=invited_user, 
            status=GroupRequest.Status.PENDING,
            is_invitation=True
        ).first()
        
        if existing_invitation:
            return Response({
                'message': f'Ya hay una invitación pendiente para {username}',
                'group_name': group.name
            }, status=status.HTTP_200_OK)
        
        # Crear una nueva invitación
        GroupRequest.objects.create(
            idgroup=group,
            username=invited_user,
            status=GroupRequest.Status.PENDING,
            is_invitation=True,
            responded_by=inviter  # El que crea la invitación
        )

        # Enviar notificación push si el invitado tiene un token registrado
        try:
            if invited_user.fcm_token and invited_user.user != request.user:
                print(f"[DEBUG] Enviando notificación de invitación a {invited_user.user.username} (token: {invited_user.fcm_token})")
                cuerpo = f"{inviter.user.username} te ha invitado a unirte al grupo \"{group.name}\""

                send_fcm_notification(
                    token=invited_user.fcm_token,
                    title="Invitación a grupo",
                    body=cuerpo,
                    data={
                        'type': 'group_invitation',
                        'group_id': str(group.id),
                        'group_name': group.name,
                        'admin': inviter.user.username
                    }
                )
        except Exception as e:
            print(f"[ERROR] Fallo al enviar notificación push: {str(e)}")

        
        return Response({
            'message': f'Se ha enviado una invitación a {username} para unirse al grupo "{group.name}"',
            'group_name': group.name
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        return Response({'error': f'Error al enviar la invitación: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_my_invitations(request):
    """
    Listar todas las invitaciones pendientes para el usuario actual.
    
    Devuelve: Lista de invitaciones pendientes a grupos
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Obtener invitaciones pendientes
        invitations = GroupRequest.objects.filter(
            username=user_profile,
            status=GroupRequest.Status.PENDING,
            is_invitation=True
        ).select_related('idgroup', 'responded_by')
        
        invitations_data = []
        for invitation in invitations:
            invitations_data.append({
                'id': invitation.id,
                'group_id': invitation.idgroup.id,
                'group_name': invitation.idgroup.name,
                'invited_by': invitation.responded_by.user.username if invitation.responded_by else None,
                'invitation_date': invitation.request_date.strftime("%Y-%m-%d %H:%M:%S")
            })
        
        return Response({
            'message': f'Tienes {len(invitations_data)} invitaciones pendientes',
            'invitations': invitations_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar invitaciones: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def respond_to_invitation(request):
    """
    Aceptar o rechazar una invitación a un grupo.
    
    Requiere: invitation_id y action ('accept' o 'reject') en el cuerpo de la petición
    Devuelve: Confirmación de la acción realizada
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        invitation_id = request.data.get('invitation_id')
        action = request.data.get('action')
        
        if not invitation_id or not action:
            return Response({'error': 'El ID de la invitación y la acción son obligatorios'}, 
                            status=status.HTTP_400_BAD_REQUEST)
            
        if action not in ['accept', 'reject']:
            return Response({'error': 'La acción debe ser "accept" o "reject"'}, 
                            status=status.HTTP_400_BAD_REQUEST)
        
        # Obtener la invitación
        try:
            invitation = GroupRequest.objects.get(
                id=invitation_id, 
                username=user_profile,
                status=GroupRequest.Status.PENDING,
                is_invitation=True
            )
        except GroupRequest.DoesNotExist:
            return Response({'error': 'Invitación no encontrada o ya procesada'}, status=status.HTTP_404_NOT_FOUND)
        
        # Procesar la respuesta
        now = timezone.now()
        if action == 'accept':
            # Actualizar el estado de la invitación
            invitation.status = GroupRequest.Status.ACCEPTED
            invitation.response_date = now
            invitation.save()
            
            # Añadir al usuario como miembro
            Participant.objects.create(
                idgroup=invitation.idgroup,
                username=user_profile,
                rol=Participant.Role.MEMBER
            )
            
            return Response({
                'message': f'Has aceptado la invitación para unirte al grupo "{invitation.idgroup.name}"',
                'group': {
                    'id': invitation.idgroup.id,
                    'name': invitation.idgroup.name,
                    'chat_id': invitation.idgroup.idchat.id.id,
                    'your_role': Participant.Role.MEMBER
                }
            }, status=status.HTTP_200_OK)
        else:
            # Rechazar la invitación
            invitation.status = GroupRequest.Status.REJECTED
            invitation.response_date = now
            invitation.save()
            
            return Response({
                'message': f'Has rechazado la invitación para unirte al grupo "{invitation.idgroup.name}"'
            }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al responder a la invitación: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
