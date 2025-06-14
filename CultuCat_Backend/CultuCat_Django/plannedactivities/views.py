from django.shortcuts import render
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status

from .models import PlannedActivity
from eventos.models import Event
from accounts.models import Users
from calendars.models import Calendar

from django.utils import timezone
import datetime
from django.db import connection
from utils.notificaciones import send_fcm_notification

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_event_to_calendar(request):
    """
    Añade un evento al calendario del usuario actual (crea una PlannedActivity)
    
    Requiere: event_id en el cuerpo de la petición
    Devuelve: mensaje de éxito o error
    """
    # Obtener el ID del evento del cuerpo de la petición
    event_id = request.data.get('event_id')
    
    if not event_id:
        return Response({"error": "Se requiere el ID del evento (event_id)"}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Obtener el evento
        event = Event.objects.get(id=event_id)
    except Event.DoesNotExist:
        return Response({"error": f"El evento con ID {event_id} no existe"}, status=status.HTTP_404_NOT_FOUND)
    
    try:
        # Obtener el perfil del usuario actual
        user_profile = Users.objects.get(user=request.user)
        
        # Verificar si el usuario tiene un calendario asignado
        if not user_profile.idcalendar:
            try:
                # Crear un nuevo calendario generando un ID manualmente
                from django.db import connection
                with connection.cursor() as cursor:
                    # Primero obtenemos el máximo ID existente
                    cursor.execute("SELECT MAX(id) FROM calendar")
                    result = cursor.fetchone()
                    next_id = 1  # Valor por defecto si no hay calendarios
                    
                    if result[0] is not None:
                        next_id = result[0] + 1  # Siguiente ID disponible
                    
                    # Insertar directamente en la tabla calendar con un ID explícito
                    cursor.execute("INSERT INTO calendar (id) VALUES (%s)", [next_id])
                
                # Obtener el objeto Calendar recién creado
                calendar = Calendar.objects.get(id=next_id)
                
                # Asociar el calendario al perfil del usuario
                user_profile.idcalendar = calendar
                user_profile.save()
                
                calendar_created = True
                calendar_id = next_id
            except Exception as e:
                return Response({"error": f"Error al crear el calendario: {str(e)}"}, 
                               status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        else:
            calendar_created = False
            calendar_id = user_profile.idcalendar.id
        
        # Verificar si el evento ya está en el calendario del usuario
        # Usar raw query para evitar que Django busque una columna 'id'
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*) FROM plannedactivity WHERE idevt = %s AND idcalendar = %s",
                [event.id, user_profile.idcalendar.id]
            )
            count = cursor.fetchone()[0]
        
        if count > 0:
            return Response(
                {"message": "Este evento ya está en tu calendario"}, 
                status=status.HTTP_200_OK
            )
        
        # Crear la nueva actividad planificada usando SQL directo
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO plannedactivity (idevt, idcalendar) VALUES (%s, %s)",
                [event.id, user_profile.idcalendar.id]
            )
        
        # Preparar mensaje de respuesta
        response_data = {
            "message": f"Evento '{event.name}' añadido con éxito a tu calendario",
            "event_id": event.id,
            "event_name": event.name
        }
        
        # Añadir información sobre la creación del calendario si fue necesario
        if calendar_created:
            response_data["calendar_created"] = True
            response_data["calendar_id"] = calendar_id
        
        return Response(response_data, status=status.HTTP_201_CREATED)
        
    except Users.DoesNotExist:
        return Response({"error": "No se encontró el perfil de usuario"}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({"error": f"Error al añadir el evento: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def remove_event_from_calendar(request, event_id):
    """
    Elimina un evento del calendario del usuario actual
    
    Requiere: event_id en la URL
    Devuelve: mensaje de éxito o error
    """
    try:
        # Obtener el perfil del usuario actual
        user_profile = Users.objects.get(user=request.user)
        
        # Verificar si el usuario tiene un calendario asignado
        if not user_profile.idcalendar:
            return Response(
                {"error": "El usuario no tiene un calendario asociado"}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Usando SQL directo para evitar el error de búsqueda de columna id
        try:
            # Primero verificamos si el evento existe
            from django.db import connection
            with connection.cursor() as cursor:
                # Verificar si existe la actividad planificada y obtener el nombre en consultas separadas
                cursor.execute(
                    """
                    SELECT COUNT(*) 
                    FROM plannedactivity pa
                    WHERE pa.idevt = %s AND pa.idcalendar = %s
                    """,
                    [event_id, user_profile.idcalendar.id]
                )
                count = cursor.fetchone()[0]
                
                if count == 0:
                    return Response(
                        {"error": "Este evento no está en tu calendario"}, 
                        status=status.HTTP_404_NOT_FOUND
                    )
                
                # Obtener el nombre del evento en una consulta separada
                cursor.execute(
                    """
                    SELECT name
                    FROM event
                    WHERE id = %s
                    """,
                    [event_id]
                )
                event_name_result = cursor.fetchone()
                
                if not event_name_result:
                    event_name = "Desconocido"
                else:
                    event_name = event_name_result[0]
                
                # Eliminar la actividad planificada
                cursor.execute(
                    "DELETE FROM plannedactivity WHERE idevt = %s AND idcalendar = %s",
                    [event_id, user_profile.idcalendar.id]
                )
        
        except Exception as e:
            return Response(
                {"error": f"Error al buscar o eliminar el evento: {str(e)}"}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
        return Response({
            "message": f"Evento '{event_name}' eliminado exitosamente de tu calendario",
            "event_id": event_id
        }, status=status.HTTP_200_OK)
        
    except Users.DoesNotExist:
        return Response({"error": "No se encontró el perfil de usuario"}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({"error": f"Error al eliminar el evento: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_user_calendar_events(request):
    """
    Obtiene todos los eventos guardados en el calendario del usuario autenticado
    
    Devuelve: lista de eventos con detalles
    """
    try:
        # Obtener el perfil del usuario actual
        user_profile = Users.objects.get(user=request.user)
        
        # Verificar si el usuario tiene un calendario asignado
        if not user_profile.idcalendar:
            return Response(
                {"error": "El usuario no tiene un calendario asociado"}, 
                status=status.HTTP_404_NOT_FOUND
            )
            
        # Consultar los eventos del usuario con SQL directo para evitar problemas con las claves compuestas
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT e.id, e.name, e.description, e.inidate, e.enddate, 
                       a.address, a.latitude, a.longitude, a.zipcode
                FROM plannedactivity pa
                JOIN event e ON pa.idevt = e.id
                LEFT JOIN place a ON e.addressid = a.id
                WHERE pa.idcalendar = %s
                ORDER BY e.inidate, e.name
                """,
                [user_profile.idcalendar.id]
            )
            columns = [col[0] for col in cursor.description]
            events = [dict(zip(columns, row)) for row in cursor.fetchall()]
            
        # Si no hay eventos, devolver lista vacía con mensaje informativo
        if not events:
            return Response({
                "message": "No tienes eventos guardados en tu calendario",
                "events": []
            }, status=status.HTTP_200_OK)
        
        # Formatear fechas para JSON
        for event in events:
            if event['inidate']:
                event['inidate'] = event['inidate'].isoformat()
            if event['enddate']:
                event['enddate'] = event['enddate'].isoformat()
                
            # Crear objeto de dirección estructurado
            if event['address']:
                event['location'] = {
                    'address': event['address'],
                    'latitude': float(event['latitude']) if event['latitude'] else None,
                    'longitude': float(event['longitude']) if event['longitude'] else None,
                    'zipcode': event['zipcode']
                }
            else:
                event['location'] = None
                
            # Eliminar campos individuales de dirección para mantener la respuesta limpia
            del event['address']
            del event['latitude'] 
            del event['longitude']
            del event['zipcode']
        
        return Response({
            "message": f"Se encontraron {len(events)} eventos en tu calendario",
            "events": events
        }, status=status.HTTP_200_OK)
        
    except Users.DoesNotExist:
        return Response({"error": "No se encontró el perfil de usuario"}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({"error": f"Error al obtener eventos del calendario: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_event_reminders(request):
    """
    Envía notificaciones push recordatorias a los usuarios para eventos cuya fecha de finalización 
    es exactamente 7 días posterior a la fecha actual.
    
    Devuelve: mensaje de éxito o error
    """
    try:
        # Calcular fecha objetivo (7 días desde ahora)
        now = timezone.now()
        target_date = (now + datetime.timedelta(days=7)).date()
        
        # Obtener eventos cuya enddate coincide con la fecha objetivo
        events = Event.objects.filter(enddate__date=target_date)
        
        # Si no hay eventos en 7 días, retornar mensaje informativo de éxito
        if not events:
            return Response(
                {"message": "No hay eventos dentro de 7 días para enviar recordatorio"},
                status=status.HTTP_200_OK
            )
        
        # Recorrer cada evento y notificar a los usuarios correspondientes
        for event in events:
            # Obtener todos los usuarios que tienen este evento en su calendario (idcalendar en común)
            with connection.cursor() as cursor:
                cursor.execute("""
                    SELECT u.fcm_token
                    FROM plannedactivity pa
                    JOIN users u ON pa.idcalendar = u.idcalendar
                    WHERE pa.idevt = %s
                """, [event.id])
                user_tokens = [row[0] for row in cursor.fetchall() if row[0]]
            
            # Enviar una notificación a cada usuario (solo si tiene fcm_token)
            for token in user_tokens:
                send_fcm_notification(
                    token=token,
                    title="Recordatori d'esdeveniment",
                    body=f"Falta una setmana per a l'esdeveniment {event.name}",
                    data={
                        "type": "event_reminder",
                        "event_id": event.id,
                        "event_name": event.name
                    }
                )
        
        # Respuesta de éxito final
        return Response(
            {"message": "Notificaciones enviadas correctamente"},
            status=status.HTTP_200_OK
        )
    
    except Exception as e:
        # Manejo de errores inesperados
        return Response(
            {"error": f"Error al enviar recordatorios: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

