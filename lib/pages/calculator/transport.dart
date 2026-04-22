import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class TransportPage extends StatefulWidget {
  const TransportPage({super.key});

  @override
  State<TransportPage> createState() => _TransportPageState();
}

class _TransportPageState extends State<TransportPage> {
  // ── Controllers ───────────────────────────────────────────────────────
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final MapController _mapController = MapController();

  // ── Location state ────────────────────────────────────────────────────
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  LatLng? _userLocation;
  double? _distanceKm;
  bool _isGeocodingStart = false;
  bool _isGeocodingEnd = false;

  // ── Resolved address strings (shown below inputs) ─────────────────────
  String? _resolvedStartAddress;
  String? _resolvedEndAddress;

  // ── Autocomplete state ────────────────────────────────────────────────
  List<_PlaceSuggestion> _startSuggestions = [];
  List<_PlaceSuggestion> _endSuggestions = [];
  Timer? _startDebounce;
  Timer? _endDebounce;
  bool _showStartSuggestions = false;
  bool _showEndSuggestions = false;

  // ── Selection state ───────────────────────────────────────────────────
  String? selectedVehicleType;
  String? selectedFuelType;
  String? selectedEngineSize;

  // ── Emission state ────────────────────────────────────────────────────
  double _dailyEmission = 0.0;
  int _treesToOffset = 0;

  // ── Constants ─────────────────────────────────────────────────────────
  static const Color _primaryGreen = Color(0xFF115925);

  final List<_VehicleType> vehicleTypes = [
    _VehicleType('Car', Icons.directions_car),
    _VehicleType('Bus', Icons.directions_bus),
    _VehicleType('Motorcycle', Icons.two_wheeler),
    _VehicleType('Scooter', Icons.electric_scooter),
  ];

  /// Fuel types available per vehicle type.
  static const Map<String, List<String>> _fuelTypesPerVehicle = {
    'Car': ['Diesel', 'Petrol (RON95)', 'Petrol (RON97)', 'EV'],
    'Motorcycle': ['Petrol (RON95)', 'Petrol (RON97)'],
    'Bus': ['Diesel'],
  };

  /// Engine size categories for Cars.
  final List<_EngineSizeOption> carEngineSizeOptions = [
    _EngineSizeOption(
      label: 'Small (≤1.0L)',
      examples: 'Perodua Axia, Kancil, Kelisa',
      color: Color(0xFF4CAF50),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: 'Medium (1.0L – 1.5L)',
      examples: 'Perodua Myvi, Proton Saga, Toyota Vios',
      color: Color(0xFF2196F3),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: 'Large (1.5L – 2.0L)',
      examples: 'Honda Civic, Toyota Corolla, Mazda 3',
      color: Color(0xFFFF9800),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: 'Extra Large (2.0L+)',
      examples: 'Toyota Hilux, Fortuner, BMW X5',
      color: Color(0xFFF44336),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: "I Don't Know",
      examples: 'We\'ll use an average estimate',
      color: Color(0xFF9E9E9E),
      icon: Icons.help_outline,
    ),
  ];

  /// Engine size categories for Motorcycles.
  final List<_EngineSizeOption> motorcycleEngineSizeOptions = [
    _EngineSizeOption(
      label: 'Small (≤150cc)',
      examples: 'Honda Wave, Yamaha LC135, Modenas Kriss',
      color: Color(0xFF4CAF50),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: 'Medium (150cc – 250cc)',
      examples: 'Yamaha R15, Honda CBR250, KTM Duke 200',
      color: Color(0xFF2196F3),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: 'Large (250cc – 500cc)',
      examples: 'Honda CB500, Kawasaki Ninja 400',
      color: Color(0xFFFF9800),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: 'Extra Large (500cc+)',
      examples: 'Kawasaki Z900, BMW R1250, Harley-Davidson',
      color: Color(0xFFF44336),
      icon: Icons.circle,
    ),
    _EngineSizeOption(
      label: "I Don't Know",
      examples: 'We\'ll use an average estimate',
      color: Color(0xFF9E9E9E),
      icon: Icons.help_outline,
    ),
  ];

  /// Engine size multiplier applied to base emission factor.
  /// Based on Malaysian average fuel consumption data (MGTC / IPCC).
  static const Map<String, double> _engineMultipliers = {
    // Car multipliers
    'Small (≤1.0L)': 0.80,
    'Medium (1.0L – 1.5L)': 1.00,
    'Large (1.5L – 2.0L)': 1.28,
    'Extra Large (2.0L+)': 1.73,
    // Motorcycle multipliers
    'Small (≤150cc)': 0.80,
    'Medium (150cc – 250cc)': 1.00,
    'Large (250cc – 500cc)': 1.30,
    'Extra Large (500cc+)': 1.65,
    // Shared
    "I Don't Know": 1.00,
  };

  /// Base emission factors in kg CO₂ per km (Well-to-Wheel, Malaysia).
  /// Petrol: 0.174 kg/km, Diesel: 0.170 kg/km, EV: 0.053 kg/km
  /// Sources: DEFRA/GHG Protocol, Malaysian Grid Emission Factor.
  static const Map<String, double> _emissionFactors = {
    'Car_Diesel': 0.170,
    'Car_Petrol (RON95)': 0.174,
    'Car_Petrol (RON97)': 0.174,
    'Car_EV': 0.053,
    'Motorcycle_Petrol (RON95)': 0.113,
    'Motorcycle_Petrol (RON97)': 0.113,
    'Bus_Diesel': 0.089,
    'Scooter_': 0.025,       // Electric scooter (grid emission)
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _startDebounce?.cancel();
    _endDebounce?.cancel();
    _startController.dispose();
    _endController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  // ── Get current location (auto-fill start) ────────────────────────────
  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('Location services are disabled.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions permanently denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latLng = LatLng(position.latitude, position.longitude);

      // Reverse geocode to get address
      String addressText = 'Current Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          addressText = _formatPlacemark(placemarks.first);
        }
      } catch (geoErr) {
        debugPrint('Reverse geocoding failed: $geoErr');
        addressText =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }

      if (mounted) {
        setState(() {
          _userLocation = latLng;
          _startLatLng = latLng;
          _startController.text = addressText;
          _resolvedStartAddress = addressText;
        });
        _mapController.move(latLng, 14.0);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackBar('Could not get current location. Enter address manually.');
    }
  }

  // ── Geocode an address string to LatLng ───────────────────────────────
  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (e) {
      debugPrint('Geocoding error for "$address": $e');
    }
    return null;
  }

  // ── Photon place autocomplete (by Komoot, OSM-based) ────────────────
  // Uses Nominatim (official OSM geocoder) — better named-place recognition,
  // restricted to Malaysia via countrycodes=my.
  // Docs: https://nominatim.openstreetmap.org/ui/search.html
  Future<List<_PlaceSuggestion>> _searchPlaces(String query) async {
    if (query.trim().length < 3) return [];
    try {
      // Use user's live location as viewbox centre if available,
      // otherwise fall back to central Malaysia.
      final double biasLat = _userLocation?.latitude ?? 4.21;
      final double biasLon = _userLocation?.longitude ?? 108.96;

      // Build a ~2° viewbox around the bias point (soft bias, not bounded).
      final String viewbox =
          '${(biasLon - 1.5).toStringAsFixed(4)},${(biasLat - 1.5).toStringAsFixed(4)},'
          '${(biasLon + 1.5).toStringAsFixed(4)},${(biasLat + 1.5).toStringAsFixed(4)}';

      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'countrycodes': 'my',   // restrict to Malaysia
        'limit': '8',
        'addressdetails': '1',
        'accept-language': 'en',
        'viewbox': viewbox,
        'bounded': '0',         // show results outside viewbox if nothing found
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'CarbonLit-FlutterApp/1.0 (education project)',
        'Referer': 'https://github.com/carbonlit',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          final double lat =
              double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final double lng =
              double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

          // Build readable label: prefer display_name but trim country suffix
          final addr = item['address'] as Map<String, dynamic>? ?? {};
          final parts = <String>[
            if ((item['name'] as String?)?.isNotEmpty == true)
              item['name'].toString(),
            if ((addr['road'] as String?)?.isNotEmpty == true)
              addr['road'].toString(),
            if ((addr['suburb'] as String?)?.isNotEmpty == true)
              addr['suburb'].toString(),
            if ((addr['city'] ?? addr['town'] ?? addr['village'] as String?)
                    ?.isNotEmpty ==
                true)
              (addr['city'] ?? addr['town'] ?? addr['village']).toString(),
            if ((addr['state'] as String?)?.isNotEmpty == true)
              addr['state'].toString(),
          ];

          final displayName = parts.isNotEmpty
              ? parts.join(', ')
              : (item['display_name']?.toString() ?? 'Unknown place');

          return _PlaceSuggestion(
            displayName: displayName,
            lat: lat,
            lng: lng,
          );
        }).toList();
      } else {
        debugPrint('Nominatim HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Place search error: $e');
    }
    return [];
  }

  // ── Debounced typing handlers ─────────────────────────────────────────
  void _onStartTyping(String text) {
    _startDebounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        _startSuggestions = [];
        _showStartSuggestions = false;
      });
      return;
    }
    _startDebounce = Timer(const Duration(milliseconds: 1000), () async {
      final results = await _searchPlaces(text);
      if (mounted) {
        setState(() {
          _startSuggestions = results;
          _showStartSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  void _onEndTyping(String text) {
    _endDebounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        _endSuggestions = [];
        _showEndSuggestions = false;
      });
      return;
    }
    _endDebounce = Timer(const Duration(milliseconds: 1000), () async {
      final results = await _searchPlaces(text);
      if (mounted) {
        setState(() {
          _endSuggestions = results;
          _showEndSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  // ── Select a suggestion ───────────────────────────────────────────────
  void _onStartSuggestionSelected(_PlaceSuggestion place) {
    final latLng = LatLng(place.lat, place.lng);
    setState(() {
      _startController.text = place.displayName;
      _startLatLng = latLng;
      _resolvedStartAddress = place.displayName;
      _startSuggestions = [];
      _showStartSuggestions = false;
      _updateMapAndDistance();
    });
  }

  void _onEndSuggestionSelected(_PlaceSuggestion place) {
    final latLng = LatLng(place.lat, place.lng);
    setState(() {
      _endController.text = place.displayName;
      _endLatLng = latLng;
      _resolvedEndAddress = place.displayName;
      _endSuggestions = [];
      _showEndSuggestions = false;
      _updateMapAndDistance();
    });
  }

  // ── Reverse geocode LatLng → readable address ─────────────────────────
  Future<String?> _reverseGeocode(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        return _formatPlacemark(placemarks.first);
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  // ── Handle start destination search ───────────────────────────────────
  Future<void> _onStartSearch() async {
    final text = _startController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isGeocodingStart = true);
    final result = await _geocodeAddress(text);
    String? addr;
    if (result != null) {
      addr = await _reverseGeocode(result);
    }
    if (mounted) {
      setState(() {
        _isGeocodingStart = false;
        if (result != null) {
          _startLatLng = result;
          _resolvedStartAddress = addr;
          _updateMapAndDistance();
        } else {
          _showSnackBar('Could not find start location.');
        }
      });
    }
  }

  // ── Handle end destination search ─────────────────────────────────────
  Future<void> _onEndSearch() async {
    final text = _endController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isGeocodingEnd = true);
    final result = await _geocodeAddress(text);
    String? addr;
    if (result != null) {
      addr = await _reverseGeocode(result);
    }
    if (mounted) {
      setState(() {
        _isGeocodingEnd = false;
        if (result != null) {
          _endLatLng = result;
          _resolvedEndAddress = addr;
          _updateMapAndDistance();
        } else {
          _showSnackBar('Could not find end location.');
        }
      });
    }
  }

  // ── Use current location as start ─────────────────────────────────────
  Future<void> _useCurrentLocationAsStart() async {
    if (_userLocation != null) {
      final addressText =
          await _reverseGeocode(_userLocation!) ?? 'Current Location';
      if (mounted) {
        setState(() {
          _startLatLng = _userLocation;
          _startController.text = addressText;
          _resolvedStartAddress = addressText;
          _updateMapAndDistance();
        });
      }
    } else {
      await _getCurrentLocation();
    }
  }

  // ── Update map view & distance ────────────────────────────────────────
  void _updateMapAndDistance() {
    if (_startLatLng != null && _endLatLng != null) {
      // Calculate distance
      final dist = const Distance().as(
        LengthUnit.Kilometer,
        _startLatLng!,
        _endLatLng!,
      );
      _distanceKm = dist;

      // Fit map to show both markers
      final midLat = (_startLatLng!.latitude + _endLatLng!.latitude) / 2;
      final midLng = (_startLatLng!.longitude + _endLatLng!.longitude) / 2;
      final zoom = _calculateZoom(dist);
      _mapController.move(LatLng(midLat, midLng), zoom);

      // Recalculate emission
      _calculateEmission();
    } else if (_startLatLng != null) {
      _mapController.move(_startLatLng!, 14.0);
      _distanceKm = null;
      _dailyEmission = 0.0;
      _treesToOffset = 0;
    } else if (_endLatLng != null) {
      _mapController.move(_endLatLng!, 14.0);
      _distanceKm = null;
      _dailyEmission = 0.0;
      _treesToOffset = 0;
    }
  }

  double _calculateZoom(double distKm) {
    if (distKm < 1) return 15.0;
    if (distKm < 5) return 13.0;
    if (distKm < 20) return 11.0;
    if (distKm < 100) return 9.0;
    if (distKm < 500) return 7.0;
    return 5.0;
  }

  // ── Calculate carbon emission ─────────────────────────────────────────
  void _calculateEmission() {
    if (_distanceKm == null || _distanceKm! <= 0) {
      _dailyEmission = 0.0;
      _treesToOffset = 0;
      return;
    }

    final vehicle = selectedVehicleType ?? '';
    final fuel = selectedFuelType ?? '';

    double factor;
    if (vehicle == 'Scooter') {
      factor = _emissionFactors['Scooter_'] ?? 0.025;
    } else {
      if (fuel.isEmpty) {
        _dailyEmission = 0.0;
        _treesToOffset = 0;
        return;
      }

      final key = '${vehicle}_$fuel';
      factor = _emissionFactors[key] ?? 0.0;
    }

    // Apply engine size multiplier (only for combustion vehicles)
    double engineMultiplier = 1.0;
    if (_shouldShowEngineSize()) {
      engineMultiplier = _engineMultipliers[selectedEngineSize] ?? 1.0;
    }

    _dailyEmission = _distanceKm! * factor * engineMultiplier;
    _treesToOffset = _calculateTreesNeeded(_dailyEmission);
  }

  /// Whether engine size section should be visible.
  /// Only for Car and Motorcycle with non-EV fuel.
  bool _shouldShowEngineSize() {
    final v = selectedVehicleType;
    if (v != 'Car' && v != 'Motorcycle') return false;
    if (selectedFuelType == 'EV') return false;
    return true;
  }

  /// Whether fuel type dropdown should be visible.
  bool _shouldShowFuelType() {
    final v = selectedVehicleType;
    if (v == null || v == 'Scooter') {
      return false;
    }
    return true;
  }

  /// Get available fuel types for the currently selected vehicle.
  List<String> _getAvailableFuelTypes() {
    return _fuelTypesPerVehicle[selectedVehicleType] ?? const [];
  }

  /// Get engine size options based on current vehicle type.
  List<_EngineSizeOption> _getEngineSizeOptions() {
    if (selectedVehicleType == 'Motorcycle') return motorcycleEngineSizeOptions;
    return carEngineSizeOptions;
  }

  int _calculateTreesNeeded(double dailyEmission) {
    const double yearlyOffsetPerTree = 21.0; // 1 tree ≈ 21 kg CO₂/year
    final yearlyEmission = dailyEmission * 365;
    return yearlyEmission <= 0 ? 0 : (yearlyEmission / yearlyOffsetPerTree).ceil();
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _formatPlacemark(Placemark p) {
    final parts = [
      if (p.street != null && p.street!.isNotEmpty) p.street,
      if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
      if (p.locality != null && p.locality!.isNotEmpty) p.locality,
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
        p.administrativeArea,
      if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode,
    ];
    return parts.whereType<String>().join(', ');
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (selectedVehicleType == null) {
      _showSnackBar('Please select a vehicle type.');
      return;
    }
    if (_startLatLng == null) {
      _showSnackBar('Please enter a start destination.');
      return;
    }
    if (_endLatLng == null) {
      _showSnackBar('Please enter an end destination.');
      return;
    }
    if (_shouldShowFuelType() && selectedFuelType == null) {
      _showSnackBar('Please select a fuel type.');
      return;
    }

    final data = {
      'vehicle_type': selectedVehicleType,
      'model_vehicle': _modelController.text.trim(),
      'fuel_type': selectedFuelType,
      'engine_size': selectedEngineSize,
      'origin_lat': _startLatLng!.latitude,
      'origin_lng': _startLatLng!.longitude,
      'origin_place': _startController.text.trim(),
      'distance_km': _distanceKm,
      'daily_emission': _dailyEmission,
      'trees_to_offset': _treesToOffset,
    };

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('You must be logged in to save.');
        return;
      }
      await supabase.from('transport_records').insert({
        ...data,
        'user_id': userId,
      });
      debugPrint('Transport record saved: $data');
      _showSnackBar('Transport emission saved!');
    } catch (e) {
      debugPrint('Error saving transport record: $e');
      _showSnackBar('Failed to save. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Transportation',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Map section ──────────────────────────────────
              _buildMapSection(),

              // ── Destination inputs ───────────────────────────
              _buildDestinationInputs(),

              // ── Resolved addresses ───────────────────────────
              _buildResolvedAddresses(),
              const SizedBox(height: 6),

              // ── Distance display ─────────────────────────────
              if (_distanceKm != null) _buildDistanceCard(),

              // ── Vehicle, model, fuel ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildVehicleTypeSection(),
                    const SizedBox(height: 22),
                    _buildModelVehicleField(),
                    const SizedBox(height: 22),
                    _buildFuelTypeDropdown(),
                    const SizedBox(height: 22),

                    // ── Engine Size ──────────────────────────
                    _buildEngineSizeSection(),
                    const SizedBox(height: 24),

                    // ── Daily Emission ───────────────────────
                    _buildDailyEmissionSection(),
                    const SizedBox(height: 22),

                    // ── Trees needed card ────────────────────
                    _buildTreesCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // ── Save button ──────────────────────────────────
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Map ────────────────────────────────────────────────────────────────
  Widget _buildMapSection() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _userLocation ?? LatLng(3.0738, 101.5183), // fallback: KL area
            zoom: 14.0,
            interactiveFlags:
                InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.carbonlit',
            ),

            // Route line between start and end
            if (_startLatLng != null && _endLatLng != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_startLatLng!, _endLatLng!],
                    strokeWidth: 4.0,
                    color: _primaryGreen.withValues(alpha: 0.7),
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                if (_startLatLng != null)
                  Marker(
                    point: _startLatLng!,
                    width: 48,
                    height: 48,
                    builder: (ctx) => const Icon(
                      Icons.trip_origin,
                      color: _primaryGreen,
                      size: 32,
                    ),
                  ),
                if (_endLatLng != null)
                  Marker(
                    point: _endLatLng!,
                    width: 48,
                    height: 48,
                    builder: (ctx) => const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Destination inputs (compact, with autocomplete) ────────────────────
  Widget _buildDestinationInputs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Start field + suggestions ──────────────────
          _buildAddressFieldWithSuggestions(
            label: 'Start',
            controller: _startController,
            icon: Icons.trip_origin,
            iconColor: _primaryGreen,
            isLoading: _isGeocodingStart,
            onSearch: _onStartSearch,
            onChanged: _onStartTyping,
            suggestions: _startSuggestions,
            showSuggestions: _showStartSuggestions,
            onSuggestionTap: _onStartSuggestionSelected,
          ),
          // "Use current location" shortcut
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: GestureDetector(
              onTap: _useCurrentLocationAsStart,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, size: 12, color: _primaryGreen),
                    SizedBox(width: 4),
                    Text(
                      'Use current location',
                      style: TextStyle(fontSize: 11, color: _primaryGreen),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── End field + suggestions ────────────────────
          _buildAddressFieldWithSuggestions(
            label: 'End',
            controller: _endController,
            icon: Icons.location_on,
            iconColor: Colors.red,
            isLoading: _isGeocodingEnd,
            onSearch: _onEndSearch,
            onChanged: _onEndTyping,
            suggestions: _endSuggestions,
            showSuggestions: _showEndSuggestions,
            onSuggestionTap: _onEndSuggestionSelected,
          ),
        ],
      ),
    );
  }

  /// Address text field with autocomplete suggestion dropdown.
  Widget _buildAddressFieldWithSuggestions({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required bool isLoading,
    required VoidCallback onSearch,
    required ValueChanged<String> onChanged,
    required List<_PlaceSuggestion> suggestions,
    required bool showSuggestions,
    required ValueChanged<_PlaceSuggestion> onSuggestionTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: controller,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF222222)),
                  decoration: InputDecoration(
                    hintText: '$label address...',
                    hintStyle:
                        TextStyle(fontSize: 13, color: Colors.grey[400]),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: _primaryGreen, width: 1.5),
                    ),
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryGreen,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search,
                                color: _primaryGreen, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onSearch,
                          ),
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => onSearch(),
                ),
              ),
            ),
          ],
        ),
        // ── Suggestion dropdown ──────────────────────────
        if (showSuggestions && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 26, top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 0.5),
              itemBuilder: (context, idx) {
                final place = suggestions[idx];
                return InkWell(
                  onTap: () => onSuggestionTap(place),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.place,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            place.displayName,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF333333)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Resolved addresses (real-time display) ─────────────────────────────
  Widget _buildResolvedAddresses() {
    if (_resolvedStartAddress == null && _resolvedEndAddress == null) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_resolvedStartAddress != null) ...[            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.trip_origin, size: 14, color: _primaryGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _resolvedStartAddress!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF555555),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_resolvedStartAddress != null && _resolvedEndAddress != null)
            const Divider(height: 10, thickness: 0.5),
          if (_resolvedEndAddress != null) ...[            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _resolvedEndAddress!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF555555),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Distance card ──────────────────────────────────────────────────────
  Widget _buildDistanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.straighten, color: _primaryGreen, size: 22),
          const SizedBox(width: 10),
          Text(
            'Distance: ${_distanceKm!.toStringAsFixed(1)} km',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ── Vehicle type list ──────────────────────────────────────────────────
  Widget _buildVehicleTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64.0 * vehicleTypes.length,
          child: ListView.separated(
            scrollDirection: Axis.vertical,
            itemCount: vehicleTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final v = vehicleTypes[idx];
              final isSelected = selectedVehicleType == v.name;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedVehicleType = v.name;
                    // Reset fuel type and engine size on vehicle change
                    selectedFuelType = null;
                    selectedEngineSize = null;
                    _modelController.clear();
                    _calculateEmission();
                  });
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? _primaryGreen
                          : const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(v.icon,
                          size: 28,
                          color: isSelected
                              ? Colors.white
                              : _primaryGreen),
                      const SizedBox(width: 18),
                      Text(
                        v.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF222222),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Model vehicle text field ───────────────────────────────────────────
  Widget _buildModelVehicleField() {
    // Only show for personal vehicles.
    if (selectedVehicleType == null ||
        selectedVehicleType == 'Bus') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Model Vehicle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
          ),
          child: TextField(
            controller: _modelController,
            style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
            decoration: const InputDecoration(
              hintText: 'Enter Model Vehicle',
              hintStyle: TextStyle(fontSize: 15, color: Color(0xFF888888)),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // ── Fuel type dropdown ─────────────────────────────────────────────────
  Widget _buildFuelTypeDropdown() {
    // Only show for vehicles that use fuel selection
    if (!_shouldShowFuelType()) {
      return const SizedBox.shrink();
    }

    final availableFuels = _getAvailableFuelTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fuel Type',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: availableFuels.contains(selectedFuelType)
                  ? selectedFuelType
                  : null,
              hint: const Text('Fuel Type',
                  style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
              isExpanded: true,
              selectedItemBuilder: (context) {
                return availableFuels.map((f) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      f,
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF222222)),
                    ),
                  );
                }).toList();
              },
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color.fromARGB(255, 0, 0, 0)),
              items: availableFuels
                  .map((f) =>
                      DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedFuelType = value;
                  // Clear engine size if switching to EV
                  if (value == 'EV') {
                    selectedEngineSize = null;
                  }
                  _calculateEmission();
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Engine size selection ──────────────────────────────────────────
  Widget _buildEngineSizeSection() {
    if (!_shouldShowEngineSize()) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Engine Size',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the size that matches your vehicle',
          style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 10),
        ..._getEngineSizeOptions().map((option) {
          final isSelected = selectedEngineSize == option.label;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedEngineSize = option.label;
                  _calculateEmission();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primaryGreen.withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _primaryGreen
                        : const Color(0xFFE0E0E0),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : option.icon,
                      color: isSelected ? _primaryGreen : option.color,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected
                                  ? _primaryGreen
                                  : const Color(0xFF222222),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option.examples,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Daily emission display ─────────────────────────────────────────────
  Widget _buildDailyEmissionSection() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Daily Emission :',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _dailyEmission.toStringAsFixed(2),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 36,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '(kg CO₂e/day)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  // ── Trees card ─────────────────────────────────────────────────────────
  Widget _buildTreesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFD6F5D6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'Trees Needed to offset/year :',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _treesToOffset.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 36,
              color: _primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text(
            'Save',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleType {
  final String name;
  final IconData icon;
  const _VehicleType(this.name, this.icon);
}

class _PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lng;
  const _PlaceSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class _EngineSizeOption {
  final String label;
  final String examples;
  final Color color;
  final IconData icon;
  const _EngineSizeOption({
    required this.label,
    required this.examples,
    required this.color,
    required this.icon,
  });
}