import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/user_preferences.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Future<void> _register() async {
    String email = _emailController.text;
    String username = _usernameController.text;
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError("Todos los campos son obligatorios");
      return;
    }

    if (!email.contains('@')) {
      _showError("Introduce un correo electrónico válido");
      return;
    }

    if (password != confirmPassword) {
      _showError("Las contraseñas no coinciden");
      return;
    }

    try {
      final response = await _makeRegisterRequest(email, username, password, confirmPassword);

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Opcional: Guardar token y user_id si el backend lo devuelve
        /*if (data.containsKey('token') && data.containsKey('user_id')) {
          await UserPreferences.setToken(data['token']);
          await UserPreferences.setUserId(data['user_id']);
        }*/

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registro exitoso")),
        );
        Navigator.pop(context);
      } else {
        _showError(data["error"] ?? "Error desconocido");
      }
    } catch (e) {
      _showError("Error de conexión con el servidor $e");
      print("Error: $e");
    }
  }

  Future<http.Response> _makeRegisterRequest(String email, String username, String password, String confirmPassword) {
    final url = Uri.parse('http://10.0.2.2:8000/api/register/');
    return http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "username": username,
        "password": password,
        "confirm_password": confirmPassword,
      }),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool obscureText, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          obscureText: obscureText,
          keyboardType: keyboardType,
        ),
        SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text("Registro")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField("Correo Electrónico", _emailController, false, TextInputType.emailAddress),
            _buildTextField("Usuario", _usernameController, false, TextInputType.text),
            _buildTextField("Contraseña", _passwordController, true, TextInputType.visiblePassword),
            _buildTextField("Confirmar Contraseña", _confirmPasswordController, true, TextInputType.visiblePassword),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade900,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Registrarse',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}