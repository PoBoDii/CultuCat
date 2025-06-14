import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';

class AddFriendScreen extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Future<bool> Function(String username) onSendRequest;

  const AddFriendScreen({
    super.key,
    required this.users,
    required this.onSendRequest,
  });

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  Set<String> sentRequestsUsernames = {};
  bool loadingRequests = true;

  @override
  void initState() {
    super.initState();
    fetchSentRequests();
  }

  Future<void> fetchSentRequests() async {
    setState(() => loadingRequests = true);
    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/friendships/my-sent-requests/'),
      headers: {"Authorization": "Token $token"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> requests = data['requests'] ?? [];
      setState(() {
        sentRequestsUsernames = requests
            .map<String>((req) => req['username'].toString())
            .toSet();
        loadingRequests = false;
      });
    } else {
      setState(() => loadingRequests = false);
      // Puedes mostrar un error aquí si quieres, pero no uses SnackBar aquí.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.person_add, color: Colors.blue, size: 25),
                  SizedBox(width: 8),
                  Text(
                    "Añadir amigos",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              loadingRequests
                  ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              )
                  : widget.users.isEmpty
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  "No hay usuarios disponibles",
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.users.length,
                  itemBuilder: (context, index) {
                    final user = widget.users[index];
                    final username = user['username'];
                    final alreadySent = sentRequestsUsernames.contains(username);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Text(
                          username[0].toUpperCase(),
                          style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: alreadySent
                          ? TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: null, // <-- Disabled
                        child: const Text(
                          "ENVIADA",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      )
                          : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final ok = await widget.onSendRequest(username);
                          if (ok) {
                            setState(() {
                              sentRequestsUsernames.add(username);
                            });
                            // Ya no hay SnackBar aquí.
                          }
                        },
                        child: const Text(
                          "+ ADD",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar", style: TextStyle(color: Colors.blue)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
