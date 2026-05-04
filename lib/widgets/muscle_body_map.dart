import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/workout_summary_screen.dart';
import '../theme.dart';

// ── Muscle → set-count mapping ────────────────────────────────────────────────

/// Infers which muscle groups an exercise targets from its name.
/// Returns 1-2 primary groups.
List<String> exercisePrimaryMuscles(String name) {
  final n = name.toLowerCase();

  // Chest
  if (_any(n, ['bench', 'chest', 'pec', 'fly', 'flye', 'push-up', 'pushup',
                'dip', 'cable cross']))
    return ['Chest'];

  // Back
  if (_any(n, ['row', 'lat pull', 'pull-up', 'pullup', 'chin', 'deadlift',
                'rdl', 'rack pull', 'shrug', 'lat spread']))
    return ['Back'];

  // Shoulders
  if (_any(n, ['press overhead', 'ohp', 'military', 'shoulder press',
                'lateral raise', 'front raise', 'rear delt', 'face pull',
                'arnold', 'upright row']))
    return ['Shoulders'];

  // Legs (broad — quads, hamstrings, glutes)
  if (_any(n, ['squat', 'leg press', 'hack squat', 'lunge', 'split squat',
                'step up', 'leg extension', 'leg curl', 'hip thrust',
                'glute bridge', 'rdl', 'nordic']))
    return _legsDetail(n);

  // Calves
  if (_any(n, ['calf', 'calves', 'standing calf', 'seated calf', 'donkey']))
    return ['Calves'];

  // Core
  if (_any(n, ['crunch', 'plank', 'ab ', 'abs', 'sit-up', 'situp',
                'core', 'cable crunch', 'oblique', 'russian twist',
                'hanging leg', 'leg raise']))
    return ['Core'];

  // Biceps
  if (_any(n, ['curl', 'bicep', 'hammer curl', 'preacher', 'incline curl']))
    return ['Biceps'];

  // Triceps
  if (_any(n, ['tricep', 'triceps', 'pushdown', 'skull', 'overhead extension',
                'close grip', 'kickback']))
    return ['Triceps'];

  // Forearms
  if (_any(n, ['wrist', 'forearm', 'reverse curl', 'farmers', 'farmer']))
    return ['Forearms'];

  // Cardio
  if (_any(n, ['run', 'sprint', 'bike', 'row', 'jump', 'burpee', 'cardio',
                'elliptical', 'treadmill']))
    return ['Cardio'];

  return [];
}

List<String> _legsDetail(String n) {
  if (_any(n, ['rdl', 'leg curl', 'hamstring', 'nordic'])) return ['Hamstrings'];
  if (_any(n, ['hip thrust', 'glute bridge', 'glute'])) return ['Glutes'];
  return ['Quads'];
}

bool _any(String s, List<String> keywords) => keywords.any((k) => s.contains(k));

/// Computes muscle → set count from the exercise list.
Map<String, double> computeMuscleSetMap(List<SummaryExercise> exercises) {
  final map = <String, double>{};
  for (final ex in exercises) {
    final groups = exercisePrimaryMuscles(ex.name);
    final sets = ex.completedSets.length.toDouble();
    if (groups.isEmpty) continue;
    for (final g in groups) {
      map[g] = (map[g] ?? 0) + sets / groups.length;
    }
  }
  return map;
}

// ── Full distribution panel ───────────────────────────────────────────────────

/// The complete Muscle Distribution card — body map + set list.
class MuscleDistributionPanel extends StatelessWidget {
  final Map<String, double> muscleSetMap;

  const MuscleDistributionPanel({super.key, required this.muscleSetMap});

  @override
  Widget build(BuildContext context) {
    final sorted = muscleSetMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.isEmpty ? 1.0 : sorted.first.value;

    return Container(
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Text('Muscle Distribution',
                style: GoogleFonts.dmSans(
                  color: IronMindTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 12),

          // Body map
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                painter: _BodyMapPainter(activeGroups: muscleSetMap),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (sorted.isNotEmpty) ...[
            const Divider(height: 1, color: IronMindTheme.border),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(children: [
                Expanded(child: Text('Muscle',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1))),
                Text('Completed Sets',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
              ]),
            ),
            // Rows
            ...sorted.map((e) => _MuscleRow(
              label: e.key,
              sets:  e.value,
              max:   max,
            )),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  final String label;
  final double sets;
  final double max;

  const _MuscleRow({required this.label, required this.sets, required this.max});

  @override
  Widget build(BuildContext context) {
    final color = _muscleColor(label);
    final frac  = max > 0 ? (sets / max).clamp(0.0, 1.0) : 0.0;
    final setsLabel = sets == sets.roundToDouble()
        ? sets.toInt().toString()
        : sets.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(label,
            style: GoogleFonts.dmSans(
              color: IronMindTheme.textPrimary, fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 7,
              backgroundColor: IronMindTheme.surface2,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(setsLabel,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text2, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _BodyMapPainter extends CustomPainter {
  final Map<String, double> activeGroups;

  const _BodyMapPainter({required this.activeGroups});

  @override
  void paint(Canvas canvas, Size size) {
    // Two figures: front (left half) and back (right half)
    final figW = size.width / 2;
    final scale = figW / 56.0; // normalize to 56 units wide per figure

    _paintFigure(canvas, size, scale, 0,      isFront: true);
    _paintFigure(canvas, size, scale, figW,   isFront: false);
  }

  void _paintFigure(Canvas canvas, Size size, double scale,
      double xOffset, {required bool isFront}) {
    final cx = 28.0; // center of figure in normalized space

    // ── Silhouette fill ──────────────────────────────────────────────────────
    final silhouettePaint = Paint()
      ..color = const Color(0xFF2A2A2E)
      ..style = PaintingStyle.fill;

    for (final shape in _silhouette(cx)) {
      canvas.drawPath(_scalePath(shape, scale, xOffset), silhouettePaint);
    }

    // ── Muscle regions ───────────────────────────────────────────────────────
    final regions = isFront ? _frontRegions(cx) : _backRegions(cx);
    for (final region in regions) {
      final isActive = activeGroups.containsKey(region.muscle);
      if (!isActive) {
        // Inactive — subtle outline only
        final paint = Paint()
          ..color = const Color(0xFF3A3A42)
          ..style = PaintingStyle.fill;
        canvas.drawPath(_scalePath(region.path, scale, xOffset), paint);
      } else {
        final color = _muscleColor(region.muscle);
        final sets  = activeGroups[region.muscle]!;
        final maxV  = activeGroups.values.fold(1.0, (m, v) => v > m ? v : m);
        final alpha = (0.55 + 0.45 * (sets / maxV)).clamp(0.3, 1.0);
        final paint = Paint()
          ..color = color.withOpacity(alpha)
          ..style = PaintingStyle.fill;
        canvas.drawPath(_scalePath(region.path, scale, xOffset), paint);

        // Subtle glow ring
        final glowPaint = Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * scale;
        canvas.drawPath(_scalePath(region.path, scale, xOffset), glowPaint);
      }
    }

    // ── Silhouette outline ───────────────────────────────────────────────────
    final outlinePaint = Paint()
      ..color = const Color(0xFF4A4A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale
      ..strokeJoin = StrokeJoin.round;

    for (final shape in _silhouette(cx)) {
      canvas.drawPath(_scalePath(shape, scale, xOffset), outlinePaint);
    }
  }

  Path _scalePath(Path src, double scale, double xOffset) {
    final m = Matrix4.identity()
      ..translate(xOffset)
      ..scale(scale);
    return src.transform(m.storage);
  }

  @override
  bool shouldRepaint(_BodyMapPainter old) =>
      old.activeGroups != activeGroups;
}

// ── Body shapes (normalized, cx=28 center, y: 0-196) ─────────────────────────

List<Path> _silhouette(double cx) => [
  // Head
  _oval(cx, 10, 8, 10),
  // Neck
  _rrect(cx - 3, 20, cx + 3, 27, 2),
  // Torso
  _rrect(cx - 13, 27, cx + 13, 78, 5),
  // Hips
  _rrect(cx - 11, 78, cx + 11, 92, 4),
  // Left upper arm
  _rrect(cx - 21, 28, cx - 14, 60, 4),
  // Right upper arm
  _rrect(cx + 14, 28, cx + 21, 60, 4),
  // Left forearm
  _rrect(cx - 20, 62, cx - 13, 85, 3),
  // Right forearm
  _rrect(cx + 13, 62, cx + 20, 85, 3),
  // Left hand
  _rrect(cx - 19, 86, cx - 14, 94, 3),
  // Right hand
  _rrect(cx + 14, 86, cx + 19, 94, 3),
  // Left thigh
  _rrect(cx - 11, 93, cx - 2,  140, 5),
  // Right thigh
  _rrect(cx + 2,  93, cx + 11, 140, 5),
  // Left shin
  _rrect(cx - 10, 142, cx - 2, 180, 4),
  // Right shin
  _rrect(cx + 2,  142, cx + 10, 180, 4),
  // Left foot
  _rrect(cx - 12, 180, cx - 1, 188, 3),
  // Right foot
  _rrect(cx + 1,  180, cx + 12, 188, 3),
];

// ── Muscle region definitions ─────────────────────────────────────────────────

class _MuscleRegion {
  final String muscle;
  final Path   path;
  const _MuscleRegion(this.muscle, this.path);
}

List<_MuscleRegion> _frontRegions(double cx) => [
  // Chest
  _MuscleRegion('Chest',
    _rrect(cx - 11, 30, cx + 11, 52, 4)),
  // Left shoulder (front delt)
  _MuscleRegion('Shoulders',
    _oval(cx - 17.5, 33, 5, 7)),
  // Right shoulder (front delt)
  _MuscleRegion('Shoulders',
    _oval(cx + 17.5, 33, 5, 7)),
  // Left bicep
  _MuscleRegion('Biceps',
    _rrect(cx - 21, 34, cx - 14, 54, 3)),
  // Right bicep
  _MuscleRegion('Biceps',
    _rrect(cx + 14, 34, cx + 21, 54, 3)),
  // Left forearm (front)
  _MuscleRegion('Forearms',
    _rrect(cx - 20, 60, cx - 13, 82, 3)),
  // Right forearm (front)
  _MuscleRegion('Forearms',
    _rrect(cx + 13, 60, cx + 20, 82, 3)),
  // Abs / Core
  _MuscleRegion('Core',
    _rrect(cx - 9, 52, cx + 9, 78, 5)),
  // Left quad
  _MuscleRegion('Quads',
    _rrect(cx - 11, 94, cx - 2, 138, 4)),
  // Right quad
  _MuscleRegion('Quads',
    _rrect(cx + 2, 94, cx + 11, 138, 4)),
  // Left calf (front)
  _MuscleRegion('Calves',
    _oval(cx - 6, 158, 4, 11)),
  // Right calf (front)
  _MuscleRegion('Calves',
    _oval(cx + 6, 158, 4, 11)),
];

List<_MuscleRegion> _backRegions(double cx) => [
  // Left trap
  _MuscleRegion('Back',
    _rrect(cx - 13, 28, cx - 1, 50, 3)),
  // Right trap
  _MuscleRegion('Back',
    _rrect(cx + 1, 28, cx + 13, 50, 3)),
  // Left lat
  _MuscleRegion('Back',
    _latsPath(cx, left: true)),
  // Right lat
  _MuscleRegion('Back',
    _latsPath(cx, left: false)),
  // Lower back
  _MuscleRegion('Back',
    _rrect(cx - 8, 68, cx + 8, 80, 3)),
  // Rear left shoulder
  _MuscleRegion('Shoulders',
    _oval(cx - 17.5, 33, 5, 7)),
  // Rear right shoulder
  _MuscleRegion('Shoulders',
    _oval(cx + 17.5, 33, 5, 7)),
  // Left tricep
  _MuscleRegion('Triceps',
    _rrect(cx - 21, 36, cx - 14, 56, 3)),
  // Right tricep
  _MuscleRegion('Triceps',
    _rrect(cx + 14, 36, cx + 21, 56, 3)),
  // Left forearm (back)
  _MuscleRegion('Forearms',
    _rrect(cx - 20, 60, cx - 13, 82, 3)),
  // Right forearm (back)
  _MuscleRegion('Forearms',
    _rrect(cx + 13, 60, cx + 20, 82, 3)),
  // Left glute
  _MuscleRegion('Glutes',
    _oval(cx - 6, 87, 8, 7)),
  // Right glute
  _MuscleRegion('Glutes',
    _oval(cx + 6, 87, 8, 7)),
  // Left hamstring
  _MuscleRegion('Hamstrings',
    _rrect(cx - 11, 94, cx - 2, 138, 4)),
  // Right hamstring
  _MuscleRegion('Hamstrings',
    _rrect(cx + 2, 94, cx + 11, 138, 4)),
  // Left calf (back)
  _MuscleRegion('Calves',
    _oval(cx - 6, 158, 4, 11)),
  // Right calf (back)
  _MuscleRegion('Calves',
    _oval(cx + 6, 158, 4, 11)),
];

// ── Shape helpers ─────────────────────────────────────────────────────────────

Path _rrect(double l, double t, double r, double b, double radius) =>
    Path()..addRRect(RRect.fromLTRBR(l, t, r, b, Radius.circular(radius)));

Path _oval(double cx, double cy, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(
      center: Offset(cx, cy), width: rx * 2, height: ry * 2));

Path _latsPath(double cx, {required bool left}) {
  // Teardrop lat shape — wide at shoulder, tapers toward waist
  final sign = left ? -1.0 : 1.0;
  final path = Path();
  if (left) {
    path
      ..moveTo(cx - 13, 48)
      ..quadraticBezierTo(cx - 22, 60, cx - 20, 76)
      ..quadraticBezierTo(cx - 16, 82, cx - 13, 78)
      ..lineTo(cx - 13, 48);
  } else {
    path
      ..moveTo(cx + 13, 48)
      ..quadraticBezierTo(cx + 22, 60, cx + 20, 76)
      ..quadraticBezierTo(cx + 16, 82, cx + 13, 78)
      ..lineTo(cx + 13, 48);
  }
  path.close();
  return path;
}

// ── Muscle group → color ──────────────────────────────────────────────────────

Color _muscleColor(String group) {
  switch (group) {
    case 'Chest':       return const Color(0xFFFF6B6B);
    case 'Back':        return const Color(0xFF47B4FF);
    case 'Shoulders':   return const Color(0xFF9B8AFB);
    case 'Biceps':      return const Color(0xFFFFB347);
    case 'Triceps':     return const Color(0xFFFFD147);
    case 'Forearms':    return const Color(0xFFFFB347);
    case 'Core':        return const Color(0xFF4ECDC4);
    case 'Quads':       return const Color(0xFF47FF8A);
    case 'Hamstrings':  return const Color(0xFF6BFF6B);
    case 'Glutes':      return const Color(0xFF6BFF6B);
    case 'Calves':      return const Color(0xFF4ECDC4);
    case 'Cardio':      return const Color(0xFFFF8EC8);
    case 'Push':        return const Color(0xFFFF6B6B);
    case 'Pull':        return const Color(0xFF47B4FF);
    default:            return IronMindTheme.accent;
  }
}
