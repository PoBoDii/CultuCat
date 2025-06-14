import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '/utils/server_url.dart';

class GroupInvitationsScreen extends StatefulWidget {
  const GroupInvitationsScreen({super.key});

  @override
  State<GroupInvitationsScreen> createState() => _GroupInvitationsScreenState();
}

class _GroupInvitationsScreenState extends State<GroupInvitationsScreen> {
  List<dynamic> _invitations = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchInvitations();
  }

  Future<void> _fetchInvitations() async {
    setState(() => _loading = true);

    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/my-invitations/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _invitations = data['invitations'];
        _loading = false;
      });
    } else {
      print('Error al obtener invitaciones: ${response.body}');
      setState(() => _loading = false);
    }
  }

  Future<void> _respondInvitation(int invitationId, String action) async {
    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/respond-invitation/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'invitation_id': invitationId,
        'action': action,
      }),
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      showNiceSnackBar(
        context,
        message: action == 'accept' ? 'invitation_accepted'.tr() : 'invitation_rejected'.tr(),
        color: Colors.redAccent,
        icon: Icons.error,
      );
      await _fetchInvitations();
    } else {
      print('Error al responder: ${response.body}');
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'pending_invitations_title'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invitations.isEmpty
          ? Center(
        child: Text(
          'no_pending_invitations'.tr(),
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        itemCount: _invitations.length,
        separatorBuilder: (_, __) => const Divider(height: 8),
        itemBuilder: (context, index) {
          final inv = _invitations[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  inv['group_name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              title: Text(
                inv['group_name'],
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  'invited_by'.tr(args: [inv['invited_by'] ?? '---']),
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontSize: 13,
                  ),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    onPressed: () => _respondInvitation(inv['id'], 'accept'),
                    tooltip: 'accept'.tr(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                    onPressed: () => _respondInvitation(inv['id'], 'reject'),
                    tooltip: 'reject'.tr(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
