import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const Color _primaryGreen = Color(0xFF115925);

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _firstName = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load name
      final profile = await supabase
          .from('profiles')
          .select('first_name')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _firstName = profile?['first_name'] as String? ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final authProvider = Provider.of<AuthProvider>(context);
    final meta = authProvider.user?.userMetadata ?? {};
    final displayName = _firstName.isNotEmpty
        ? _firstName
        : (meta['first_name'] as String? ?? '');

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFECF1FD),
              Color(0xFFDFF9FB),
              Color(0xFFBFF2BF),
              Color(0xFF9CD69C),
              Color(0xFF376834),
            ],
          ),
        ),
        child: Stack(
          children: [
            // ── Forest background ──
            Positioned(
              bottom: 0,
              left: -50,
              right: 0,
              child: Image.asset(
                'assets/images/forest.png',
                fit: BoxFit.cover,
                height: height * 0.72,
              ),
            ),

            // ── Content ──
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        width * 0.05, height * 0.01, width * 0.05, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top bar ──
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: height * 0.015),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName.isNotEmpty
                                          ? 'Hello, $displayName \u{1F44B}'
                                          : 'Hello! \u{1F44B}',
                                      style: const TextStyle(
                                        color: Color(0xFF0D0D0D),
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Track your carbon footprint today',
                                      style: TextStyle(
                                        color: Color(0xFF444444),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/personal'),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _primaryGreen, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            _primaryGreen.withOpacity(0.25),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/profile.png',
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Quote Card ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(16),
                            border: const Border(
                              left: BorderSide(color: _primaryGreen, width: 4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.eco,
                                  color: _primaryGreen, size: 22),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Your footprint tells a story \u2014 make it one of responsibility and positive change.',
                                  style: TextStyle(
                                    color: Color(0xFF2A2A2A),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── HERO: Carbon Calculator ──
                        _HeroButton(
                          label: 'Carbon Calculator',
                          subtitle: 'Log your daily footprint',
                          icon: Icons.calculate_rounded,
                          onTap: () =>
                              Navigator.pushNamed(context, '/carbon_calculator'),
                        ),

                        const SizedBox(height: 14),

                        // ── Secondary row ──
                        Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                label: 'Leaderboard',
                                icon: Icons.emoji_events_rounded,
                                iconColor: const Color(0xFFFFCC00),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/leaderboard'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SecondaryButton(
                                label: 'Dashboard',
                                icon: Icons.bar_chart_rounded,
                                iconColor: const Color(0xFF64D2FF),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/dashboard'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Hero Button (Carbon Calculator)
// ─────────────────────────────────────────────
class _HeroButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF115925), Color(0xFF1B8C3D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF115925).withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Secondary Button (Leaderboard / Dashboard)
// ─────────────────────────────────────────────
class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
