import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_preferences.dart';
import 'package:html_unescape/html_unescape.dart';
import '/utils/server_url.dart';
import 'event_info.dart';
import 'review.dart';
import 'join_group.dart';
import 'image_widget.dart';
import 'event_navigation_button.dart'; // Import the navigation button
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:share_plus/share_plus.dart';
// ignore_for_file: deprecated_member_use


class EventScreen extends StatefulWidget {
  final String texto;
  final String id;

  const EventScreen({super.key, required this.texto, required this.id});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final EventService eventService = EventService();
  late Future<Map<String, dynamic>> _eventDetailFuture;
  Map<String, dynamic> _eventDetails = {};

  @override
  void initState() {
    super.initState();
    _eventDetailFuture = eventService.fetchEventDetail(int.parse(widget.id));
    _loadEventDetails();
  }

  Future<void> shareEvent(BuildContext context, String eventId, String eventName) async {
    final String title = 'share_event_title'.tr(args: [eventName]);
    final String description = 'share_event_description'.tr();

    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://cultucat.page.link',
      link: Uri.parse('https://cultucat.page.link/event?id=$eventId&name=${Uri.encodeComponent(eventName)}'),
      androidParameters: AndroidParameters(
        packageName: 'cat.cultucat.app',
        minimumVersion: 0,
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: title,
        description: description,
      ),
    );

    final ShortDynamicLink shortLink = await FirebaseDynamicLinks.instance.buildShortLink(parameters);
    final Uri shortUrl = shortLink.shortUrl;

    final String message = 'share_event_message'.tr(args: [shortUrl.toString()]);

    await Share.share(message);
  }

  Future<void> _loadEventDetails() async {
    try {
      final details = await _eventDetailFuture;
      if (mounted) {
        setState(() {
          _eventDetails = details;
        });
      }
    } catch (e) {
      print('Error loading event details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.texto,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              if (_eventDetails['name'] != null) {
                shareEvent(context, widget.id, _eventDetails['name'] ?? '');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: _eventDetails['imagepath'] != null && _eventDetails['imagepath'] != '---'
                    ? ImageWidget(
                  imageString: _eventDetails['imagepath']!,
                  fit: BoxFit.cover,
                )
                    : Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            // Add the navigation button if event details are loaded
            // Justo después de la imagen del evento
            if (_eventDetails.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: EventNavigationButton(
                      eventId: int.parse(widget.id),
                      eventName: widget.texto,
                      eventDetails: _eventDetails,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: Colors.blue),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        'save_to_calendar'.tr(),
                        style: const TextStyle(
                          fontSize: 13, // <--- Cambia el tamaño aquí (ajusta a tu gusto)
                          fontWeight: FontWeight.w500,
                          overflow: TextOverflow.ellipsis, // Opcional, evita salto de línea
                        ),
                        maxLines: 1, // <--- Esto asegura que no pase a dos líneas
                        softWrap: false, // <--- Opcional, pero ayuda a forzar una línea
                      ),
                      onPressed: () {
                        eventService.addEventToCalendar(context, int.parse(widget.id));
                      },
                    ),
                  ),
                ],
              ),
            Expanded(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: DefaultTabController(
                  length: 3,
                  child: Scaffold(
                    appBar: const TabBar(
                      indicatorColor: Colors.blue,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.black,
                      tabs: [
                        Tab(icon: Icon(Icons.info)),
                        Tab(icon: Icon(Icons.chat_bubble)),
                        Tab(icon: Icon(Icons.star)),
                      ],
                    ),
                    body: TabBarView(
                      children: [
                        EventInfo(eventId: int.parse(widget.id)), // Fixed: Using widget.id
                        EventChatJoinButton(eventId: int.parse(widget.id), eventName: widget.texto), // Fixed: Using widget properties
                        ReviewTab(
                          eventId: int.parse(widget.id),
                          averageRating: double.tryParse(_eventDetails['average_rate'] ?? '0.0') ?? 0.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class TranslationService {
  static const String libreTranslateUrl = "https://libretranslate.com/translate";

  /// Traduce el texto desde el español al inglés utilizando LibreTranslate
  static Future<String> translateTo(String text, String lan) async {
    if (text.isEmpty || text == '---') {
      return text;
    }

    try {
      final response = await http.post(
        Uri.parse(libreTranslateUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'q': text,
          'source': 'auto', // Assumimos que el texto está en catalan
          'target': 'en',
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final translatedData = json.decode(response.body);
        return translatedData['translatedText'] ?? text;
      } else {
        print('Error en la traducción: ${response.statusCode}');
        return "ERROR";
      }
    } catch (e) {
      print('Excepción durante la traducción: $e');
      return "ERROR";
    }
  }
}

class EventService {
  final String baseUrl = "${ServerUrl.getBaseUrl()}/events"; // Cambia esto por la URL de tu API
  final HtmlUnescape _htmlUnescape = HtmlUnescape();

  String _decodeText(String text) {
    // Primero decodificar entidades HTML como &aacute;
    String decoded = _htmlUnescape.convert(text);

    // Luego manejar codificaciones incorrectas comunes
    try {
      // Intentar utf8.decode para corregir caracteres especiales
      return utf8.decode(latin1.encode(decoded));
    } catch (e) {
      // Si hay error, devolver el texto original decodificado de HTML
      return decoded;
    }
  }

  Future<Map<String, dynamic>> fetchEventDetail(int eventId) async {
    final response = await http.get(Uri.parse("$baseUrl/$eventId"));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body)['event'];

      String? zipcode = data['addressid']['zipcode']?.toString();
      // If zipcode is null or 'null' string, set it to null explicitly
      if (zipcode == 'null') zipcode = null;

      // Extraer coordenadas
      double? latitude = data['addressid']['latitude']?.toDouble();
      double? longitude = data['addressid']['longitude']?.toDouble();

      // Handle multiple image paths
      String? imagePath = data['imagepath'];
      if (imagePath != null && imagePath != '---') {
        // Split the image paths and take the first one
        List<String> imagePaths = imagePath.split(',');
        imagePath = imagePaths.first.trim();

        // Add base URL if not already a full URL
        if (!imagePath.startsWith('http')) {
          imagePath = 'https://agenda.cultura.gencat.cat$imagePath';
        }
        print('First image path: $imagePath');
      }

      return {
        'name': data['name'] ?? '',
        'inidate': data['inidate'] ?? '',
        'enddate': data['enddate'] ?? '',
        'description': data['description'] ?? '---',
        'address': data['addressid']['address'] ?? '',
        'zipcode': zipcode,
        'latitude': latitude,
        'longitude': longitude,
        'categories': (data['categories'] as List<dynamic>).join(', '),
        'tematiques': (data['tematiques'] as List<dynamic>).join(', '),
        'tickets': data['tickets'] ?? '---',
        'schedule': data['schedule'] ?? '---',
        'link': data['link'] ?? '---',
        'email': data['email'] ?? '---',
        'telefon': data['telefon'] ?? '---',
        'imagepath': imagePath ?? '---',
        'average_rate': data['average_rate'].toString(),
      };
    } else {
      throw Exception("Failed to load event details");
    }
  }

  Future<void> addEventToCalendar(BuildContext context, int eventId) async {
    // Store context reference before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final url = Uri.parse('${ServerUrl.getBaseUrl()}/api/calendar/add-event/');
    final token = await UserPreferences.getToken();
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'event_id': eventId}),
    );

    String message;

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      message = data['message'] ?? 'calendar_add'.tr();
    } else {
      try {
        final error = jsonDecode(response.body);
        message = error['error'] ?? '';
      } catch (_) {
        message = '${'calendar_add_error'.tr()} (${response.statusCode})';
      }
    }

    // Show message in SnackBar using the stored reference
    showNiceSnackBar(
      context,
      message: _decodeText(message),
      color: response.statusCode == 201 ? Colors.green : Colors.red,
      icon: response.statusCode == 201 ? Icons.check_circle : Icons.error,
    );
  }
}

void showNiceSnackBar(BuildContext context, {
  required String message,
  required Color color,
  required IconData icon,
}) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  ScaffoldMessenger.of(rootContext).clearSnackBars();
  ScaffoldMessenger.of(rootContext).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class TranslatableInfoBox extends StatefulWidget {
  final String label;
  final String value;

  const TranslatableInfoBox({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  State<TranslatableInfoBox> createState() => _TranslatableInfoBoxState();
}

class _TranslatableInfoBoxState extends State<TranslatableInfoBox> {
  bool _isTranslating = false;
  String? _translatedText;
  bool _showTranslation = false;

  Future<void> _translateText() async {
    if (_translatedText != null) {
      if (!mounted) return;
      setState(() {
        _showTranslation = !_showTranslation;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final currentLocale = context.locale.languageCode;
      final translated = await TranslationService.translateTo(widget.value, currentLocale);

      if (!mounted) return;

      setState(() {
        _translatedText = translated;
        _showTranslation = true;
        _isTranslating = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isTranslating = false;
      });
      print('Error al traducir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener el código de idioma actual
    final currentLocale = context.locale.languageCode;
    final shouldShowTranslateButton = currentLocale != 'ca' && widget.value != '---';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${widget.label}:",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.value,
            style: const TextStyle(fontSize: 16),
          ),
          if (_isTranslating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_showTranslation && _translatedText != null) ...[
            const Divider(),
            const Row(
              children: [
                Icon(Icons.translate, size: 16),
                SizedBox(width: 4),
                Text(
                  "English:",
                  style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _translatedText!,
              style: const TextStyle(fontSize: 16),
            ),
          ],
          // Mostrar el botón de traducción solo si no estamos en catalán
          if (shouldShowTranslateButton)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isTranslating ? null : _translateText,
                icon: Icon(_showTranslation ? Icons.visibility_off : Icons.translate, size: 16),
                label: Text(_showTranslation ? "translate_hide".tr() : "translate_to".tr()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}