from rest_framework.decorators import api_view
from rest_framework.response import Response
from .models import Review, Event, Users, LikedReview
from .serializers import ReviewSerializer, LikedReviewSerializer
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.db import IntegrityError

from utils.notificaciones import send_fcm_notification



#VER REVIEWS

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def ver_reviews(request, evento_id):
    try:
        # Verificar primero si el evento existe
        evento = Event.objects.get(id=evento_id)
        
        # Si el evento existe, buscamos sus reseñas
        reviews = Review.objects.filter(event_id=evento)
        
        if not reviews.exists():
            # Si no hay reseñas, devolvemos un mensaje informativo pero con código 200
            # ya que no es un error que no haya reseñas
            return Response({"mensaje": "No hay reseñas para este evento"}, status=200)
            
        serializer = ReviewSerializer(reviews, many=True, context={'request': request})
        return Response(serializer.data, status=200)
        
    except Event.DoesNotExist:
        # Si el evento no existe, es un error 404
        return Response({"error": "Evento no encontrado"}, status=404)

#VER UNA REVIEW

@api_view(['GET'])
def ver_review_individual(request, evento_id, review_username):
    try:
        evento = Event.objects.get(id=evento_id)
        
        try:
            # Fetch the Users instance (author of the review) case-insensitively
            review_author = Users.objects.get(user__username__iexact=review_username)
        except Users.DoesNotExist:
            # If the author is not found by that username
            return Response({"error": "Usuario autor de la reseña no encontrado"}, status=404)
            
        # Fetch the review using the Event instance and the Users instance (review_author)
        review = Review.objects.get(event_id=evento, username=review_author)
        
        serializer = ReviewSerializer(review, context={'request': request})
        return Response(serializer.data, status=200)
            
    except Event.DoesNotExist:
        return Response({"error": "Evento no encontrado"}, status=404)
    except Review.DoesNotExist:
        return Response({"error": "La reseña no existe"}, status=404)


# CREAR REVIEW

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def crear_review(request, evento_id):
    try:
        # Sacamos el usuario y el evento de la propia request
        usuario = Users.objects.get(user=request.user)
        evento = Event.objects.get(id=evento_id)

        #Ahora procesamos primero el rating, ya que comprobamos que esté entre 1 y 5
        rating=request.data.get('rating')
        if rating is None:
            return Response({"error": "Es necesario poner un rating (Entero entre 1 y 5)"}, status=400)

        try:
            rating = int(rating)
        except ValueError:
            return Response({"error": "El rating debe ser un numero entero."}, status=400)

        if rating < 1 or rating > 5:
            return Response({"error": "El rating debe estar entre 1 y 5 estrellas."}, status=400)


        review = Review.objects.create(
            username=usuario,
            event_id=evento,  # Cambio de id a event_id
            rating=rating,
            text=request.data.get('text')
        )

        serializer = ReviewSerializer(review, context={'request': request})

        return Response(serializer.data, status=201)


    except Users.DoesNotExist:
        return Response({"error": "Usuario no encontrado"}, status=404)
    except Event.DoesNotExist:
        return Response({"error": "Evento no encontrado"}, status=404)
    except IntegrityError:
        return Response({"error": "Ya has publicado una review en este evento."}, status=400)



# BORRAR REVIEW

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def borrar_review(request, evento_id):
    try:
        usuario = Users.objects.get(user=request.user)
        evento = Event.objects.get(id=evento_id)

        # Buscamos las reviews utilizando el username y event_id
        # Usamos filter en lugar de get porque puede haber múltiples reseñas
        reviews = Review.objects.filter(username=usuario, event_id=evento)
        
        if not reviews.exists():
            return Response({"error": "No tienes ninguna review publicada en este evento."}, status=404)
        
        # Eliminar likes y dislikes asociados a estas reseñas antes de eliminarlas
        # Filtramos por event_id y username (autor de la reseña), no por user_liked
        LikedReview.objects.filter(event_id=evento, username=usuario).delete()
        
        # Ahora eliminar todas las reseñas encontradas
        reviews_count = reviews.count()
        reviews.delete()

        return Response({
            "mensaje": f"{reviews_count} review(s) eliminada(s) correctamente."
        }, status=200)

    except Users.DoesNotExist:
        return Response({"error": "Usuario no encontrado."}, status=404)
    except Event.DoesNotExist:
        return Response({"error": "Evento no encontrado."}, status=404)

# LIKE/DISLIKE REVIEW

@api_view(['POST', 'DELETE'])
@permission_classes([IsAuthenticated])
def gestionar_like_dislike(request, evento_id, review_username):
    """
    Gestiona likes/dislikes de reviews.
    - POST: Dar like/dislike a una review
    - DELETE: Eliminar like/dislike de una review
    """
    try:
        # Obtenemos el usuario que hace la acción (el que da o elimina like/dislike)
        user_liked = Users.objects.get(user=request.user)
        # Obtenemos el evento 
        evento = Event.objects.get(id=evento_id)
        # Obtenemos el usuario autor de la review
        review_user = Users.objects.get(user__username__iexact=review_username)
        
        # Verificamos que la review exista
        try:
            review = Review.objects.get(username=review_user, event_id=evento)
        except Review.DoesNotExist:
            return Response({"error": "La reseña no existe"}, status=404)
        
        # Procesamos según el método HTTP
        if request.method == 'POST':
            # Obtenemos el tipo de acción (like o dislike)
            is_like = request.data.get('is_like')
            if is_like is None:
                return Response({"error": "Es necesario especificar 'is_like' (true para like, false para dislike)"}, status=400)
            
            # Convertimos a booleano
            if isinstance(is_like, str):
                is_like = is_like.lower() == 'true'
            
            # Intentamos encontrar si ya existe un like/dislike previo del usuario actual a esta reseña
            try:
                liked_review = LikedReview.objects.get(
                    event_id=evento,
                    username=review_user,
                    user_liked=user_liked
                )
                # Si ya existe, actualizamos el valor
                liked_review.is_like = is_like
                liked_review.save()
                mensaje = "Like actualizado" if is_like else "Dislike actualizado"
            except LikedReview.DoesNotExist:
                # Si no existe, lo creamos
                try:
                    liked_review = LikedReview.objects.create(
                        event_id=evento,
                        username=review_user,
                        user_liked=user_liked,
                        is_like=is_like
                    )
                    mensaje = "Like agregado" if is_like else "Dislike agregado"
                except Exception as e:
                    return Response({"error": f"Error al guardar like/dislike: {str(e)}"}, status=400)
            
            # Recalcular contadores para la respuesta
            likes = LikedReview.objects.filter(event_id=evento, username=review_user, is_like=True).count()
            dislikes = LikedReview.objects.filter(event_id=evento, username=review_user, is_like=False).count()

            # ENVÍO DE NOTIFICACIÓN PUSH AL AUTOR DE LA RESEÑA
            try:
                if review_user.fcm_token and review_user.user != request.user:
                    print("Enviando notificación a " + review_user.user.username + " con token: " + review_user.fcm_token);
                    accion = "le ha dado like" if is_like else "le ha dado dislike"
                    cuerpo = f"{user_liked.user.username} {accion} a tu reseña"

                    send_fcm_notification(
                        token=review_user.fcm_token,
                        title='Nueva reacción a tu reseña',
                        body=cuerpo,
                        data={
                            'type': 'like_review',
                            'evento_id': str(evento.id),
                            'username': user_liked.user.username
                        }
                    )
            except Exception as e:
                print(f"Error al enviar notificación push: {str(e)}")
            
            return Response({
                "mensaje": mensaje, 
                "likes_count": likes,
                "dislikes_count": dislikes,
                "user_liked": is_like
            }, status=200)
            
        elif request.method == 'DELETE':
            # Intentamos encontrar y eliminar el like/dislike específico
            try:
                # Buscar el like/dislike específico que el usuario actual ha dado a esta reseña
                liked_review = LikedReview.objects.get(
                    event_id=evento,
                    username=review_user,
                    user_liked=user_liked
                )
                
                # Guardamos el valor antes de eliminar para la respuesta
                was_like = liked_review.is_like
                
                # Eliminar el like/dislike encontrado
                liked_review.delete()
                
                # Recalcular contadores para la respuesta
                likes = LikedReview.objects.filter(event_id=evento, username=review_user, is_like=True).count()
                dislikes = LikedReview.objects.filter(event_id=evento, username=review_user, is_like=False).count()
                
                return Response({
                    "mensaje": "Like/Dislike eliminado correctamente", 
                    "likes_count": likes,
                    "dislikes_count": dislikes,
                    "user_liked": None
                }, status=200)
            except LikedReview.DoesNotExist:
                return Response({"error": "No has dado like/dislike a esta reseña"}, status=404)
    
    except Users.DoesNotExist:
        return Response({"error": "Usuario no encontrado"}, status=404)
    except Event.DoesNotExist:
        return Response({"error": "Evento no encontrado"}, status=404)
    except Exception as e:
        return Response({"error": str(e)}, status=400)

# Ya no es necesario este endpoint, ya que los likes/dislikes vienen incluidos en cada reseña
# Mantenemos el código comentado por si se necesita referencia
"""
@api_view(['GET'])
def obtener_likes_dislikes(request, evento_id, review_username=None):
    try:
        # Obtenemos el evento
        evento = Event.objects.get(id=evento_id)
        
        # Si se proporciona un username específico, filtrar por ese usuario
        if review_username:
            try:
                review_user = Users.objects.get(username=review_username)                # Verificamos que la review exista
                try:
                    review = Review.objects.get(username=review_user, event_id=evento)
                except Review.DoesNotExist:
                    return Response({"error": "La reseña no existe"}, status=404)
                  # Obtenemos los likes/dislikes para esta review específica
                liked_reviews = LikedReview.objects.filter(event_id=evento)
                serializer = LikedReviewSerializer(liked_reviews, many=True)
                
                # Contamos likes y dislikes
                likes_count = sum(1 for lr in liked_reviews if lr.is_like)
                dislikes_count = len(liked_reviews) - likes_count
                
                return Response({
                    "likes": likes_count,
                    "dislikes": dislikes_count,
                    "details": serializer.data
                }, status=200)
            except Users.DoesNotExist:
                return Response({"error": "Usuario de la reseña no encontrado"}, status=404)
          # Si no se proporciona un username, obtenemos y agrupamos todos los likes/dislikes para el evento
        reviews = Review.objects.filter(event_id=evento)
        result = []
        
        for review in reviews:
            # Para cada review, obtenemos sus likes/dislikes
            liked_reviews = LikedReview.objects.filter(event_id=evento, username__username=review.username.username)
            likes_count = sum(1 for lr in liked_reviews if lr.is_like)
            dislikes_count = len(liked_reviews) - likes_count
            
            review_data = {
                "username": review.username.username,
                "event_id": evento_id,
                "likes": likes_count,
                "dislikes": dislikes_count
            }
            result.append(review_data)
        
        return Response(result, status=200)
    
    except Event.DoesNotExist:
        return Response({"error": "Evento no encontrado"}, status=404)
"""

# Ver reviews ordenadas por likes-dislikes
@api_view(['GET'])
def ver_reviews_ordenadas(request, evento_id):
    try:
        # Verificar primero si el evento existe
        evento = Event.objects.get(id=evento_id)
        
        # Si el evento existe, buscamos sus reseñas
        reviews = Review.objects.filter(event_id=evento)
        
        if not reviews.exists():
            # Si no hay reseñas, devolvemos un mensaje informativo pero con código 200
            # ya que no es un error que no haya reseñas
            return Response({"mensaje": "No hay reseñas para este evento"}, status=200)
            
        # Preparamos una lista para almacenar las reseñas con sus métricas
        reviews_con_metricas = []
        
        # Para cada reseña, calculamos sus likes, dislikes y coeficiente
        for review in reviews:
            # Obtener likes y dislikes
            likes = LikedReview.objects.filter(event_id=evento, username=review.username, is_like=True).count()
            dislikes = LikedReview.objects.filter(event_id=evento, username=review.username, is_like=False).count()
            
            # Calcular el coeficiente likes-dislikes y total de votos
            coeficiente = likes - dislikes
            total_votos = likes + dislikes
            
            # Añadir a nuestra lista
            reviews_con_metricas.append({
                'review': review,
                'coeficiente': coeficiente,
                'total_votos': total_votos
            })
        
        # Ordenar la lista: primero por coeficiente (mayor a menor) y en caso de empate por total de votos (mayor a menor)
        reviews_ordenadas = sorted(
            reviews_con_metricas,
            key=lambda x: (x['coeficiente'], x['total_votos']),
            reverse=True
        )
        
        # Extraer solo las reseñas ordenadas
        reviews_resultado = [item['review'] for item in reviews_ordenadas]
            
        serializer = ReviewSerializer(reviews_resultado, many=True, context={'request': request})
        return Response(serializer.data, status=200)
        
    except Event.DoesNotExist:
        # Si el evento no existe, es un error 404
        return Response({"error": "Evento no encontrado"}, status=404)


# Ver reviews de un usuario ordenadas por likes-dislikes

@api_view(['GET'])
def ver_reviews_usuario_ordenadas(request, username):
    try:
        # Verificar que el usuario exista
        user = Users.objects.get(user=username)

        # Obtener todas las reviews del usuario
        reviews = Review.objects.filter(username=user)

        if not reviews.exists():
            return Response({"mensaje": "Este usuario no ha escrito reseñas"}, status=200)

        reviews_con_metricas = []

        for review in reviews:
            # Likes y dislikes de esta review (por evento + usuario)
            likes = LikedReview.objects.filter(id=review.id, username=user, is_like=True).count()
            dislikes = LikedReview.objects.filter(id=review.id, username=user, is_like=False).count()

            coeficiente = likes - dislikes
            total_votos = likes + dislikes

            reviews_con_metricas.append({
                'review': review,
                'coeficiente': coeficiente,
                'total_votos': total_votos
            })

        reviews_ordenadas = sorted(
            reviews_con_metricas,
            key=lambda x: (x['coeficiente'], x['total_votos']),
            reverse=True
        )

        reviews_resultado = [item['review'] for item in reviews_ordenadas]

        serializer = ReviewSerializer(reviews_resultado, many=True, context={'request': request})
        return Response(serializer.data, status=200)

    except Users.DoesNotExist:
        return Response({"error": "Usuario no encontrado"}, status=404)

