from django.db import models

# Clase File --> Define la estructura de la tabla file
class File(models.Model):
    # Enum de tipos de archivos
    class FileType(models.TextChoices):
        IMAGE = 'Image', 'Image'
        VIDEO = 'Video', 'Video'
        DOCUMENT = 'Document', 'Document'

    path = models.TextField(primary_key=True)
    size = models.IntegerField()
    type = models.CharField(
        max_length=10, 
        choices=FileType.choices,
        default = FileType.IMAGE)
    
    class Meta:
        managed = False     # No queremos que Django modifique la tabla file porque ya está creada
        db_table = 'file'   # Nombre de la tabla en la base de datos

    def __str__(self):
        return self.path
