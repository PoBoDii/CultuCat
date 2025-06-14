from django.db import models
from images.models import Image
from groupchats.models import GroupChat

# Clase Group --> Define la estructura de la tabla groups
class Group(models.Model):
    id = models.AutoField(primary_key=True)  # ID del grupo (clave primaria)
    name = models.CharField(max_length=255)  # Nombre del grupo
    groupphoto = models.ForeignKey(Image, on_delete=models.SET_NULL, null=True, db_column='groupphoto')  # FK a Image
    idchat = models.ForeignKey(GroupChat, on_delete=models.CASCADE, db_column='idchat')  # FK a Chat

    class Meta:
        managed = False  # No queremos que Django modifique la tabla porque ya está creada
        db_table = 'groups'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.name  # Cambiado de group_name a name para coincidir con el campo definido

# Estados posibles para las solicitudes
class GroupRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = 'Pendiente', 'Pendiente'
        ACCEPTED = 'Aceptado', 'Aceptado'
        REJECTED = 'Rechazado', 'Rechazado'
    
    # Datos de la solicitud
    idgroup = models.ForeignKey(Group, on_delete=models.CASCADE, db_column='idgroup')
    username = models.ForeignKey('accounts.Users', on_delete=models.CASCADE, db_column='username', related_name='group_requests')
    request_date = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=15, choices=Status.choices, default=Status.PENDING)
    responded_by = models.ForeignKey('accounts.Users', on_delete=models.SET_NULL, null=True, related_name='responded_requests', db_column='responded_by')
    response_date = models.DateTimeField(null=True, blank=True)
    # Tipo de solicitud: unirse al grupo o invitación
    is_invitation = models.BooleanField(default=False)
    
    class Meta:
        managed = True  # Queremos que Django cree y gestione esta tabla
        db_table = 'group_request'
        constraints = [
            models.UniqueConstraint(
                fields=['idgroup', 'username', 'status'],
                name='unique_group_user_request'
            )
        ]
    
    def __str__(self):
        request_type = "Invitación" if self.is_invitation else "Solicitud"
        return f"{request_type} de {self.username} para {self.idgroup} - {self.status}"