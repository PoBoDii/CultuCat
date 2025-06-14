import 'package:cultucat_front/screens/profile/user_review.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';

class OtherProfilePage extends StatefulWidget {
  final String username; // El usuario que quieres ver

  const OtherProfilePage({super.key, required this.username});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage> {
  Map<String, dynamic>? userData;
  int reviewsCount = 0;
  bool loading = true;
  String? profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchReviewsCount(widget.username);
  }

  Future<void> fetchUserData() async {
    setState(() {
      loading = true;
    });
    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/ver-perfil/${widget.username}/'),
      headers: {
        "Authorization": "Token $token",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        userData = data;
        profilePhotoUrl = data['profilephoto'] != null
            ? '${ServerUrl.getBaseUrl()}/media/${data['profilephoto']}'
            : null;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
      // Puedes mostrar un error si quieres
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
      }
      setState(() {
        reviewsCount = count;
      });
    } else {
      setState(() {
        reviewsCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: userData != null && userData!['username'] != null
            ? RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'profile'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 20,
                ),
              ),
              TextSpan(
                text: userData!['username'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        )
            : Text(
          'profile'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
          ? const Center(child: Text("No se encontró el perfil."))
          : Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Foto de perfil
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue[100],
                  backgroundImage: profilePhotoUrl != null
                      ? NetworkImage(profilePhotoUrl!)
                      : null,
                  child: profilePhotoUrl == null
                      ? Text(
                    widget.username[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 40, color: Colors.blue[800]),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                userData?['username'] ?? '---',
                style: const TextStyle(
                    fontSize: 25, fontWeight: FontWeight.bold,color: Colors.black, ),
              ),

              const SizedBox(height: 16),

              // Solo reviews hechas para otros perfiles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserReviewsScreen(username: widget.username),
                          ),
                        );
                        await fetchReviewsCount(widget.username);
                        setState(() {});
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

              // Descripción (solo info, sin editar)
              if (userData?['description'] != null &&
                  (userData?['description'] as String).trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    userData!['description'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      decoration: TextDecoration.none,
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
                        Text(userData?['location'] ?? '---', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text("phone".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(userData?['telf'] ?? '---', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text("email".tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(userData?['email'] ?? '---', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
