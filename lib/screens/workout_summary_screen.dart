import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/ironmind_theme.dart';
import '../widgets/muscle_body_map.dart';

// ── Plain data models (no widget state, safe to pass across screens) ──────────

class WorkoutSummaryData {
  final String name;
  final DateTime date;
  final int elapsedSeconds;
  final List<SummaryExercise> exercises;
  final List<String> muscleGroups;
  final Map<String, double> muscleSetMap;

  const WorkoutSummaryData({
    required this.name,
    required this.date,
    required this.elapsedSeconds,
    required this.exercises,
    required this.muscleGroups,
    required this.muscleSetMap,
  });

  int get totalSets => exercises.fold(0, (s, e) => s + e.completedSets.length);

  double get totalVolume => exercises.fold(0.0, (vol, e) =>
      vol + e.completedSets.fold(0.0, (s, set) => s + set.weight * set.reps));

  List<SummarySet> get allPRs =>
      exercises.expand((e) => e.completedSets.where((s) => s.isPR)).toList();

  String get durationLabel {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get volumeLabel {
    if (totalVolume >= 1000) {
      return '${(totalVolume / 1000).toStringAsFixed(1)}k lbs';
    }
    return '${totalVolume.toInt()} lbs';
  }
}

class SummaryExercise {
  final String name;
  final List<SummarySet> completedSets;

  const SummaryExercise({required this.name, required this.completedSets});

  double get maxWeight =>
      completedSets.isEmpty ? 0 : completedSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);

  int get maxReps =>
      completedSets.isEmpty ? 0 : completedSets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
}

class SummarySet {
  final double weight;
  final int reps;
  final bool isPR;

  const SummarySet({required this.weight, required this.reps, this.isPR = false});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WorkoutSummaryScreen extends StatefulWidget {
  final WorkoutSummaryData data;

  const WorkoutSummaryScreen({super.key, required this.data});

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkOpacity;
  late final Animation<double> _bodyFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _checkScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );
    _checkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );
    _bodyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final hasPRs = d.allPRs.isNotEmpty;

    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Animated header ───────────────────────────────────────
                  Center(
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => Opacity(
                        opacity: _checkOpacity.value,
                        child: Transform.scale(
                          scale: _checkScale.value,
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: IronMindTheme.green.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: IronMindTheme.green.withOpacity(0.5), width: 2),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: IronMindTheme.green,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  AnimatedBuilder(
                    animation: _bodyFade,
                    builder: (_, child) =>
                        Opacity(opacity: _bodyFade.value, child: child),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Workout name + date
                        Center(
                          child: Column(children: [
                            Text(
                              d.name.isEmpty ? 'WORKOUT COMPLETE' : d.name.toUpperCase(),
                              style: GoogleFonts.bebasNeue(
                                color: IronMindTheme.textPrimary,
                                fontSize: 30,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _formatDate(d.date),
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.text2, fontSize: 11),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 24),

                        // ── Stat cards ────────────────────────────────────
                        Row(children: [
                          _StatCard(label: 'Duration', value: d.durationLabel,
                              icon: Icons.timer_outlined, color: IronMindTheme.accent),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Volume', value: d.volumeLabel,
                              icon: Icons.fitness_center, color: IronMindTheme.green),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          _StatCard(label: 'Sets', value: '${d.totalSets}',
                              icon: Icons.repeat_rounded, color: IronMindTheme.blue),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Exercises', value: '${d.exercises.length}',
                              icon: Icons.format_list_numbered, color: IronMindTheme.orange),
                        ]),
                        const SizedBox(height: 24),

                        // ── Muscle distribution ───────────────────────────
                        if (d.muscleSetMap.isNotEmpty) ...[
                          MuscleDistributionPanel(muscleSetMap: d.muscleSetMap),
                          const SizedBox(height: 24),
                        ] else if (d.muscleGroups.isNotEmpty) ...[
                          _SectionLabel('MUSCLES TRAINED'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: d.muscleGroups.map((g) =>
                              _MuscleChip(label: g)).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── PRs ────────────────────────────────────────────
                        if (hasPRs) ...[
                          _SectionLabel('PERSONAL RECORDS'),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: IronMindTheme.green.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: IronMindTheme.green.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: d.exercises.where((e) =>
                                e.completedSets.any((s) => s.isPR)).map((ex) {
                                  final prSet = ex.completedSets
                                      .lastWhere((s) => s.isPR);
                                  return _PRRow(
                                    exercise: ex.name,
                                    weight: prSet.weight,
                                    reps: prSet.reps,
                                    isLast: ex == d.exercises
                                      .where((e) => e.completedSets.any((s) => s.isPR))
                                      .last,
                                  );
                                }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Exercise breakdown ─────────────────────────────
                        _SectionLabel('EXERCISE LOG'),
                        const SizedBox(height: 10),
                        ...d.exercises.map((ex) => _ExerciseSummaryCard(exercise: ex)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky bottom bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: AnimatedBuilder(
                animation: _bodyFade,
                builder: (_, child) =>
                    Opacity(opacity: _bodyFade.value, child: child),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: IronMindTheme.bg,
                    border: const Border(top: BorderSide(color: IronMindTheme.border)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('CLOSE',
                        style: GoogleFonts.bebasNeue(
                          fontSize: 20, letterSpacing: 2)),
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

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday - 1]} ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.dmMono(
      color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5),
  );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                Text(value,
                  style: GoogleFonts.bebasNeue(
                    color: color, fontSize: 18, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Muscle group → color mapping
const _muscleColors = <String, Color>{
  'Chest':       Color(0xFFFF6B6B),
  'Back':        Color(0xFF47B4FF),
  'Shoulders':   Color(0xFF9B8AFB),
  'Legs':        Color(0xFF47FF8A),
  'Quads':       Color(0xFF47FF8A),
  'Hamstrings':  Color(0xFF6BFF6B),
  'Glutes':      Color(0xFF6BFF6B),
  'Calves':      Color(0xFF4ECDC4),
  'Arms':        Color(0xFFFFB347),
  'Biceps':      Color(0xFFFFB347),
  'Triceps':     Color(0xFFFFD147),
  'Core':        Color(0xFF4ECDC4),
  'Push':        Color(0xFFFF6B6B),
  'Pull':        Color(0xFF47B4FF),
  'Full Body':   Color(0xFFFF8EC8),
  'Cardio':      Color(0xFFFF8EC8),
};

class _MuscleChip extends StatelessWidget {
  final String label;
  const _MuscleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _muscleColors[label] ?? IronMindTheme.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
        style: GoogleFonts.dmSans(
          color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _PRRow extends StatelessWidget {
  final String exercise;
  final double weight;
  final int reps;
  final bool isLast;

  const _PRRow({
    required this.exercise, required this.weight,
    required this.reps,     required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: IronMindTheme.border)),
      ),
      child: Row(children: [
        const Icon(Icons.emoji_events_outlined,
          color: IronMindTheme.green, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(exercise,
            style: GoogleFonts.dmSans(
              color: IronMindTheme.textPrimary,
              fontWeight: FontWeight.w500, fontSize: 13)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: IronMindTheme.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: IronMindTheme.green.withOpacity(0.4)),
          ),
          child: Text('${_fmt(weight)} lbs × $reps',
            style: GoogleFonts.dmMono(
              color: IronMindTheme.green, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _ExerciseSummaryCard extends StatefulWidget {
  final SummaryExercise exercise;
  const _ExerciseSummaryCard({required this.exercise});

  @override
  State<_ExerciseSummaryCard> createState() => _ExerciseSummaryCardState();
}

class _ExerciseSummaryCardState extends State<_ExerciseSummaryCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Column(
          children: [
            // Exercise header
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Expanded(
                    child: Text(ex.name,
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Text(
                    '${ex.completedSets.length} set${ex.completedSets.length == 1 ? "" : "s"}',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 10)),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: IronMindTheme.text3),
                ]),
              ),
            ),

            // Set rows
            if (_expanded) ...[
              const Divider(height: 1, color: IronMindTheme.border),
              // Column labels
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(children: [
                  SizedBox(
                    width: 32,
                    child: Text('SET',
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                  ),
                  Expanded(
                    child: Text('WEIGHT',
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                  ),
                  Text('REPS',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                ]),
              ),
              ...ex.completedSets.asMap().entries.map((entry) {
                final i   = entry.key;
                final set = entry.value;
                return _SetRow(
                  number: i + 1,
                  weight: set.weight,
                  reps:   set.reps,
                  isPR:   set.isPR,
                );
              }),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int number;
  final double weight;
  final int reps;
  final bool isPR;

  const _SetRow({
    required this.number, required this.weight,
    required this.reps,   required this.isPR,
  });

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(children: [
        SizedBox(
          width: 32,
          child: Text('$number',
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text2, fontSize: 12)),
        ),
        Expanded(
          child: Row(children: [
            Text(
              weight > 0 ? '${_fmt(weight)} lbs' : 'BW',
              style: GoogleFonts.dmMono(
                color: IronMindTheme.textPrimary, fontSize: 13,
                fontWeight: FontWeight.w600)),
            if (isPR) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: IronMindTheme.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: IronMindTheme.green.withOpacity(0.4)),
                ),
                child: Text('PR',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.green, fontSize: 9,
                    fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
        Text('$reps',
          style: GoogleFonts.dmMono(
            color: IronMindTheme.textPrimary, fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
