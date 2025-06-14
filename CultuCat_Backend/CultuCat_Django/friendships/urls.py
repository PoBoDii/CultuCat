from django.urls import path
from . import views

urlpatterns = [
    path('api/friendships/send-request/', views.send_friendship_request, name='send_friendship_request'),
    path('api/friendships/my-requests/', views.list_my_friendship_requests, name='list_my_friendship_requests'),
    path('api/friendships/my-sent-requests/', views.list_my_sent_friendship_requests, name='list_my_sent_friendship_requests'),
    path('api/friendships/respond-request/', views.respond_to_friendship_request, name='respond_to_friendship_request'),
    path('api/friendships/my-friends/', views.list_my_friends, name='list_my_friends'),
    path('api/friendships/remove-friend/', views.remove_friend, name='remove_friend'),
    path('api/friendships/block-user/', views.block_user, name='block_user'),
    path('api/friendships/status/', views.get_friendship_status, name='get_friendship_status'),
]
