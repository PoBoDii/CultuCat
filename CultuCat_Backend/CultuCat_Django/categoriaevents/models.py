from django.db import models
from eventos.models import Event
from categories.models import Category

# Clase CategoriaEvent --> Define la estructura de la tabla categoriaevent
class CategoriaEvent(models.Model):
    id = models.ForeignKey(Event, on_delete=models.CASCADE, db_column='id', primary_key=True) 
    name = models.ForeignKey(Category, on_delete=models.CASCADE, db_column='name')

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['id', 'name'],  # Combinación única de event y category
                name='unique_event_category'   # Nombre de la restricción
            )
        ]

        managed = False     # No queremos que Django modifique la tabla categoriaevent porque ya está creada
        db_table = 'categoriaevent'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return f"{self.id} - {self.name}"
