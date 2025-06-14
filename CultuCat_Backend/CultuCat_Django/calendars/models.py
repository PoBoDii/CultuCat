from django.db import models

# Clase Calendar --> Corresponde a la tabla Calendar de la BD
class Calendar(models.Model):
    id = models.AutoField(primary_key=True)

    class Meta:
        managed = False     # No queremos que Django modifique la tabla
        db_table = 'calendar'    # Nombre correcto de la tabla en la base de datos

    def __str__(self):
        return f"Calendar {self.id}"
