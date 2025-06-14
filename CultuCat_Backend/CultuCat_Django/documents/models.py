from django.db import models
from files.models import File

# Clase Document --> Define la estructura de la tabla document
class Document(models.Model):
    path = models.ForeignKey(File, on_delete=models.CASCADE, db_column='path', primary_key=True)  # Campo clave primaria

    class Meta:
        managed = False  # No queremos que Django modifique la tabla document porque ya está creada
        db_table = 'document'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.path
