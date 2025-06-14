from django.db import models

# Clase Field --> Define la estructura de la tabla field
class Field(models.Model):
    name = models.CharField( max_length=255, primary_key=True)

    class Meta:
        managed = False     # No queremos que Django modifique la tabla field porque ya está creada
        db_table = 'field'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.name
