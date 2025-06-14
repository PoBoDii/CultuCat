from django.db import models
from files.models import File

# Clase Video --> Define la estructura de la tabla video
class Video(models.Model):
    path = models.ForeignKey(File, on_delete=models.CASCADE, db_column='path', primary_key=True)  # Campo clave primaria

    class Meta:
        managed = False  # No queremos que Django modifique la tabla video porque ya está creada
        db_table = 'video'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.path
