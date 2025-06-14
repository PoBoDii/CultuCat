from django.urls import path
from . import views

urlpatterns = [
    path('api/event-chat/join/', views.join_event_chat, name='join_event_chat'),
    path('api/event-chat/<int:chat_id>/messages/', views.get_event_messages, name='get_event_messages'),
    path('api/event-chat/send/', views.send_event_message, name='send_event_message'),
    path('api/event-chat/my-chats/', views.list_my_event_chats, name='list_my_event_chats'),
]