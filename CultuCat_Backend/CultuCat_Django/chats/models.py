from django.db import models

# Clase Chat --> Permite obtener los chats de la BD
class Chat(models.Model):
    # Enum de tipos de chat
    class ChatType(models.TextChoices):
        EVENT_CHAT = 'EventChat', 'Event Chat'
        GROUP_CHAT = 'GroupChat', 'Group Chat'
        PRIVATE_CHAT = 'PrivateChat', 'Private Chat'
    
    id = models.AutoField(primary_key=True)
    type = models.CharField(
        max_length=20,
        choices=ChatType.choices,
        default=ChatType.PRIVATE_CHAT
    )

    class Meta:
        managed = False     # No queremos que Django modifique la tabla chat porque ya está creada
        db_table = 'chat'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return f" {self.id} - {self.type}"