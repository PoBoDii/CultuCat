from django.db import models

# Clase Categoria --> Define la estructura de la tabla category
class Category(models.Model):
    name = models.CharField(max_length=255, primary_key=True)

    class Meta:
        managed = False     # No queremos que Django modifique la tabla category porque ya está creada
        db_table = 'category'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.name
