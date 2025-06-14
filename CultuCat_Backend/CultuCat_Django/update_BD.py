import requests
import psycopg2
from datetime import datetime
import uuid
import base64

# Configuración de la base de datos
# Credenciales para dev (si se quiere probar con la BD real el dbname es cultucat_db)
# DB_CONFIG = {
#     'dbname': 'cultucat_dbtest',
#     'user': 'admin',
#     'password': 'admin',
#     'host': 'nattech.fib.upc.edu',
#     'port': "40341"
# }

# Credenciales para producción
DB_CONFIG = {
    'dbname': 'cultucat_db',
    'user': 'admin',
    'password': 'admin',
    'host': 'localhost',
    'port': "8081"
}

# Configuración de la API
API_URL = "https://analisi.transparenciacatalunya.cat/resource/rhpv-yr4f.json"
APP_TOKEN = "xsfjuMT3oc9znFOJY80xbSxKCmslf-Rp0vZB"
API_KEY = "acid3yjrsp2it79oqy0zvf2vn"
API_SECRET = "8w1qak4amynq29o52tul6922z6tklksvbifyauuye0sxnqnwo"
LIMIT = 1000  # Límite máximo de datos por consulta
OFFSET_INCREMENT = 1000  # Incremento para paginación

# Función para conectar a la base de datos
def connect_db():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        print(f"Conexión realizada con éxito")
        return conn
    except Exception as e:
        print(f"Error conectando a la base de datos: {e}")
        return None

# Función para obtener el código del último evento guardado en la BD
def get_last_event_code(conn):
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT MAX(codeEvent) FROM Event;")
            result = cur.fetchone()
            return result[0] if result and result[0] is not None else 0
    except Exception as e:
        print(f"Error obteniendo el último evento: {e}")
        return 0

# Función para filtrar eventos según las condiciones
def filter_events(events, existing_codes):
    filtered_events = []
    
    for event in events:
        # Verificar si tiene la fecha de inicio y el código
        if 'data_inici' not in event or 'codi' not in event:
            continue
            
        # Verificar si el evento ya existe en la BD
        if event.get('codi') in existing_codes:
            print(f"Evento con código {event.get('codi')} ya existe en la BD, omitiendo.")
            continue
            
        # Obtener fechas de la API
        start_date_str = event.get('data_inici')
        
        # Convertir fechas a objetos datetime.date
        try:
            start_date = datetime.strptime(start_date_str, '%Y-%m-%dT%H:%M:%S.%f').date() if start_date_str else None
        except ValueError:
            try:
                start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date() if start_date_str else None
            except ValueError:
                continue
                
        # Aplicar filtros - solo eventos de 2025 en adelante
        if start_date and start_date.year >= 2025:
            filtered_events.append(event)

    return filtered_events

def fetch_data_from_api(offset=0):
    #Credenciales de la API
    credentials = f"{API_KEY}:{API_SECRET}"
    encoded_credentials = base64.b64encode(credentials.encode()).decode()
    headers = {
        "Authorization": f"Basic {encoded_credentials}"
    }
    
    params = {
        '$limit': LIMIT,
        '$offset': offset
    }
    
    try:
        print(f"Intentando conexión a {API_URL}")
        response = requests.get(API_URL, headers=headers, params=params)
        print(f"Código de respuesta: {response.status_code}")
        
        if response.status_code != 200:
            print(f"Respuesta de error: {response.text[:200]}...")  # Mostrar parte de la respuesta de error
            
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error obteniendo datos de la API: {e}")
        return []
    
# Función para obtener el código de los eventos ya insertados en la BD
def get_existing_event_codes(conn):
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT codeEvent FROM Event;")
            results = cur.fetchall()
            return set([result[0] for result in results])  # Convert to set for faster lookups
    except Exception as e:
        print(f"Error obteniendo códigos de eventos existentes: {e}")
        return set()

# Función para insertar datos en la BD
def insert_data_into_db(conn, data):
    inserted_count = 0
    
    try:
        with conn.cursor() as cur:
            for event in data:
                try:
                    # Mapeo de campos de la API a tu esquema
                    name = event.get('denominaci')
                    description = event.get('descripcio')
                    ini_date = event.get('data_inici')
                    end_date = event.get('data_fi', ini_date)
                    tickets = event.get('entrades')  
                    schedule = event.get('horari')   
                    link = event.get('enlla')
                    email = event.get('email')       
                    telefon = event.get('tel_fon')  
                    address = event.get('adre_a') or 'Desconocida'
                    latitude = event.get('latitud')
                    longitude = event.get('longitud')
                    zip_code = event.get('codi_postal')         
                    code_event = event.get('codi')   # Código del evento en la API

                    # Doble comprobación para evitar duplicados
                    cur.execute("SELECT id FROM Event WHERE codeEvent = %s", (code_event,))
                    if cur.fetchone():
                        print(f"Evento con código {code_event} ya existe en la BD, omitiendo.")
                        continue
                    
                    # Generar una ruta para la imagen
                    image_path = event.get('imatges') or f"/default/event_{code_event}.jpg"
                    
                    # Insertar en la tabla Place (si no existe) y obtener su ID
                    place_id = None
                    if address and latitude and longitude:
                        cur.execute("""
                            INSERT INTO Place (address, latitude, longitude, zipCode)
                            VALUES (%s, %s, %s, %s)
                            RETURNING id;
                        """, (
                            address,
                            float(latitude) if latitude else None,
                            float(longitude) if longitude else None,
                            zip_code
                        ))
                        place_id = cur.fetchone()[0]  # Obtener el ID generado

                    # Insertar en Chat (EventChat) - Con ID autoincrementable
                    if place_id:
                        cur.execute("""
                            INSERT INTO Chat (type)
                            VALUES (%s) RETURNING id;
                        """, ('EventChat',))
                        
                        # Obtener el ID generado para el chat
                        chat_id = cur.fetchone()[0]
                        
                        cur.execute("""
                            INSERT INTO EventChat (id)
                            VALUES (%s);
                        """, (chat_id,))
                    
                    # Insertar File e Image
                    if place_id:
                        if image_path:
                            cur.execute("""
                                INSERT INTO File (path, size, type) 
                                VALUES (%s, %s, %s) 
                                ON CONFLICT (path) DO NOTHING;
                            """, (image_path, 0, 'Image'))
                            
                            cur.execute("""
                                INSERT INTO Image (path) 
                                VALUES (%s) 
                                ON CONFLICT (path) DO NOTHING;
                            """, (image_path,))

                    # Insertar en la tabla Event - Usando addressId en lugar de address
                    event_id = None
                    if place_id:
                        cur.execute("""
                            INSERT INTO Event (iniDate, endDate, name, description, tickets, schedule, link, email, telefon, addressId, idChat, imagePath, codeEvent)
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            RETURNING id;
                        """, (
                            ini_date,
                            end_date,
                            name,
                            description,
                            tickets,
                            schedule,
                            link,
                            email,
                            telefon,
                            place_id,  # Usar place_id en lugar de address
                            chat_id,
                            image_path,
                            code_event
                        ))

                    # Obtener el ID generado para el evento
                    result = cur.fetchone()
                    if result:
                        event_id = result[0]
                    
                    # Insertar en la tabla CategoriaEvent (si hay categorías)
                    if event_id:
                        categories = event.get('tags_categor_es', '').split(',') if event.get('tags_categor_es') else []
                        for category in categories:
                            category = category.strip()
                            if category:
                                cur.execute("""
                                    INSERT INTO Category (name)
                                    VALUES (%s)
                                    ON CONFLICT (name) DO NOTHING;
                                """, (category,))
                                
                                cur.execute("""
                                    INSERT INTO CategoriaEvent (id, name)
                                    VALUES (%s, %s)
                                    ON CONFLICT (id, name) DO NOTHING;
                                """, (event_id, category))
                    
                    # Insertar en la tabla TematicaActivitat (si hay temáticas)
                    if event_id:
                        themes = event.get('tags_mbits', '').split(',') if event.get('tags_mbits') else []
                        for theme in themes:
                            theme = theme.strip()
                            if theme:
                                cur.execute("""
                                    INSERT INTO Field (name)
                                    VALUES (%s)
                                    ON CONFLICT (name) DO NOTHING;
                                """, (theme,))
                                
                                cur.execute("""
                                    INSERT INTO TematicaActivitat (id, name)
                                    VALUES (%s, %s)
                                    ON CONFLICT (id, name) DO NOTHING;
                                """, (event_id, theme))
                        
                    if event_id:
                        inserted_count += 1
                        print(f"Evento {event.get('codi')} insertado correctamente.")
                    
                except Exception as e:
                    print(f"Error insertando evento {event.get('codi')}: {e}")
                    conn.rollback()
                    continue
            
            conn.commit()
    except Exception as e:
        print(f"Error general insertando datos en la BD: {e}")
        conn.rollback()
    
    return inserted_count

def clean_event_tables(conn):
    """
    Elimina todos los registros de las tablas relacionadas con eventos
    manteniendo la estructura de la base de datos intacta.
    
    Args:
        conn: Conexión a la base de datos PostgreSQL
        
    Returns:
        dict: Diccionario con el número de registros eliminados por tabla
    """
    deleted_counts = {}
    
    try:
        with conn.cursor() as cur:
            # Es importante seguir el orden correcto para evitar violaciones de restricciones de clave foránea
            
            # 1. Primero eliminamos las tablas de relación
            tables_to_clean = [
                "TematicaActivitat",  # Relación entre eventos y temáticas
                "CategoriaEvent",     # Relación entre eventos y categorías
            ]
            
            for table in tables_to_clean:
                cur.execute(f"DELETE FROM {table}")
                deleted_counts[table] = cur.rowcount
                print(f"Eliminados {cur.rowcount} registros de la tabla {table}")
            
            # 2. Eliminar los eventos
            cur.execute("DELETE FROM Event")
            deleted_counts["Event"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros de la tabla Event")
            
            # 3. Eliminar los chats de eventos
            cur.execute("DELETE FROM EventChat")
            deleted_counts["EventChat"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros de la tabla EventChat")
            
            # 4. Eliminar los chats generales
            cur.execute("DELETE FROM Chat WHERE type = 'EventChat'")
            deleted_counts["Chat"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros de la tabla Chat de tipo EventChat")
            
            # 5. Eliminar las imágenes y archivos (opcional, pueden ser reutilizados)
            cur.execute("DELETE FROM Image")
            deleted_counts["Image"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros de la tabla Image")
            
            cur.execute("DELETE FROM File")
            deleted_counts["File"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros de la tabla File")
            
            # 6. Eliminar los lugares (si no se utilizan en otras entidades)
            cur.execute("DELETE FROM Place")
            deleted_counts["Place"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros de la tabla Place")
            
            # Opcional: Limpiar categorías y campos que no estén vinculados
            cur.execute("DELETE FROM Category WHERE name NOT IN (SELECT name FROM CategoriaEvent)")
            deleted_counts["Category"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros huérfanos de la tabla Category")
            
            cur.execute("DELETE FROM Field WHERE name NOT IN (SELECT name FROM TematicaActivitat)")
            deleted_counts["Field"] = cur.rowcount
            print(f"Eliminados {cur.rowcount} registros huérfanos de la tabla Field")
            
            # Confirmar los cambios
            conn.commit()
            print("Limpieza completada con éxito")

            existing_events = get_existing_event_codes(conn)
            print(f"Existen {len(existing_events)} eventos en la BD.")
            
    except Exception as e:
        conn.rollback()
        print(f"Error durante la limpieza de tablas: {e}")
        raise
    
    return deleted_counts  

# Función principal
def main():
    conn = connect_db()
    if not conn:
        return
    
    try:
        #Limpieza de la BD por si hay duplicados (activar solo si se sabe que hay duplicados)
        #clean_event_tables(conn)

        # Obtener los códigos de eventos existentes
        existing_codes = get_existing_event_codes(conn)
        print(f"Se encontraron {len(existing_codes)} eventos existentes en la BD.")

        # Para la primera ejecución - cargar todos los eventos de 2025 en adelante
        total_inserted = 0
        total_skipped = 0
        offset = 0
        has_more_data = True
        
        while has_more_data:
            print(f"Obteniendo datos con offset {offset}...")
            data = fetch_data_from_api(offset)
            
            if not data:
                has_more_data = False
                break
                
            # Filtrar eventos según las condiciones (2025 en adelante)
            filtered_data = filter_events(data, existing_codes)

            # Actualizar los códigos de eventos existentes con los que acabo de insertar
            for event in filtered_data:
                existing_codes.add(event.get('codi'))
            
            # Insertar datos en la BD
            inserted = insert_data_into_db(conn, filtered_data)
            total_inserted += inserted
            total_skipped += len(data) - len(filtered_data)
            
            print(f"Se insertaron {inserted} eventos de este lote.")
            
            if len(data) < LIMIT:
                has_more_data = False
            else:
                offset += OFFSET_INCREMENT
        
        print(f"Proceso completado. Se insertaron un total de {total_inserted} eventos.")
        print(f"Se omitieron {total_skipped} eventos por no cumplir los filtros o ya existir en la BD.")

        # Imprimir los eventos existentes
        existing_events = get_existing_event_codes(conn)
        print(f"Existen {len(existing_events)} eventos en la BD.")
        
    except Exception as e:
        print(f"Error en el proceso principal: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()