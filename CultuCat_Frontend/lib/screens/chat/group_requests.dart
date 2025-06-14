import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '/utils/server_url.dart';

class GroupRequestsScreen extends StatefulWidget {
  final int groupId;

  const GroupRequestsScreen({super.key, required this.groupId});

  @override
  GroupRequestsScreenState createState() => GroupRequestsScreenState();
}

class GroupRequestsScreenState extends State<GroupRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/${widget.groupId}/requests/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _requests = data['requests'] ?? [];
        _loading = false;
      });
    } else {
      print('Error al obtener solicitudes: ${response.body}');
      setState(() => _loading = false);
    }
  }

  Future<void> handleRequest(int requestId, String action) async {
    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/groups/handle-request/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'request_id': requestId,
        'action': action,
      }),
    );

    if (response.statusCode == 200) {
      await fetchRequests();
    } else {
      print('Error al procesar solicitud: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text(
          'pending_requests_title'.tr(),
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
          : _requests.isEmpty
          ? Center(
        child: Text(
          'no_pending_requests'.tr(),
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const Divider(height: 8),
        itemBuilder: (context, index) {
          final req = _requests[index];
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
                  req['username'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              title: Text(
                req['username'],
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  req['request_date'],
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
                    onPressed: () => handleRequest(req['id'], 'accept'),
                    tooltip: 'accept'.tr(),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                    onPressed: () => handleRequest(req['id'], 'reject'),
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
