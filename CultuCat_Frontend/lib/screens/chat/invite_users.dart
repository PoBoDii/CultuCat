import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';
import 'package:easy_localization/easy_localization.dart';

class InviteUserScreen extends StatefulWidget {
  final int groupId;

  const InviteUserScreen({super.key, required this.groupId});

  @override
  State<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends State<InviteUserScreen> {
  List<dynamic> _allUsers = [];
  Set<String> _invitedUsers = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
  }

  Future<void> _fetchAllUsers() async {
    setState(() => _loading = true);
    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/users/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _allUsers = data;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      // Puedes poner tu snackbar bonito aquí si quieres
      showNiceSnackBar(
        context,
        message: 'Error al cargar usuarios',
        color: Colors.green, // O el color que quieras para éxito
        icon: Icons.check_circle,
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

  Future<void> _inviteUser(String username) async {
    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/invite/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'group_id': widget.groupId,
        'username': username,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 201 || response.statusCode == 200) {
      setState(() {
        _invitedUsers.add(username);
      });
      showNiceSnackBar(
        context,
        message: 'invite_sent'.tr(args: [username]),
        color: Colors.green, // O el color que quieras para éxito
        icon: Icons.check_circle,
      );
    } else {
      // Mostramos el error real
      final errMsg = jsonDecode(response.body);
      showNiceSnackBar(
        context,
        message: errMsg['error']?.toString() ?? 'invite_error'.tr(),
        color: Colors.green, // O el color que quieras para éxito
        icon: Icons.check_circle,
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'invite_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,      // Puedes ajustar el tamaño si quieres
            color: Colors.black, // Opcional: color negro (queda más moderno)
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black), // Si quieres el icono en negro también
        backgroundColor: Colors.white, // Opcional: fondo blanco para el AppBar
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : _allUsers.isEmpty
            ? Center(child: Text('no_results'.tr()))
            : ListView.builder(
          itemCount: _allUsers.length,
          itemBuilder: (context, index) {
            final user = _allUsers[index];
            final username = user['username'];
            final isInvited = _invitedUsers.contains(username);
            return ListTile(
              leading: CircleAvatar(
                child: Text(username[0].toUpperCase()),
              ),
              title: Text(username),
              trailing: ElevatedButton(
                onPressed: isInvited ? null : () => _inviteUser(username),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInvited ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isInvited ? 'invite_sent_btn'.tr() : 'invite'.tr(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
