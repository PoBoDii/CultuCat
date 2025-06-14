# Usem la imatge oficial de Python
FROM python:3.10

# Establim el directori de treball dins del contenidor
WORKDIR /app

# Copiem el fitxer de dependències i instal·lem les llibreries
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiem el projecte al contenidor
COPY . .
COPY .env .env


# Afegim permisos d'execució a l'entrypoint
RUN chmod +x entrypoint.sh

# Exposem el port 8000 per a Django
EXPOSE 8082

# Executem l'script d'entrada quan es crea el contenidor
ENTRYPOINT ["./entrypoint.sh"]