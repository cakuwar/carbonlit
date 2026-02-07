import 'package:flutter/material.dart';

class GadgetsPage extends StatefulWidget {
  const GadgetsPage({super.key});

  @override
  State<GadgetsPage> createState() => _GadgetsPageState();
}

class _GadgetsPageState extends State<GadgetsPage> {
  // Metadata object to store user input
  final Map<String, dynamic> metadata = {
    'gadgetType': null,
    'deviceName': '',
    'usageHoursPerDay': 0,
    'dailyEmission': 0.0,
    'treesToOffset': 0,
  };

  // TODO: Replace with actual emission factor and calculation logic
  void calculateEmissionAndTrees() {
    setState(() {
      metadata['dailyEmission'] = metadata['usageHoursPerDay'] * 0.1; // Placeholder for emission factor
      metadata['treesToOffset'] = (metadata['dailyEmission'] * 365 / 21).ceil(); // Placeholder for yearly factor
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF115925),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Gadgets',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            color: const Color(0xFFF7F7F7), // Set background color to match TransportPage
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gadget Type Label
                  const Text(
                    'Gadget Types',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Gadget Type Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: metadata['gadgetType'],
                        hint: const Text(
                          'Select Your Gadget Types',
                          style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
                        ),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF888888)),
                        items: <String>['Type 1', 'Type 2', 'Type 3'] // Example options
                            .map((type) => DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            metadata['gadgetType'] = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Device Name Label
                  const Text(
                    'Device Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Device Name Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Enter Device Name',
                        hintStyle: TextStyle(fontSize: 15, color: Color(0xFF888888)),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          metadata['deviceName'] = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Usage Hours Label
                  const Text(
                    'Usage Hours per Day',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Usage Hours Input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                    ),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter Usage Hours per Day',
                        hintStyle: TextStyle(fontSize: 15, color: Color(0xFF888888)),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        setState(() {
                          metadata['usageHoursPerDay'] = double.tryParse(value) ?? 0;
                          calculateEmissionAndTrees();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Daily Emission Display
                  Column(
                    children: [
                      const Text(
                        'Daily Emission :',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metadata['dailyEmission'].toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          color: Color(0xFF115925),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(kg CO₂e/day)',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

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

                  // Save Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Save gadget emission metadata to backend
                          debugPrint(metadata.toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF115925),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
        ),
      ),
    );
  }
}