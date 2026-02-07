import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class TransportPage extends StatefulWidget {
  const TransportPage({super.key});

  @override
  State<TransportPage> createState() => _TransportPageState<TransportPage>();
}

class _TransportPageState<T extends TransportPage> extends State<T> {
  // Metadata state
  String? selectedVehicleType;
  String? selectedModelVehicle;
  String? selectedFuelType;
  // TODO: Store selected location, distance, etc.

  String? placeName; // Will be set dynamically from user location
  String? distance; // Will be calculated based on user location
  String? address; // Will be set to real address
  
  late Map<String, dynamic> metadata = {
    'treesToOffset': calculateTreesNeeded(0.10),
  };

  final List<_VehicleType> vehicleTypes = [
    _VehicleType('Car', Icons.directions_car),
    _VehicleType('Walking', Icons.directions_walk),
    _VehicleType('Bus', Icons.directions_bus),
    _VehicleType('Motorcycle', Icons.two_wheeler),
    _VehicleType('Bicycle', Icons.directions_bike),
    _VehicleType('Scooter', Icons.electric_scooter),
  ];

  final List<String> fuelTypes = [
    'Diesel',
    'Petrol (RON95)',
    'Petrol (RON97)',
    'EV',
  ];

  final MapController _mapController = MapController();
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndAddress();
  }

  Future<void> _getCurrentLocationAndAddress() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _showLocationError('Location services are disabled. Please enable them.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showLocationError('Location permissions are denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      await _showLocationError('Location permissions are permanently denied.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final LatLng userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = userLatLng;
      });
      _mapController.move(userLatLng, 16.0);

      // Reverse geocode to get address and place name from user location
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final Placemark p = placemarks.first;
        setState(() {
          address = _formatPlacemark(p);
          placeName = p.name ?? 'Unknown place';
        });
      } else {
        setState(() {
          address = 'Unknown address';
          placeName = 'Unknown place';
        });
      }

      // Calculate distance dynamically if destination is set
      final LatLng destination = LatLng(-6.186486, 106.819294); // Replace with actual destination
      if (_userLocation != null) {
        final double calculatedDistance = const Distance().as(LengthUnit.Kilometer, userLatLng, destination);
        setState(() {
          distance = '${calculatedDistance.toStringAsFixed(1)} KM';
        });
      }
    } catch (e) {
      debugPrint('Error fetching location or address: $e');
      await _showLocationError('Failed to get location: $e');
    }
  }

  Future<void> _showLocationError(String message) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String _formatPlacemark(Placemark p) {
    final parts = [
      if (p.street != null && p.street!.isNotEmpty) p.street,
      if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality,
      if (p.locality != null && p.locality!.isNotEmpty) p.locality,
      if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) p.subAdministrativeArea,
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea,
      if (p.postalCode != null && p.postalCode!.isNotEmpty) p.postalCode,
      if (p.country != null && p.country!.isNotEmpty) p.country,
    ];
    return parts.whereType<String>().join(', ');
  }

  int calculateTreesNeeded(double dailyEmission) {
    // Assuming 1 tree offsets 21 kg CO₂ per year
    const double yearlyOffsetPerTree = 21.0;
    double yearlyEmission = dailyEmission * 365;
    return (yearlyEmission / yearlyOffsetPerTree).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: const Color(0xFF115925),
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
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Map section (real OSM map, half page)
              Container(
                width: double.infinity,
                height: 220,
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
                      center: _userLocation ?? LatLng(-6.186486, 106.819294), // fallback: Jakarta
                      zoom: 16.0,
                      interactiveFlags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      if (_userLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _userLocation!,
                              width: 48,
                              height: 48,
                              builder: (ctx) => const Icon(
                                Icons.location_on,
                                color: Color(0xFF115925),
                                size: 48,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Card below map
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            placeName ?? 'Locating address...',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF222222),
                            ),
                          ),
                        ),
                        const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
                        const SizedBox(width: 2),
                        Text(
                          distance ?? '0 KM',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '| $distance',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address ?? 'Locating address...',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Open in maps
                          },
                          icon: const Icon(Icons.map, color: Color(0xFF115925), size: 20),
                          label: const Text(
                            'Maps',
                            style: TextStyle(
                              color: Color(0xFF115925),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF115925), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Choose this location
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF115925),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Choose this location',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
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
                      height: 64 * 3.0, // 3 rows visible, scrollable
                      child: ListView.separated(
                        scrollDirection: Axis.vertical,
                        itemCount: vehicleTypes.length,
                        separatorBuilder: (context, idx) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final v = vehicleTypes[idx];
                          final isSelected = selectedVehicleType == v.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedVehicleType = v.name;
                                // TODO: Store selected vehicle type in metadata
                              });
                            },
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF115925) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF115925) : const Color(0xFFE0E0E0),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Icon(v.icon, size: 28, color: isSelected ? Colors.white : const Color(0xFF115925)),
                                  const SizedBox(width: 18),
                                  Text(
                                    v.name,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF222222),
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
                    const SizedBox(height: 22),
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
                        controller: TextEditingController(text: selectedModelVehicle),
                        decoration: const InputDecoration(
                          hintText: 'Enter Model Vehicle',
                          hintStyle: TextStyle(fontSize: 15, color: Color(0xFF888888)),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            selectedModelVehicle = value;
                            // TODO: Store user input for model vehicle in metadata
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
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
                          value: selectedFuelType,
                          hint: const Text('Fuel Type', style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF888888)),
                          items: fuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedFuelType = value;
                              // TODO: Store selected fuel type in metadata
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Daily Emission :',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4), // Adjust spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '0.10',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 36,
                            color: Color(0xFF115925),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '(kg CO₂e/day)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                  // Trees Needed Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6F5D6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Trees Needed to offset/year :',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF115925),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              metadata['treesToOffset'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 36,
                                color: Color(0xFF115925),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              'assets/images/tree_illustration.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Save button (fixed at bottom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Save transportation emission metadata
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF115925),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              ),
            ],
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