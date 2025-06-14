from django.db import models

# Clase Place --> Define la estructura de la tabla place
class Place (models.Model):
    address = models.TextField(null=False)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=False)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=False)
    zipcode = models.CharField(max_length=20, null=False)
    id = models.AutoField(primary_key=True)

    class Meta:
        managed = False     # No queremos que Django modifique la tabla place porque ya está creada
        db_table = 'place'  # Nombre de la tabla en la base de datos
        constraints = [
            models.CheckConstraint(
                check=models.Q(latitude__gte=-90) & models.Q(latitude__lte=90),
                name='place_latitude_check'
            ),
            models.CheckConstraint(
                check=models.Q(longitude__gte=-180) & models.Q(longitude__lte=180),
                name='place_longitude_check'
            ),
        ]

    def __str__(self):
        return self.address