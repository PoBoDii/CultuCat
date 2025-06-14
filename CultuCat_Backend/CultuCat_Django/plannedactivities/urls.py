from django.urls import path
from . import views

urlpatterns = [
    path('api/calendar/add-event/', views.add_event_to_calendar, name='add_event_to_calendar'),
    path('api/calendar/remove-event/<int:event_id>/', views.remove_event_from_calendar, name='remove_event_from_calendar'),
    path('api/calendar/events/', views.get_user_calendar_events, name='get_user_calendar_events'),
]