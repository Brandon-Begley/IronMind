import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/nutrition_screen.dart';
import 'screens/wellness_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadBaseUrl();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: IronMindTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const IronMindApp());
}

class IronMindApp extends StatelessWidget {
  const IronMindApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'IronMind',
    debugShowCheckedModeBanner: false,
    theme: IronMindTheme.theme,
    home: const MainShell(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _current = 2;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    ApiService.testConnection().then((v) => setState(() => _connected = v));
  }

  final _labels = ['Workout', 'Nutrition', 'Dashboard', 'Wellness', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final screens = [
      WorkoutScreen(connected: _connected),
      NutritionScreen(connected: _connected),
      DashboardScreen(connected: _connected),
      WellnessScreen(connected: _connected),
      ProfileScreen(connected: _connected),
    ];

    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      body: IndexedStack(index: _current, children: screens),
      bottomNavigationBar: _BottomNav(
        current: _current,
        labels: _labels,
        onTap: (i) => setState(() => _current = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final List<String> labels;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.labels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: IronMindTheme.surface,
        border: Border(top: BorderSide(color: IronMindTheme.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(children: List.generate(5, (i) => Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _icon(i, i == current),
                const SizedBox(height: 4),
                Text(labels[i], style: GoogleFonts.dmMono(
                  color: i == current ? IronMindTheme.accent : IronMindTheme.text3,
                  fontSize: 8, letterSpacing: 0.3,
                )),
              ]),
            ),
          ))),
        ),
      ),
    );
  }

  Widget _icon(int i, bool active) {
    final color = active ? IronMindTheme.accent : IronMindTheme.text3;
    switch (i) {
      case 0: return CustomPaint(size: const Size(22, 22), painter: _BarbellPainter(color));
      case 1: return Icon(Icons.restaurant_outlined, color: color, size: 22);
      case 2: return Icon(Icons.home_outlined, color: color, size: 22);
      case 3: return Icon(Icons.favorite_border, color: color, size: 22);
      case 4: return Icon(Icons.person_outline, color: color, size: 22);
      default: return Icon(Icons.circle, color: color, size: 22);
    }
  }
}

class _BarbellPainter extends CustomPainter {
  final Color color;
  const _BarbellPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width; final h = size.height;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h*0.44, w, h*0.12), const Radius.circular(2)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*0.12, h*0.22, w*0.15, h*0.56), const Radius.circular(3)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*0.73, h*0.22, w*0.15, h*0.56), const Radius.circular(3)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, h*0.34, w*0.12, h*0.32), const Radius.circular(2)), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*0.88, h*0.34, w*0.12, h*0.32), const Radius.circular(2)), p);
  }
  @override
  bool shouldRepaint(_BarbellPainter old) => old.color != color;
}
