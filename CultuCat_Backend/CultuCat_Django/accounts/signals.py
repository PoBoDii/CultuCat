from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import Users  # Asumiendo que este es tu modelo de usuarios personalizado

@receiver(post_save, sender=User)
def create_or_update_user_profile(sender, instance, created, **kwargs):
    # Utilizamos get_or_create para manejar la creación o recuperación del perfil de usuario
    profile, created = Users.objects.get_or_create(
        user=instance,
        defaults={
            'language': 'Català'  # Valor por defecto solo para nuevos usuarios
        }
    )
    
    # Si no es un usuario nuevo, guardamos los cambios (si los hubiera)
    if not created:
        profile.save()