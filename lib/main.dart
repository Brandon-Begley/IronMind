import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/trainer_screen.dart';
import 'screens/wellness_screen.dart';
import 'screens/workout_screen.dart';
import 'services/auth_service.dart';
import 'services/health_service.dart';
import 'services/supabase_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();
  await HealthService.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const IronMindApp());
}

class IronMindApp extends StatefulWidget {
  const IronMindApp({super.key});

  @override
  State<IronMindApp> createState() => _IronMindAppState();
}

class _IronMindAppState extends State<IronMindApp> {
  bool _loading = true;
  bool _signedIn = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _refreshSession();
  }

  Future<void> _refreshSession() async {
    final signedIn = await AuthService.isSignedIn();
    final showOnboarding = signedIn
        ? await AuthService.needsOnboarding()
        : false;
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _showOnboarding = showOnboarding;
      _loading = false;
    });
  }

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
    await _refreshSession();
  }

  Future<void> _handleRedoOnboarding() async {
    await AuthService.requireOnboarding();
    await _refreshSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronMind',
      debugShowCheckedModeBanner: false,
      theme: buildIronMindTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_loading) {
      return const _LaunchScreen();
    }
    if (!_signedIn) {
      return AuthScreen(onAuthenticated: _refreshSession);
    }
    if (_showOnboarding) {
      return OnboardingScreen(onComplete: _refreshSession);
    }
    return MainShell(
      onSignOut: _handleSignOut,
      onRedoOnboarding: _handleRedoOnboarding,
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'IRONMIND',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 46,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: IronMindColors.accent),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final Future<void> Function() onSignOut;
  final Future<void> Function() onRedoOnboarding;

  const MainShell({
    super.key,
    required this.onSignOut,
    required this.onRedoOnboarding,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0; // default to Dashboard
  int _profileRefreshTick = 0;
  int _dashboardRefreshTick = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(key: ValueKey(_dashboardRefreshTick), connected: true),
      const TrainerScreen(),
      const WorkoutScreen(connected: true),
      const WellnessScreen(),
      ProfileScreen(
        key: ValueKey(_profileRefreshTick),
        onSignOut: widget.onSignOut,
        onRedoOnboarding: widget.onRedoOnboarding,
      ),
    ];

    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2A32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: IronMindColors.accent.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                label: 'Dashboard',
                selected: _selectedIndex == 0,
                onTap: () => setState(() {
                  _dashboardRefreshTick++;
                  _selectedIndex = 0;
                }),
              ),
              _NavItem(
                icon: Icons.auto_awesome,
                label: 'Trainer',
                selected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _NavItem(
                icon: Icons.fitness_center,
                label: 'Workout',
                selected: _selectedIndex == 2,
                rotate: true,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _NavItem(
                icon: Icons.favorite_border,
                label: 'Wellness',
                selected: _selectedIndex == 3,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: _selectedIndex == 4,
                onTap: () => setState(() {
                  _profileRefreshTick++;
                  _selectedIndex = 4;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool rotate;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.rotate = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: selected ? IronMindColors.accent : IronMindColors.textMuted,
      size: selected ? 23 : 21,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    IronMindColors.accent.withOpacity(0.22),
                    IronMindColors.accent.withOpacity(0.08),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: IronMindColors.accent.withOpacity(0.30))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            rotate
                ? Transform.rotate(angle: -0.78, child: iconWidget)
                : iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: selected
                    ? IronMindColors.accent
                    : IronMindColors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: selected ? 0.3 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
