from django.db import models
from chats.models import Chat

# Clase EventChat --> Define la estructura de la tabla eventchat
class EventChat(models.Model):
    id = models.ForeignKey(Chat, on_delete=models.CASCADE, db_column='id', primary_key=True)
    
    class Meta:
        managed = False     # No queremos que Django modifique la tabla eventchat porque ya está creada
        db_table = 'eventchat'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.id