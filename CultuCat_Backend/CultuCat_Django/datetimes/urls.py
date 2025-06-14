from django.urls import path
from . import views

urlpatterns = [
    path('', views.datetime_list, name='datetime_list'),
    path('<str:date>/<str:time>/', views.datetime_detail, name='datetime_detail'),
    path('create/', views.datetime_create, name='datetime_create'),
    path('update/<str:date>/<str:time>/', views.datetime_update, name='datetime_update'),
    path('delete/<str:date>/<str:time>/', views.datetime_delete, name='datetime_delete'),
]