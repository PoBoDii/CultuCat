from django.http import JsonResponse
from django.db.models import F, ExpressionWrapper, FloatField
from django.db.models.functions import Cast 
import math 
from django.contrib.postgres.search import TrigramSimilarity
from django.db.models.functions import Sin, Cos, ATan2, Sqrt, Power
from django.db.models import Value
from django.views.decorators.csrf import csrf_exempt

from categoriaevents.models import CategoriaEvent
from tematicaactivitats.models import TematicaActivitat
from eventos.models import Event
import json
import requests

# Funcion para buscar información y montar el JSON
def make_json(events):
    events_all = []
    for event in events:
        # Obtener las categorias del evento
        categories = CategoriaEvent.objects.filter(id=event.id).values_list('name', flat=True)

        # Obtener las temáticas del evento
        tematiques = TematicaActivitat.objects.filter(id=event.id).values_list('name', flat=True)

        events_all.append({
            'name': event.name,
            'imagepath': event.imagepath.path,
            'description': event.description,
            'start date': event.inidate,
            'end date': event.enddate,
            'addressid': {
                'address': event.addressid.address,
                'latitude': float(event.addressid.latitude),
                'longitude': float(event.addressid.longitude),
            },
            'categories': list(categories),
            'tematiques': list(tematiques),
        })
    return events_all

# Endpoint para obtener los datos básicos y localización de los eventos
def events_all_service(request):
    #try:
    # Obtener todos los eventos
    events = Event.objects.select_related('addressid').all()

    # Crear una lista con los datos necesarios para el servicio de los eventos
    events_all = make_json(events)

    return JsonResponse({'events': events_all}, safe=False)


    """
    Endpoint para buscar eventos por nombre y ordenarlos por cercanía geográfica.
    
    Parámetros de la petición:
    - latitude: latitud del usuario (float)
    - longitude: longitud del usuario (float)
    - query: texto a buscar en el nombre del evento (string)
    
    Ejemplo de uso:
    http://127.0.0.1:8000/service/events-search?latitude=41.3851&longitude=2.1734&query=ba
    http://nattech.fib.upc.edu:40340/service/events-search?latitude=41.3851&longitude=2.1734&query=ba
    
    Retorna:
    - Lista JSON de eventos que coinciden con el texto de búsqueda, ordenados por cercanía
    """

def search_events_service(request):
    try:
        # Obtener parámetros de la petición
        user_lat = float(request.GET.get('latitude', 0))
        user_lon = float(request.GET.get('longitude', 0))
        query = request.GET.get('query', '')

        if not query or not user_lon or not user_lat:
            return JsonResponse({'error': 'Es necesario aportar la posición del usuario (latitud y longitud) y el texto buscado.'}, status=400)

        # Validar coordenadas
        if not (-90 <= user_lat <= 90) or not (-180 <= user_lon <= 180):
            return JsonResponse({'error': 'Coordenadas inválidas'}, status=400)

        # Buscar eventos que coincidan con el nombre (filtro parcial)
        events = Event.objects.filter(name__icontains=query)

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

        # Ordenar por distancia
        events = events.order_by('distance')

        # Preparar datos para respuesta JSON
        events_data = make_json(events)

        return JsonResponse({
            'count': len(events_data),
            'results': events_data
        })

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@csrf_exempt
def calcular_ruta(request):
    if request.method != "POST":
        return JsonResponse({"error": "Method not allowed"}, status=405)

    try:
        data = json.loads(request.body)

        originLat = data.get("originLat")
        originLng = data.get("originLng")
        destinationLat = data.get("destinationLat")
        destinationLng = data.get("destinationLng")
        mode = data.get("mode")
        preference = data.get("preference")

        if None in [originLat, originLng, destinationLat, destinationLng, mode, preference]:
            return JsonResponse({"error": "Missing parameters"}, status=400)

        url = "https://e-movebcn-back.onrender.com/api/public/calcular"
        headers = {
            "x-api-key": "c1eaca04fc20bc7df0bd4672c6a0128eb6bb18f6902f5d37db30388e00e6b971",
            "Content-Type": "application/json"
        }
        payload = {
            "originLat": originLat,
            "originLng": originLng,
            "destinationLat": destinationLat,
            "destinationLng": destinationLng,
            "mode": mode,
            "preference": preference
        }

        response = requests.post(url, headers=headers, json=payload)

        if response.status_code != 200:
            return JsonResponse({"error": "Error from external API", "details": response.text}, status=502)

        data_response = response.json()

        # Eliminar instrucciones
        data_response.pop("instructions", None)

        return JsonResponse(data_response, status=200)

    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)
    except Exception as e:
        return JsonResponse({"error": "Internal server error", "details": str(e)}, status=500)