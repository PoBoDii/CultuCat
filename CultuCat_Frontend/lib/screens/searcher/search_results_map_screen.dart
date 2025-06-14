import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '/screens/event_map/event.dart';
import 'package:easy_localization/easy_localization.dart';

class SearchResultsMapScreen extends StatefulWidget {
  final List<dynamic> searchResults;
  final String searchTerm;

  const SearchResultsMapScreen({
    required this.searchResults,
    this.searchTerm = "",
    super.key,
  });

  @override
  State<SearchResultsMapScreen> createState() => _SearchResultsMapScreenState();
}

class _SearchResultsMapScreenState extends State<SearchResultsMapScreen> {
  final Set<Marker> _markers = {};
  late GoogleMapController mapController;
  BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker;

  void customMarker() {
    // BitmapDescriptor methods don't return Futures, they return synchronously
    try {
      // Using defaultMarkerWithHue to avoid deprecated methods
      customIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } catch (error) {
      print("Error loading custom marker: $error");
    }
  }

  @override
  void initState() {
    super.initState();
    customMarker();
    _loadMarkers();
  }

  void _loadMarkers() {
    if (widget.searchResults.isEmpty) return;

    setState(() {
      _markers.addAll(widget.searchResults.map((result) {
        double lat = result['addressid__latitude'] is double
            ? result['addressid__latitude']
            : double.parse(result['addressid__latitude'].toString());

        double lng = result['addressid__longitude'] is double
            ? result['addressid__longitude']
            : double.parse(result['addressid__longitude'].toString());

        String id = result['id'].toString();
        String title = result['name'] ?? 'Event';
        String address = result['addressid__address'] ?? '';
        String zipcode = result['addressid__zipcode'] ?? '';

        if (address == "Desconocida") address = "";
        String snippet = address;
        if (zipcode != null) {
          snippet += ", $zipcode";
        }

        return Marker(
          markerId: MarkerId(id),
          position: LatLng(lat, lng),
          icon: customIcon,
          infoWindow: InfoWindow(
            title: title,
            snippet: snippet,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EventScreen(texto: title, id: id),
                ),
              );
            },
          ),
        );
      }));
    });
  }

  // Calculate the optimal camera bounds to show all markers
  LatLngBounds _getBounds() {
    if (_markers.isEmpty) {
      // Default to Barcelona if no markers
      return  LatLngBounds(
        southwest: LatLng(41.35, 2.10),
        northeast: LatLng(41.45, 2.22),
      );
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (Marker marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    // Add some padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.searchTerm.isNotEmpty
            ? "${tr('search_results_for')}: ${widget.searchTerm}"
            : tr('search_results_map')),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;

              // If we have markers, adjust camera to show all of them
              if (_markers.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  try {
                    mapController.animateCamera(
                      CameraUpdate.newLatLngBounds(_getBounds(), 50),
                    );
                  } catch (e) {
                    print("Error setting camera bounds: $e");
                  }
                });
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.390205, 2.154007), // Barcelona by default
              zoom: 12.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Store context reference before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(tr('location_error'))),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(tr('location_error'))),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(tr('location_error3'))),
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("${tr('location_error2')} $e")),
      );
    }
  }
}