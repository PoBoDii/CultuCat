from django.db import models
from chats.models import Chat

# Clase GroupChat --> Define la estructura de la tabla groupchat
class GroupChat(models.Model):
    id = models.ForeignKey(Chat, on_delete=models.CASCADE, db_column='id', primary_key=True)
    
    class Meta:
        managed = False     # No queremos que Django modifique la tabla groupchat porque ya está creada
        db_table = 'groupchat'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.id
