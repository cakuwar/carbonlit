import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
//  Gadgets used by university students
//  Wattage = typical midpoint of range
// ─────────────────────────────────────────────
class GadgetInfo {
  final String name;
  final double wattage; // Watts (midpoint)
  final String wattageHint; // Range shown on card
  final IconData icon;

  const GadgetInfo(this.name, this.wattage, this.wattageHint, this.icon);
}

const List<GadgetInfo> gadgetList = [
  // 1. Laptop
  GadgetInfo('Office Laptop', 48, '30–65W', Icons.laptop),
  GadgetInfo('Gaming Laptop', 195, '150–240W+', Icons.laptop),
  // 2. Phone
  GadgetInfo('Phone (Standard)', 8, '5–12W', Icons.smartphone),
  GadgetInfo('Phone (Fast Charge)', 33, '20–45W', Icons.smartphone),
  // 3. iPad / Tablet
  GadgetInfo('iPad / Tablet', 28, '20–35W', Icons.tablet),
  // 4. Power Bank
  GadgetInfo('Power Bank (Portable)', 32, '18–45W', Icons.battery_charging_full),
  GadgetInfo('Power Bank (Large)', 83, '65–100W+', Icons.battery_charging_full),
  // 5. Laptop Cooler
  GadgetInfo('Laptop Cooler', 5, '<5W', Icons.ac_unit),
  // 6. Smart Watch
  GadgetInfo('Smart Watch', 3, '<5W', Icons.watch),
  // 7. Monitor
  GadgetInfo('Monitor (19"–22")', 23, '15–30W', Icons.monitor),
  GadgetInfo('Monitor (27"–34"+)', 110, '60–160W', Icons.monitor),
];

/// Malaysia grid emission factor (kg CO₂e per kWh)
const double _gridEmissionFactor = 0.740;

class GadgetsPage extends StatefulWidget {
  const GadgetsPage({super.key});

  @override
  State<GadgetsPage> createState() => _GadgetsPageState();
}

class _GadgetsPageState extends State<GadgetsPage> {
  GadgetInfo? _selectedGadget;
  double _customWattage = 0;
  double _usageHours = 0;
  double _dailyEmission = 0;
  int _treesToOffset = 0;
  bool _useCustomDevice = false;
  bool _saving = false;
  bool _loadingSaved = true;

  // ── Saved records from DB ──
  List<Map<String, dynamic>> _savedRecords = [];
  double _totalDailyEmission = 0;
  int _totalTrees = 0;

  final _deviceNameController = TextEditingController();
  final _wattageController = TextEditingController();
  final _hoursController = TextEditingController();

  double get _wattage =>
      _useCustomDevice ? _customWattage : (_selectedGadget?.wattage ?? 0);

  @override
  void initState() {
    super.initState();
    _fetchSavedRecords();
  }

  /// Fetch all saved gadget records for this user
  Future<void> _fetchSavedRecords() async {
    setState(() => _loadingSaved = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _loadingSaved = false);
        return;
      }
      final data = await supabase
          .from('gadget_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      double totalEmission = 0;
      int totalTrees = 0;
      for (final r in data) {
        totalEmission += (r['daily_emission'] as num?)?.toDouble() ?? 0;
        totalTrees += (r['trees_to_offset'] as num?)?.toInt() ?? 0;
      }
      setState(() {
        _savedRecords = List<Map<String, dynamic>>.from(data);
        _totalDailyEmission = totalEmission;
        _totalTrees = totalTrees;
        _loadingSaved = false;
      });
    } catch (e) {
      debugPrint('Error fetching gadget records: $e');
      setState(() => _loadingSaved = false);
    }
  }

  /// Delete a single saved record
  Future<void> _deleteRecord(String recordId) async {
    try {
      await Supabase.instance.client
          .from('gadget_records')
          .delete()
          .eq('id', recordId);
      _showSnack('Record deleted');
      _fetchSavedRecords();
    } catch (e) {
      _showSnack('Failed to delete');
    }
  }

  /// Formula: (wattage × hours/day) / 1000 × emission_factor
  void _calculate() {
    setState(() {
      final kWh = (_wattage * _usageHours) / 1000;
      _dailyEmission = kWh * _gridEmissionFactor;
      _treesToOffset = (_dailyEmission * 365 / 21.77).ceil();
    });
  }

  /// Reset the form after saving
  void _resetForm() {
    setState(() {
      _selectedGadget = null;
      _customWattage = 0;
      _usageHours = 0;
      _dailyEmission = 0;
      _treesToOffset = 0;
      _deviceNameController.clear();
      _wattageController.clear();
      _hoursController.clear();
    });
  }

  Future<void> _onSave() async {
    if (_wattage == 0) {
      _showSnack('Please select a gadget or enter wattage.');
      return;
    }
    if (_usageHours <= 0) {
      _showSnack('Please enter usage hours.');
      return;
    }

    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        _showSnack('You must be logged in to save.');
        setState(() => _saving = false);
        return;
      }

      final deviceName = _useCustomDevice
          ? _deviceNameController.text.trim()
          : _selectedGadget?.name ?? '';

      if (deviceName.isEmpty) {
        _showSnack('Please enter a device name.');
        setState(() => _saving = false);
        return;
      }

      await supabase.from('gadget_records').insert({
        'user_id': userId,
        'gadget_type': 'Gadget',
        'device_name': deviceName,
        'wattage': _wattage,
        'usage_hours_per_day': _usageHours,
        'daily_emission': _dailyEmission,
        'trees_to_offset': _treesToOffset,
      });

      _showSnack('$deviceName saved! Add another or view below.');
      _resetForm();
      _fetchSavedRecords();
    } catch (e) {
      debugPrint('Error saving gadget: $e');
      _showSnack('Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _wattageController.dispose();
    _hoursController.dispose();
    super.dispose();
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
            color: const Color(0xFFF7F7F7),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ══════════════════════════════════
                  // SECTION 1: Total Summary Banner
                  // ══════════════════════════════════
                  if (_savedRecords.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF115925), Color(0xFF1B7A3A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Gadget Emissions',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_totalDailyEmission.toStringAsFixed(4)} kg CO₂e/day',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$_totalTrees',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                                const Text(
                                  'trees/yr',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_savedRecords.length} device(s) logged',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ══════════════════════════════════
                  // SECTION 2: Add New Device
                  // ══════════════════════════════════
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                SizedBox(width: 8),
                                Text(
                                  'Add Device',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF222222),
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              icon: Icon(
                                _useCustomDevice ? Icons.list : Icons.edit,
                                size: 16,
                                color: const Color(0xFF115925),
                              ),
                              label: Text(
                                _useCustomDevice
                                    ? 'Pick from list'
                                    : 'Custom device',
                                style: const TextStyle(
                                  color: Color(0xFF115925),
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _useCustomDevice = !_useCustomDevice;
                                  _selectedGadget = null;
                                  _wattageController.clear();
                                  _deviceNameController.clear();
                                  _customWattage = 0;
                                  _calculate();
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (!_useCustomDevice) ...[
                          // ── Device card grid ──
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: gadgetList.length,
                            itemBuilder: (context, index) {
                              final device = gadgetList[index];
                              final isSelected = _selectedGadget == device;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedGadget = device;
                                    _calculate();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF115925)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF115925)
                                          : const Color(0xFFE0E0E0),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF115925)
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        device.icon,
                                        size: 26,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF555555),
                                      ),
                                      const SizedBox(height: 5),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          device.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF333333),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        device.wattageHint,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isSelected
                                              ? Colors.white70
                                              : const Color(0xFF888888),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          if (_selectedGadget != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(_selectedGadget!.icon,
                                      color: const Color(0xFF115925)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${_selectedGadget!.name}  —  ${_selectedGadget!.wattage.toInt()}W (${_selectedGadget!.wattageHint})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF115925),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          // ── Custom device input ──
                          _buildInputField(
                            controller: _deviceNameController,
                            hint: 'Enter Device Name',
                            icon: Icons.devices_other,
                          ),
                          const SizedBox(height: 12),
                          _buildInputField(
                            controller: _wattageController,
                            hint: 'Enter Wattage (W)',
                            icon: Icons.bolt,
                            isNumber: true,
                            onChanged: (val) {
                              _customWattage = double.tryParse(val) ?? 0;
                              _calculate();
                            },
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ── Usage hours ──
                        const Text(
                          'Usage Hours per Day',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInputField(
                          controller: _hoursController,
                          hint: 'e.g. 8',
                          icon: Icons.access_time,
                          isNumber: true,
                          onChanged: (val) {
                            _usageHours = double.tryParse(val) ?? 0;
                            _calculate();
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Formula: (${_wattage.toInt()}W × ${_usageHours.toStringAsFixed(1)}h) ÷ 1000 × $_gridEmissionFactor',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF795548)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Preview result ──
                        if (_dailyEmission > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8E9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      _dailyEmission.toStringAsFixed(4),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        color: Color(0xFF115925),
                                      ),
                                    ),
                                    const Text(
                                      'kg CO₂e/day',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888)),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey[300],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '$_treesToOffset',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        color: Color(0xFF115925),
                                      ),
                                    ),
                                    const Text(
                                      'trees/year',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ── Save button ──
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _onSave,
                            icon: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add, color: Colors.white),
                            label: Text(
                              _saving ? 'Saving...' : 'Save & Add Another',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF115925),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════
                  // SECTION 3: Saved Devices List
                  // ══════════════════════════════════
                  Row(
                    children: [
                      const Text(
                        'Your Devices',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const Spacer(),
                      if (_savedRecords.isNotEmpty)
                        TextButton(
                          onPressed: () => _confirmDeleteAll(),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_loadingSaved)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF115925),
                        ),
                      ),
                    )
                  else if (_savedRecords.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.devices,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'No devices logged yet.\nSelect a device above and save!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _savedRecords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final record = _savedRecords[index];
                        final name = record['device_name'] ?? 'Unknown';
                        final wattage =
                            (record['wattage'] as num?)?.toDouble() ?? 0;
                        final hours =
                            (record['usage_hours_per_day'] as num?)
                                ?.toDouble() ??
                            0;
                        final emission =
                            (record['daily_emission'] as num?)?.toDouble() ?? 0;
                        // ignore: unused_local_variable
                        final trees =
                            (record['trees_to_offset'] as num?)?.toInt() ?? 0;
                        final recordId = record['id']?.toString() ?? '';
                        final createdAtRaw = record['created_at']?.toString();
                        String createdAtLabel = '';
                        if (createdAtRaw != null) {
                          try {
                            final dt = DateTime.parse(createdAtRaw).toLocal();
                            createdAtLabel =
                                '${dt.day.toString().padLeft(2, '0')}/'
                                '${dt.month.toString().padLeft(2, '0')}/'
                                '${dt.year}  '
                                '${dt.hour.toString().padLeft(2, '0')}:'
                                '${dt.minute.toString().padLeft(2, '0')}';
                          } catch (_) {}
                        }

                        // Find matching icon
                        IconData deviceIcon = Icons.devices_other;
                        for (final g in gadgetList) {
                          if (g.name == name) {
                            deviceIcon = g.icon;
                            break;
                          }
                        }

                        return Dismissible(
                          key: Key(recordId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.delete,
                                color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteRecord(recordId),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFE8E8E8)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(deviceIcon,
                                      color: const Color(0xFF115925),
                                      size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF222222),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${wattage.toInt()}W • ${hours.toStringAsFixed(1)}h/day',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (createdAtLabel.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 10,
                                                color: Colors.grey[400]),
                                            const SizedBox(width: 3),
                                            Text(
                                              createdAtLabel,
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      emission.toStringAsFixed(4),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF115925),
                                      ),
                                    ),
                                    Text(
                                      'kg CO₂e',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Confirm delete all ──
  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Devices?'),
        content: const Text(
            'This will remove all your saved gadget records. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final supabase = Supabase.instance.client;
                final userId = supabase.auth.currentUser?.id;
                if (userId == null) return;
                await supabase
                    .from('gadget_records')
                    .delete()
                    .eq('user_id', userId);
                _showSnack('All records cleared');
                _fetchSavedRecords();
              } catch (e) {
                _showSnack('Failed to delete');
              }
            },
            child: const Text('Delete All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Reusable text field ──
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
        keyboardType:
            isNumber ? TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 15, color: Color(0xFF888888)),
          border: InputBorder.none,
          icon: Icon(icon, color: const Color(0xFF888888), size: 20),
        ),
        onChanged: onChanged,
      ),
    );
  }
}