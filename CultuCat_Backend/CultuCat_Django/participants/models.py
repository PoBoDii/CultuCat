from django.db import models
from accounts.models import Users
from groups.models import Group

# Clase Participant --> Define la estructura de la tabla participant
class Participant(models.Model):
    class Role(models.TextChoices):
        ADMIN = 'Administrador', 'Administrador'
        MEMBER = 'Membre', 'Membre'
        CREATOR = 'Creador', 'Creador'
    
    # Definimos ambos campos como parte de una clave primaria compuesta
    idgroup = models.ForeignKey(Group, on_delete=models.CASCADE, db_column='idgroup', primary_key=True)
    username = models.ForeignKey(Users, on_delete=models.CASCADE, db_column='username')
    rol = models.CharField(max_length=15, choices=Role.choices, default=Role.MEMBER)

    class Meta:
        managed = False  # No queremos que Django modifique la tabla participant porque ya está creada
        db_table = 'participant'  # Nombre de la tabla en la base de datos
        # Definimos la clave primaria compuesta
        constraints = [
            models.UniqueConstraint(
                fields=['idgroup', 'username'],
                name='unique_group_user_participant'
            )
        ]

    def __str__(self):
        return f"{self.username} - {self.idgroup} ({self.rol})"
