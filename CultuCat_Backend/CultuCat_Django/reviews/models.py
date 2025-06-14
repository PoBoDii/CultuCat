from django.db import models
from django.core.exceptions import ValidationError
from accounts.models import Users
from eventos.models import Event
from django.db.models import Q

# Clase Review --> Define la estructura de la tabla review
class Review(models.Model):
    # Campos que forman la clave primaria compuesta
    id = models.AutoField(primary_key=True, db_column='id')  # Campo ID único para la tabla review
    username = models.ForeignKey(Users, on_delete=models.CASCADE, db_column='username')
    event_id = models.ForeignKey(Event, on_delete=models.CASCADE, db_column='event_id')
    
    # Campos adicionales
    rating = models.IntegerField(null=True, blank=True)
    text = models.TextField(null=True, blank=True)
    
    class Meta:
        managed = False  # No queremos que Django modifique la tabla review porque ya está creada
        db_table = 'review'  # Nombre de la tabla en la base de datos
        
        constraints = [
            # Restricción de unicidad
            models.UniqueConstraint(
                fields=['username', 'id'],
                name='unique_user_event_review'
            ),
            # Restricción de valores para rating (entre 0 y 10)
            models.CheckConstraint(
                check=Q(rating__range=(0, 10)) | Q(rating__isnull=True),
                name='rating_between_0_and_10'
            ),
            # Restricción de que al menos uno de rating o text esté presente
            models.CheckConstraint(
                check=Q(rating__isnull=False) | ~Q(text__isnull=True, text=''),
                name='at_least_rating_or_text'
            )
        ]
    
    def __str__(self):
        return f"Review por {self.username} para {self.id}"
    
class LikedReview(models.Model):
    id = models.AutoField(primary_key=True, db_column='id')  # Campo ID único para la tabla de likes/dislikes
    event_id = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='likes', db_column='event_id')
    username = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='review_likes', db_column='username')
    user_liked = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='liked', db_column='user_liked')
    is_like = models.BooleanField(default=True, help_text="True para like, False para dislike")

    class Meta:
        managed = False
        db_table = 'likedreview'
        constraints = [
            models.UniqueConstraint(
                fields=['event_id', 'username', 'user_liked'],
                name='unique_event_user_like'
            )
        ]
        verbose_name = 'Like/Dislike de reseña'
        verbose_name_plural = 'Likes/Dislikes de reseñas'

    def __str__(self):
        return f"{'Like' if self.is_like else 'Dislike'} de {self.user_liked.user.username} para reseña de {self.username.user.username} en evento {self.event_id.id}"

