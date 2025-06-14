from django.db import models
from files.models import File

# Clase Image --> Define la estructura de la tabla image
class Image(models.Model):
    path = models.ForeignKey(File, on_delete=models.CASCADE, db_column='path', primary_key=True)  # Campo clave primaria

    class Meta:
        managed = False  # No queremos que Django modifique la tabla image porque ya está creada
        db_table = 'image'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.path.path
