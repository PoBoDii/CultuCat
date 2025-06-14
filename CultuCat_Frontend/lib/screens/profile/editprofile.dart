import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../utils/user_preferences.dart';
import '/utils/server_url.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _telfController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loading = true;
  File? _selectedImage;
  String? _currentProfilePhotoUrl; // Nueva variable para la foto actual

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final token = await UserPreferences.getToken();
    final response = await http.get(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/ver-perfil/'),
      headers: {
        'Authorization': 'Token $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (mounted) {
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _locationController.text = data['location'] ?? '';
          _telfController.text = data['telf'] ?? '';
          _emailController.text = data['email'] ?? '';
          _currentProfilePhotoUrl = data['profilephoto']; // Guardar la URL de la foto actual
          _loading = false;
        });
      }
    } else {
      print('Error al cargar datos: ${response.body}');
    }
  }

  Future<void> _selectImage() async {
    print("Seleccionar imagen...");

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        print("Imagen seleccionada: ${pickedFile.path}");
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      } else {
        print("No se seleccionó ninguna imagen.");
      }
    } catch (e) {
      print("Error al seleccionar la imagen: $e");
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    final token = await UserPreferences.getToken();
    final uri = Uri.parse('${ServerUrl.getBaseUrl()}/api/editar-perfil/');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Token $token';

    request.files.add(
      await http.MultipartFile.fromPath('profilephoto', _selectedImage!.path),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      print('Foto subida correctamente');
      setState(() {
        _selectedImage = null;
      });
      _loadUserData();
    } else {
      print('Error al subir la foto: ${response.statusCode}');
    }
  }

  Future<void> saveChanges() async {
    _uploadImage();
    final token = await UserPreferences.getToken();
    final response = await http.post(
      Uri.parse('${ServerUrl.getBaseUrl()}/api/editar-perfil/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': _usernameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'telf': _telfController.text.trim(),
        'email': _emailController.text.trim(),
      }),
    );

    if (response.statusCode == 200) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      print('Error al guardar cambios: ${response.body}');
    }
  }

  Widget _profileField(String label, TextEditingController controller, {bool editable = true}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: TextField(
        controller: controller,
        enabled: editable,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          border: InputBorder.none,
        ),
      ),
      dense: true,
    );
  }

  void _showDescriptionDialog() async {
    final tempController = TextEditingController(text: _descriptionController.text);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                    const Icon(Icons.edit_note, color: Colors.blue, size: 40),
                    const SizedBox(height: 10),
                    // Título
                    Text(
                      "Editar descripción",
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
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: tempController,
                        maxLength: 80,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 15),
                        cursorColor: Colors.blue, // azul
                        decoration: const InputDecoration(
                          hintText: "Escribe una breve descripción...",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          counterText: "",
                        ),
                        onChanged: (value) {
                          setStateDialog(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Contador de caracteres
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "${tempController.text.length}/80",
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
                            child: const Text("Cancelar"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, tempController.text); // <-- Devolver texto (solo local)
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Guardar"),
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

    // Si el usuario pulsó guardar, actualizas el controlador (pero NO haces save)
    if (result != null) {
      setState(() {
        _descriptionController.text = result;
      });
    }
  }

  Widget _buildProfileImage() {
    String baseUrl = ServerUrl.getBaseUrl();

    // Si hay una imagen seleccionada localmente, mostrarla
    if (_selectedImage != null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.blue[100],
        backgroundImage: FileImage(_selectedImage!),
      );
    }

    // Si hay una foto de perfil actual en el servidor, mostrarla
    if (_currentProfilePhotoUrl != null && _currentProfilePhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.blue[100],
        backgroundImage: NetworkImage('$baseUrl/$_currentProfilePhotoUrl'),
        onBackgroundImageError: (exception, stackTrace) {
          // En caso de error al cargar la imagen, mostrar la inicial
          print('Error cargando imagen: $exception');
        },
        child: null,
      );
    }

    // Si no hay imagen, mostrar la inicial del username
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.blue[100],
      child: Text(
        _usernameController.text.isNotEmpty
            ? _usernameController.text[0].toUpperCase()
            : '?',
        style: TextStyle(fontSize: 32, color: Colors.blue[800]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Edición del perfil',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold, // <- ahora en negrita
                fontSize: 18,
              ),
            ),
            if (_usernameController.text.isNotEmpty)
              Text(
                _usernameController.text,
                style: const TextStyle(
                  color: Colors.blue,           // <- azul
                  fontWeight: FontWeight.bold,  // <- negrita
                  fontSize: 22,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                  _buildProfileImage(), // Usar el nuevo widget
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _selectImage,
                    child: const Text(
                      "Editar foto o avatar",
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Elimina el campo usuario aquí
            // _profileField("Usuario", _usernameController),
            // -------------------------------
            const Divider(color: Colors.grey, thickness: 0.5),
            GestureDetector(
              onTap: _showDescriptionDialog,
              child: ListTile(
                title: const Text("Descripción corta", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _descriptionController.text.isEmpty ? "Añadir una descripción corta" : _descriptionController.text,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                dense: true,
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5),
            _profileField("Ubicación", _locationController),
            const Divider(color: Colors.grey, thickness: 0.5),
            _profileField("Teléfono", _telfController),
            const Divider(color: Colors.grey, thickness: 0.5),
            _profileField("Email", _emailController),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}