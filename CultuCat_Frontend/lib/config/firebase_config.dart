import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      print("Firebase inicializado correctamente");
    } catch (e) {
      print("Error al inicializar Firebase: $e");
    }
  }
}