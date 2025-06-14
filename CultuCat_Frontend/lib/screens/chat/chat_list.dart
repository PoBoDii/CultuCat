import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';
import '/screens/chat/chat_view.dart';
import 'package:easy_localization/easy_localization.dart';
import '/screens/chat/group_actions.dart';
import '/screens/chat/group_invitations.dart';
import '/utils/server_url.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _username = '';
  List<dynamic> _chats = [];
  bool _loadingChats = true;

  List<dynamic> _myGroups = [];
  bool _loadingGroups = true;

  List<dynamic> _eventChats = [];
  bool _loadingEventChats = true;

  Timer? _refreshTimer;

  Set<String> sentInvites = {};

  int pendingGroupInvitations = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _loadUsername();
    _fetchChats();
    _fetchMyGroups();
    _fetchEventChats();
    _fetchPendingGroupInvitations();

    _refreshTimer = Timer.periodic(Duration(seconds: 1000), (_) { //cada cuanto refrescar
      _fetchChats();
      _fetchMyGroups();
      _fetchEventChats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
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

  Future<void> _fetchPendingGroupInvitations() async {
    final token = await UserPreferences.getToken();

    final resp = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/my-invitations/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final invitations = data['invitations'] as List;
      setState(() {
        pendingGroupInvitations = invitations.length;
      });
    } else {
      setState(() {
        pendingGroupInvitations = 0;
      });
    }
  }


  Future<bool> _hasUnread(DateTime? lastMessageTime, String chatKeyBase, String? senderUsername) async {
    final key = '${chatKeyBase}_$_username';

    if (senderUsername == _username) return false;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);
    if (stored == null) return true;

    final lastSeen = DateTime.tryParse(stored);
    if (lastSeen == null) return true;

    if (lastMessageTime != null && lastMessageTime.year > 1970) {
      return lastMessageTime.isAfter(lastSeen);
    }

    return true; // si no sabemos la fecha exacta, preferimos mostrar el punto azul
  }

  Future<bool> _hasUnreadPrivateChat(DateTime? lastMessageTime, String chatKeyBase, String senderUsername) async {
    final key = '${chatKeyBase}_$_username';

    if (senderUsername == _username) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(key);

    if (stored == null) {
      return true;
    }

    final lastSeen = DateTime.tryParse(stored);
    if (lastSeen == null) {
      return true;
    }

    if (lastMessageTime != null) {
      final result = lastMessageTime.isAfter(lastSeen);
      return result;
    }

    return false;
  }

  Future<void> _loadUsername() async {
    final name = await UserPreferences.getUsername();
    setState(() => _username = name ?? '');
  }

  Future<void> _fetchChats() async {
    setState(() => _loadingChats = true);
    final token = await UserPreferences.getToken();
    final resp = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/chat/list/'),
      headers: {'Authorization': 'Token $token'},
    );

    print('Respuesta código: ${resp.statusCode}');
    print('Cuerpo: ${resp.body}');

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      print('Chats parseados: $data');  // <- más info
      setState(() {
        _chats = data;
        _loadingChats = false;
      });
    } else {
      setState(() => _loadingChats = false);
    }
  }

  Future<void> _fetchMyGroups() async {
    setState(() => _loadingGroups = true);
    final token = await UserPreferences.getToken();
    final resp = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/my-groups/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (resp.statusCode == 200) {
      setState(() {
        _myGroups = jsonDecode(resp.body)['groups'];
        _loadingGroups = false;
      });
    } else {
      setState(() => _loadingGroups = false);
    }
  }

  void _openSearchGroups() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => GroupActionsScreen()));

  void _openInvitations() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupInvitationsScreen()),
    );
    // Cuando vuelvas (pop), recarga el contador
    _fetchPendingGroupInvitations();
    _fetchMyGroups();
  }


  void _showCreateGroupSheet() {
    final nameCtrl = TextEditingController();
    List<dynamic> allUsers = [];
    int? createdGroupId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) {
          final Set<String> invitedUsernames = {};
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> loadUsers() async {
                if (allUsers.isNotEmpty) return;
                final token = await UserPreferences.getToken();
                final resp = await http.get(
                  Uri.parse('${ServerUrl.getBaseUrl()}/api/users/'),
                  headers: {'Authorization': 'Token $token'},
                );
                if (resp.statusCode == 200) {
                  setSheetState(() {
                    allUsers = jsonDecode(resp.body);
                  });
                }
              }

              Future<void> createGroup() async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final token = await UserPreferences.getToken();
                final resp = await http.post(
                  Uri.parse('${ServerUrl.getBaseUrl()}/groups/create/'),
                  headers: {
                    'Authorization': 'Token $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({'name': name}),
                );

                // FIXED: Proper mounted check before using context
                if (!context.mounted) return;

                if (resp.statusCode == 201) {
                  final group = jsonDecode(resp.body)['group'];
                  createdGroupId = group['id'];
                  sentInvites.clear(); // <-- Aquí reseteas la lista de enviados
                  await _fetchMyGroups();
                  await loadUsers();
                  setSheetState(() {}); // muestra la lista de usuarios
                } else {
                  showNiceSnackBar(
                    context,
                    message: 'group_create_error'.tr(),
                    color: Colors.redAccent,
                    icon: Icons.error,
                  );
                }
              }

              Future<void> invite(String username) async {
                final token = await UserPreferences.getToken();
                final resp = await http.post(
                  Uri.parse('${ServerUrl.getBaseUrl()}/groups/invite/'),
                  headers: {
                    'Authorization': 'Token $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'group_id': createdGroupId,
                    'username': username,
                  }),
                );

                // FIXED: Proper mounted check before using context
                if (!context.mounted) return;

                if (resp.statusCode == 201) {
                  showNiceSnackBar(
                    context,
                    message: 'Invitado: $username',
                    color: Colors.green,
                    icon: Icons.check_circle,
                  );
                } else {
                  showNiceSnackBar(
                    context,
                    message: 'Error al invitar'.tr(args: [username]),
                    color: Colors.redAccent,
                    icon: Icons.error,
                  );
                }
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        createdGroupId == null ? 'create_group'.tr() : 'invite_users'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (createdGroupId == null) ...[
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'group_name_hint'.tr(),
                          labelStyle: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: createGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'create'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                    ] else if (allUsers.isEmpty) ...[
                      const Center(child: CircularProgressIndicator()),
                    ] else ...[
                      ...allUsers.map((u) {
                        final username = u['username'] as String;
                        final alreadyInvited = invitedUsernames.contains(username);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: alreadyInvited
                              ? TextButton(
                            onPressed: null,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.green[100],
                              foregroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'sent'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                              : ElevatedButton(
                            onPressed: () async {
                              await invite(username);
                              invitedUsernames.add(username);
                              setSheetState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'invite'.tr(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '@$_username',
              style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'chats_title'.tr()),
              Tab(text: 'chats_grups'.tr()),
              Tab(text: 'chats_events'.tr()),
            ],
          ),
          actions: _tabController.index == 1
              ? [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.mail_outline, color: Colors.black),
                  onPressed: _openInvitations,
                ),
                if (pendingGroupInvitations > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        '$pendingGroupInvitations',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.add, color: Colors.black),
              onPressed: _showCreateGroupSheet,
            ),
          ]
              : null,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivateChats(),
          _buildGroupChats(),
          _buildEventChats(),
        ],
      ),
    );
  }

  Widget _buildPrivateChats() {
    if (_loadingChats) return Center(child: CircularProgressIndicator());
    if (_chats.isEmpty) return Center(child: Text('no_chats'.tr()));

    return ListView.separated(
      itemCount: _chats.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: .4, color: Colors.grey[400]),
      itemBuilder: (_, i) {
        final c = _chats[i];
        final active = c['hasChat'] == true;
        final timeStr = c['time'] ?? '';
        final showTime = timeStr.isNotEmpty;
        print('Chat item id: ${c['id']} username: ${c['username']} hasChat: $active');

        DateTime? lastMessageTime;

        if (showTime) {
          try {
            lastMessageTime = DateTime.parse(timeStr); // <-- Esto parsea directamente el ISO 8601
          } catch (e) {
            print('Error parseando fecha: $timeStr');
          }
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple[100],
            child: Text(c['username'][0].toUpperCase()),
          ),
          title: Text(c['username'], style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: active
              ? Text(c['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)
              : Text('new_user'.tr(), style: TextStyle(color: Colors.grey)),
          trailing: active && showTime
              ? FutureBuilder<bool>(
            future: _hasUnreadPrivateChat(
              lastMessageTime,
              'lastAccess_chat_${c['chat_id']}',
              c['lastSender'] ?? '',
            ),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data ?? false;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lastMessageTime != null
                        ? _formatTimestampFromDateTime(lastMessageTime)
                        : '',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (hasUnread)
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
              : null,
          onTap: () async {
            final userId = c['id'] ?? c['userId'];
            if (c['hasChat'] == true) {
              if (userId == null) {
                print('Error: userId null en chat existente para ${c['username']}');
                return;
              }
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatViewScreen(
                    toUserId: userId,
                    title: c['username'],
                    chatId: c['id'],
                  ),
                ),
              );
              if (mounted) _fetchChats();
            } else {
              if (userId == null) {
                print('Error: no se pudo obtener userId para crear chat con ${c['username']}');
                return;
              }
              await createChat(userId, c['username']);
            }
          },
        );
      },
    );
  }

  Widget _buildGroupChats() {
    if (_loadingGroups) return Center(child: CircularProgressIndicator());
    if (_myGroups.isEmpty) return Center(child: Text('no_groups'.tr()));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            readOnly: true,
            onTap: _openSearchGroups,
            decoration: InputDecoration(
              hintText: 'search_groups'.tr(),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _myGroups.length,
            separatorBuilder: (_, __) => Divider(height: 1, thickness: .4, color: Colors.grey[400]),
            itemBuilder: (_, i) {
              final g = _myGroups[i];
              final last = g['last_message'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(g['name'][0].toUpperCase()),
                ),
                title: Text(g['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: last != null
                    ? Text(last['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)
                    : Text('no_messages_yet'.tr(), style: TextStyle(color: Colors.grey)),
                trailing: last != null
                    ? FutureBuilder<bool>(
                  future: _hasUnread(
                    DateTime.parse('${last['date']} ${last['time']}'),
                    'lastAccess_group_${g['id']}',
                    last['username'],
                  ),
                  builder: (context, snapshot) {
                    final hasUnread = snapshot.data ?? false;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestampFromDateTime(DateTime.parse('${last['date']} ${last['time']}')),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (hasUnread)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
                    : null,
                onTap: () async {
                  final currentContext = context;
                  await Navigator.push(
                    currentContext,
                    MaterialPageRoute(builder: (_) => ChatViewScreen(chatId: g['id'], title: g['name'])),
                  );
                  if (mounted) {
                    _fetchMyGroups(); // 🔁 Recarga los grupos después de volver
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> createChat(int toUserId, String username) async {
    final token = await UserPreferences.getToken();
    final currentContext = context;

    final resp = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/chat/create/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"to_user_id": toUserId}),
    );

    if (!currentContext.mounted) return;

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final data = jsonDecode(resp.body);
      await _fetchChats();

      if (currentContext.mounted) {
        Navigator.push(
          currentContext,
          MaterialPageRoute(
            builder: (_) => ChatViewScreen(
              toUserId: toUserId,
              title: data['username'] ?? username,
              chatId: data['chat_id'],  // <--- IMPORTANTE: que venga este dato
            ),
          ),
        );
      }
    } else {
      print('Error al crear chat: ${resp.body}');
      // Opcional: mostrar snackbar de error aquí
    }
    print('Creando chat con userId: $toUserId username: $username');
  }

  Future<void> _fetchEventChats() async {
    setState(() => _loadingEventChats = true);
    final token = await UserPreferences.getToken();
    final resp = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/event-chat/my-chats/'),
      headers: {'Authorization': 'Token $token'},
    );
    if (resp.statusCode == 200) {
      setState(() {
        _eventChats = jsonDecode(resp.body)['event_chats'];
        _loadingEventChats = false;
      });
    } else {
      setState(() => _loadingEventChats = false);
    }
  }

  Widget _buildEventChats() {
    if (_loadingEventChats) return Center(child: CircularProgressIndicator());
    if (_eventChats.isEmpty) return Center(child: Text('no_events_chats'.tr()));
    return ListView.separated(
      itemCount: _eventChats.length,
      separatorBuilder: (_, __) => Divider(height: 1, thickness: .4, color: Colors.grey[400]),
      itemBuilder: (_, i) {
        final e = _eventChats[i];
        final last = e['last_message'];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange[100],
            child: Text(e['event_name'][0].toUpperCase()),
          ),
          title: Text(e['event_name'], style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: last != null
              ? Text(last['text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)
              : Text('no_messages_yet'.tr(), style: TextStyle(color: Colors.grey)),
          trailing: last != null
              ? FutureBuilder<bool>(
            future: _hasUnread(
              DateTime.parse('${last['date']} ${last['time']}'),
              'lastAccess_group_${e['id']}',
              last['username'],
            ),
            builder: (context, snapshot) {
              final hasUnread = snapshot.data ?? false;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
              _formatTimestampFromDateTime(DateTime.parse('${last['date']} ${last['time']}')),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (hasUnread)
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
              : null,
            onTap: () async {
              print(">> TAP en chat de evento");
              print("Datos del chat evento: $e");

              final eventId = e['event_id'];
              final eventName = e['event_name'];

              // Llama al mismo endpoint que el botón
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
                final chatId = data['chat_id'];
                print("Abriendo ChatViewScreen para evento con chatId $chatId y título $eventName");
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatViewScreen(
                      chatId: chatId,
                      eventId: eventId,
                      title: eventName,
                    ),
                  ),
                );
                if (mounted) _fetchEventChats();
              } else {
                showNiceSnackBar(
                  context,
                  message: 'No se pudo abrir el chat del evento',
                  color: Colors.redAccent,
                  icon: Icons.error,
                );
              }
            }
        );
      },
    );
  }

  String _formatTimestampFromDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dt.year, dt.month, dt.day);

    if (messageDay == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(Duration(days: 1))) {
      return 'Ayer';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }
  }
}