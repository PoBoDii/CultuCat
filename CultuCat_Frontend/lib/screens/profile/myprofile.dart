import 'package:cultucat_front/screens/profile/user_review.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/user_preferences.dart';
import '/screens/profile/editprofile.dart';
import '/utils/server_url.dart';
import 'add_friend.dart';
import 'friends_list.dart';
import 'friends_request_list.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  Future<Map<String, dynamic>>? userFuture;
  int friendCount = 0;
  List<String> friends = [];
  int pendingRequests = 0;
  int reviewsCount = 0;
  String username = '';

  @override
  void initState() {
    super.initState();
    userFuture = fetchUserData();

    userFuture!.then((user) {
      username = user['username'] ?? '';
      fetchReviewsCount(username);
    });
    fetchFriends().then((result) {
      setState(() {
        friends = result;
        friendCount = result.length;
      });
    });
    fetchPendingRequests();
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

  Future<void> fetchPendingRequests() async {
    final token = await UserPreferences.getToken();

    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/friendships/my-requests/'),
      headers: {
        "Authorization": "Token $token",
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List<dynamic> requests = decoded['requests'] ?? [];
      setState(() {
        pendingRequests = requests.length;
      });
    } else {
      print("Error al obtener solicitudes pendientes");
    }
  }

  Future<void> fetchReviewsCount(String username) async {
    final token = await UserPreferences.getToken();

    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/reviews/user-sorted/$username'),
      headers: {
        "Authorization": "Token $token",
      },
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      int count = 0;
      if (decoded is List) {
        count = decoded.length;
        print('fetchReviewsCount: reviews count for $username = $count');
      } else if (decoded is Map && decoded['mensaje'] != null) {
        print('fetchReviewsCount: mensaje backend = ${decoded['mensaje']}');
        count = 0;
      } else {
        print('fetchReviewsCount: respuesta inesperada $decoded');
        count = 0;
      }
      if (!mounted) return;
      setState(() {
        reviewsCount = count;
        print('Nuevo reviewsCount actualizado en setState: $reviewsCount');
      });
    } else {
      print('Error al obtener reviews del usuario');
    }
  }

  Future<Map<String, dynamic>> fetchUserData() async {
    final token = await UserPreferences.getToken();

    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/ver-perfil/'),
      headers: {
        "Authorization": "Token $token",
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Error al obtener el perfil");
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final token = await UserPreferences.getToken();

    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/users/'), // O el endpoint correcto
      headers: {
        "Authorization": "Token $token",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al obtener la lista de usuarios');
    }
  }

  Future<bool> sendFriendRequest(String username) async {
    final token = await UserPreferences.getToken();

    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/friendships/send-request/'),
      headers: {
        "Authorization": "Token $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"username": username}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      showNiceSnackBar(
        context,
        message: 'request_sent_to_username'.tr(namedArgs: {'username': username}),
        color: Colors.green,
        icon: Icons.check_circle,
      );
      return true;
    } else {
      showNiceSnackBar(
        context,
        message: 'error_sending_request'.tr(),
        color: Colors.redAccent,
        icon: Icons.error,
      );
      return false;
    }
  }

  Future<List<String>> fetchFriends() async {
    final token = await UserPreferences.getToken();

    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/friendships/my-friends/'),
      headers: {
        "Authorization": "Token $token",
      },
    );

    print("CÓDIGO RESPUESTA FRIENDS: ${response.statusCode}");
    print("CUERPO: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List<dynamic> friendsList = decoded['friends'] ?? [];
      return friendsList.map<String>((f) => f['username'].toString()).toList();
    } else {
      throw Exception('Error al cargar los amigos');
    }
  }

  void _showFriendshipRequests() async {
    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/friendships/my-requests/'),
      headers: {
        "Authorization": "Token $token",
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List<dynamic> requests = decoded['requests'] ?? [];

      showDialog(
        context: context,
        builder: (context) => FriendRequestsList(
          requests: requests.cast<Map<String, dynamic>>(),
          onRespond: respondToFriendRequest,
        ),
      );
    } else {
      showNiceSnackBar(
        context,
        message: 'error_loading_requests'.tr(),
        color: Colors.redAccent,
        icon: Icons.error,
      );
    }
  }

  Future<void> respondToFriendRequest(int requestId, String action) async {
    final token = await UserPreferences.getToken();

    final url = '${ServerUrl.getBaseUrl()}/api/friendships/respond-request/';
    final body = json.encode({
      "request": requestId,
      "action": action,
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Token $token",
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      showNiceSnackBar(
        context,
        message: action == "accept"
            ? 'request_accepted'.tr()
            : 'request_rejected'.tr(),
        color: action == "accept" ? Colors.green : Colors.redAccent,
        icon: action == "accept" ? Icons.check_circle : Icons.cancel,
      );

      Navigator.of(context).pop(); // Cerrar el diálogo
      _showFriendshipRequests();   // Recargar solicitudes

      // 🔁 Recargar lista de amigos
      final updatedFriends = await fetchFriends();
      setState(() {
        friends = updatedFriends;
        friendCount = updatedFriends.length;
      });
    } else {
      showNiceSnackBar(
        context,
        message: 'error_responding_request'.tr(),
        color: Colors.redAccent,
        icon: Icons.error,
      );
    }
    await fetchPendingRequests(); // 🔄 actualiza contador tras aceptar/rechazar
  }

  Future<bool> removeFriend(String username) async {
    final token = await UserPreferences.getToken();

    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/friendships/remove-friend/'),
      headers: {
        "Authorization": "Token $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"username": username}),
    );

    if (response.statusCode == 200) {
      showNiceSnackBar(
        context,
        message: 'user_removed'.tr(namedArgs: {'username': username}),
        color: Colors.redAccent,
        icon: Icons.remove_circle,
      );
      return true;
    } else {
      showNiceSnackBar(
        context,
        message: 'error_removing_user'.tr(namedArgs: {'username': username}),
        color: Colors.grey,
        icon: Icons.error,
      );
      return false;
    }
  }

  Future<void> saveDescription(String newDescription) async {
    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/editar-perfil/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'description': newDescription.trim(),
      }),
    );

    if (response.statusCode == 200) {
      // Refresca el perfil después de editar
      setState(() {
        userFuture = fetchUserData();
      });
    } else {
      showNiceSnackBar(
        context,
        message: 'error_saving_description'.tr(),
        color: Colors.redAccent,
        icon: Icons.error,
      );
    }
  }

  void _showDescriptionDialog(String currentDescription) {
    TextEditingController descriptionController = TextEditingController(
      text: currentDescription ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono superior
                    Icon(Icons.edit_note, color: Colors.blue, size: 40),
                    const SizedBox(height: 10),
                    // Título
                    Text(
                      "edit_description".tr(),
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Caja de texto
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.07),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: descriptionController,
                        maxLength: 80,
                        maxLines: 4,
                        style: TextStyle(fontSize: 15),
                        cursorColor: Colors.blue, // <--- AQUÍ CAMBIAS EL COLOR DEL CURSOR
                        decoration: InputDecoration(
                          hintText: "write_brief_description".tr(),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          counterText: "",
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Contador de caracteres
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "${descriptionController.text.length}/80",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.grey[700],
                            ),
                            child: Text('cancel'.tr()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              await saveDescription(descriptionController.text);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text("save".tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.mail_outline, color: Colors.blue),
                  onPressed: () {
                    _showFriendshipRequests();
                    fetchPendingRequests(); // recarga contador tras abrir
                  },
                ),
                if (pendingRequests > 0)
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
                        '$pendingRequests',
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
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: userFuture ?? Future.value({}), // si es nulo, usa un Future vacío para no romper
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            String? profilePhotoUrl = user['profilephoto'];
            String baseUrl = ServerUrl.getBaseUrl();

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Foto de perfil
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.blue[100],
                            backgroundImage: profilePhotoUrl != null
                                ? NetworkImage('$baseUrl/$profilePhotoUrl?v=${DateTime.now().millisecondsSinceEpoch}')
                                : null,
                            child: profilePhotoUrl == null
                                ? Text(
                              user['username']?[0].toUpperCase() ?? '?',
                              style: TextStyle(fontSize: 40, color: Colors.blue[800]),
                            )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      user['username'] ?? '---',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 16),

                    // Amigos - Eventos Asistidos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () async {
                              final updatedFriends = await fetchFriends();
                              setState(() {
                                friends = updatedFriends;
                                friendCount = updatedFriends.length;
                              });

                              showDialog(
                                context: context,
                                builder: (context) => FriendsList(
                                  initialFriends: friends,
                                  onRemoveFriend: (username) => removeFriend(username),
                                  onFriendRemoved: () async {
                                    final refreshed = await fetchFriends();
                                    setState(() {
                                      friends = refreshed;
                                      friendCount = refreshed.length;
                                    });
                                  },
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                Text(
                                  "$friendCount",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text("friends".tr(), style: TextStyle(fontSize: 14, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () async {
                              if (username.isNotEmpty) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserReviewsScreen(username: username),
                                  ),
                                );
                                print('Volviendo de reviews, llamando a fetchReviewsCount');
                                await fetchReviewsCount(username);
                                print('Después de fetchReviewsCount: reviewsCount = $reviewsCount');
                                setState(() {});
                              }
                            },
                            child: Column(
                              children: [
                                Text(
                                  "$reviewsCount",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  "reviews_made".tr(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botones Editar Perfil y Añadir Amigos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const EditProfilePage()),
                            );
                            if (result == true) {
                              setState(() {
                                userFuture = fetchUserData();
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          ),
                          child: Text("edit_profile".tr(), style: TextStyle(color: Colors.blue)),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () async {
                            final allUsers = await fetchAllUsers();
                            final currentUser = (await fetchUserData())['username'];
                            final Set<String> currentFriends = friends.toSet();

                            final filteredUsers = allUsers.where((user) =>
                            user['username'] != currentUser &&
                                !currentFriends.contains(user['username'])).toList();

                            showDialog(
                              context: context,
                              builder: (context) => AddFriendScreen(
                                users: filteredUsers,
                                onSendRequest: (username) async {
                                  final success = await sendFriendRequest(username); // <- esta función debe devolver bool

                                  if (success) {
                                    final refreshed = await fetchFriends();
                                    setState(() {
                                      friends = refreshed;
                                      friendCount = refreshed.length;
                                    });
                                  }

                                  return success; // <- esto soluciona el error
                                },
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Icon(Icons.person_add, color: Colors.blue),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Botón pequeño para añadir descripción
                    (user['description'] == null || (user['description'] as String).trim().isEmpty)
                        ? TextButton(
                      onPressed: () => _showDescriptionDialog(""),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size(40, 20),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        "add_description".tr(),
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                        : GestureDetector(
                      onTap: () => _showDescriptionDialog(user['description'] ?? ""),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          user['description'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black, // o pon el color que prefieras
                            fontSize: 13,
                            fontStyle: FontStyle.italic, // si quieres mantenerlo, si no, quítalo
                            decoration: TextDecoration.none, // sin subrayado
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Línea Separadora
                    Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 1,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    // Información del usuario
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text("location".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(user['location'] ?? '---', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text("phone".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(user['telf'] ?? '---', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Text("email".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              Text(user['email'] ?? '---', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return  Center(child: Text("no_profile_data".tr()));
          }
        },
      ),
    );
  }
}
