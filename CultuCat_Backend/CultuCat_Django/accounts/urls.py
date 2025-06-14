from django.urls import path
from django.conf import settings
from django.conf.urls.static import static
from .views import api_login, api_register, send_password_reset_email, reset_password, ver_perfil, editar_perfil, eliminar_cuenta, GoogleAuthView, ver_perfil_usuario, save_fcm_token, send_fcm_notification, send_fcm_data_message


urlpatterns = [
    path('api/auth/google/', GoogleAuthView.as_view(), name='google_auth'),
    path('api/login/', api_login, name="api_login"),
    path('api/register/', api_register, name="api_register"),
    path('api/send-password-reset-email/', send_password_reset_email, name="send_password_reset_email"),
    path('api/reset-password/<uidb64>/<token>/', reset_password, name="reset_password"),
    path('api/ver-perfil/', ver_perfil, name="ver_perfil"),
    path('api/ver-perfil/<str:username>/', ver_perfil_usuario, name="ver_perfil_usuario"),
    path('api/editar-perfil/', editar_perfil, name="editar_perfil"),
    path('api/eliminar-cuenta/', eliminar_cuenta, name="eliminar_cuenta"),
    # Recoger token FCM
    path('api/save-fcm-token/', save_fcm_token, name="save_fcm_token"),
]

# Add this to serve media files during development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)