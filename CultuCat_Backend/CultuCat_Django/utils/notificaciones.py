from firebase.firebase_init import *
from firebase_admin import messaging

# Notificación visible
def send_fcm_notification(token, title, body, data=None):
    print(f"[NOTIFICACIO] Enviant a {token} amb title: {title}")

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
            data=data or {}
        )

        response = messaging.send(message)
        return {'success': True, 'response_id': response}

    except Exception as e:
        return {'success': False, 'error': str(e)}



# Notificación invisible para actualizar chats (only data)
def send_fcm_data_message(token, data):
    print(f"[NOTIFICACIO] Enviant DATA message a {token} amb data: {data}")

    try:
        message = messaging.Message(
            token=token,
            data=data or {}
        )

        response = messaging.send(message)
        return {'success': True, 'response_id': response}

    except Exception as e:
        return {'success': False, 'error': str(e)}
