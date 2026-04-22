import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'calculator_page.dart';
import 'admin_campus_dashboard.dart';
import 'admin_dashboard.dart';

/// Admin Carbon Calculator shell with bottom navigation.
///
/// Contains three tab pages:
/// - Calculator: Energy emission entry and tracking
/// - Dashboard: Analytics placeholder
/// - Admin: User management (existing [AdminDashboard])
class AdminCalc extends StatefulWidget {
  final int initialIndex;

  const AdminCalc({super.key, this.initialIndex = 0});

  @override
  State<AdminCalc> createState() => _AdminCalcState();
}

class _AdminCalcState extends State<AdminCalc> {
  late int _selectedIndex;

  static const List<Widget> _pages = [
    CalculatorPage(),
    AdminCampusDashboard(),
    AdminDashboard(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _pages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          backgroundColor: Colors.white,
          indicatorColor: AppColors.lightGreen,
          surfaceTintColor: Colors.transparent,
          elevation: 3,
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined, color: AppColors.grey),
              selectedIcon:
                  Icon(Icons.calculate, color: AppColors.primaryGreen),
              label: 'Calculator',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppColors.grey),
              selectedIcon:
                  Icon(Icons.dashboard, color: AppColors.primaryGreen),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(
                  Icons.admin_panel_settings_outlined, color: AppColors.grey),
              selectedIcon: Icon(
                  Icons.admin_panel_settings, color: AppColors.primaryGreen),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}