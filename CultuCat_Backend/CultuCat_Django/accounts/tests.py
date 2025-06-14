from django.test import TestCase
from django.urls import reverse
from django.contrib.auth.models import User
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.contrib.auth.tokens import default_token_generator
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from django.core import mail
import json
from django.db.models.signals import post_save
from .signals import create_or_update_user_profile

class AuthenticationTests(TestCase):
    @classmethod
    def setUpClass(cls):
        # Desconectar la señal durante las pruebas
        post_save.disconnect(create_or_update_user_profile, sender=User)
        super().setUpClass()
        
    @classmethod
    def tearDownClass(cls):
        # Reconectar la señal después de las pruebas
        post_save.connect(create_or_update_user_profile, sender=User)
        super().tearDownClass()
        
    def setUp(self):
        # Setup test client
        self.client = APIClient()
        
        # Create a test user
        self.test_user = User.objects.create_user(
            username='testuser',
            email='test@example.com',
            password='securepassword123'
        )
        
        # URLs correctas según el archivo urls.py
        self.login_url = '/api/login/'
        self.register_url = '/api/register/'
        self.reset_password_email_url = '/api/send-password-reset-email/'  # Corregido: se añadió / al inicio
        
    def test_login_successful(self):
        """Test successful login with correct credentials"""
        data = {
            'username': 'testuser',
            'password': 'securepassword123'
        }
        response = self.client.post(self.login_url, data, format='json')
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('token', response.data)
        self.assertEqual(response.data['message'], 'Login exitoso')
        
        # Verify token exists in database
        token = Token.objects.get(user=self.test_user)
        self.assertEqual(response.data['token'], token.key)
        
    def test_login_failed_wrong_password(self):
        """Test login with incorrect password"""
        data = {
            'username': 'testuser',
            'password': 'wrongpassword'
        }
        response = self.client.post(self.login_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Username o password incorrectos')
        
    def test_login_failed_nonexistent_user(self):
        """Test login with nonexistent username"""
        data = {
            'username': 'nonexistentuser',
            'password': 'securepassword123'
        }
        response = self.client.post(self.login_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Username o password incorrectos')
    
    def test_register_successful(self):
        """Test successful user registration"""
        data = {
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'newpassword123',
            'confirm_password': 'newpassword123'
        }
        response = self.client.post(self.register_url, data, format='json')
        
        self.assertEqual(response.status_code, 201)
        self.assertIn('token', response.data)
        self.assertEqual(response.data['message'], 'Registro completado')
        
        # Verify user was created
        self.assertTrue(User.objects.filter(username='newuser').exists())
        
    def test_register_failed_missing_fields(self):
        """Test registration with missing fields"""
        data = {
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'newpassword123',
            # Missing confirm_password
        }
        response = self.client.post(self.register_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Todos los campos son obligatorios')
        
    def test_register_failed_password_mismatch(self):
        """Test registration with mismatched passwords"""
        data = {
            'username': 'newuser',
            'email': 'newuser@example.com',
            'password': 'newpassword123',
            'confirm_password': 'differentpassword'
        }
        response = self.client.post(self.register_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Las contraseñas no coinciden')
        
    def test_register_failed_existing_username(self):
        """Test registration with existing username"""
        data = {
            'username': 'testuser',  # This username already exists
            'email': 'another@example.com',
            'password': 'newpassword123',
            'confirm_password': 'newpassword123'
        }
        response = self.client.post(self.register_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Este username ya esta registrado')
        
    def test_register_failed_existing_email(self):
        """Test registration with existing email"""
        data = {
            'username': 'anotheruser',
            'email': 'test@example.com',  # This email already exists
            'password': 'newpassword123',
            'confirm_password': 'newpassword123'
        }
        response = self.client.post(self.register_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Este email ya esta registrado')
        
    def test_password_reset_email_sent(self):
        """Test sending password reset email"""
        data = {
            'email': 'test@example.com'
        }
        response = self.client.post(self.reset_password_email_url, data, format='json')
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'Correo de recuperación enviado')
        
        # Check that an email was sent
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].subject, 'Recuperación de contraseña')
        self.assertEqual(mail.outbox[0].to, ['test@example.com'])
        
    def test_password_reset_email_nonexistent_user(self):
        """Test sending password reset email to nonexistent user"""
        data = {
            'email': 'nonexistent@example.com'
        }
        response = self.client.post(self.reset_password_email_url, data, format='json')
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'No existe un usuario con este correo electronico')
        
    def test_password_reset_flow(self):
        """Test the complete password reset flow"""
        user = self.test_user
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = default_token_generator.make_token(user)
        reset_url = f'/api/reset-password/{uid}/{token}/'  # Esta URL está correcta
        
        # First, test the GET request to show the form
        response = self.client.get(reset_url)
        self.assertEqual(response.status_code, 200)
        
        # Now test the POST request to change the password
        data = {
            'new_password': 'newpassword456',
            'confirm_password': 'newpassword456'
        }
        response = self.client.post(reset_url, data)
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'Password actualizado correctamente')
        
        # Verify the password was changed by logging in
        self.client.logout()
        login_successful = self.client.login(username='testuser', password='newpassword456')
        self.assertTrue(login_successful)
        
    def test_password_reset_mismatch_passwords(self):
        """Test password reset with mismatched passwords"""
        user = self.test_user
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        token = default_token_generator.make_token(user)
        reset_url = f'/api/reset-password/{uid}/{token}/'  # Corregido: eliminado 'accounts' del path
        
        data = {
            'new_password': 'newpassword456',
            'confirm_password': 'differentpassword'
        }
        response = self.client.post(reset_url, data)
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Las contraseñas no coinciden')
        
    def test_password_reset_invalid_token(self):
        """Test password reset with invalid token"""
        user = self.test_user
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        reset_url = f'/api/reset-password/{uid}/invalid-token/'
        
        data = {
            'new_password': 'newpassword456',
            'confirm_password': 'newpassword456'
        }
        response = self.client.post(reset_url, data)
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Token inválido o expirado')
        
    def test_password_reset_invalid_uid(self):
        """Test password reset with invalid uid"""
        user = self.test_user
        token = default_token_generator.make_token(user)
        reset_url = f'/api/reset-password/invalid-uid/{token}/'
        
        data = {
            'new_password': 'newpassword456',
            'confirm_password': 'newpassword456'
        }
        response = self.client.post(reset_url, data)
        
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['error'], 'Enlace inválido')