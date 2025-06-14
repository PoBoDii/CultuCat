from django.db import models
from django.core.exceptions import ValidationError
from datetimes.models import DateTime
from chats.models import Chat
from files.models import File
from accounts.models import Users

# Clase Message --> Define la estructura de la tabla message
class Message(models.Model):
    date = models.DateField()  # Parte de la clave compuesta que referencia a DateTime
    time = models.TimeField()  # Parte de la clave compuesta que referencia a DateTime
    username = models.ForeignKey(Users, on_delete=models.CASCADE, related_name='messages', db_column='username')
    idchat = models.ForeignKey(Chat, on_delete=models.CASCADE, db_column='idchat')
    text = models.CharField(max_length=255, null=True, blank=True)
    filepath = models.ForeignKey(File, on_delete=models.SET_NULL, related_name='messages', null=True, blank=True, db_column='filepath')
    
    class Meta:
        managed = False
        db_table = 'message'
    
    def clean(self):
        # Verificar que al menos uno de text o filepath tenga valor
        if not self.text and not self.filepath:
            raise ValidationError("Un mensaje debe tener al menos un texto o un archivo.")
        
        # Verificar que exista un objeto DateTime correspondiente
        try:
            DateTime.objects.get(date=self.date, time=self.time)
        except DateTime.DoesNotExist:
            raise ValidationError("No existe un DateTime con la fecha y hora proporcionadas.")
    
    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)
    
    def __str__(self):
        return f"Message from {self.username} at {self.date} {self.time}"