import 'package:cultucat_front/screens/calendar/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'event.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/screens/profile/myprofile.dart';
import '/screens/login/login_screen.dart';
import '/screens/searcher/searcher.dart';
import '/screens/settings/settings.dart';
import '/screens/chat/chat_list.dart';
import 'package:easy_localization/easy_localization.dart';
import '/utils/server_url.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {}; // Set for location circles
  late GoogleMapController mapController;
  BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker;
  Position? _currentPosition;

  void customMarker() {
    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(), 
      "assets/images/5307184.png"
    ).then((icon) {
      setState(() {
        customIcon = icon;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  void _loadMarkers() async {
    List<Map<String, dynamic>> places = [];
    try {
      final response = await http.get(Uri.parse('${ServerUrl.getBaseUrl()}/events'));
      print('API Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        List<dynamic> eventos = jsonData['events'];
        print('Loaded ${eventos.length} events from API');

        for (var evento in eventos) {
          try {
            // Get coordinates safely with null checking
            double? latitude = evento['addressid']['latitude']?.toDouble();
            double? longitude = evento['addressid']['longitude']?.toDouble();

            // Skip this event if coordinates are invalid
            if (latitude == null || longitude == null) {
              print('Skipping event with invalid coordinates: ${evento['name']}');
              continue;
            }

            // Create the snippet with null checks
            String address = evento['addressid']['address'] ?? '';
            var zipcode = evento['addressid']['zipcode'];

            if (address == "Desconocida") address = "";
            String snippet = address;
            if (zipcode != null) {
              snippet += ", $zipcode";
            }

            places.add({
              'id': evento['eventid'].toString(),
              'position': LatLng(latitude, longitude),
              'title': evento['name'] ?? 'Unknown Event',
              'snippet': snippet,
            });
          } catch (e) {
            print('Error processing event: $e');
          }
        }

        print('Processed ${places.length} valid places');
      } else {
        print('Error: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error in request: $e');
    }

    if (mounted) {
      setState(() {
        _markers.addAll(places.map((place) {
          return Marker(
            markerId: MarkerId(place['id']),
            position: place['position'],
            icon: customIcon, // Use custom marker
            infoWindow: InfoWindow(
              title: place['title'],
              snippet: place['snippet'],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EventScreen(texto: place['title'], id: place['id']),
                  ),
                );
              },
            ),
          );
        }));

        print('Added ${_markers.length} markers to the map');
      });
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return null;
      _showErrorMessage('location_error'.tr());
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        _showErrorMessage('location_error'.tr());
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      _showErrorMessage('location_error3'.tr());
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (!mounted) return null;
      _showErrorMessage('location_error2'.tr() + e.toString());
      return null;
    }
  }

  // Helper method to show error messages
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _updateUserLocationCircle(Position position) {
    setState(() {
      // Store current position
      _currentPosition = position;

      // Remove previous location marker (if exists)
      _markers.removeWhere((marker) => marker.markerId.value == 'LOCATION');

      // Remove previous location circle (if exists)
      _circles.removeWhere((circle) => circle.circleId.value == 'USER_LOCATION');

      // Add new circle for user location
      _circles.add(
        Circle(
          circleId: const CircleId('USER_LOCATION'),
          center: LatLng(position.latitude, position.longitude),
          radius: 50, // Radius in meters
          fillColor: Colors.blue.withAlpha(128), // Semi-transparent
          strokeColor: Colors.blue, // Circle border
          strokeWidth: 2, // Border thickness
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: const Text(
          'CultuCat',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.2,
            color: Colors.blue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.blue),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              setState(() {
                mapController = controller;
              });
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(41.390205, 2.154007),
              zoom: 10.0,
            ),
            markers: _markers,
            circles: _circles, // Add circles set to map
            myLocationEnabled: false, // Disable default blue dot
            padding: const EdgeInsets.only(bottom: 80),
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchScreen()),
                );
              },
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: AbsorbPointer(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'search_term'.tr(),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.person, color: Colors.blue, size: 28),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage()));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.blue, size: 28),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatListScreen()));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Colors.blue, size: 28),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarScreen()));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.blue, size: 28),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 170.0),
        child: FloatingActionButton(
          onPressed: () async {
            final position = await _determinePosition();
            if (position != null && mounted) {
              _updateUserLocationCircle(position);

              mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: 14.0,
                    tilt: 50.0,
                    bearing: 0,
                  ),
                ),
              );
            }
          },
          child: const Icon(
            Icons.my_location,
            size: 30,
          ),
        ),
      ),
    );
  }
}