from django.db import models
from eventos.models import Event
from calendars.models import Calendar

# Clase PlannedActivity --> Define la estructura de la tabla plannedactivity
class PlannedActivity(models.Model):
    idevt = models.ForeignKey(Event, on_delete=models.CASCADE, db_column='idevt')
    idcalendar = models.ForeignKey(Calendar, on_delete=models.CASCADE, db_column='idcalendar')

    class Meta:
        managed = False # No queremos que Django modifique la tabla plannedactivity porque ya está creada
        db_table = 'plannedactivity' # Nombre de la tabla en la base de datos
        # Definimos la clave primaria compuesta
        constraints = [
            models.UniqueConstraint(
                fields=['idevt', 'idcalendar'],
                name='unique_event_calendar_activity'
            )
        ]

    def __str__(self):
        return f"PlannedActivity {self.idevt} - {self.idcalendar}"
