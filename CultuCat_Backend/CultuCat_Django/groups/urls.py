from django.urls import path
from . import views

urlpatterns = [
    # Funcionalidades básicas de grupos
    path('groups/create/', views.create_group, name='create_group'),
    path('groups/join/', views.join_group, name='join_group'),
    path('groups/search/', views.search_groups, name='search_groups'),
    path('groups/<int:group_id>/messages/', views.get_group_messages, name='get_group_messages'),
    path('groups/send/', views.send_group_message, name='send_group_message'),
    path('groups/my-groups/', views.list_my_groups, name='list_my_groups'),
    
    # Funcionalidades de solicitudes y invitaciones
    path('groups/<int:group_id>/requests/', views.list_group_requests, name='list_group_requests'),
    path('groups/handle-request/', views.handle_group_request, name='handle_group_request'),
    path('groups/invite/', views.invite_to_group, name='invite_to_group'),
    path('groups/my-invitations/', views.list_my_invitations, name='list_my_invitations'),
    path('groups/respond-invitation/', views.respond_to_invitation, name='respond_to_invitation'),
]