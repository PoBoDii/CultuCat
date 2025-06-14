from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q
from django.utils import timezone

from eventchats.models import EventChat
from chat_messages.models import Message
from chats.models import Chat
from accounts.models import Users
from datetimes.models import DateTime



@api_view(['POST'])
@permission_classes([IsAuthenticated])
def join_event_chat(request):
    """
    Permite a un usuario unirse al chat de un evento.
    Si el chat no existe, se crea automáticamente.
    
    Requiere: event_id en el cuerpo de la petición
    Devuelve: ID del chat y un indicador si fue creado o ya existía
    """
    user_profile = Users.objects.get(user=request.user)
    event_id = request.data.get('event_id')

    if not event_id:
        return Response({'error': 'Falta el parámetro event_id'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Intentar recuperar un EventChat existente relacionado con el evento
        from eventos.models import Event
        try:
            # Primero verificar si el evento existe
            event = Event.objects.get(id=event_id)
        except Event.DoesNotExist:
            return Response({'error': f'No existe un evento con ID {event_id}'}, status=status.HTTP_404_NOT_FOUND)
            
        # Buscar si ya existe un chat para este evento
        event_chat = None
        is_new = False
        
        # Si el evento tiene idchat directo, usamos ese
        if hasattr(event, 'idchat') and event.idchat:
            try:
                # Accedemos al ID numérico del chat
                chat_id_num = event.idchat.id if hasattr(event.idchat, 'id') else event.idchat.pk
                event_chat = EventChat.objects.get(id_id=chat_id_num)
            except (EventChat.DoesNotExist, AttributeError):
                pass
                
        # Si no encontramos el chat por la relación directa, buscamos por ID del evento
        if not event_chat:
            # Intentamos buscar un chat de evento con el mismo ID numérico del evento
            event_chat = EventChat.objects.filter(id_id=event_id).first()
            
        # Si sigue sin existir, creamos uno nuevo
        if not event_chat:
            # Crear un nuevo chat genérico
            chat_base = Chat.objects.create(type=Chat.ChatType.EVENT_CHAT)
            # Crear EventChat asociado
            event_chat = EventChat.objects.create(id=chat_base)
            is_new = True
            
            # Si el evento no tiene chat asignado, actualizamos su referencia
            if hasattr(event, 'idchat') and not event.idchat:
                event.idchat = chat_base  # Asignamos el objeto Chat, no EventChat
                event.save()
        
        # Obtenemos el ID del chat para devolver en la respuesta
        # Usamos acceso seguro a las propiedades
        if hasattr(event_chat.id, 'id'):
            chat_id = event_chat.id.id  # Si id es un objeto con su propio id
        else:
            chat_id = event_chat.id.pk  # Alternativa usando pk
        
        return Response({
            "chat_id": chat_id,
            "is_new": is_new,
            "event_name": event.name,
            "message": "Te has unido al chat del evento exitosamente"
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({'error': f'Error al unirse al chat: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_event_messages(request, chat_id):
    """
    Devuelve todos los mensajes de un chat de evento.
    
    Requiere: chat_id en la URL
    Devuelve: Lista de mensajes ordenados por fecha y hora
    """
    try:
        user_profile = Users.objects.get(user=request.user)

        try:
            # Verificar que el chat existe y es de tipo evento
            chat = Chat.objects.get(id=chat_id)
            if chat.type != Chat.ChatType.EVENT_CHAT:
                return Response({'error': 'El chat especificado no es un chat de evento'}, status=status.HTTP_400_BAD_REQUEST)
                
            event_chat = EventChat.objects.get(id=chat_id)
        except (EventChat.DoesNotExist, Chat.DoesNotExist):
            return Response({'error': 'Chat de evento no encontrado'}, status=status.HTTP_404_NOT_FOUND)

        # Obtener mensajes ordenados por fecha y hora
        messages = Message.objects.filter(idchat=event_chat.id).order_by('date', 'time').values(
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

        if not data:
            return Response({
                'message': 'No hay mensajes en este chat todavía',
                'messages': []
            }, status=status.HTTP_200_OK)
            
        return Response({
            'message': f'Se encontraron {len(data)} mensajes',
            'messages': data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al obtener mensajes: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_event_message(request):
    """
    Envía un mensaje al chat de un evento.
    
    Requiere: chat_id y message en el cuerpo de la petición
    Devuelve: Detalles del mensaje enviado
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        chat_id = request.data.get('chat_id')
        text = request.data.get('message')

        if not chat_id or not text:
            return Response({'error': 'Parámetros obligatorios: chat_id y message'}, status=status.HTTP_400_BAD_REQUEST)

        # Verificar que el chat existe y es de tipo evento
        try:
            chat = Chat.objects.get(id=chat_id)
            if chat.type != Chat.ChatType.EVENT_CHAT:
                return Response({'error': 'El chat especificado no es un chat de evento'}, status=status.HTTP_400_BAD_REQUEST)
                
            event_chat = EventChat.objects.get(id=chat_id)
        except (EventChat.DoesNotExist, Chat.DoesNotExist):
            return Response({'error': 'Chat de evento no encontrado'}, status=status.HTTP_404_NOT_FOUND)

        # Obtener fecha y hora actuales
        now = timezone.now()
        date = now.date()
        time = now.time().replace(microsecond=0)
        
        # Asegurar que existe el registro DateTime correspondiente
        dt, _ = DateTime.objects.get_or_create(date=date, time=time)

        # Guardar el mensaje usando SQL directo
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute("""
                INSERT INTO message (date, time, username, idchat, text, filepath)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, [date, time, user_profile.pk, event_chat.id.pk, text, None])

        
        return Response({
            'message': 'Mensaje enviado correctamente',
            'details': {
                'senderUsername': request.user.username,
                'message': text,
                'date': str(date),
                'time': str(time),
            }
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        return Response({'error': f'Error al enviar mensaje: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_my_event_chats(request):
    """
    Lista todos los chats de eventos del usuario, ordenados por el último mensaje (del más reciente al más antiguo).
    
    Devuelve: Lista de chats de eventos con el último mensaje de cada uno
    """
    try:
        user_profile = Users.objects.get(user=request.user)
        
        # Obtener todos los chats de eventos que tienen al menos un mensaje del usuario
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute('''
                SELECT DISTINCT e.id, e.name as event_name, c.id as chat_id
                FROM message m
                JOIN chat c ON m.idchat = c.id AND c.type = 'EventChat'
                JOIN eventchat ec ON c.id = ec.id
                JOIN event e ON e.idchat = ec.id
                WHERE m.username = %s
            ''', [user_profile.user.username])
            
            columns = [col[0] for col in cursor.description]
            event_chats = [dict(zip(columns, row)) for row in cursor.fetchall()]
        
        # Si no hay chats de eventos
        if not event_chats:
            return Response({
                'message': 'No tienes chats de eventos activos',
                'event_chats': []
            }, status=status.HTTP_200_OK)
        
        # Para cada chat, obtener el último mensaje
        event_chats_data = []
        for event_chat in event_chats:
            chat_id = event_chat['chat_id']
            
            # Obtener el último mensaje del chat
            with connection.cursor() as cursor:
                cursor.execute('''
                    SELECT m.date, m.time, u.username, m.text
                    FROM message m
                    JOIN auth_user u ON m.username = u.username
                    WHERE m.idchat = %s
                    ORDER BY m.date DESC, m.time DESC
                    LIMIT 1
                ''', [chat_id])
                
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
            
            event_chats_data.append({
                'event_id': event_chat['id'],
                'event_name': event_chat['event_name'],
                'chat_id': chat_id,
                'last_message': last_message,
                'last_activity': last_activity  # Campo temporal para ordenación
            })
        
        # Ordenar por actividad reciente (último mensaje)
        event_chats_data.sort(key=lambda x: x['last_activity'], reverse=True)
        
        # Eliminar el campo temporal de ordenación
        for chat_data in event_chats_data:
            del chat_data['last_activity']
        
        return Response({
            'message': f'Se encontraron {len(event_chats_data)} chats de eventos',
            'event_chats': event_chats_data
        }, status=status.HTTP_200_OK)
    
    except Exception as e:
        return Response({'error': f'Error al listar chats de eventos: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
