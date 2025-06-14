from django.db import models
from accounts.models import Users
from django.core.validators import MinLengthValidator
from django.utils import timezone 
from django.core.exceptions import ValidationError

# Class FriendshipRequest --> Define la estructura de la tabla FriendshipRequest
class FriendshipRequest(models.Model):
    STATUS_CHOICES = [
        ('Pendiente', 'Pendiente'),
        ('Aceptado', 'Aceptado'),
        ('Rechazado', 'Rechazado'),
    ]

    id = models.AutoField(primary_key=True)
    request_date = models.DateTimeField(auto_now_add=True, verbose_name='Fecha de solicitud')
    status = models.CharField(max_length=10,choices=STATUS_CHOICES,default='Pendiente',verbose_name='Estado')
    response_date = models.DateTimeField(null=True, blank=True, verbose_name='Fecha de respuesta')
    user_orderer = models.ForeignKey(Users,on_delete=models.CASCADE,related_name='sent_requests',to_field='user',verbose_name='Usuario solicitante', db_column='user_orderer')
    user_ordered = models.ForeignKey(Users,on_delete=models.CASCADE,related_name='received_requests',to_field='user',verbose_name='Usuario receptor', db_column='user_ordered')

    class Meta:
        managed = False  # No queremos que Django modifique la tabla porque ya está creada
        db_table = 'friendshiprequest'

        verbose_name = 'Solicitud de amistad'
        verbose_name_plural = 'Solicitudes de amistad'
        constraints = [
            models.CheckConstraint(
                check=models.Q(
                    (models.Q(status__in=['Aceptado', 'Rechazado']) & models.Q(response_date__isnull=False)) |
                    (models.Q(status='Pendiente') & models.Q(response_date__isnull=True))
                ),
                name='status_response_date_consistency'
            )
        ]

    def __str__(self):
        return f"Solicitud de {self.user_orderer} a {self.user_ordered} ({self.status})"

    def save(self, *args, **kwargs):
        if self.status in ['Aceptado', 'Rechazado'] and not self.response_date:
            self.response_date = timezone.now()
        super().save(*args, **kwargs)

class Friendship(models.Model):
    user1 = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='friendships_as_user1', to_field='user', verbose_name='Usuario 1', db_column='user1', primary_key=True)
    user2 = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='friendships_as_user2', to_field='user', verbose_name='Usuario 2', db_column='user2')
    is_friend = models.BooleanField(default=True, verbose_name='Son amigos')
    request = models.ForeignKey(FriendshipRequest, on_delete=models.SET_NULL, null=True, blank=True, verbose_name='Solicitud asociada', db_column='request')

    class Meta:
        managed = False # No queremos que Django modifique la tabla porque ya está creada
        db_table = 'friendship'
        verbose_name = 'Amistad/Relación'
        verbose_name_plural = 'Amistades/Relaciones'
        unique_together = ['user1', 'user2']  # This enforces that the combination is unique
        constraints = [
            models.CheckConstraint(
                check=models.Q(
                    (models.Q(is_friend=True) & models.Q(request__isnull=False)) |
                    (models.Q(is_friend=False))
                ),
                name='friendship_status_consistency'
            )
        ]

    def __str__(self):
        status = "Amigos" if self.is_friend else "Bloqueados"
        return f"{self.user1} y {self.user2} ({status})"

    def clean(self):
        if self.user1 == self.user2:
            raise ValidationError("Un usuario no puede tener relación consigo mismo")
        if self.is_friend and not self.request:
            raise ValidationError("Las amistades deben tener una solicitud asociada")