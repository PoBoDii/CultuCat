import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.favorite_border,
            label: 'Favoritos',
            onPressed: () => context.push('/favorites'),
          ),
          _buildActionButton(
            icon: Icons.settings,
            label: 'Configuración',
            onPressed: () => context.push('/settings'),
          ),
          _buildActionButton(
            icon: Icons.help_outline,
            label: 'Ayuda',
            onPressed: () => context.push('/help'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.blue),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(color: Colors.blue),
        )
      ],
    );
  }
}
