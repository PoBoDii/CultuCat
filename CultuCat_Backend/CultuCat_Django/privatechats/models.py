from django.db import models
from chats.models import Chat
from accounts.models import Users

# Clase PrivateChat --> Define la estructura de la tabla privatechat
class PrivateChat(models.Model):
    id = models.ForeignKey(Chat, on_delete=models.CASCADE, db_column='id', primary_key=True)
    user1 = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='user1_privatechat', db_column='user1')
    user2 = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='user2_privatechat', db_column='user2')
    
    class Meta:
        managed = False     # No queremos que Django modifique la tabla privatechat porque ya está creada
        db_table = 'privatechat'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.id
