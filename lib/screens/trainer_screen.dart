import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../core/theme/ironmind_theme.dart';
import '../shared/widgets/common.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  // Setup state
  String _goal         = '';
  int    _daysPerWeek  = 4;
  int    _sessionMins  = 60;
  String _level        = 'Intermediate';

  // Generation state
  bool                   _generating = false;
  Map<String, dynamic>?  _program;
  String?                _error;

  static const _prefsKey = 'ai_coach_program';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && mounted) {
      setState(() => _program = Map<String, dynamic>.from(jsonDecode(raw)));
    }
  }

  Future<void> _saveProgram(Map<String, dynamic> p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(p));
  }

  void _updateDay(int index, Map<String, dynamic> updatedDay) {
    if (_program == null) return;
    final days = List<dynamic>.from(_program!['days'] as List);
    days[index] = updatedDay;
    final updated = {..._program!, 'days': days};
    setState(() => _program = updated);
    _saveProgram(updated);
  }

  Future<void> _generate() async {
    if (_goal.isEmpty) {
      setState(() => _error = 'Choose a goal first.');
      return;
    }
    setState(() { _generating = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800)); // brief UX beat

    final program = _generateProgram(
      goal:           _goal,
      daysPerWeek:    _daysPerWeek,
      sessionMinutes: _sessionMins,
      level:          _level,
    );
    await _saveProgram(program);
    if (mounted) setState(() { _program = program; _generating = false; });
  }

  Future<void> _saveAllAsRoutines() async {
    final days = (_program?['days'] as List? ?? []);
    final base  = _program?['goalLabel'] as String? ?? 'Program';
    int saved = 0;
    for (final day in days) {
      final exercises = (day['exercises'] as List? ?? [])
          .map((e) {
            final name = e['name'] as String? ?? '';
            final sets = e['sets']?.toString() ?? '3';
            final reps = e['reps']?.toString() ?? '10';
            return '$name — ${sets}×$reps';
          })
          .toList();
      await ApiService.saveRoutine({
        'name':      '$base — ${day['label']}',
        'exercises': exercises,
      });
      saved++;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$saved routines saved to Workout tab.',
          style: GoogleFonts.dmSans(fontSize: 13)),
        backgroundColor: IronMindTheme.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
    }
  }

  void _startDay(Map<String, dynamic> day) {
    // Load this day's exercises into a new workout session via the workout tab
    // For now show a summary sheet — deep linking into an active workout
    // requires a callback up to MainShell (future enhancement).
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: IronMindTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _DayDetailSheet(day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: 'AI Coach',
        connected: true,
        actions: [
          if (_program != null)
            TextButton(
              onPressed: () => setState(() { _program = null; _goal = ''; }),
              child: Text('New',
                style: GoogleFonts.dmSans(color: IronMindTheme.accent, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _generating
          ? _buildGenerating()
          : _program != null
              ? _buildProgram()
              : _buildSetup(),
    );
  }

  // ── Generating state ───────────────────────────────────────────────────────

  Widget _buildGenerating() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: IronMindTheme.accent),
          const SizedBox(height: 20),
          Text('Building your program…',
            style: GoogleFonts.bebasNeue(
              color: IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text('Tailored to your goal and schedule.',
            style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Setup ──────────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Build Your Program',
            style: GoogleFonts.bebasNeue(
              color: IronMindTheme.textPrimary, fontSize: 30, letterSpacing: 2)),
          Text('Answer a few questions and get a personalized training plan.',
            style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13, height: 1.4)),
          const SizedBox(height: 28),

          // Goal
          const SectionHeader(title: 'What\'s your goal?'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            children: _goals.map((g) => _GoalCard(
              goal: g,
              selected: _goal == g.id,
              onTap: () => setState(() => _goal = g.id),
            )).toList(),
          ),
          const SizedBox(height: 28),

          // Days per week
          const SectionHeader(title: 'Days per week'),
          const SizedBox(height: 12),
          _ChipRow(
            options: const ['3', '4', '5', '6'],
            selected: '$_daysPerWeek',
            onSelect: (v) => setState(() => _daysPerWeek = int.parse(v)),
          ),
          const SizedBox(height: 24),

          // Session length
          const SectionHeader(title: 'Session length'),
          const SizedBox(height: 12),
          _ChipRow(
            options: const ['45 min', '60 min', '75 min', '90 min'],
            selected: '$_sessionMins min',
            onSelect: (v) => setState(() => _sessionMins = int.parse(v.split(' ')[0])),
          ),
          const SizedBox(height: 24),

          // Level
          const SectionHeader(title: 'Experience level'),
          const SizedBox(height: 12),
          _ChipRow(
            options: const ['Beginner', 'Intermediate', 'Advanced'],
            selected: _level,
            onSelect: (v) => setState(() => _level = v),
          ),
          const SizedBox(height: 32),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Text(_error!,
                style: GoogleFonts.dmSans(color: Colors.redAccent, fontSize: 12)),
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text('Generate Program',
                style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.3)),
              onPressed: _generate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Generated program ──────────────────────────────────────────────────────

  Widget _buildProgram() {
    final p    = _program!;
    final days = (p['days'] as List? ?? []).cast<Map<String, dynamic>>();
    final goalLabel = p['goalLabel'] as String? ?? '';
    final daysNum   = p['daysPerWeek'] as int? ?? _daysPerWeek;
    final mins      = p['sessionLength'] as int? ?? _sessionMins;
    final lvl       = p['level'] as String? ?? _level;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IronMindTheme.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IronMindTheme.accent.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: IronMindTheme.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goalLabel,
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 1.5)),
                  Text('$daysNum days/week · $mins min sessions · $lvl',
                    style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        const SectionHeader(title: 'Weekly Schedule'),
        const SizedBox(height: 10),

        // Day cards
        ...days.asMap().entries.map((entry) =>
          _DayCard(
            dayNumber: entry.key + 1,
            day:       entry.value,
            onStart:   () => _startDay(entry.value),
            onChanged: (updated) => _updateDay(entry.key, updated),
          ),
        ),
        const SizedBox(height: 24),

        // Save as routines
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text('Save All Days as Workout Routines',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: _saveAllAsRoutines,
            style: OutlinedButton.styleFrom(
              foregroundColor: IronMindTheme.blue,
              side: BorderSide(color: IronMindTheme.blue.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: Text('Regenerate',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
            onPressed: _generate,
            style: TextButton.styleFrom(foregroundColor: IronMindTheme.text2),
          ),
        ),
      ],
    );
  }
}

// ── Goal definitions ──────────────────────────────────────────────────────────

class _GoalDef {
  final String id;
  final String label;
  final String emoji;
  final String subtitle;
  final Color  color;
  const _GoalDef(this.id, this.label, this.emoji, this.subtitle, this.color);
}

const _goals = [
  _GoalDef('muscle',   'Build Muscle',    '💪', 'Hypertrophy focus',      Color(0xFFFF6B6B)),
  _GoalDef('strength', 'Gain Strength',   '🏋️', 'Heavy compounds',        Color(0xFF47B4FF)),
  _GoalDef('fat_loss', 'Lose Weight',     '🔥', 'Burn fat, keep muscle',  Color(0xFFFFB347)),
  _GoalDef('athletic', 'Athletic',        '⚡', 'Power & conditioning',   Color(0xFF9B8AFB)),
  _GoalDef('general',  'General Fitness', '🎯', 'Balanced approach',      Color(0xFF47FF8A)),
];

class _GoalCard extends StatelessWidget {
  final _GoalDef   goal;
  final bool       selected;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? goal.color.withOpacity(0.12) : IronMindTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? goal.color.withOpacity(0.6) : IronMindTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Text(goal.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(goal.label,
                  style: GoogleFonts.dmSans(
                    color: selected ? goal.color : IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
                Text(goal.subtitle,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.text3, fontSize: 9)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final String       selected;
  final ValueChanged<String> onSelect;
  const _ChipRow({required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: options.map((o) {
      final sel = o == selected;
      return GestureDetector(
        onTap: () => onSelect(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? IronMindTheme.accent.withOpacity(0.12) : IronMindTheme.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: sel ? IronMindTheme.accent.withOpacity(0.6) : IronMindTheme.border,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Text(o,
            style: GoogleFonts.dmSans(
              color: sel ? IronMindTheme.accent : IronMindTheme.text2,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13)),
        ),
      );
    }).toList(),
  );
}

// ── Day card ──────────────────────────────────────────────────────────────────

class _DayCard extends StatefulWidget {
  final int dayNumber;
  final Map<String, dynamic> day;
  final VoidCallback onStart;
  final void Function(Map<String, dynamic> updatedDay) onChanged;

  const _DayCard({
    required this.dayNumber,
    required this.day,
    required this.onStart,
    required this.onChanged,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  bool _expanded = false;
  late List<Map<String, dynamic>> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = (widget.day['exercises'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _swapExercise(int index) async {
    final current     = _exercises[index]['name'] as String? ?? '';
    final alternatives = _alternativesFor(current);
    if (alternatives.isEmpty) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: IronMindTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SwapExerciseSheet(
        current:      current,
        alternatives: alternatives,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _exercises[index] = {
        ..._exercises[index],
        'name': picked,
      };
    });

    final updatedDay = {
      ...widget.day,
      'exercises': _exercises,
    };
    widget.onChanged(updatedDay);
  }

  @override
  Widget build(BuildContext context) {
    final label  = widget.day['label'] as String? ?? 'Day ${widget.dayNumber}';
    final isRest = widget.day['rest'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: isRest ? null : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: isRest
                          ? IronMindTheme.surface2
                          : IronMindTheme.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isRest
                            ? IronMindTheme.border
                            : IronMindTheme.accent.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text('${widget.dayNumber}',
                        style: GoogleFonts.bebasNeue(
                          color: isRest ? IronMindTheme.text3 : IronMindTheme.accent,
                          fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                          style: GoogleFonts.dmSans(
                            color: isRest ? IronMindTheme.text2 : IronMindTheme.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                        if (!isRest)
                          Text('${_exercises.length} exercises',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.text3, fontSize: 9)),
                      ],
                    ),
                  ),
                  if (!isRest) ...[
                    GestureDetector(
                      onTap: widget.onStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: IronMindTheme.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: IronMindTheme.accent.withOpacity(0.4)),
                        ),
                        child: Text('VIEW',
                          style: GoogleFonts.dmMono(
                            color: IronMindTheme.accent, fontSize: 9, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: IronMindTheme.text3),
                  ],
                ]),
              ),
            ),

            // Exercise list
            if (_expanded && !isRest) ...[
              const Divider(height: 1, color: IronMindTheme.border),
              ..._exercises.asMap().entries.map((entry) {
                final i  = entry.key;
                final ex = entry.value;
                final hasAlts = _alternativesFor(ex['name'] as String? ?? '').isNotEmpty;
                return Container(
                  decoration: i < _exercises.length - 1
                      ? const BoxDecoration(
                          border: Border(bottom: BorderSide(color: IronMindTheme.border)))
                      : null,
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex['name'] as String? ?? '',
                            style: GoogleFonts.dmSans(
                              color: IronMindTheme.textPrimary,
                              fontWeight: FontWeight.w500, fontSize: 13)),
                          Text(
                            '${ex['sets']} sets · ${ex['reps']} reps · ${ex['rest']}',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.text3, fontSize: 10)),
                        ],
                      ),
                    ),
                    if (hasAlts)
                      GestureDetector(
                        onTap: () => _swapExercise(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: IronMindTheme.surface2,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: IronMindTheme.border),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.swap_horiz,
                              size: 12, color: IronMindTheme.text2),
                            const SizedBox(width: 3),
                            Text('Swap',
                              style: GoogleFonts.dmSans(
                                color: IronMindTheme.text2, fontSize: 10,
                                fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ),
                  ]),
                );
              }),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Swap exercise sheet ───────────────────────────────────────────────────────

class _SwapExerciseSheet extends StatelessWidget {
  final String       current;
  final List<String> alternatives;

  const _SwapExerciseSheet({required this.current, required this.alternatives});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SWAP EXERCISE',
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(current,
            style: GoogleFonts.bebasNeue(
              color: IronMindTheme.text2, fontSize: 18, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text('Choose a replacement:',
            style: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 12)),
          const SizedBox(height: 14),
          ...alternatives.map((alt) => GestureDetector(
            onTap: () => Navigator.pop(context, alt),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: IronMindTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IronMindTheme.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(alt,
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.textPrimary,
                      fontWeight: FontWeight.w500, fontSize: 13)),
                ),
                const Icon(Icons.arrow_forward_ios,
                  size: 12, color: IronMindTheme.text3),
              ]),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Day detail sheet ──────────────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  final Map<String, dynamic> day;
  const _DayDetailSheet({required this.day});

  @override
  Widget build(BuildContext context) {
    final label     = day['label'] as String? ?? 'Workout';
    final exercises = (day['exercises'] as List? ?? []).cast<Map<String, dynamic>>();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: IronMindTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: IronMindTheme.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(label,
                  style: GoogleFonts.bebasNeue(
                    color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('${exercises.length} exercises — tap Workout tab to start',
                  style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12)),
                const SizedBox(height: 16),

                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(children: [
                    Expanded(child: Text('EXERCISE',
                      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1))),
                    Text('SETS×REPS',
                      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                    const SizedBox(width: 12),
                    Text('REST',
                      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                  ]),
                ),
                const Divider(color: IronMindTheme.border),

                ...exercises.asMap().entries.map((entry) {
                  final ex     = entry.value;
                  final isLast = entry.key == exercises.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: isLast ? null : const Border(
                        bottom: BorderSide(color: IronMindTheme.border))),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex['name'] as String? ?? '',
                              style: GoogleFonts.dmSans(
                                color: IronMindTheme.textPrimary,
                                fontWeight: FontWeight.w500, fontSize: 13)),
                            if ((ex['note'] as String? ?? '').isNotEmpty)
                              Text(ex['note'] as String,
                                style: GoogleFonts.dmSans(
                                  color: IronMindTheme.text3, fontSize: 10)),
                          ],
                        ),
                      ),
                      Text('${ex['sets']}×${ex['reps']}',
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.accent, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 36,
                        child: Text(ex['rest'] as String? ?? '',
                          style: GoogleFonts.dmMono(
                            color: IronMindTheme.text3, fontSize: 10)),
                      ),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Program generator ─────────────────────────────────────────────────────────

Map<String, dynamic> _generateProgram({
  required String goal,
  required int daysPerWeek,
  required int sessionMinutes,
  required String level,
}) {
  final goalDef = _goals.firstWhere((g) => g.id == goal);
  final split   = _selectSplit(goal, daysPerWeek);
  final days    = split.map((dayTemplate) {
    if (dayTemplate['rest'] == true) return dayTemplate;
    final exercises = _fillExercises(
      muscles:        (dayTemplate['muscles'] as List).cast<String>(),
      goal:           goal,
      level:          level,
      sessionMinutes: sessionMinutes,
    );
    return {
      'label':     dayTemplate['label'],
      'exercises': exercises,
    };
  }).toList();

  return {
    'goal':          goal,
    'goalLabel':     goalDef.label,
    'daysPerWeek':   daysPerWeek,
    'sessionLength': sessionMinutes,
    'level':         level,
    'createdAt':     DateTime.now().toIso8601String(),
    'days':          days,
  };
}

// ── Split selector ────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _selectSplit(String goal, int days) {
  switch (goal) {
    case 'muscle':  return _muscleSplit(days);
    case 'strength': return _strengthSplit(days);
    case 'fat_loss': return _fatLossSplit(days);
    case 'athletic': return _athleticSplit(days);
    default:         return _generalSplit(days);
  }
}

List<Map<String, dynamic>> _muscleSplit(int days) {
  switch (days) {
    case 3: return [
      _day('Push — Chest & Triceps', ['chest','triceps','shoulders']),
      _day('Pull — Back & Biceps',   ['back','biceps']),
      _day('Legs & Core',            ['quads','hamstrings','glutes','core']),
    ];
    case 4: return [
      _day('Upper A — Chest & Back',     ['chest','back']),
      _day('Lower A — Quads & Glutes',   ['quads','glutes','core']),
      _day('Upper B — Shoulders & Arms', ['shoulders','biceps','triceps']),
      _day('Lower B — Hamstrings & Calves', ['hamstrings','calves']),
    ];
    case 5: return [
      _day('Chest & Triceps',    ['chest','triceps']),
      _day('Back & Biceps',      ['back','biceps']),
      _day('Legs',               ['quads','hamstrings','glutes']),
      _day('Shoulders & Core',   ['shoulders','core']),
      _day('Arms & Weak Points', ['biceps','triceps','forearms']),
    ];
    default: return [
      _day('Push A — Chest focus',      ['chest','triceps','shoulders']),
      _day('Pull A — Back focus',       ['back','biceps']),
      _day('Legs A — Quad focus',       ['quads','glutes','core']),
      _day('Push B — Shoulder focus',   ['shoulders','chest','triceps']),
      _day('Pull B — Bicep focus',      ['biceps','back']),
      _day('Legs B — Hamstring focus',  ['hamstrings','calves','core']),
    ];
  }
}

List<Map<String, dynamic>> _strengthSplit(int days) {
  switch (days) {
    case 3: return [
      _day('Squat Day',    ['quads','hamstrings','core']),
      _day('Bench Day',    ['chest','triceps','shoulders']),
      _day('Deadlift Day', ['back','hamstrings','core']),
    ];
    case 4: return [
      _day('Squat & Accessories',    ['quads','hamstrings','core']),
      _day('Bench & Upper Push',     ['chest','triceps','shoulders']),
      _day('Deadlift & Accessories', ['back','hamstrings','glutes']),
      _day('OHP & Upper Pull',       ['shoulders','back','biceps']),
    ];
    case 5: return [
      _day('Squat — Heavy',          ['quads','core']),
      _day('Bench — Heavy',          ['chest','triceps']),
      _day('Deadlift — Heavy',       ['back','hamstrings']),
      _day('OHP + Accessory Upper',  ['shoulders','biceps','triceps']),
      _day('Squat + Accessory Lower',['quads','hamstrings','calves']),
    ];
    default: return [
      _day('Squat Heavy',     ['quads','hamstrings','core']),
      _day('Bench Heavy',     ['chest','triceps','shoulders']),
      _day('Deadlift Heavy',  ['back','hamstrings','glutes']),
      _day('OHP Heavy',       ['shoulders','triceps','core']),
      _day('Squat Volume',    ['quads','calves']),
      _day('Bench Volume',    ['chest','biceps','back']),
    ];
  }
}

List<Map<String, dynamic>> _fatLossSplit(int days) {
  switch (days) {
    case 3: return [
      _day('Full Body A — Push bias',  ['chest','shoulders','quads','core']),
      _day('Full Body B — Pull bias',  ['back','biceps','hamstrings','core']),
      _day('Full Body C — Leg bias',   ['quads','hamstrings','glutes','core']),
    ];
    case 4: return [
      _day('Upper — Push',     ['chest','shoulders','triceps']),
      _day('Lower — Quad',     ['quads','glutes','core']),
      _day('Upper — Pull',     ['back','biceps','core']),
      _day('Lower — Hamstring',['hamstrings','calves','core']),
    ];
    case 5: return [
      _day('Full Body A',     ['chest','back','quads','core']),
      _day('Upper Circuit',   ['shoulders','biceps','triceps','chest']),
      _day('Lower Circuit',   ['quads','hamstrings','glutes','calves']),
      _day('Full Body B',     ['back','chest','hamstrings','core']),
      _day('Core & Cardio',   ['core','calves']),
    ];
    default: return [
      _day('Upper A',         ['chest','back','shoulders']),
      _day('Lower A',         ['quads','hamstrings','glutes']),
      _day('Full Body',       ['chest','back','quads','core']),
      _day('Upper B',         ['shoulders','biceps','triceps']),
      _day('Lower B',         ['hamstrings','calves','glutes']),
      _day('Core & Conditioning', ['core','calves']),
    ];
  }
}

List<Map<String, dynamic>> _athleticSplit(int days) {
  switch (days) {
    case 3: return [
      _day('Power & Lower Body',     ['quads','hamstrings','glutes','core']),
      _day('Strength Upper',         ['chest','back','shoulders']),
      _day('Conditioning & Core',    ['core','calves','hamstrings']),
    ];
    case 4: return [
      _day('Lower Power',            ['quads','hamstrings','glutes']),
      _day('Upper Strength',         ['chest','back','shoulders']),
      _day('Lower Strength',         ['hamstrings','quads','calves','core']),
      _day('Upper Power & Core',     ['shoulders','back','chest','core']),
    ];
    default: return [
      _day('Lower Power',            ['quads','hamstrings','glutes']),
      _day('Upper Strength — Push',  ['chest','shoulders','triceps']),
      _day('Lower Strength',         ['hamstrings','quads','calves']),
      _day('Upper Strength — Pull',  ['back','biceps','core']),
      _day('Full Body Power',        ['quads','chest','back','core']),
    ];
  }
}

List<Map<String, dynamic>> _generalSplit(int days) {
  switch (days) {
    case 3: return [
      _day('Full Body A', ['chest','back','quads','core']),
      _day('Full Body B', ['shoulders','back','hamstrings','core']),
      _day('Full Body C', ['chest','quads','glutes','core']),
    ];
    case 4: return [
      _day('Upper A — Push heavy', ['chest','shoulders','triceps']),
      _day('Lower A',              ['quads','hamstrings','glutes']),
      _day('Upper B — Pull heavy', ['back','biceps','core']),
      _day('Lower B',              ['hamstrings','quads','calves']),
    ];
    default: return [
      _day('Chest & Triceps',    ['chest','triceps']),
      _day('Back & Biceps',      ['back','biceps']),
      _day('Legs & Glutes',      ['quads','hamstrings','glutes']),
      _day('Shoulders & Core',   ['shoulders','core']),
      _day('Full Body & Cardio', ['chest','back','quads','core']),
    ];
  }
}

Map<String, dynamic> _day(String label, List<String> muscles) =>
    {'label': label, 'muscles': muscles};

// ── Exercise filler ───────────────────────────────────────────────────────────

List<Map<String, dynamic>> _fillExercises({
  required List<String> muscles,
  required String goal,
  required String level,
  required int sessionMinutes,
}) {
  // How many exercises to include based on session length
  final maxExercises = sessionMinutes <= 45 ? 4 : sessionMinutes <= 60 ? 5 : 6;
  final exercises = <Map<String, dynamic>>[];

  // Sets/reps/rest by goal
  final _SetScheme scheme = _schemeFor(goal, level);

  // Pick exercises per muscle group
  for (final muscle in muscles) {
    if (exercises.length >= maxExercises) break;
    final pool = _db[muscle] ?? [];
    if (pool.isEmpty) continue;
    final picked = _pickExercise(pool, exercises.map((e) => e['name'] as String).toSet());
    if (picked == null) continue;
    final overrides = scheme.overrideFor(muscle);
    exercises.add({
      'name': picked,
      'sets': overrides?.sets ?? scheme.sets,
      'reps': overrides?.reps ?? scheme.reps,
      'rest': overrides?.rest ?? scheme.rest,
      'note': '',
    });
  }

  return exercises;
}

String? _pickExercise(List<String> pool, Set<String> used) {
  final available = pool.where((e) => !used.contains(e)).toList();
  if (available.isEmpty) return pool.first;
  final rng = math.Random();
  return available[rng.nextInt(available.length)];
}

// ── Set schemes ───────────────────────────────────────────────────────────────

class _SetScheme {
  final int    sets;
  final String reps;
  final String rest;
  final Map<String, _SetScheme> muscleOverrides;

  const _SetScheme({
    required this.sets,
    required this.reps,
    required this.rest,
    this.muscleOverrides = const {},
  });

  _SetScheme? overrideFor(String muscle) => muscleOverrides[muscle];
}

_SetScheme _schemeFor(String goal, String level) {
  final isAdv  = level == 'Advanced';
  final isBeg  = level == 'Beginner';

  switch (goal) {
    case 'strength':
      return _SetScheme(
        sets: isAdv ? 5 : 4,
        reps: isBeg ? '5' : '3-5',
        rest: '3-4 min',
        muscleOverrides: {
          'core':    _SetScheme(sets: 3, reps: '12-15', rest: '60s'),
          'calves':  _SetScheme(sets: 3, reps: '12-15', rest: '60s'),
          'biceps':  _SetScheme(sets: 3, reps: '8-10',  rest: '90s'),
          'triceps': _SetScheme(sets: 3, reps: '8-10',  rest: '90s'),
        },
      );
    case 'fat_loss':
      return _SetScheme(
        sets: 3,
        reps: '12-15',
        rest: '45s',
        muscleOverrides: {
          'core': _SetScheme(sets: 3, reps: '15-20', rest: '30s'),
        },
      );
    case 'athletic':
      return _SetScheme(
        sets: isAdv ? 5 : 4,
        reps: '4-6',
        rest: '2 min',
        muscleOverrides: {
          'core':   _SetScheme(sets: 3, reps: '12-15', rest: '60s'),
          'calves': _SetScheme(sets: 3, reps: '12',    rest: '60s'),
        },
      );
    default: // muscle + general
      return _SetScheme(
        sets: isAdv ? 4 : 3,
        reps: isBeg ? '10-12' : isAdv ? '8-12' : '8-12',
        rest: '90s',
        muscleOverrides: {
          'core':   _SetScheme(sets: 3, reps: '12-15', rest: '60s'),
          'calves': _SetScheme(sets: 4, reps: '15-20', rest: '60s'),
        },
      );
  }
}

// ── Reverse-lookup: exercise name → muscle key ────────────────────────────────

String? _muscleForExercise(String name) {
  for (final entry in _db.entries) {
    if (entry.value.any((e) => e.toLowerCase() == name.toLowerCase())) {
      return entry.key;
    }
  }
  return null;
}

List<String> _alternativesFor(String exerciseName) {
  final muscle = _muscleForExercise(exerciseName);
  if (muscle == null) return [];
  return (_db[muscle] ?? [])
      .where((e) => e.toLowerCase() != exerciseName.toLowerCase())
      .toList();
}

// ── Exercise database ─────────────────────────────────────────────────────────

const _db = <String, List<String>>{
  'chest': [
    'Barbell Bench Press',
    'Incline Barbell Bench Press',
    'Dumbbell Bench Press',
    'Incline Dumbbell Press',
    'Decline Bench Press',
    'Cable Fly',
    'Dumbbell Fly',
    'Push-Up',
    'Weighted Dip',
    'Pec Deck Machine',
  ],
  'back': [
    'Barbell Deadlift',
    'Barbell Row',
    'Dumbbell Row',
    'Lat Pulldown',
    'Pull-Up',
    'Seated Cable Row',
    'T-Bar Row',
    'Face Pull',
    'Rack Pull',
    'Chest-Supported Row',
  ],
  'shoulders': [
    'Overhead Press (Barbell)',
    'Dumbbell Shoulder Press',
    'Lateral Raise',
    'Cable Lateral Raise',
    'Front Raise',
    'Arnold Press',
    'Rear Delt Fly',
    'Upright Row',
    'Machine Shoulder Press',
    'Cable Face Pull',
  ],
  'biceps': [
    'Barbell Curl',
    'Dumbbell Curl',
    'Hammer Curl',
    'Incline Dumbbell Curl',
    'Preacher Curl',
    'Cable Curl',
    'Concentration Curl',
    'EZ-Bar Curl',
  ],
  'triceps': [
    'Tricep Pushdown (Cable)',
    'Skull Crusher',
    'Overhead Tricep Extension',
    'Close-Grip Bench Press',
    'Dumbbell Kickback',
    'Dip (Tricep-focused)',
    'Cable Overhead Extension',
    'Machine Tricep Dip',
  ],
  'forearms': [
    'Wrist Curl',
    'Reverse Curl',
    'Farmer\'s Carry',
    'Dead Hang',
    'Wrist Roller',
  ],
  'quads': [
    'Barbell Squat',
    'Front Squat',
    'Leg Press',
    'Hack Squat',
    'Leg Extension',
    'Bulgarian Split Squat',
    'Lunge',
    'Step-Up',
    'Goblet Squat',
  ],
  'hamstrings': [
    'Romanian Deadlift',
    'Leg Curl (Lying)',
    'Leg Curl (Seated)',
    'Nordic Curl',
    'Stiff-Leg Deadlift',
    'Good Morning',
    'Swiss Ball Leg Curl',
  ],
  'glutes': [
    'Hip Thrust (Barbell)',
    'Glute Bridge',
    'Bulgarian Split Squat',
    'Cable Kickback',
    'Sumo Deadlift',
    'Romanian Deadlift',
    'Hip Abduction Machine',
  ],
  'calves': [
    'Standing Calf Raise',
    'Seated Calf Raise',
    'Leg Press Calf Raise',
    'Donkey Calf Raise',
    'Single-Leg Calf Raise',
  ],
  'core': [
    'Plank',
    'Ab Wheel Rollout',
    'Cable Crunch',
    'Hanging Leg Raise',
    'Russian Twist',
    'Dead Bug',
    'Pallof Press',
    'Decline Sit-Up',
    'Dragon Flag',
    'L-Sit',
  ],
};
