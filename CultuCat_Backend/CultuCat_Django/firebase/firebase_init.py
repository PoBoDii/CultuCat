import os
import firebase_admin
from firebase_admin import credentials

# Calcular BASE_DIR (dos niveles arriba del archivo actual)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Ruta absoluta al archivo de credenciales JSON
CREDENTIALS_PATH = os.path.join(BASE_DIR, 'firebase', 'firebase-credentials.json')

print(f"[Firebase Init] BASE_DIR: {BASE_DIR}")
print(f"[Firebase Init] CREDENTIALS_PATH: {CREDENTIALS_PATH}")

try:
    if not firebase_admin._apps:
        cred = credentials.Certificate(CREDENTIALS_PATH)
        firebase_admin.initialize_app(cred)
        print("[Firebase Init] Firebase Admin inicializado correctamente")
    else:
        print("[Firebase Init] Firebase Admin ya estaba inicializado")
except Exception as e:
    print(f"[Firebase Init] Error inicializando Firebase Admin: {e}")
