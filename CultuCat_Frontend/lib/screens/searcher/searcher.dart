import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../event_map/top_rated_events.dart';
import '/screens/event_map/event.dart';
import 'package:easy_localization/easy_localization.dart';
import '/utils/server_url.dart';
// Import the new screen
import 'search_results_map_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _organizerController = TextEditingController();
  Map<String, dynamic> _searchResults = {};
  bool _isLoading = false;
  bool _isLocationEnabled = false;
  final List<String> categories = [
    'concerts',
    'teatre',
    'exposicions',
    'infantil',
    'festivals',
    'festes',
    'conferencies',
    'fires',
    'dansa',
    'rutes i visites',
  ];
  List<String> _selectedCategories = [];
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _exactDate;
  final List<String> distances = [
    '5km',
    '10km',
    '25km',
    '50km',
    '100km'
  ];
  String? _selectedDist;
  bool _useRangeDate = false;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    setState(() {
      _isLocationEnabled = serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);

      // Clear distance selection if location is disabled
      if (!_isLocationEnabled) {
        _selectedDist = null;
      }
    });
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location_error'.tr())),
      );
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('location_error'.tr())),
        );
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location_error3'.tr())),
      );
      return null;
    }

    // Update location status
    setState(() {
      _isLocationEnabled = true;
    });

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location_error2'.tr() + e.toString())),
      );
      return null;
    }
  }

  Future<void> _searchApi() async {
    // Verificar si hay al menos un filtro según la API
    if (_controller.text.isEmpty && _selectedCategories.isEmpty &&
        _startDate == null && _endDate == null && _exactDate == null &&
        _selectedDist == null && _organizerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('searcher_hint2'.tr())),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = {};
    });

    try {
      // Obtener posición del usuario
      Position? position = await _determinePosition();
      double lat = position?.latitude ?? 41.38;
      double long = position?.longitude ?? 2.17;

      // Construir parámetros de consulta
      Map<String, String> queryParams = {
        'latitude': lat.toString(),
        'longitude': long.toString(),
      };

      // Añadir query si existe
      if (_controller.text.isNotEmpty) {
        queryParams['query'] = _controller.text;
      }

      // Añadir categorías si se seleccionaron algunas
      if (_selectedCategories.isNotEmpty) {
        // Unir las categorías con comas
        queryParams['category'] = _selectedCategories.join(',');
      }

      // Añadir distancia si se seleccionó
      if (_selectedDist != null && _isLocationEnabled) {
        // Convertir formato de distancia (ej: "10km" a "10")
        String distanceValue = _selectedDist!.replaceAll('km', '');
        queryParams['max_distance'] = distanceValue;
      }

      // Añadir organizador si existe
      if (_organizerController.text.isNotEmpty) {
        queryParams['organizer'] = _organizerController.text;
      }

      // Añadir fechas según corresponda
      if (_useRangeDate && _startDate != null && _endDate != null) {
        queryParams['start_date'] = _formatDate(_startDate!);
        queryParams['end_date'] = _formatDate(_endDate!);
      } else if (!_useRangeDate && _exactDate != null) {
        queryParams['exact_date'] = _formatDate(_exactDate!);
      }

      // Construir URI con parámetros
      final uri = Uri.parse("${ServerUrl.getBaseUrl()}/events/search/").replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {"Content-Type": "application/json"},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
        });
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'searcher_error'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('searcher_error'.tr())),
      );
      print(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categorías
                    Text('sel_cat'.tr(), style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: categories.map((category) {
                        final isSelected = _selectedCategories.contains(category);
                        return FilterChip(
                          label: Text(category.tr()),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setModalState(() {
                              if (selected) {
                                // Permitir múltiples categorías
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Filtro por distancia - solo mostrar si la ubicación está habilitada
                    if (_isLocationEnabled) ...[
                      Text('sel_dist'.tr(), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8.0,
                        children: distances.map((dist) {
                          final isSelected = _selectedDist == dist;
                          return ChoiceChip(
                            label: Text(dist),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setModalState(() {
                                _selectedDist = selected ? dist : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Selector de tipo de fecha
                    Text("filter_date".tr(), style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _useRangeDate,
                          onChanged: (value) {
                            setModalState(() {
                              _useRangeDate = value!;
                            });
                          },
                        ),
                        Text("exact_date".tr()),
                        const SizedBox(width: 20),
                        Radio<bool>(
                          value: true,
                          groupValue: _useRangeDate,
                          onChanged: (value) {
                            setModalState(() {
                              _useRangeDate = value!;
                            });
                          },
                        ),
                        Text("range_date".tr()),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Selector de fecha basado en la opción elegida
                    if (_useRangeDate) ...[
                      // Rango de fechas
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2101),
                                );
                                if (pickedDate != null) {
                                  setModalState(() {
                                    _startDate = pickedDate;
                                  });
                                }
                              },
                              child: Text(
                                _startDate == null
                                    ? "ini_date".tr()
                                    : _formatDate(_startDate!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? (_startDate != null ? _startDate! : DateTime.now()),
                                  firstDate: _startDate ?? DateTime(2000),
                                  lastDate: DateTime(2101),
                                );
                                if (pickedDate != null) {
                                  setModalState(() {
                                    _endDate = pickedDate;
                                  });
                                }
                              },
                              child: Text(
                                _endDate == null
                                    ? "end_date".tr()
                                    : _formatDate(_endDate!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Fecha exacta
                      ElevatedButton(
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _exactDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (pickedDate != null) {
                            setModalState(() {
                              _exactDate = pickedDate;
                            });
                          }
                        },
                        child: Text(
                          _exactDate == null
                              ? "sel_date".tr()
                              : _formatDate(_exactDate!),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Botones de acción
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedCategories = [];
                              _selectedDist = null;
                              _exactDate = null;
                              _startDate = null;
                              _endDate = null;
                              _useRangeDate = false;
                              _organizerController.clear();
                            });
                          },
                          child: Text('clean'.tr()),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: Text('apply'.tr()),
                          onPressed: () {
                            Navigator.pop(context);
                            _searchApi();
                          },
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Navigate to map view with the search results
  void _navigateToMapView() {
    if (_searchResults.isEmpty || _searchResults['results'] == null || _searchResults['results'].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('no_results_for_map'.tr())),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsMapScreen(
          searchResults: _searchResults['results'],
          searchTerm: _controller.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "searcher_title".tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1), // fondo suave
                borderRadius: BorderRadius.circular(8), // esquinas redondeadas
              ),
              child: IconButton(
                icon: const Icon(Icons.star, color: Colors.orange),
                tooltip: 'top_events'.tr(),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TopRatedEventsScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'search_term'.tr(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchApi,
                ),
              ),
              onSubmitted: (_) => _searchApi(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_selectedCategories.isNotEmpty || _selectedDist != null ||
                    _exactDate != null || (_startDate != null && _endDate != null) ||
                    _organizerController.text.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8.0,
                        children: [
                          ..._selectedCategories.map((category) => Chip(
                            label: Text(category.tr()),
                            onDeleted: () {
                              setState(() {
                                _selectedCategories.remove(category);
                              });
                              _searchApi(); // Realizar búsqueda al eliminar un filtro
                            },
                          )),
                          if (_selectedDist != null && _isLocationEnabled)
                            Chip(
                              label: Text(_selectedDist!),
                              onDeleted: () {
                                setState(() {
                                  _selectedDist = null;
                                });
                                _searchApi(); // Realizar búsqueda al eliminar un filtro
                              },
                            ),
                          if (_exactDate != null)
                            Chip(
                              label: Text(_formatDate(_exactDate!)),
                              onDeleted: () {
                                setState(() {
                                  _exactDate = null;
                                });
                                _searchApi(); // Realizar búsqueda al eliminar un filtro
                              },
                            ),
                          if (_startDate != null && _endDate != null)
                            Chip(
                              label: Text("${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}"),
                              onDeleted: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                                _searchApi(); // Realizar búsqueda al eliminar un filtro
                              },
                            ),
                          if (_organizerController.text.isNotEmpty)
                            Chip(
                              label: Text(_organizerController.text),
                              onDeleted: () {
                                setState(() {
                                  _organizerController.clear();
                                });
                                _searchApi(); // Realizar búsqueda al eliminar un filtro
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.filter_list),
                      label: Text('filter'.tr()),
                      onPressed: _showFilterModal,
                    ),
                    const SizedBox(width: 8),
                    // Map button - only visible when we have results
                    if (_searchResults.isNotEmpty &&
                        _searchResults['results'] != null &&
                        _searchResults['results'].isNotEmpty)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map),
                        label: Text('map'.tr()),
                        onPressed: _navigateToMapView,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
            child: _searchResults.isNotEmpty &&
                _searchResults['results'] != null &&
                _searchResults['results'].isNotEmpty
                ? ListView.builder(
              itemCount: _searchResults['results'].length,
              itemBuilder: (context, index) {
                var result = _searchResults['results'][index];
                return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 3,
                      child: ListTile(
                        title: Text(result['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result['addressid__address'] ?? 'Sin dirección'),
                            Text('${'dist'.tr()}: ${result['distance'].toStringAsFixed(2)} km'),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EventScreen(
                                texto: result['name'],
                                id: result['id'].toString(),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                );
              },
            )
                : Center(child: Text("search_not_found".tr())),
          ),
        ],
      ),
    );
  }
}