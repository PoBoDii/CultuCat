import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  final Map<String, dynamic> user;

  const ProfileStats({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatColumn('Publicaciones', user['posts'].toString()),
          _buildStatColumn('Seguidores', user['followers'].toString()),
          _buildStatColumn('Puntos', user['points'].toString()),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
