import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import '../../utils/user_preferences.dart';
import '/screens/chat/chat_view.dart';
import '/utils/server_url.dart';


class EventChatJoinButton extends StatelessWidget {
  final int eventId;
  final String eventName;

  const EventChatJoinButton({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  Future<void> joinEventChat(BuildContext context) async {
    // Store necessary context information before async operation
    final navigator = Navigator.of(context);

    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/event-chat/join/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'event_id': eventId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatViewScreen(
            chatId: data['chat_id'],
            eventId: eventId,
            title: eventName, // Esto es lo que aparece en el AppBar
          ),
        ),
      );
    } else {
      print('Error al unirse al chat de evento: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => joinEventChat(context),
        icon: Icon(Icons.forum, color: Colors.blue),
        label: Text(
          'unirChatEvent'.tr(),
          style: TextStyle(color: Colors.blue), // Color del texto
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.blue, // Color del texto
          backgroundColor: Colors.white, // Color del fondo
          side: BorderSide(color: Colors.blue), // Borde azul
        ),
      ),
    );
  }
}