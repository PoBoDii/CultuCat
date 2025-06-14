import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'faq_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'settings_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: ListView(
        children: [
          // Configuración de idioma
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(
              'settings_language'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _getLanguageName(currentLocale.languageCode),
            ),
            onTap: () {
              _showLanguageDialog(context);
            },
          ),

          // FAQ
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(
              'faq_title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FAQScreen()),
              );
            },
          ),

          // Soporte por email
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(
              'settings_support'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('settings_support_description'.tr()),
            onTap: () {
              _launchEmail();
            },
          ),

          // Más opciones aquí si las necesitas
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'es':
        return 'Español';
      case 'en':
        return 'English';
      case 'ca':
        return 'Català';
      default:
        return code;
    }
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'settings_language'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _languageOption(context, 'es', 'Español'),
            _languageOption(context, 'en', 'English'),
            _languageOption(context, 'ca', 'Català'),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(BuildContext context, String code, String name) {
    return ListTile(
      title: Text(name),
      leading: const Icon(Icons.language),
      onTap: () {
        context.setLocale(Locale(code));
        Navigator.pop(context); // Cerrar el diálogo
      },
    );
  }

  // Función para abrir la aplicación de correo predeterminada
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'cultucat@gmail.com',
      query: _encodeQueryParameters({
        'subject': 'support_email_subject'.tr(),
        'body': 'support_email_body'.tr(),
      }),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      // No se pudo abrir la aplicación de correo
      debugPrint('No se pudo abrir la aplicación de correo');
    }
  }

  // Función auxiliar para codificar los parámetros de la URL
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}