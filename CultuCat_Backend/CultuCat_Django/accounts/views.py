from django.contrib.auth.models import User
from .models import Users
from django.contrib.auth import authenticate
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.db.models.functions import Lower
# Perfil de usuario
from .serializers import UserProfileSerializer
from rest_framework.permissions import AllowAny
from rest_framework.permissions import IsAuthenticated
# Recuperació de password
from django.shortcuts import render, redirect
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.core.mail import send_mail
#Login Google
import firebase_admin
from firebase_admin import credentials, auth
from django.conf import settings
from rest_framework.views import APIView
from rest_framework import status
import uuid
#Notificaciones
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
#Imagen de perfil
import os
from images.models import Image
from files.models import File
from django.core.files.storage import default_storage






# Inicializar Firebase Admin SDK
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate(settings.FIREBASE_SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)

User = get_user_model()

# LOGIN GOOGLE
class GoogleAuthView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        id_token = request.data.get('id_token')
        name = request.data.get('name', '')
        email = request.data.get('email', '')
        photo_url = request.data.get('photo_url', '')

        if not id_token:
            return Response({'error': 'Token no proporcionado'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            decoded_token = auth.verify_id_token(id_token)
            firebase_uid = decoded_token['uid']

            if not email and 'email' in decoded_token:
                email = decoded_token['email']

            if not email:
                return Response({'error': 'No se pudo obtener el email'}, status=status.HTTP_400_BAD_REQUEST)

            base_username = email.split('@')[0]
            username = base_username
            counter = 1
            while User.objects.filter(username=username).exists():
                username = f"{base_username}{counter}"
                counter += 1

            try:
                user = User.objects.get(email=email)
                user.last_login = timezone.now()
                user.save()
            except User.DoesNotExist:
                random_password = str(uuid.uuid4())
                user = User.objects.create_user(username=username, email=email, password=random_password)
                try:
                    Users.objects.create(user=user, telf="", language="es")
                except Exception as e:
                    print(f"Error creating extended profile: {e}")

            token, created = Token.objects.get_or_create(user=user)

            return Response({
                'user': {
                    'token': token.key,
                    'user_id': user.id,
                    'username': user.username,
                    'email': user.email
                }
            })



        except auth.InvalidIdTokenError as e:
            print(f"Firebase token validation error: {str(e)}")
            return Response({'error': f'Token de Firebase inválido: {str(e)}'}, status=status.HTTP_401_UNAUTHORIZED)
        except Exception as e:
            return Response({'error': f'Error en la autenticación: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# LOG IN MANUAL
@api_view(['POST'])
@permission_classes([AllowAny])
def api_login(request):
    username = request.data.get("username")
    password = request.data.get("password")

    user = authenticate(username=username, password=password)

    if user:
        user.last_login = timezone.now()
        user.save()
        token, created = Token.objects.get_or_create(user=user)
        return Response({"message": "Login exitoso", "token": token.key}, status=200)
    else:
        return Response({"error": "Username o password incorrectos"}, status=400)


# REGISTRO DE USUARIO
@api_view(['POST'])
@permission_classes([AllowAny])
def api_register(request):
    username = request.data.get("username")
    email = request.data.get("email")
    password = request.data.get("password")
    confirm_password = request.data.get("confirm_password")

    if not username or not email or not password or not confirm_password:
        return Response({"error": "Todos los campos son obligatorios"}, status=400)

    if password != confirm_password:
        return Response({"error": "Las contraseñas no coinciden"}, status=400)

    if User.objects.filter(username=username).exists():
        return Response({"error": "Este username ya esta registrado"}, status=400)

    if User.objects.filter(email=email).exists():
        return Response({"error": "Este email ya esta registrado"}, status=400)

    user = User.objects.create_user(username=username, email=email, password=password)
    token = Token.objects.create(user=user)

    return Response({"message": "Registro completado", "token": token.key}, status=201)


#Recuperar contraseña
@api_view(['POST'])
@permission_classes([AllowAny])
def send_password_reset_email(request):
    email = request.data.get('email')
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({"error": "No existe un usuario con este correo electronico"}, status=400)

    token = default_token_generator.make_token(user)
    uid = urlsafe_base64_encode(force_bytes(user.pk))

    # Detectar dominio y protocolo dinámicamente
    current_site = request.get_host()
    protocol = 'https' if request.is_secure() else 'http'
    reset_link = f"{protocol}://{current_site}/api/reset-password/{uid}/{token}/"

    send_mail(
        'Recuperación de contraseña',
        f'Usa este enlace para recuperar tu contraseña: {reset_link}',
        'cultucat.correo@gmail.com',
        [email],
        fail_silently=False,
    )

    return Response({"status": "Correo de recuperación enviado"}, status=200)



@api_view(['GET', 'POST'])
@permission_classes([AllowAny])
def reset_password(request, uidb64, token):
    if request.method == 'GET':
        return render(request, 'accounts/reset_password.html', {'uidb64': uidb64, 'token': token})

    elif request.method == 'POST':
        data = request.data if hasattr(request, 'data') else request.POST
        new_password = data.get('new_password')
        confirm_password = data.get('confirm_password')

        if new_password != confirm_password:
            return Response({"error": "Las contraseñas no coinciden"}, status=400)

        try:
            uid = force_str(urlsafe_base64_decode(uidb64))
            user = User.objects.get(pk=uid)
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            return Response({"error": "Enlace inválido"}, status=400)

        if not default_token_generator.check_token(user, token):
            return Response({"error": "Token inválido o expirado"}, status=400)

        user.set_password(new_password)
        user.save()

        return Response({"status": "Password actualizado correctamente"}, status=200)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_users(request):
    current_user = request.user
    users = User.objects.exclude(id=current_user.id).order_by(Lower('username'))
    data = [{"id": u.id, "username": u.username} for u in users]
    return Response(data)



# VER PERFIL
from django.conf import settings

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def ver_perfil(request):
    try:
        user_data = {
            'username': request.user.username,
            'email': request.user.email,
        }
        
        try:
            perfil_extendido = Users.objects.get(user=request.user)

            # Return only the relative path, not the full URL
            if perfil_extendido.profilephoto:
                photo_path = perfil_extendido.profilephoto.path.path
                # Just return the filename, let Flutter construct the full URL
                photo_filename = os.path.basename(photo_path)
                photo_url = f"media/{photo_filename}"  # Changed this line
            else:
                photo_url = None

            extended_data = {
                'profilephoto': photo_url,  # This will now be "media/filename.jpg"
                'telf': perfil_extendido.telf,
                'language': perfil_extendido.language,
                'description': perfil_extendido.description,
                'location': perfil_extendido.location
            }

            user_data.update(extended_data)
            
        except Users.DoesNotExist:
            user_data.update({
                'profilephoto': None,
                'telf': None,
                'language': None,
                'description': None,
                'location': None
            })

        return Response(user_data)

    except Exception as e:
        return Response({"error": f"Error al obtener perfil: {str(e)}"}, status=500)


# VER PERFIL DE OTRO USUARIO
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def ver_perfil_usuario(request, username):
    try:
        # Obtener el usuario solicitado
        try:
            target_user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response({"error": f"Usuario {username} no encontrado"}, status=404)
        
        # Obtener el perfil extendido del usuario solicitado
        try:
            target_user_extended = Users.objects.get(user=target_user)
        except Users.DoesNotExist:
            target_user_extended = None
            
        # Obtener el usuario actual (quien hace la solicitud)
        current_user = Users.objects.get(user=request.user)
        
        # Verificar si el usuario objetivo ha bloqueado al usuario actual
        from django.db.models import Q
        from friendships.models import Friendship
        
        # Comprobamos si hay una relación de bloqueo donde target_user es user1 y current_user es user2
        is_blocked = Friendship.objects.filter(
            user1=target_user_extended,
            user2=current_user,
            is_friend=False
        ).exists()
        if is_blocked:
            return Response({"error": "No tienes permiso para ver este perfil"}, status=403)
        
        # Preparar los datos del perfil
        user_data = {
            'username': target_user.username,
            'email': target_user.email,
        }

        if target_user_extended:
            extended_data = {
                'profilephoto': target_user_extended.profilephoto_id if target_user_extended.profilephoto else None,
                'telf': target_user_extended.telf,
                'language': target_user_extended.language,
                'description': target_user_extended.description,
                'location': target_user_extended.location
            }
            user_data.update(extended_data)

        return Response(user_data)

    except Exception as e:
        return Response({"error": f"Error al obtener perfil: {str(e)}"}, status=500)


# EDITAR PERFIL

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def editar_perfil(request):
    try:
        try:
            perfil_extendido = Users.objects.get(user=request.user)
        except Users.DoesNotExist:
            perfil_extendido = Users.objects.create(user=request.user)        
        if 'email' in request.data:
            request.user.email = request.data.get('email')
            request.user.save()
            
        serializer = UserProfileSerializer(perfil_extendido, data=request.data, partial=True)

        # Procesar imagen si viene
        uploaded_file = request.FILES.get('profilephoto')
        if uploaded_file:
            # Eliminar imagen anterior si existe
            if perfil_extendido.profilephoto:
                old_file_path = os.path.join(settings.MEDIA_ROOT, perfil_extendido.profilephoto.path.path)
                if os.path.exists(old_file_path):
                    try:
                        os.remove(old_file_path)
                        print(f"Imagen anterior eliminada: {old_file_path}")
                    except Exception as e:
                        print(f"Error al eliminar imagen anterior: {str(e)}")

            # Construir nombre único para archivo
            filename = f"{request.user.username}_{uploaded_file.name}"
            filepath = os.path.join(settings.MEDIA_ROOT, filename)

            # Guardar archivo físicamente
            with default_storage.open(filepath, 'wb+') as destination:
                for chunk in uploaded_file.chunks():
                    destination.write(chunk)

            print("FILE NAME guardado:", filename)

            # Crear o actualizar el objeto File
            file_obj, _ = File.objects.update_or_create(
                path=filename,
                defaults={
                    'size': uploaded_file.size,
                    'type': 'Image'
                }
            )

            print("FILE PATH guardado:", file_obj.path)

            # Crear o obtener Image asociado
            image_obj, _ = Image.objects.get_or_create(path=file_obj)
            print("IMAGE OBJ guardado:", image_obj.path)

            # Asignar al perfil
            perfil_extendido.profilephoto = image_obj
            perfil_extendido.save()

            print("PERFIL EXTENDIDO guardado:", perfil_extendido.profilephoto.path)

        # Eliminar 'profilephoto' de los datos para evitar error de serialización
        request_data = request.data.copy()
        request_data.pop('profilephoto', None)

        # Serializar y guardar resto de datos
        serializer = UserProfileSerializer(perfil_extendido, data=request_data, partial=True)

        if serializer.is_valid():
            serializer.save()
            
            response_data = {
                'message': "Perfil actualizado correctamente",
                'perfil': {
                    'username': request.user.username,
                    'email': request.user.email,
                    'profilephoto': f"media/{os.path.basename(perfil_extendido.profilephoto.path.path)}" if perfil_extendido.profilephoto else None,  # Fixed this line
                    'telf': perfil_extendido.telf,
                    'language': perfil_extendido.language,
                    'description': perfil_extendido.description,
                    'location': perfil_extendido.location
                }
            }
            return Response(response_data)
        else:
            return Response(serializer.errors, status=400)

    except Exception as e:
        return Response({"error": f"Error al actualizar perfil: {str(e)}"}, status=500)



# ELIMINAR CUENTA
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def eliminar_cuenta(request):
    user = request.user
    username = user.username
    user.delete()  # Esto también eliminará el perfil en Users por la relación OneToOne con on_delete=CASCADE
    return Response({"message": f"La cuenta '{username}' ha sido eliminada correctamente."}, status=200)


# NOTIFICACIONES (guardamos el token FCM del usuario)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_fcm_token(request):
    fcm_token = request.data.get('token')

    if not fcm_token:
        return Response({'error': 'No se proporcionó el token FCM.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Acceder al perfil extendido
        perfil_extendido = Users.objects.get(user=request.user)
        perfil_extendido.fcm_token = fcm_token
        perfil_extendido.save(update_fields=['fcm_token'])

        return Response({'message': 'Token FCM guardado correctamente.'})
    except Users.DoesNotExist:
        return Response({'error': 'Perfil extendido no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
