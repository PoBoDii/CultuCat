from django.db import models

# Clase DateTime --> Define la estructura de la tabla datetime
class DateTime(models.Model):
    date = models.DateField(primary_key=True)
    time = models.TimeField()

    class Meta:
        managed = False  # No queremos que Django modifique la tabla datetime porque ya está creada
        db_table = 'datetime'  # Nombre de la tabla en la base de datos
        unique_together = (('date', 'time'),)  # Alternativa más clara a constraints

    def __str__(self):
        return f"{self.date} {self.time}"
