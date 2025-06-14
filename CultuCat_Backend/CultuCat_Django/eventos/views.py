from django.http import JsonResponse
from django.db.models import F, ExpressionWrapper, FloatField, Q, Avg, Count, Case, When, Value
from django.db.models.functions import Cast 
import math 
from django.contrib.postgres.search import TrigramSimilarity
from django.db.models.functions import Sin, Cos, ATan2, Sqrt, Power

from categoriaevents.models import CategoriaEvent
from tematicaactivitats.models import TematicaActivitat
from eventos.models import Event
from reviews.models import Review

from files.models import File
from places.models import Place
from chats.models import Chat

from django.utils.dateparse import parse_date

from django.contrib.auth.models import User
from accounts.models import Users

from utils.notificaciones import send_fcm_notification




# Endpoint para obtener los datos básicos y localización de los eventos
def events_list(request):
    # Obtener todos los eventos
    events = Event.objects.select_related('addressid').all()

    # Crear una lista con los datos básicos de los eventos
    events_list = []

    for event in events:
        events_list.append({
            'eventid': event.id,
            'name': event.name,
            'imagepath': event.imagepath.path,
            'codeevent': event.codeevent,
            'addressid': {
                'address': event.addressid.address,
                'latitude': float(event.addressid.latitude),
                'longitude': float(event.addressid.longitude),
                'zipcode': event.addressid.zipcode,
                'addressid': event.addressid.id
            }   
        })

    return JsonResponse({'events': events_list}, safe=False)

# Endpoint para obtener todos los datos de un evento
def event_detail(request, event_id):
    try:
        # Obtener todos los eventos
        event = Event.objects.select_related('addressid', 'idchat', 'imagepath').get(id=event_id)

        # Obtener las categorias del evento
        categories = CategoriaEvent.objects.filter(id=event.id).values_list('name', flat=True)        # Obtener las temáticas del evento
        tematiques = TematicaActivitat.objects.filter(id=event.id).values_list('name', flat=True)
          # Calcular la puntuación media de las reviews (solo incluyendo aquellas con puntuación)
        # Usamos id=event porque id es el nombre de la FK en Review que apunta a Event
        avg_rating = Review.objects.filter(id=event.id, rating__isnull=False).aggregate(avg_rating=Avg('rating'))
        average_rate = avg_rating['avg_rating'] if avg_rating['avg_rating'] is not None else 0
        
        # Extraer ID del chat de manera segura
        try:
            chat_id = event.idchat_id  # Acceder directamente al valor de la columna Foreign Key
        except Exception as e:
            print(f"Error accediendo a idchat_id: {e}")
            try:
                chat_id = event.idchat.pk if event.idchat else None
            except Exception as e2:
                print(f"Error accediendo a idchat.pk: {e2}")
                chat_id = None
          # Construir el diccionario con datos serializables
        event_data = {
            'eventid': event.id,
            'inidate': event.inidate.isoformat() if event.inidate else None,
            'enddate': event.enddate.isoformat() if event.enddate else None,
            'name': event.name,
            'description': event.description if event.description else '---',
            'tickets': event.tickets if event.tickets else '---',
            'schedule': event.schedule if event.schedule else '---',
            'link': event.link if event.link else '---',
            'email': event.email if event.email else '---',
            'telefon': event.telefon if event.telefon else '---',
            'addressid': {
                'address': event.addressid.address,
                'latitude': float(event.addressid.latitude),
                'longitude': float(event.addressid.longitude),
                'zipcode': event.addressid.zipcode,
                'addressid': event.addressid.id
            },
            'idchat': chat_id,  # Usar el ID extraído directamente
            'imagepath': event.imagepath.path if hasattr(event.imagepath, 'path') else str(event.imagepath),
            'codeevent': event.codeevent,
            'average_rate': float(average_rate),  # Incluir el rating promedio
            'categories': list(categories),
            'tematiques': list(tematiques),
            'average_rate': float(average_rate) if average_rate is not None else 0,
        }

        # Verificar que todos los valores son serializables antes de enviar la respuesta
        try:
            import json
            # Intentar serializar para detectar problemas temprano
            
            #json.dumps(event_data)
            #return JsonResponse({'event': event_data}, safe=False)

            json.dumps(event_data)

            return JsonResponse({'event': event_data}, safe=False)
   
        except TypeError as e:
            # Si hay un error de serialización, log e identificar el campo problemático
            import traceback
            print(f"Error de serialización: {e}")
            traceback.print_exc()
            
            # Última opción: forzar conversión a valores primitivos
            for key in event_data:
                if key != 'addressid':  # Preservar el diccionario addressid
                    event_data[key] = str(event_data[key])
                else:
                    for addr_key in event_data[key]:
                        event_data[key][addr_key] = str(event_data[key][addr_key])
            
            return JsonResponse({
                'event': event_data, 
                'error': 'Algunos campos fueron convertidos a string para permitir serialización'
            }, safe=False)
    
    except Event.DoesNotExist:
        return JsonResponse({'error': 'Event does not exist'}, status=404)
    except Exception as e:
        import traceback
        print(f"Error en event_detail: {e}")
        traceback.print_exc()
        return JsonResponse({'error': str(e)}, status=500)

# Endpoint para obtener los eventos ordenados por rating promedio
def events_by_rating(request):
    # Obtener todos los eventos con sus puntuaciones medias
    events = Event.objects.select_related('addressid').annotate(
        # La relación es desde review.id (FK) hacia event, así que usamos review__rating correctamente
        average_rate=Avg('review__rating', filter=Q(review__rating__isnull=False)),
        num_reviews=Count('review', filter=Q(review__rating__isnull=False))
    )
      # Ordenamos para asegurar que los eventos con rating aparezcan primero
    # Usamos Case para manejar NULLs correctamente y obtener el orden correcto
    events = events.annotate(
        has_rating=Case(
            When(average_rate__isnull=False, then=Value(1)),
            default=Value(0),
            output_field=FloatField()
        )
    ).order_by('-has_rating', '-average_rate', '-num_reviews')
    
    # Crear una lista con los datos básicos de los eventos
    events_list = []

    for event in events:
        # Calcular la puntuación media (puede ser None si no hay reviews)
        avg_rating = event.average_rate if event.average_rate is not None else 0
        
        events_list.append({
            'eventid': event.id,
            'name': event.name,
            'imagepath': event.imagepath.path if hasattr(event.imagepath, 'path') else str(event.imagepath),
            'codeevent': event.codeevent,
            'average_rate': float(avg_rating),
            'num_reviews': event.num_reviews,
            'addressid': {
                'address': event.addressid.address,
                'latitude': float(event.addressid.latitude),
                'longitude': float(event.addressid.longitude),
                'zipcode': event.addressid.zipcode,
                'addressid': event.addressid.id
            }   
        })

    return JsonResponse({'events': events_list}, safe=False)

    """
    Endpoint para buscar eventos por nombre y ordenarlos por cercanía geográfica.
    
    Parámetros de la petición:
    - latitude: latitud del usuario (float)
    - longitude: longitud del usuario (float)
    - query: texto a buscar en el nombre del evento (string)
    
    Retorna:
    - Lista JSON de eventos que coinciden con el texto de búsqueda, ordenados por cercanía
    """
def search_events(request):
    try:
        # Obtener parámetros de la petición
        user_lat = float(request.GET.get('latitude', 0))
        user_lon = float(request.GET.get('longitude', 0))
        query = request.GET.get('query', '')
        # Parámetros de la petición que harán de filtros
        max_distance = request.GET.get('max_distance')
        category = request.GET.get('category')
        # Fechas, ponerlas en YYYY-MM-DD
        start_date = request.GET.get('start_date')
        end_date = request.GET.get('end_date')
        exact_date = request.GET.get('exact_date')

        # Verificar si al menos uno de los filtros está presente
        if not (query or max_distance or category or start_date or end_date or exact_date):
            return JsonResponse({'error': 'Debe proporcionar al menos un filtro (búsqueda, distancia, categoría, etc.).'}, status=400)
        
        # Verificar que se proporcionan latitud y longitud
        if not user_lat or not user_lon:
            return JsonResponse({'error': 'Es necesario aportar la posición del usuario (latitud y longitud).'}, status=400)

        # Validar coordenadas
        if not (-90 <= user_lat <= 90) or not (-180 <= user_lon <= 180):
            return JsonResponse({'error': 'Coordenadas inválidas'}, status=400)

        # Buscar eventos que coincidan con el nombre (filtro parcial)
        events = Event.objects.filter(name__icontains=query)

        # Filtros de categoria
        category_param = request.GET.get('category')
        if category_param:
            category_list = [
                f"agenda:categories/{c.strip()}" 
                for c in category_param.split(',') 
                if c.strip()
            ]
            if category_list:
                events = events.filter(categoriaevent__name__in=category_list)

        # Filtro de intervalo de fechas
        if start_date and end_date:
            start = parse_date(start_date)
            end = parse_date(end_date)
            if start and end:
                events = events.filter(inidate__range=[start, end])
            else:
                return JsonResponse({'error': 'Fechas inválidas (start_date o end_date)'}, status=400)
        #Filtro de fecha exacta
        elif exact_date:
            date_parsed = parse_date(exact_date)
            if date_parsed:
                events = events.filter(inidate__date=date_parsed)
            else:
                return JsonResponse({'error': 'Fecha inválida (date)'}, status=400)


        # Calcular la distancia para cada evento usando la fórmula haversine (fórmula de cálculo de distancias en el globo terráqueo)
        # Con annotate añadimos a cada evento las coordenadas del usuario y evento convertidas a radianes
        events = events.annotate(
            # Coordenadas del evento
            lat_rad=Cast(F('addressid__latitude') * math.pi / 180, FloatField()),
            lon_rad=Cast(F('addressid__longitude') * math.pi / 180, FloatField()),
            # Coordenadas del usuario
            user_lat_rad=Value(user_lat * math.pi / 180, FloatField()),
            user_lon_rad=Value(user_lon * math.pi / 180, FloatField())
        )

        # Calculamos la distancia usando la fórmula haversine
        R = 6371  # Radio de la Tierra en km

        # Fórmula haversine implementada como expresión de Django
        # a = sin²(Δlat/2) + cos(lat1) · cos(lat2) · sin²(Δlong/2)
        # c = 2 · atan2(√a, √(1−a))
        # d = R · c

        events = events.annotate(
            dlat=ExpressionWrapper(F('lat_rad') - F('user_lat_rad'), output_field=FloatField()),
            dlon=ExpressionWrapper(F('lon_rad') - F('user_lon_rad'), output_field=FloatField()),
            a=ExpressionWrapper(
                Power(Sin(F('dlat') / 2), 2) + 
                Cos(F('user_lat_rad')) * Cos(F('lat_rad')) * 
                Power(Sin(F('dlon') / 2), 2),
                output_field=FloatField()
            ),
            distance=ExpressionWrapper(
                2 * R * ATan2(Sqrt(F('a')), Sqrt(1 - F('a'))),
                output_field=FloatField()
            )
        )

        # Filtro de distancia
        if max_distance:
            try:
                max_km = float(max_distance)
                events = events.filter(distance__lte=max_km)
            except ValueError:
                return JsonResponse({'error': 'max_distance debe ser un número válido'}, status=400)

        # Ordenar por distancia (más cercanos primero)
        events = events.order_by('distance')


        # Preparar datos para respuesta JSON
        events_data = list(events.values(
            'id','name', 'imagepath__path','codeevent',
            'addressid__address', 'addressid__latitude', 'addressid__longitude', 'addressid__zipcode', 'addressid__id', 'distance'))    

        return JsonResponse({
            'count': len(events_data),
            'results': events_data
        })

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
