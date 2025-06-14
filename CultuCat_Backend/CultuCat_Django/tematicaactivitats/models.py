from django.db import models
from eventos.models import Event
from fields.models import Field

# Clase TematicaActivitat --> Define la estructura de la tabla tematicaactivitats
class TematicaActivitat(models.Model):
    id = models.ForeignKey(Event, on_delete=models.CASCADE, db_column='id', primary_key=True)
    name = models.ForeignKey(Field, on_delete=models.CASCADE, db_column='name')    

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['id', 'name'],  # Combinación única de event y category
                name='unique_event_field'   # Nombre de la restricción
            )
        ]
        
        managed = False     # No queremos que Django modifique la tabla tematicaactivitats porque ya está creada
        db_table = 'tematicaactivitat'  # Nombre de la tabla en la base de datos

    def __str__(self):
        return f"{self.id} - {self.name}"