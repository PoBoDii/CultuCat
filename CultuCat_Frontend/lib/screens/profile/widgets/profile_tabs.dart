import 'package:flutter/material.dart';

class ProfileTabs extends StatelessWidget {
  const ProfileTabs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Publicaciones'),
              Tab(text: 'Logros'),
              Tab(text: 'Comentarios'),
            ],
          ),
          Container(
            height: 300, // Ajusta según contenido
            child: TabBarView(
              children: [
                _buildPublicaciones(),
                _buildLogros(),
                _buildComentarios(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicaciones() {
    return Center(child: Text('Aquí irán las publicaciones del usuario'));
  }

  Widget _buildLogros() {
    return Center(child: Text('Aquí irán los logros reales del usuario'));
  }

  Widget _buildComentarios() {
    return Center(child: Text('Aquí irán los comentarios reales del usuario'));
  }
}
