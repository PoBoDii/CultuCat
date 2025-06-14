import 'package:flutter/material.dart';
import 'route_map_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class EventNavigationButton extends StatelessWidget {
  final int eventId;
  final String eventName;
  final Map<String, dynamic> eventDetails;

  const EventNavigationButton({
    Key? key,
    required this.eventId,
    required this.eventName,
    required this.eventDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extraer coordenadas de los detalles del evento
    final double? latitude = eventDetails['latitude'] as double?;
    final double? longitude = eventDetails['longitude'] as double?;

    // Verificar si hay dirección disponible
    final String? address = eventDetails['address'] as String?;
    final bool hasValidAddress = address != null && address.isNotEmpty && address != '---';

    // Verificar si hay coordenadas válidas
    final bool hasValidCoordinates = latitude != null && longitude != null;

    // El botón estará habilitado solo si hay dirección Y coordenadas
    final bool isButtonEnabled = hasValidAddress && hasValidCoordinates;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: ElevatedButton.icon(
        onPressed: isButtonEnabled
            ? () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RouteMapScreen(
                destLat: latitude!,
                destLng: longitude!,
                eventName: eventName,
              ),
            ),
          );
        }
            : null,
        icon: const Icon(Icons.directions),
        label: Text(
          !hasValidAddress
              ? 'no_address'.tr()
              : !hasValidCoordinates
              ? 'no_coordinates'.tr()
              : 'get_directions'.tr(),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}