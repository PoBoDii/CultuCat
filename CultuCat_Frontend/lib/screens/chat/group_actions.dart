import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';
import 'package:easy_localization/easy_localization.dart';

class GroupActionsScreen extends StatefulWidget {
  const GroupActionsScreen({super.key});

  @override
  State<GroupActionsScreen> createState() => _GroupActionsScreenState();
}

class _GroupActionsScreenState extends State<GroupActionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _loading = false;

  Future<void> _searchGroups() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _loading = true);

    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/search/?query=$query'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _searchResults = data['groups'] ?? [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      showNiceSnackBar(
        context,
        message: 'group_search_error'.tr(),
        color: Colors.redAccent,
        icon: Icons.error,
      );
    }
  }

  Future<void> _joinGroup(int groupId, String groupName) async {
    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/join/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'group_id': groupId}),
    );

    if (!mounted) return;

    if (response.statusCode == 201 || response.statusCode == 200) {
      showNiceSnackBar(
        context,
        message: 'join_request_sent'.tr(args: [groupName]),
        color: Colors.green,
        icon: Icons.check_circle,
      );
      Navigator.pop(context);
    } else {
      showNiceSnackBar(
        context,
        message: 'join_request_error'.tr(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Título en negrita y negro
        title: Text(
          'search_groups_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black87,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.8,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Buscador
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'search_group_hint'.tr(),
                hintStyle: TextStyle(color: Colors.grey[500]),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue),
                  onPressed: _searchGroups,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                child: Text(
                  'no_results'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
                  : ListView.separated(
                separatorBuilder: (_, __) => const Divider(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final group = _searchResults[index];
                  final isMember = group['is_member'];
                  final groupName = group['name'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        groupName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: Text(
                      isMember
                          ? 'already_member'.tr()
                          : 'not_member'.tr(),
                      style: TextStyle(
                        color: isMember
                            ? Colors.blue[300]
                            : Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: isMember
                        ? null
                        : ElevatedButton(
                      onPressed: () => _joinGroup(group['id'], groupName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'join'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
