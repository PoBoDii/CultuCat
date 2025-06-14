import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecuperarContraScreen extends StatefulWidget {
  @override
  _RecuperarContraScreenState createState() => _RecuperarContraScreenState();
}

class _RecuperarContraScreenState extends State<RecuperarContraScreen> {
  final TextEditingController _emailController = TextEditingController();

  Future<void> _sendRecoveryEmail() async {
    String email = _emailController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showError("Por favor, ingresa un correo electrónico válido.");
      return;
    }

    final url = Uri.parse('http://10.0.2.2:8000/accounts/api/send-password-reset-email/');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["status"] ?? "Correo enviado correctamente.")),
        );
        Navigator.pop(context);
      } else {
        _showError(data["error"] ?? "Error al enviar correo de recuperación.");
      }
    } catch (e) {
      _showError("Error de conexión con el servidor: $e");
      print("Error: $e");
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Recuperar Contraseña")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Introduce tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendRecoveryEmail,
              child: Text("Enviar"),
            ),
          ],
        ),
      ),
    );
  }
}
