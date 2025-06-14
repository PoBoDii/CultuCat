import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import '/utils/server_url.dart';
import '../../utils/user_preferences.dart';

class RouteMapScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String eventName;

  const RouteMapScreen({
    Key? key,
    required this.destLat,
    required this.destLng,
    required this.eventName,
  }) : super(key: key);

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isLoading = false;
  bool _routeLoaded = false;
  double _totalDistance = 0;
  int _totalDuration = 0;
  String? _routeId;

  // Origen (por defecto la ubicación actual)
  late double _originLat;
  late double _originLng;
  bool _useCurrentLocation = true;
  bool _locationInitialized = false;
  String _customLocationName = '';

  // Modo de transporte seleccionado
  String _selectedTransportMode = 'default';

  // Mapa para los iconos según el modo de transporte
  final Map<String, IconData> _transportIcons = {
    'car': Icons.directions_car,
    'walk': Icons.directions_walk,
    'bicycle': Icons.directions_bike,
    'transit': Icons.directions_bus,
  };

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('route_map.location_permission_denied'.tr())),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('route_map.location_permission_denied_forever'.tr()),
          ),
        );
      }
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );
      if (mounted) {
        setState(() {
          _originLat = position.latitude;
          _originLng = position.longitude;
          _locationInitialized = true;
        });
      }
    } catch (e) {
      print('Error al obtener la ubicación actual: $e');
      // Ubicación por defecto (Barcelona) en caso de error
      if (mounted) {
        setState(() {
          _originLat = 41.3851;
          _originLng = 2.1734;
          _useCurrentLocation = false;
          _locationInitialized = true;
        });
      }
    }
  }

  Future<void> _selectCustomLocation() async {
    TextEditingController addressController = TextEditingController();
    bool isSearching = false;
    String? errorMessage;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> searchAddress() async {
            if (addressController.text.trim().isEmpty) {
              setState(() {
                errorMessage = 'route_map.enter_valid_address'.tr();
              });
              return;
            }

            setState(() {
              isSearching = true;
              errorMessage = null;
            });

            try {
              List<Location> locations = await locationFromAddress(addressController.text.trim());

              if (locations.isNotEmpty) {
                Location location = locations.first;
                Navigator.pop(context, {
                  'lat': location.latitude,
                  'lng': location.longitude,
                  'address': addressController.text.trim(),
                });
              } else {
                setState(() {
                  isSearching = false;
                  errorMessage = 'route_map.address_not_found'.tr();
                });
              }
            } catch (e) {
              print('Error al buscar la dirección: $e');
              setState(() {
                isSearching = false;
                errorMessage = 'route_map.address_search_error'.tr();
              });
            }
          }

          return AlertDialog(
            title: Text('route_map.select_address'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'route_map.write_address'.tr(),
                    hintText: 'route_map.address_example'.tr(),
                    prefixIcon: const Icon(Icons.location_on),
                    errorText: errorMessage,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => searchAddress(),
                ),
                if (isSearching) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('route_map.searching_address'.tr()),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSearching ? null : () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton.icon(
                onPressed: isSearching ? null : searchAddress,
                icon: isSearching
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.search),
                label: Text('common.search'.tr()),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        _originLat = result['lat']!;
        _originLng = result['lng']!;
        _customLocationName = result['address']!;
        _useCurrentLocation = false;
        // Limpiar ruta anterior al cambiar origen
        _routeLoaded = false;
        _polylines.clear();
        _markers.clear();
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (!_locationInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('route_map.waiting_location'.tr())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _polylines.clear();
      _markers.clear();
      _routeLoaded = false;
    });

    try {
      // Llamada a la API de rutas
      Map<String, dynamic> routeData = await _fetchRouteFromApi();

      if (routeData.containsKey('error')) {
        throw Exception(routeData['error']);
      }

      _drawRoute(routeData);
      setState(() {
        _routeLoaded = true;
      });
    } catch (e) {
      print('Error al calcular la ruta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('route_map.route_calculation_error'.tr(args: [e.toString()]))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchRouteFromApi() async {
    try {
      final apiUrl = "${ServerUrl.getBaseUrl()}/api/calcular-ruta/";
      final token = await UserPreferences.getToken();

      final requestBody = {
        'originLat': _originLat,
        'originLng': _originLng,
        'destinationLat': widget.destLat,
        'destinationLng': widget.destLng,
        'mode': _selectedTransportMode,
        'preference': 'recommended',
      };

      print('Enviando request: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Verificar que la respuesta tenga la estructura esperada
        if (!data.containsKey('geometry') || !data.containsKey('distance') || !data.containsKey('duration')) {
          throw Exception('route_map.incomplete_api_response'.tr());
        }

        return data;
      } else {
        String errorMsg = 'route_map.error'.tr(args: [response.statusCode.toString()]);
        try {
          final errorData = json.decode(response.body);
          if (errorData.containsKey('message')) {
            errorMsg += ': ${errorData['message']}';
          }
        } catch (e) {
          errorMsg += ': ${response.body}';
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error en _fetchRouteFromApi: $e');
      rethrow;
    }
  }

  void _drawRoute(Map<String, dynamic> routeData) {
    try {
      // Convertir los puntos de geometría en LatLng
      List<LatLng> polylineCoordinates = [];
      List<dynamic> geometryPoints = routeData['geometry'];

      for (var point in geometryPoints) {
        if (point is List && point.length >= 2) {
          // El formato es [lng, lat] según tu ejemplo
          double lng = (point[0] as num).toDouble();
          double lat = (point[1] as num).toDouble();
          polylineCoordinates.add(LatLng(lat, lng));
        }
      }

      if (polylineCoordinates.isEmpty) {
        throw Exception('route_map.no_route_points'.tr());
      }

      // Crear la polilínea con color según el modo de transporte
      Color routeColor = _getRouteColor(_selectedTransportMode);

      final Polyline polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: polylineCoordinates,
        color: routeColor,
        width: 5,
      );

      // Añadir marcadores para el inicio y el fin
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: polylineCoordinates.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'route_map.origin'.tr(),
            snippet: _useCurrentLocation
                ? 'route_map.my_location'.tr()
                : _customLocationName.isNotEmpty
                ? _customLocationName
                : 'route_map.custom_location'.tr(),
          ),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: polylineCoordinates.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'route_map.destination'.tr(),
            snippet: widget.eventName,
          ),
        ),
      );

      // Guardar los datos de la ruta
      _totalDistance = (routeData['distance'] as num?)?.toDouble() ?? 0;
      _totalDuration = (routeData['duration'] as num?)?.round() ?? 0;
      _routeId = routeData['routeId'] as String?;

      setState(() {
        _polylines.add(polyline);
      });

      // Mover la cámara para mostrar toda la ruta
      if (_mapController != null) {
        _fitMapToBounds(polylineCoordinates);
      }
    } catch (e) {
      print('Error en _drawRoute: $e');
      throw Exception('route_map.draw_route_error'.tr(args: [e.toString()]));
    }
  }

  Color _getRouteColor(String mode) {
    switch (mode) {
      case 'car':
        return Colors.blue;
      case 'walk':
        return Colors.green;
      case 'bicycle':
        return Colors.orange;
      case 'transit':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  void _fitMapToBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Añadir un pequeño padding para evitar que los marcadores estén en el borde
    const double padding = 0.001;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100, // padding en píxeles
      ),
    );
  }

  Widget _buildTransportSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _transportButton('car', 'route_map.transport.car'.tr()),
          _transportButton('walk', 'route_map.transport.walking'.tr()),
          _transportButton('bicycle', 'route_map.transport.bicycle'.tr()),
          _transportButton('transit', 'route_map.transport.public_transport'.tr()),
        ],
      ),
    );
  }

  Widget _transportButton(String mode, String label) {
    bool isSelected = _selectedTransportMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _transportIcons[mode],
              size: 16,
              color: isSelected ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 12,
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedTransportMode = mode;
              // Limpiar ruta anterior al cambiar modo de transporte
              _routeLoaded = false;
              _polylines.clear();
              _markers.clear();
            });
          }
        },
      ),
    );
  }

  Widget _buildOriginSelector() {
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text('route_map.origin_label'.tr()),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text('route_map.my_location'.tr()),
          selected: _useCurrentLocation,
          onSelected: (selected) {
            if (selected && !_useCurrentLocation) {
              setState(() {
                _useCurrentLocation = true;
                _customLocationName = '';
                // Limpiar ruta anterior al cambiar origen
                _routeLoaded = false;
                _polylines.clear();
                _markers.clear();
              });
              _getCurrentLocation();
            }
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: Text(_customLocationName.isNotEmpty
              ? (_customLocationName.length > 20
              ? '${_customLocationName.substring(0, 20)}...'
              : _customLocationName)
              : 'route_map.other_address'.tr()),
          selected: !_useCurrentLocation,
          onSelected: (selected) {
            if (selected) {
              _selectCustomLocation();
            }
          },
        ),
      ],
    );
  }

  String _formatDuration(int durationInSeconds) {
    int hours = durationInSeconds ~/ 3600;
    int minutes = (durationInSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return 'route_map.duration_hours_minutes'.tr(args: [hours.toString(), minutes.toString()]);
    } else {
      return 'route_map.duration_minutes'.tr(args: [minutes.toString()]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('route_map.how_to_get_to'.tr(args: [widget.eventName])),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Panel de opciones
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOriginSelector(),
                    const SizedBox(height: 12),
                    _buildTransportSelector(),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: (_isLoading || !_locationInitialized) ? null : _calculateRoute,
                      icon: _isLoading
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.navigation),
                      label: Text(_isLoading ? 'route_map.calculating'.tr() : 'route_map.calculate_route'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Información de la ruta (si está disponible)
          if (_routeLoaded && _totalDistance > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _getRouteColor(_selectedTransportMode).withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: _getRouteColor(_selectedTransportMode).withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Icon(
                        _transportIcons[_selectedTransportMode] ?? Icons.directions,
                        color: _getRouteColor(_selectedTransportMode),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'route_map.distance_km'.tr(args: [(_totalDistance / 1000).toStringAsFixed(1)]),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: _getRouteColor(_selectedTransportMode),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_totalDuration),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Mapa
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.destLat, widget.destLng),
                zoom: 14,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Si ya tenemos una ruta cargada, ajustar el mapa
                if (_routeLoaded && _polylines.isNotEmpty) {
                  final points = _polylines.first.points;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _fitMapToBounds(points);
                  });
                }
              },
              polylines: _polylines,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}