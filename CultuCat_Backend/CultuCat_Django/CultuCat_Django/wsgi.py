"""
WSGI config for CultuCat_Django project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.1/howto/deployment/wsgi/
"""
import os
os.environ['CRYPTOGRAPHY_OPENSSL_NO_LEGACY'] = '1'

try:
	from OpenSSL import SSL
	if not hasattr(SSL._lib, 'X509_V_FLAG_NOTIFY_POLICY'):
		SSL._lib.X509_V_FLAG_NOTIFY_POLICY = 0x200000
except ImportError:
	pass

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'CultuCat_Django.settings')

application = get_wsgi_application()
