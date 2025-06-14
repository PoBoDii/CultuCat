from django.db import models
from accounts.models import Users
from fields.models import Field

# Clase TematicaPreferida --> Define la estructura de la tabla TematicaPreferida
class TematicaPreferida(models.Model):
    username = models.ForeignKey(Users, on_delete=models.CASCADE, db_column='username', to_field='user')
    name = models.ForeignKey(Field, on_delete=models.CASCADE, db_column='name', to_field='name')

    class Meta:
        managed = False      # No queremos que Django modifique la tabla porque ya está creada
        db_table = 'TematicaPreferida'  # Nombre de la tabla en la base de datos
        unique_together = (('username', 'name'),)  # Clave primaria compuesta

    def __str__(self):
        return f"{self.username} - {self.name}"
