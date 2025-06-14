from django.urls import path, include
from eventos import views
from service import views as views_service
"""
URL configuration for CultuCat_Django project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path, include
from accounts import views as accounts_views
from privatechats import views as privatechats_views
from reviews import views as reviews_views
from friendships import views as friendships_views
#Fotos de perfil en modo debug
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [    
    path('admin/', admin.site.urls),
  # Buscar eventos
    path('events', views.events_list, name='events_con_localizacion'),
    path('events/rated/', views.events_by_rating, name='events_by_rating'),
    path('events/<int:event_id>/', views.event_detail, name='event_detail'),
    path('events/search/', views.search_events, name='search_events'),
  # Login y registro
    path('api/login/', accounts_views.api_login, name="api_login"),
    path('api/auth/google/', accounts_views.GoogleAuthView.as_view(), name='google_auth'),
    path('api/register/', accounts_views.api_register, name="api_register"),
    path('api/send-password-reset-email/', accounts_views.send_password_reset_email, name="send_password_reset_email"),
    path('api/reset-password/<uidb64>/<token>/', accounts_views.reset_password, name="reset_password"),
  # Servicios
    path('service/events-all/', views_service.events_all_service, name='events_all_service'),
    path('service/events-search/', views_service.search_events_service, name='search_events_service'),
  # Notificaciones
    path('api/save-fcm-token/', accounts_views.save_fcm_token, name="save_fcm_token"),
  # Calcular ruta API E-Move
    path('api/calcular-ruta/', views_service.calcular_ruta, name='calcular_ruta'),
  # Chats privados
    path('api/chat/list/', privatechats_views.list_private_chats, name='list_private_chats'),
    path('api/chat/<int:chat_id>/messages/', privatechats_views.get_private_messages, name='get_private_messages'),
    path('api/chat/send/', privatechats_views.send_private_message, name='send_private_message'),
    path('api/users/', accounts_views.list_users, name='list_users'),
    path('api/users/by-chats/', privatechats_views.list_users_ordered_by_chats, name='list_users_ordered_by_chats'),
    path('api/chat/create/', privatechats_views.create_private_chat, name='create_private_chat'),
  # Gestión de perfil
    path('api/ver-perfil/', accounts_views.ver_perfil, name="ver_perfil"),
    path('api/editar-perfil/', accounts_views.editar_perfil, name="editar_perfil"),
    path('api/eliminar-cuenta/', accounts_views.eliminar_cuenta, name="eliminar_cuenta"),
    path('api/ver-perfil/<str:username>/', accounts_views.ver_perfil_usuario, name="ver_perfil_usuario"),
  # Reviews
    path('api/reviews/<int:evento_id>/', reviews_views.ver_reviews, name='ver_reviews'),
    path('api/reviews/<int:evento_id>/crear/', reviews_views.crear_review, name='crear_review'),
    path('api/reviews/<int:evento_id>/borrar/', reviews_views.borrar_review, name='borrar_review'),
    path('api/reviews/<int:evento_id>/sorted/', reviews_views.ver_reviews_ordenadas, name='ver_reviews_ordenadas'),
    path('api/reviews/user-sorted/<str:username>', reviews_views.ver_reviews_usuario_ordenadas, name='ver_reviews_usuario_ordenadas'),
    path('api/reviews/<int:evento_id>/<str:review_username>/', reviews_views.ver_review_individual, name='ver_review_individual'),
    path('api/reviews/<int:evento_id>/<str:review_username>/like/', reviews_views.gestionar_like_dislike, name='gestionar_like_dislike'),
  #Planned activities
    path('', include('plannedactivities.urls')),

  # Chats de eventos
    path('', include('eventchats.urls')),
  # Grupos
    path('', include('groups.urls')),
    
  # Amistades
    path('', include('friendships.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)