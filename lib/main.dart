import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'pages/auth/authentication_page.dart';
import 'pages/home/access_page.dart';
import 'pages/home/opening_page.dart';
import 'pages/home/home_page.dart';
import 'pages/personal/profile_page.dart';
import 'pages/personal/edit_profile_page.dart' as edit;
import 'pages/personal/security_page.dart' as security;
import 'pages/personal/notifications_page.dart' as notifications;
import 'pages/personal/privacy_page.dart' as privacy;
import 'pages/personal/subscription_page.dart' as subscription;
import 'pages/personal/help_support_page.dart' as help;
import 'pages/personal/terms_page.dart';
import 'pages/calculator/carbon_calc.dart';
import 'pages/calculator/transport.dart';
import 'pages/calculator/gadgets.dart';
import 'pages/calculator/accomo.dart';
import 'package:geolocator/geolocator.dart';
import 'pages/result/personal_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GeolocatorPlatform.instance; // Ensures the plugin is initialized

  try {
    await dotenv.load(fileName: '.env');
    debugPrint('Environment loaded successfully');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '', // Replace with your Supabase Project URL
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '', // Replace with your Supabase anon key
  );

  runApp(const CarbonLitApp());
}

class CarbonLitApp extends StatelessWidget {
  const CarbonLitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'CarbonLit - MISSION ZERO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          primaryColor: const Color(0xFF115925),
          colorScheme: const ColorScheme.dark().copyWith(
            primary: const Color(0xFF115925),
          ),
        ),
        // Define named routes
        initialRoute: '/',
        routes: {
          '/': (context) => const AppWrapper(),
          '/opening': (context) => const OpeningPage(),
          '/access': (context) => const AccessPage(),
          '/auth': (context) => const AuthenticationPage(),
          '/home': (context) => const HomePage(),
          '/profile': (context) => ProfilePage(),
          '/edit_profile': (context) => edit.EditProfilePage(),
          '/security': (context) => security.SecurityPage(),
          '/notifications': (context) => notifications.NotificationsPage(),
          '/privacy': (context) => privacy.PrivacyPage(),
          '/subscription': (context) => subscription.SubscriptionPage(),
          '/help_support': (context) => help.HelpSupportPage(),
          '/terms': (context) => TermsPage(),
          '/carbon_calculator': (context) => Calculator(),
          '/transportation': (context) => TransportPage(),
          '/gadgets': (context) => GadgetsPage(),
          '/accommodation': (context) => AccommodationPage(),
          '/personal': (context) => PersonalPage(),
        },
      ),
    );
  }
}

/// AppWrapper handles the initial routing logic
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // If user is authenticated, go to home
        if (authProvider.isAuthenticated) {
          return const HomePage();
        }
        // Otherwise show the opening page (splash/welcome)
        return const OpeningPage();
      },
    );
  }
}

