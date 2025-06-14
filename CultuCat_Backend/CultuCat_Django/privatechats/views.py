from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q
from django.db.models import F
from django.utils import timezone
from django.contrib.auth.models import User

from privatechats.models import PrivateChat  # Modelo de chats privados
from chat_messages.models import Message      # Modelo de mensajes de chat
from accounts.models import Users             # Perfil de usuario extendido
from datetimes.models import DateTime         # Fecha y hora compuesta
from friendships.models import Friendship     # Modelo de amistades

#Notificaciones
from django.db import connection
from utils.notificaciones import send_fcm_data_message, send_fcm_notification



@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_private_chats(request):
    """
    Devuelve la lista de:
    1. Todos los chats privados del usuario autenticado ordenados por mensaje más reciente
    2. Amigos con los que no tiene chat, ordenados alfabéticamente
    """
    # Obtener perfil de usuario
    user_profile = Users.objects.get(user=request.user)
    
    # Obtener todos los chats privados del usuario
    chats = PrivateChat.objects.filter(
        Q(user1=user_profile) | Q(user2=user_profile)
    )
    
    # Obtener IDs de todos los usuarios con los que el usuario tiene chat
    chat_user_ids = set()
    for chat in chats:
        other_user = chat.user1 if chat.user2 == user_profile else chat.user2
        chat_user_ids.add(other_user.user.id)
    
    # Obtener IDs de amigos
    friend_ids = set()
    
    # Buscar amistades donde el usuario es user1
    friendships1 = Friendship.objects.filter(user1=user_profile, is_friend=True)
    for friendship in friendships1:
        friend_ids.add(friendship.user2.user.id)
    
    # Buscar amistades donde el usuario es user2
    friendships2 = Friendship.objects.filter(user2=user_profile, is_friend=True)
    for friendship in friendships2:
        friend_ids.add(friendship.user1.user.id)
    
    # IDs de amigos que no tienen chat con el usuario
    friends_without_chat_ids = friend_ids - chat_user_ids
    
    # Preparar datos de los chats existentes
    chats_data = []
    chats_without_messages = []
    
    for chat in chats:
        # Determinar el otro participante
        other = chat.user1 if chat.user2 == user_profile else chat.user2

        # Ultimo mensaje real
        # Use .values() to specify exactly which fields to retrieve, avoiding the id field
        last_messages = Message.objects.filter(idchat=chat.id).order_by('-date', '-time').values('date', 'time', 'text')
        
        # Manejar correctamente el caso donde no hay mensajes
        last_text = ''
        time_str = ''
        has_messages = False
        
        if last_messages:
            last = last_messages[0]
            last_text = last['text'] if last['text'] else ''
            time_str = f"{last['date']} {last['time']}"
            has_messages = True
            
        # Conteo de mensajes no leidos (si tu modelo los lleva)
        unread_count = 0

        chat_data = {
            'id': chat.id.pk,  # Use the primary key of the chat
            'username': other.user.username,
            'lastMessage': last_text,
            'time': time_str,
            'unread': unread_count,
            'hasChat': True,
            'hasMessages': has_messages
        }
        
        # Separar chats con mensajes de los sin mensajes
        if has_messages:
            chats_data.append(chat_data)
        else:
            chats_without_messages.append(chat_data)
    
    # Ordenar chats con mensajes por fecha del último mensaje (más reciente primero)
    sorted_chats = sorted(chats_data, key=lambda x: x['time'] if x['time'] else '', reverse=True)
    
    # Añadir amigos sin chat, ordenados alfabéticamente
    friends_without_chat = Users.objects.filter(user__id__in=friends_without_chat_ids).order_by('user__username')
    
    # Ordenar chats sin mensajes alfabéticamente
    chats_without_messages = sorted(chats_without_messages, key=lambda x: x['username'].lower())
    
    # Preparar amigos sin chat
    friends_data = []
    for friend in friends_without_chat:
        friends_data.append({
            'id': None,  # No hay chat aún
            'username': friend.user.username,
            'lastMessage': '',
            'time': '',
            'unread': 0,
            'hasChat': False,
            'hasMessages': False,
            'userId': friend.user.id  # Añadimos el ID del usuario para facilitar la creación de un chat
        })

    # Combinar los resultados: primero chats con mensajes ordenados por tiempo,
    # luego chats sin mensajes ordenados alfabéticamente,
    # finalmente amigos sin chat ordenados alfabéticamente
    data = sorted_chats + chats_without_messages + friends_data
    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_private_messages(request, chat_id):
    """
    Devuelve todos los mensajes de un chat privado concreto.
    """
    user_profile = Users.objects.get(user=request.user)
    try:
        # Validar que el chat existe y el usuario pertenece
        chat = PrivateChat.objects.get(
            Q(user1=user_profile) | Q(user2=user_profile),
            id=chat_id
        )
    except PrivateChat.DoesNotExist:
        return Response({'error': 'Chat no encontrado'}, status=status.HTTP_404_NOT_FOUND)

    # Obtener mensajes ordenados por fecha y hora usando .values() para evitar errores con campos inexistentes
    messages = Message.objects.filter(idchat=chat.id).order_by('date', 'time').values(
        'username__user__username', 'text', 'date', 'time'
    )

    data = []
    for msg in messages:
        data.append({
            'senderUsername': msg['username__user__username'],
            'message': msg['text'],
            'date': str(msg['date']),
            'time': str(msg['time']),
        })

    return Response(data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_private_message(request):
    try:
        user_profile = Users.objects.get(user=request.user)
        chat_id = request.data.get('chat_id')
        text = request.data.get('message')

        if not chat_id or not text:
            return Response({'error': 'Parametros obligatorios'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            chat = PrivateChat.objects.get(
                Q(user1=user_profile) | Q(user2=user_profile),
                id=chat_id
            )
        except PrivateChat.DoesNotExist:
            return Response({'error': 'Chat no encontrado o sin permiso'}, status=status.HTTP_404_NOT_FOUND)

        # Obtener fecha y hora actual sin microsegundos
        now = timezone.now()
        date = now.date()
        time = now.time().replace(microsecond=0)

        # Asegurar que existe la entrada DateTime correspondiente
        dt, _ = DateTime.objects.get_or_create(date=date, time=time)

        # Insertar el mensaje directamente (ya que no hay ID autogenerado)
        with connection.cursor() as cursor:
            cursor.execute("""
                INSERT INTO message (date, time, username, idchat, text, filepath)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, [date, time, user_profile.pk, chat.id.pk, text, None])

        # Determinar receptor
        receiver = chat.user1 if chat.user2 == user_profile else chat.user2

        # Enviar notificación invisible si tiene token (para actualizar chat)
        # Enviar notificación visible si tiene token (para testeo)
        if receiver.fcm_token:
            if request.data.get("is_foreground") == "true":
                send_fcm_data_message(
                    token=receiver.fcm_token,
                    data={
                        'type': 'new_message',
                        'chat_id': str(chat.id.pk),
                        'sender_username': request.user.username,
                        'text': text,
                    }
                )
                
            else:
                send_fcm_notification(
                    token=receiver.fcm_token,
                    title=f"Nuevo mensaje de {request.user.username}",
                    body=text,
                    data={
                        'type': 'new_message',
                        'chat_id': str(chat.id.pk),
                        'sender_username': request.user.username,
                        'text': text,
                    }
                )



        return Response({
            'senderUsername': request.user.username,
            'message': text,
            'date': str(date),
            'time': str(time),
        }, status=status.HTTP_201_CREATED)

    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({'error': f'Error interno: {str(e)}'}, status=500)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_private_chat(request):
    try:
        current_user = Users.objects.get(user=request.user)
        to_user_id = request.data.get('to_user_id')

        if not to_user_id:
            return Response({"error": "Falta el parametro to_user_id"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            to_user = Users.objects.get(user__id=to_user_id)
        except Users.DoesNotExist:
            return Response({"error": "Usuario destino no encontrado"}, status=status.HTTP_404_NOT_FOUND)

        # Verificar si ya existe un chat entre ambos
        existing_chat = PrivateChat.objects.filter(
            (Q(user1=current_user) & Q(user2=to_user)) |
            (Q(user1=to_user) & Q(user2=current_user))
        ).first()

        if existing_chat:
            return Response({
                "message": "Chat ya existente",
                "chat_id": existing_chat.id.id,  # .id es el FK a Chat
                "username": to_user.user.username,
                "exists": True
            }, status=status.HTTP_200_OK)

        # Crear objeto Chat primero
        from chats.models import Chat
        chat_base = Chat.objects.create()  # Asumimos que no requiere campos adicionales

        # Crear PrivateChat usando el Chat creado como id
        chat = PrivateChat.objects.create(id=chat_base, user1=current_user, user2=to_user)

        return Response({
            "message": "Chat creado correctamente",
            "chat_id": chat.id.id,
            "username": to_user.user.username,
            "exists": False
        }, status=status.HTTP_201_CREATED)
    
    except Exception as e:
        import traceback
        traceback.print_exc()
        return Response({"error": f"Error interno del servidor: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth.models import User
from django.db.models import Q
import datetime

from privatechats.models import PrivateChat
from chat_messages.models import Message
from accounts.models import Users


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_users_ordered_by_chats(request):
    """
    Lista los usuarios ordenados por:
    1. Primero los que tienen chat con el usuario actual, ordenados por recientes.
    2. Luego los demás usuarios ordenados alfabéticamente.
    """
    import datetime
    from django.utils.timezone import localtime

    current_user_profile = Users.objects.get(user=request.user)
    
    private_chats = PrivateChat.objects.filter(
        Q(user1=current_user_profile) | Q(user2=current_user_profile)
    )

    users_with_chats = {}

    for chat in private_chats:
        other_user_profile = chat.user2 if chat.user1 == current_user_profile else chat.user1
        other_user = other_user_profile.user

        latest_msg = Message.objects.filter(
            idchat=chat.id
        ).order_by('-date', '-time').values('date', 'time', 'text', 'username_user_username').first()

        last_sender = latest_msg['username_user_username'] if latest_msg else None

        if latest_msg:
            msg_date = latest_msg['date']
            msg_time = latest_msg['time']
            timestamp = (msg_date, msg_time)
            last_text = latest_msg['text']

            today = datetime.date.today()
            if msg_date == today:
                time_str = msg_time.strftime('%H:%M')
            elif msg_date == today - datetime.timedelta(days=1):
                time_str = "Ayer"
            else:
                time_str = msg_date.strftime('%d/%m/%Y')
        else:
            timestamp = (datetime.date(2000, 1, 1), datetime.time(0, 0))
            last_text = ""
            time_str = ""

        chat_id = chat.id.id if hasattr(chat.id, 'id') else chat.id.pk

        users_with_chats[other_user.id] = {
            'id': other_user.id,
            'username': other_user.username,
            'has_chat': True,
            'chat_id': chat_id,
            'lastMessage': last_text,
            'time': time_str,
            'lastSender': last_sender,
            'timestamp': timestamp
        }

    users_without_chats = User.objects.exclude(
        id__in=list(users_with_chats.keys()) + [request.user.id]
    ).order_by('username')

    result = []

    # Ordenar usuarios con chat por timestamp reciente
    users_with_chat_sorted = sorted(
        users_with_chats.values(),
        key=lambda x: x['timestamp'],
        reverse=True
    )

    for user_data in users_with_chat_sorted:
        user_data.pop('timestamp', None)  # quitarlo antes de enviar

    result.extend(users_with_chat_sorted)

    for user in users_without_chats:
        result.append({
            'id': user.id,
            'username': user.username,
            'has_chat': False
        })

    return Response(result)

