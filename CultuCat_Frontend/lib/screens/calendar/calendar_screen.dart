import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'package:html_unescape/html_unescape.dart';
import '/screens/event_map/event.dart';
import '/screens/calendar/calendar.dart';
import '../../utils/user_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '/utils/server_url.dart';

class CalendarScreen extends StatefulWidget {
  @override
  CalendarScreenState createState() => CalendarScreenState();
}

class CalendarScreenState extends State<CalendarScreen> {
  List<Map<String, dynamic>> _allEvents = []; // Todos los eventos
  List<Map<String, dynamic>> _filteredEvents = []; // Eventos filtrados por día
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime _selectedDate = DateTime.now(); // Fecha seleccionada (por defecto hoy)
  bool _showAllEvents = false; // Controla si se muestran todos los eventos o solo por día
  // Propiedad para controlar el formato del calendario
  CalendarFormat _currentCalendarFormat = CalendarFormat.month;
  // Instancia para decodificar entidades HTML
  final HtmlUnescape _htmlUnescape = HtmlUnescape();

  @override
  void initState() {
    super.initState();
    _loadEventos();
  }

  Future<void> _loadEventos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final eventsList = await getUserEvents();
      if (!mounted) return;
      setState(() {
        _allEvents = eventsList;
        _updateDisplayedEvents(); // Actualiza los eventos según el modo de visualización
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'calendar_error'.tr()}: $_errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método actualizado para filtrar eventos o mostrar todos
  void _updateDisplayedEvents() {
    setState(() {
      if (_showAllEvents) {
        _filteredEvents = List.from(_allEvents);
      } else {
        _filteredEvents = _allEvents.where((event) {
          if (event['inidate'] == null) return false;

          DateTime eventDate = DateTime.parse(event['inidate']);
          return eventDate.year == _selectedDate.year &&
              eventDate.month == _selectedDate.month &&
              eventDate.day == _selectedDate.day;
        }).toList();
      }
    });
  }

  // Método para manejar el cambio de fecha seleccionada
  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      _showAllEvents = false; // Resetear a mostrar solo eventos del día
    });
    _updateDisplayedEvents();
  }

  // Método para alternar entre mostrar todos los eventos o solo del día seleccionado
  void _toggleViewAllEvents() {
    setState(() {
      _showAllEvents = !_showAllEvents;
    });
    _updateDisplayedEvents();
  }

  // Método para actualizar el formato del calendario
  void _onCalendarFormatChanged(CalendarFormat format) {
    setState(() {
      _currentCalendarFormat = format;
    });
  }

  // Método para decodificar texto con caracteres especiales
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

  Future<List<Map<String, dynamic>>> getUserEvents() async {
    final url = Uri.parse('${ServerUrl.getBaseUrl()}/api/calendar/events/');
    final token = await UserPreferences.getToken();
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> eventsJson = data['events'] ?? [];

      // Procesar cada evento para corregir la codificación de texto
      final processedEvents = eventsJson.map((event) {
        if (event is Map<String, dynamic>) {
          // Decodificar el nombre del evento
          if (event['name'] != null) {
            event['name'] = _decodeText(event['name']);
          }

          // Decodificar la dirección si existe
          if (event['location'] != null && event['location']['address'] != null) {
            event['location']['address'] = _decodeText(event['location']['address']);
          }
        }
        return event;
      }).toList();

      return List<Map<String, dynamic>>.from(processedEvents);
    } else {
      throw Exception('${'calendar_error'.tr()} (${response.statusCode})');
    }
  }

  Future<void> _refreshEvents() async {
    await _loadEventos();
  }

  @override
  Widget build(BuildContext context) {
    // Calcular la altura disponible para la pantalla
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final availableHeight = screenHeight - appBarHeight - statusBarHeight - bottomPadding;

    return Scaffold(
      appBar: AppBar(
        title: Text('calendar_title'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Widget de calendario con selección de fecha y botón para ver todos
          // Altura adaptativa según el formato del calendario
          SizedBox(
            height: _calculateCalendarHeight(availableHeight, _currentCalendarFormat),
            child: TableBasicsExample(
              onDateSelected: _onDateSelected,
              selectedDate: _selectedDate,
              onViewAllEvents: _toggleViewAllEvents,
              onFormatChanged: _onCalendarFormatChanged,
              initialFormat: _currentCalendarFormat,
            ),
          ),

          // Sección de eventos del día seleccionado o todos los eventos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showAllEvents
                      ? 'calendar_all_events'.tr()
                      : '${'calendar_events_for_day'.tr()} ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_filteredEvents.length} ${_filteredEvents.length == 1 ? "chats_events".tr() : "chats_events".tr()}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
            child: _filteredEvents.isNotEmpty
                ? RefreshIndicator(
              onRefresh: _refreshEvents,
              child: ListView.builder(
                itemCount: _filteredEvents.length,
                itemBuilder: (context, index) {
                  var event = _filteredEvents[index];
                  // Ordenar eventos por fecha si se muestran todos
                  if (_showAllEvents && index == 0) {
                    _filteredEvents.sort((a, b) {
                      if (a['inidate'] == null) return 1;
                      if (b['inidate'] == null) return -1;
                      return DateTime.parse(a['inidate']).compareTo(DateTime.parse(b['inidate']));
                    });
                    event = _filteredEvents[index]; // Actualizar después de ordenar
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                      child: ListTile(
                        title: Text(event['name'] ?? 'Sin nombre'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event['location'] != null)
                              Text(event['location']['address'] ?? 'no_address'.tr()),
                            if (event['inidate'] != null)
                              Text(
                                _formatDate(event['inidate']) ?? 'no_date'.tr(),
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeEventFromCalendar(event['id']),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EventScreen(
                                texto: event['name'] ?? 'event_hint'.tr(),
                                id: event['id'].toString(),
                              ),
                            ),
                          ).then((_) => _refreshEvents());
                        },
                      ),
                    ),
                  );
                },
              ),
            )
                : Center(child: Text(_showAllEvents
                ? "calendar_no_events".tr()
                : "calendar_no_events_for_date".tr())),
          ),
        ],
      ),
    );
  }

  // Método mejorado para calcular la altura adaptativa del calendario
  double _calculateCalendarHeight(double availableHeight, CalendarFormat format) {
    // Asignar un porcentaje del espacio disponible según el formato
    switch (format) {
      case CalendarFormat.month:
        return availableHeight * 0.45; // 45% del espacio disponible
      case CalendarFormat.twoWeeks:
        return availableHeight * 0.3; // 30% del espacio disponible
      case CalendarFormat.week:
        return availableHeight * 0.23; // 20% del espacio disponible
      default:
        return availableHeight * 0.45;
    }
  }

  // Formatear la fecha para mostrarla de manera amigable
  String? _formatDate(String? dateString) {
    if (dateString == null) return null;

    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Eliminar un evento del calendario
  void _removeEventFromCalendar(int eventId) async {
    // Capture context safely before async operations
    final currentContext = context;

    final shouldRemove = await showDialog<bool>(
      context: currentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("calendar_remove_confirm_title".tr()),
          content: Text("calendar_remove_confirm_message".tr()),
          actions: [
            TextButton(
              child: Text("calendar_cancel".tr()),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text("calendar_remove".tr(), style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;

    // If user canceled, exit early
    if (!shouldRemove) return;

    // Mostrar indicador de carga
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('http://10.0.2.2:8000/api/calendar/remove-event/$eventId/');
      final token = await UserPreferences.getToken();
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Token $token',
        },
      );

      // Check if widget is still mounted before updating UI
      if (!mounted) return;

      if (response.statusCode == 200) {
        // Evento eliminado con éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('calendar_event_removed'.tr()),
            backgroundColor: Colors.green,
          ),
        );

        // Recargar eventos
        _loadEventos();
      } else {
        // Error al eliminar
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'calendar_remove_error'.tr());
      }
    } catch (e) {
      // Check if widget is still mounted before updating UI
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
}