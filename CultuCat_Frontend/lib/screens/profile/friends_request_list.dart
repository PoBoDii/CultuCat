import 'package:flutter/material.dart';

class FriendRequestsList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Future<void> Function(int, String) onRespond;

  const FriendRequestsList({
    super.key,
    required this.requests,
    required this.onRespond,
  });

  void _showNiceSnackBar(
      BuildContext context, {
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
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Solicitudes de amistad',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: requests.isEmpty
                  ? Text(
                'No tienes solicitudes pendientes.',
                style: TextStyle(color: Colors.grey[600]),
              )
                  : ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.blue),
                    title: Text(
                      request['username'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('Fecha: ${request['request_date']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Aceptar',
                          onPressed: () async {
                            await onRespond(request['id'], "accept");
                            _showNiceSnackBar(
                              context,
                              message: 'Ahora eres amigo de ${request['username']}',
                              color: Colors.green,
                              icon: Icons.check_circle,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          tooltip: 'Rechazar',
                          onPressed: () async {
                            await onRespond(request['id'], "reject");
                            _showNiceSnackBar(
                              context,
                              message: 'Solicitud de ${request['username']} rechazada',
                              color: Colors.redAccent,
                              icon: Icons.cancel,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cerrar'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.blue[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
