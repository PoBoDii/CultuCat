import 'dart:convert';
import 'package:cultucat_front/screens/event_map/map.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/screens/register/register.dart';
import '/screens/register/recuperar_contra.dart';
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Configurar correctamente GoogleSignIn con serverClientId
  final GoogleSignIn _googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: '627361310467-3cricd513ap7nk06ovhdt3ehd8g8cqvu.apps.googleusercontent.com' // Reemplaza con tu client ID web de Firebase
  );

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  Future<void> _login() async {
    String username = _usernameController.text;
    String password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError('login_missing'.tr());
      return;
    }
    if (username == "admin" && password == "1234") {
      print("Inicio de sesión con usuario hardcodeado");

      // Navigate without using context across async gap
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
      return;
    }

    final url = Uri.parse('${ServerUrl.getBaseUrl()}/api/login/');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      ).timeout(const Duration(seconds: 5));

      print("Código HTTP: ${response.statusCode}");
      print("Respuesta del servidor: ${response.body}");

      // Check if widget is still mounted after async operations
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(response.body);

        // Guardar token y user_id usando UserPreferences
        await UserPreferences.setToken(data['token']);
        await UserPreferences.setUsername(username);

        // Check again if still mounted after more async operations
        if (!mounted) return;

        // Navegar a la pantalla principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "Error desconocido.");
      }
    } catch (e) {
      if (!mounted) return;
      _showError("Error de conexión con el servidor.");
      print("Error: $e");
    }
  }

  Future<void> _signInWithGoogleUsingFirebase() async {
    try {
      print("Starting Google Sign-In process");

      // Iniciar el proceso de inicio de sesión de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print("Sign-in was cancelled");
        return;
      }

      // Obtener las credenciales de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print("Got Google authentication tokens");

      // Crear credenciales para Firebase
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Iniciar sesión en Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Obtener el token de ID de Firebase (no de Google)
        final idToken = await user.getIdToken();
        print("Firebase ID token obtained");

        if (!mounted) return;

        // Enviar este token al backend
        await _authenticateWithBackendGoogle(
            idToken!,
            user.displayName ?? '',
            user.email ?? '',
            user.photoURL ?? ''
        );
      }
    } catch (e) {
      if (!mounted) return;
      print("Detailed Google Sign-In error: $e");
      _showError("${'google_error'.tr()}: ${e.toString()}");
    }
  }

  Future<void> _authenticateWithBackendGoogle(String idToken, String name, String email, String photoUrl) async {
    final url = Uri.parse('${ServerUrl.getBaseUrl()}/api/auth/google/');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id_token": idToken,
          "name": name,
          "email": email,
          "photo_url": photoUrl
        }),
      ).timeout(const Duration(seconds: 5));

      print("Respuesta de autenticación con backend: ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Decodificar la respuesta JSON
        final data = jsonDecode(response.body);

        // Acceder al objeto 'user' que contiene la información
        final user = data['user'];

        // Guardar el token recibido desde el backend (ahora está dentro de 'user')
        await UserPreferences.setToken(user['token']);

        // Check if widget is still mounted after async operations
        if (!mounted) return;

        // Navegar a la pantalla principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        );
      } else {
        final data = jsonDecode(response.body);
        _showError(data["error"] ?? "login_error".tr());
      }
    } catch (e) {
      if (!mounted) return;
      _showError("login_error".tr());
      print("Error al comunicarse con el backend: $e");
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'CultuCat',
          style: TextStyle(
            fontFamily: 'Poppins', // asegúrate de haberla cargado en pubspec.yaml
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black,
            letterSpacing: 1.2,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.8 - kToolbarHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField("login_user".tr(), _usernameController, false, TextInputType.text),
                    _buildTextField("login_password".tr(), _passwordController, true, TextInputType.visiblePassword),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'login_title'.tr(),
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text("or".tr(), style: const TextStyle(color: Colors.grey)),
                        ),
                        const Expanded(child: Divider(thickness: 1, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Image.asset('assets/images/google_logo.png', height: 24),
                      label: Text(
                        'google_login'.tr(),
                        style: const TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                      onPressed: _signInWithGoogleUsingFirebase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('login_no_account'.tr(), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) =>  RegisterScreen()),
                          ),
                          child: Text(
                            'sign_in_title'.tr(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                          ),
                        ),
                      ],
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  RecuperarContraScreen()),
                        ),
                        child: Text(
                          'forgot_password'.tr(),
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationThickness: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool obscureText, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withAlpha(204), // Replaced deprecated withOpacity(0.8)
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          obscureText: obscureText,
          keyboardType: keyboardType,
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}