#!/bin/sh

echo "Esperant que la base de dades estigui disponible..."
sleep 5  # Esperem uns segons per assegurar-nos que la DB està activa

echo "Executant migracions de la base de dades..."
python manage.py migrate

echo "Creant superusuari si no existeix..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@example.com', 'admin')" | python manage.py shell

echo "Iniciant el servidor Django..."
exec python manage.py runserver 0.0.0.0:8082
