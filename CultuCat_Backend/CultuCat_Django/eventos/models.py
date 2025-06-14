from django.db import models
from places.models import Place
from eventchats.models import EventChat
from files.models import File

# Clase Evento --> Define la estructura de la tabla event
class Event(models.Model):
    id = models.IntegerField(primary_key=True)
    inidate = models.DateTimeField()
    enddate = models.DateTimeField()
    name = models.CharField(max_length=500)
    description = models.TextField(blank=True, null=True)
    tickets = models.TextField(blank=True, null=True)
    schedule = models.TextField(blank=True, null=True)
    link = models.TextField(blank=True, null=True)
    email = models.TextField(blank=True, null=True)
    telefon = models.TextField(blank=True, null=True)
    addressid = models.ForeignKey(Place, on_delete=models.CASCADE, db_column='addressid')
    idchat = models.ForeignKey(EventChat, on_delete=models.CASCADE, db_column='idchat')
    imagepath = models.ForeignKey(File, on_delete=models.SET_NULL, null=True, db_column='imagepath')
    codeevent = models.BigIntegerField(blank=True, null=True)    

    class Meta:
        managed = False     # No queremos que Django modifique la tabla event porque ya está creada
        db_table = 'event'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.name