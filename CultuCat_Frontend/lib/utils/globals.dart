import 'package:flutter/material.dart';

bool onChat = false;

// 🆕 MODELO: Clase para mensajes de chat más estructurada

class ChatMessage {
  final int chatId;
  final String senderUsername;
  final String text;
  final DateTime timestamp;
  final String? messageType;

  ChatMessage({
    required this.chatId,
    required this.senderUsername,
    required this.text,
    required this.timestamp,
    this.messageType,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      chatId: int.tryParse(map['chat_id']?.toString() ?? '') ?? 0,
      senderUsername: map['sender_username']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      messageType: map['type']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chat_id': chatId,
      'sender_username': senderUsername,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': messageType,
    };
  }

  @override
  String toString() {
    return 'ChatMessage(chatId: $chatId, sender: $senderUsername, text: $text, timestamp: $timestamp)';
  }
}

// 🔄 MANTENER: Sistema existente de notificaciones para compatibilidad
final ValueNotifier<Map<String, dynamic>?> newMessageNotifier = ValueNotifier(null);

// 🆕 NUEVO: Notifier más estructurado (opcional para futuras mejoras)
final ValueNotifier<ChatMessage?> newChatMessageNotifier = ValueNotifier(null);

// 🆕 UTILIDADES: Funciones helper para manejo de mensajes
class MessageUtils {

  /// Convierte un mensaje FCM a formato de chat
  static Map<String, dynamic> fcmToChat(Map<String, dynamic> fcmData) {
    return {
      'senderUsername': fcmData['sender_username'],
      'message': fcmData['text'],
      'text': fcmData['text'],
      'date': DateTime.now().toString().split(' ')[0],
      'time': DateTime.now().toString().split(' ')[1].substring(0, 5),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Verifica si un mensaje es duplicado comparando con los últimos mensajes
  static bool isDuplicate(
      Map<String, dynamic> newMessage,
      List<dynamic> existingMessages,
      {int checkLastCount = 3}
      ) {
    if (existingMessages.isEmpty) return false;

    final lastMessages = existingMessages.take(checkLastCount);

    return lastMessages.any((msg) =>
    msg['message'] == newMessage['message'] &&
        msg['senderUsername'] == newMessage['senderUsername'] &&
        (msg['timestamp'] != null && newMessage['timestamp'] != null
            ? (msg['timestamp'] - newMessage['timestamp']).abs() < 5000 // 5 segundos
            : false)
    );
  }

  /// Debug: Imprime información del mensaje
  static void debugMessage(String prefix, dynamic message) {
    print('$prefix: $message');
    if (message is Map) {
      message.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
    }
  }
}

// 🆕 CONSTANTES: Estados de la aplicación
enum AppState {
  foreground,
  background,
  terminated,
}

// 🆕 GLOBAL: Estado actual de la aplicación
ValueNotifier<AppState> appStateNotifier = ValueNotifier(AppState.foreground);