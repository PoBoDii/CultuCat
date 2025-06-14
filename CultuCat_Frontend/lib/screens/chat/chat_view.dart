import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';
import 'package:easy_localization/easy_localization.dart';
import 'invite_users.dart';
import 'group_requests.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/utils/globals.dart';

class ChatViewScreen extends StatefulWidget {
  final int chatId;
  final int? toUserId; // privado
  final int? eventId;  // evento
  final String title;

  const ChatViewScreen({
    super.key, // Changed to super parameter
    required this.chatId,
    this.toUserId,
    this.eventId,
    required this.title,
  });

  @override
  State<ChatViewScreen> createState() => _ChatViewScreenState();
}

class _ChatViewScreenState extends State<ChatViewScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  String? _myUsername;
  bool _isScreenActive = true; // 🆕 Para saber si esta pantalla está activa
  bool _isLoading = false; // 🆕 Para mostrar loading

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🆕 Observer para lifecycle
    _loadUsername();
    fetchMessages();
    _setupMessageListener(); // 🆕 Separar la configuración del listener
    onChat = true;
  }

  // 🆕 NUEVO: Configurar listener de mensajes
  void _setupMessageListener() {
    newMessageNotifier.addListener(_handleNewMessage);
    print('🔧 Listener configurado para chat ${widget.chatId}');
  }

  // 🆕 NUEVO: Manejar nuevos mensajes
  void _handleNewMessage() {
    print('🧲 Listener activado. Mensaje: ${newMessageNotifier}');
    final data = newMessageNotifier.value;

    if (data != null && mounted && _isScreenActive) {
      var messageChatId = data['chat_id'];
      if (isGroupChat){
        messageChatId = data['group_id'];}


      print('📱 Chat actual: ${widget.chatId}');
      print('📱 Chat del mensaje: $messageChatId');
      print('📱 ¿Es para este chat?: ${messageChatId.toString() == widget.chatId.toString()}');

      // Verificar que el mensaje es para este chat
      if (messageChatId != null && messageChatId.toString() == widget.chatId.toString()) {
        print('✅ Mensaje para este chat (${widget.chatId})');

        // 🆕 CONVERTIR datos FCM a formato de chat
        final newMessage = {
          'senderUsername': data['sender_username'],
          'message': data['text'],
          'text': data['text'], // Para compatibilidad
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'time': DateFormat('HH:mm').format(DateTime.now()),
          'timestamp': data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        };

        // 🆕 VERIFICAR que no es un mensaje duplicado
        bool isDuplicate = MessageUtils.isDuplicate(newMessage, _messages.reversed.toList());

        if (!isDuplicate) {
          setState(() {
            _messages.add(newMessage);
          });

          // Scroll al final con un pequeño delay
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted) _scrollToBottom();
          });

          print('📝 Mensaje agregado al chat');
          MessageUtils.debugMessage('📝 Nuevo mensaje', newMessage);
        } else {
          print('⚠️ Mensaje duplicado, ignorando');
        }
      }
  }
  }

  // 🆕 NUEVO: Observer para el ciclo de vida de la app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _isScreenActive = false;
    } else if (state == AppLifecycleState.resumed) {
      _isScreenActive = true;
    }
    print('🔄 Estado de la app: $state, Pantalla activa: $_isScreenActive');

    // Actualizar el estado global
    switch (state) {
      case AppLifecycleState.resumed:
        appStateNotifier.value = AppState.foreground;
        break;
      case AppLifecycleState.paused:
        appStateNotifier.value = AppState.background;
        break;
      case AppLifecycleState.detached:
        appStateNotifier.value = AppState.terminated;
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    newMessageNotifier.removeListener(_handleNewMessage); // 🆕 Remover listener
    _saveLastAccessTime();
    print('🗑️ ChatView disposed, listener removido');
    onChat = false;
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final name = await UserPreferences.getUsername();
    setState(() {
      _myUsername = name;
    });
  }

  String _chatKey() {
    final username = _myUsername ?? 'unknown';
    if (isEventChat) return 'lastAccess_event_${widget.chatId}_$username';
    if (isGroupChat) return 'lastAccess_group_${widget.chatId}_$username';
    return 'lastAccess_chat_${widget.chatId}_$username';
  }

  Future<void> _saveLastAccessTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_chatKey(), now.toIso8601String());
  }

  bool get isEventChat => widget.eventId != null;
  bool get isGroupChat => widget.toUserId == null && widget.eventId == null;

  // 🆕 MEJORADO: fetchMessages con mejor manejo de loading
  Future<void> fetchMessages() async {
    if (_isLoading) return; // Evitar múltiples llamadas simultáneas

    setState(() {
      _isLoading = true;
    });

    final token = await UserPreferences.getToken();
    final url = isEventChat
        ? '${ServerUrl.getBaseUrl()}/api/event-chat/${widget.chatId}/messages/'
        : isGroupChat
        ? '${ServerUrl.getBaseUrl()}/groups/${widget.chatId}/messages/'
        : '${ServerUrl.getBaseUrl()}/api/chat/${widget.chatId}/messages/';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Token $token',
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> rawMessages = decoded is List ? decoded : decoded['messages'];

        // 👇 Ajustamos los mensajes de grupo para que tengan siempre senderUsername
        if (isGroupChat) {
          rawMessages = rawMessages.map((msg) {
            return {
              'senderUsername': msg['username'],
              'message': msg['text'],
              'text': msg['text'], // Para compatibilidad
              'date': msg['date'],
              'time': msg['time'],
              'timestamp': DateTime.now().millisecondsSinceEpoch, // Agregar timestamp
            };
          }).toList();
        } else {
          // Asegurar que todos los mensajes tengan timestamp
          rawMessages = rawMessages.map((msg) {
            if (msg['timestamp'] == null) {
              msg['timestamp'] = DateTime.now().millisecondsSinceEpoch;
            }
            return msg;
          }).toList();
        }

        setState(() {
          _messages = rawMessages;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        print('✅ ${rawMessages.length} mensajes cargados');
      } else {
        print('Error al cargar mensajes: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error de conexión al cargar mensajes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🆕 NUEVO: Método para refrescar mensajes manualmente
  Future<void> _refreshMessages() async {
    print('🔄 Refrescando mensajes...');
    await fetchMessages();
  }

  // 🆕 MEJORAR: Envío de mensajes con mejor feedback
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Limpiar el campo inmediatamente para mejor UX
    final originalText = text;
    _controller.clear();

    final token = await UserPreferences.getToken();
    final url = isEventChat
        ? '${ServerUrl.getBaseUrl()}/api/event-chat/send/'
        : isGroupChat
        ? '${ServerUrl.getBaseUrl()}/groups/send/'
        : '${ServerUrl.getBaseUrl()}/api/chat/send/';

    final body = isGroupChat
        ? {
      'group_id': widget.chatId,
      'message': text,
      'is_foreground': _isScreenActive.toString(),
    }
        : {
      'chat_id': widget.chatId,
      'message': text,
      'is_foreground': _isScreenActive.toString(),
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        print('✅ Mensaje enviado correctamente');
        // El mensaje se agregará automáticamente vía FCM
        // Solo hacer scroll si es necesario
        Future.delayed(Duration(milliseconds: 200), () {
          if (mounted) _scrollToBottom();
        });
        fetchMessages();
      } else {
        print('Error al enviar mensaje: ${response.statusCode} - ${response.body}');
        // Restaurar el texto si hay error
        _controller.text = originalText;
        showNiceSnackBar(
          context,
          message: 'Error al enviar mensaje',
          color: Colors.redAccent,
          icon: Icons.error,
        );
      }
    } catch (e) {
      print('Error de conexión al enviar mensaje: $e');
      // Restaurar el texto si hay error
      _controller.text = originalText;
      showNiceSnackBar(
        context,
        message: 'Error de conexión',
        color: Colors.redAccent,
        icon: Icons.error,
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

  // 🆕 MEJORAR: Método para scroll más suave
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // Más espacio
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'today'.tr();
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'yesterday'.tr();
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  void _navigateToInvite() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InviteUserScreen(groupId: widget.chatId),
      ),
    );
  }

  void _navigateToRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupRequestsScreen(groupId: widget.chatId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<dynamic>> groupedMessages = {};
    for (var msg in _messages) {
      final dateStr = msg['date'] ?? '';
      if (dateStr.isNotEmpty) {
        groupedMessages.putIfAbsent(dateStr, () => []).add(msg);
      }
    }

    final sortedDates = groupedMessages.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar mensajes',
            onPressed: _refreshMessages,
          ),
          if (isGroupChat) ...[
            IconButton(
              icon: Icon(Icons.person_add),
              tooltip: 'Invitar usuarios',
              onPressed: _navigateToInvite,
            ),
            IconButton(
              icon: Icon(Icons.mark_email_unread),
              tooltip: 'Ver solicitudes',
              onPressed: _navigateToRequests,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final dateKey = sortedDates[index];
                final messagesOfDate = groupedMessages[dateKey]!;
                final dateTime = DateTime.parse(dateKey);

                return Column(
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 10),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_formatDateSeparator(dateTime),
                          style: TextStyle(color: Colors.blueGrey)),
                    ),
                    ...messagesOfDate.map((msg) {
                      final isMe = msg['senderUsername'] == _myUsername;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)  // Solo mostrar nombre si NO soy yo
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    msg['senderUsername'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ),
                              Text(
                                msg['text'] ?? msg['message'] ?? '',
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                msg['time']?.substring(0, 5) ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'chat_message'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(), // Enviar con Enter
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}