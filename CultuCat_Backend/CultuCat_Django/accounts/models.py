from django.db import models
from django.contrib.auth.models import User
from django.db.models.signals import post_save
from django.dispatch import receiver

from calendars.models import Calendar
from images.models import Image

# Clase Users --> Corresponde a la tabla Users de la BD'
# Patrón "Perfil de usuario extendido": Consiste en enlazar nuestra tabla Users con atributos personalizados y enlazada con nuestro dominio,
# con la tabla auth_user de Django, utilizada en la autenticación y creación de usuarios.

class Users(models.Model):
    # Relación uno a uno con auth_user
    user = models.OneToOneField(User, on_delete=models.CASCADE, primary_key=True, to_field='username', db_column='username', related_name='users')
    
    # Atributos
    language = models.CharField(max_length=50)
    profilephoto = models.ForeignKey(Image, on_delete=models.SET_NULL, null=True, blank=True, db_column='profilephoto', related_name='user_profiles')
    telf = models.CharField(max_length=20, null=True, blank=True)
    description = models.CharField(max_length=150,null=True, blank=True, db_column='description')
    location = models.CharField(max_length=50, null=True, blank=True, db_column='location')
    
    # Relación con calendar
    idcalendar = models.ForeignKey(Calendar, on_delete=models.SET_NULL, null=True, blank=True, db_column='idcalendar')
    
    #fcm token
    fcm_token = models.CharField(max_length=255, null=True, blank=True)

    class Meta:
        managed = False     # No queremos que Django modifique la tabla event porque ya está creada
        db_table = 'users'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return f"Perfil de {self.user.username}"
