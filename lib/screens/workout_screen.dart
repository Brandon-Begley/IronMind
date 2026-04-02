import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'exercise_library_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

class WorkoutScreen extends StatefulWidget {
  final bool connected;
  const WorkoutScreen({super.key, this.connected = false});
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _workoutActive = false;
  int _elapsed = 0;
  Timer? _timer;
  int _routineRefreshTick = 0;
  String _workoutName = '';
  String _workoutFocus = '';
  String _sessionPlan = '';
  final List<_ExerciseEntry> _exercises = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerLabel {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _beginWorkout({
    String name = '',
    String focus = '',
    String sessionPlan = '',
    List<_ExerciseEntry>? exercises,
  }) {
    _timer?.cancel();
    final nextExercises = exercises == null || exercises.isEmpty
        ? <_ExerciseEntry>[_ExerciseEntry()]
        : exercises;
    setState(() {
      _workoutActive = true;
      _elapsed = 0;
      _workoutName = name;
      _workoutFocus = focus;
      _sessionPlan = sessionPlan;
      _exercises
        ..clear()
        ..addAll(nextExercises);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  void _startEmptyWorkout() {
    _beginWorkout();
  }

  void _showStartWorkoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'START WORKOUT',
              style: GoogleFonts.bebasNeue(
                color: IronMindTheme.textPrimary,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kick off a blank session or pull your first exercise from the library.',
              style: GoogleFonts.dmSans(
                color: IronMindTheme.text2,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startEmptyWorkout();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: IronMindTheme.textPrimary,
                  side: BorderSide(color: IronMindTheme.border2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'START BLANK SESSION',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 18,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openExerciseLibrary();
                },
                child: Text(
                  'PICK FROM EXERCISE LIBRARY',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 18,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startRoutine(Map<String, dynamic> routine) {
    final exerciseNames = (routine['exercises'] as List? ?? [])
        .whereType<String>()
        .where((exercise) => exercise.trim().isNotEmpty)
        .map((exercise) => _ExerciseEntry(name: exercise))
        .toList();
    _beginWorkout(
      name: routine['name']?.toString() ?? '',
      focus: (routine['primary'] as List?)?.join(', ') ?? '',
      exercises: exerciseNames,
    );
  }

  void _addExerciseFromLibrary(String exerciseName) {
    if (_workoutActive) {
      setState(() => _exercises.add(_ExerciseEntry(name: exerciseName)));
      return;
    }
    _beginWorkout(exercises: [_ExerciseEntry(name: exerciseName)]);
  }

  void _openExerciseLibrary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ExerciseLibraryScreen(onAddToWorkout: _addExerciseFromLibrary),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadAiProfile() async {
    return ApiService.getLifterProfile();
  }

  String _buildAiPrompt(String base, Map<String, dynamic> profile) {
    final parts = <String>[];
    if ((profile['bodyweight'] ?? '').toString().isNotEmpty)
      parts.add('Bodyweight: ${profile['bodyweight']}lb');
    if ((profile['goalWeight'] ?? '').toString().isNotEmpty)
      parts.add('Target weight: ${profile['goalWeight']}lb');
    if ((profile['squat'] ?? '').toString().isNotEmpty)
      parts.add('Squat 1RM: ${profile['squat']}lb');
    if ((profile['bench'] ?? '').toString().isNotEmpty)
      parts.add('Bench 1RM: ${profile['bench']}lb');
    if ((profile['deadlift'] ?? '').toString().isNotEmpty)
      parts.add('Deadlift 1RM: ${profile['deadlift']}lb');
    if ((profile['ohp'] ?? '').toString().isNotEmpty)
      parts.add('OHP 1RM: ${profile['ohp']}lb');
    parts.add('Experience: ${profile['experience'] ?? 'intermediate'}');
    parts.add('Goal: ${profile['goal'] ?? 'general fitness'}');
    final equipment = List<String>.from(profile['equipment'] ?? const []);
    if (equipment.isNotEmpty) parts.add('Equipment: ${equipment.join(', ')}');
    return '$base\n\nAthlete profile: ${parts.join(' | ')}';
  }

  String _deriveSessionName(String prompt) {
    final normalized = prompt.trim();
    if (normalized.isEmpty) return 'AI Session';
    return normalized.length <= 32
        ? normalized
        : '${normalized.substring(0, 32).trim()}...';
  }

  void _showAiWorkoutPrompt() async {
    final profile = await _loadAiProfile();
    if (!mounted) return;

    final promptController = TextEditingController();
    const quickPrompts = <String, String>{
      'Push': 'Build a push workout focused on chest, shoulders, and triceps.',
      'Pull': 'Build a pull workout focused on back, rear delts, and biceps.',
      'Legs':
          'Build a lower-body workout focused on squat strength and leg volume.',
      'Upper':
          'Build an upper-body session focused on strength and hypertrophy balance.',
      'Full Body':
          'Build a full body session that fits today and balances fatigue.',
      'Recovery':
          'Build a lighter recovery-focused workout with technique and accessory work.',
    };
    String output = '';
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> generate() async {
            if (promptController.text.trim().isEmpty) return;
            setModalState(() {
              loading = true;
              output = '';
            });
            try {
              final result = await ApiService.generateWorkout(
                _buildAiPrompt(promptController.text.trim(), profile),
              );
              setModalState(() => output = result);
            } catch (_) {
              setModalState(
                () => output =
                    'Could not generate a workout right now. Try again in a moment.',
              );
            } finally {
              setModalState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI WORKOUT PROMPT',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Describe what you want to train today and IronMind will build a session around that target.',
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.text2,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickPrompts.entries
                        .map(
                          (entry) => GestureDetector(
                            onTap: () => setModalState(
                              () => promptController.text = entry.value,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: IronMindTheme.surface2,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: IronMindTheme.border2,
                                ),
                              ),
                              child: Text(
                                entry.key,
                                style: GoogleFonts.dmMono(
                                  color: IronMindTheme.text2,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptController,
                    maxLines: 4,
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Session Target',
                      hintText:
                          'Example: Upper body strength with extra back volume and a short finisher',
                    ),
                  ),
                  const SizedBox(height: 14),
                  IronButton(
                    label: 'GENERATE WORKOUT',
                    onPressed: generate,
                    loading: loading,
                  ),
                  if (output.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    IronCard2(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IronLabel('Generated Session'),
                          const SizedBox(height: 10),
                          SelectableText(
                            output,
                            style: GoogleFonts.dmSans(
                              color: IronMindTheme.textPrimary,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 14),
                          IronButton(
                            label: 'START THIS SESSION',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _beginWorkout(
                                name: _deriveSessionName(promptController.text),
                                focus: promptController.text.trim(),
                                sessionPlan: output,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateRoutineSheet() {
    _showRoutineBuilderSheet(
      context,
      onCreated: () => setState(() => _routineRefreshTick++),
    );
  }

  void _finishWorkout() async {
    _timer?.cancel();
    final data = _exercises
        .where((e) => e.name.isNotEmpty)
        .map(
          (e) => {
            'name': e.name,
            'sets': e.sets.length,
            'reps': e.sets.isNotEmpty ? e.sets.last.reps : 0,
            'weight': e.sets.isNotEmpty ? e.sets.last.weight : 0,
          },
        )
        .toList();
    if (data.isNotEmpty) {
      try {
        await ApiService.saveLog({
          'date': DateTime.now().toIso8601String().split('T')[0],
          'program_name': _workoutName,
          'day_name': _workoutName.isEmpty ? 'Workout' : _workoutName,
          'focus': _workoutFocus,
          'exercises': data,
          'notes': _sessionPlan,
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Workout saved!'),
              backgroundColor: IronMindTheme.green,
            ),
          );
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server offline — workout not saved'),
              backgroundColor: IronMindTheme.orange,
            ),
          );
      }
    }
    setState(() {
      _workoutActive = false;
      _elapsed = 0;
      _exercises.clear();
      _workoutName = '';
      _workoutFocus = '';
      _sessionPlan = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: _workoutActive ? _timerLabel : 'Workout',
        connected: widget.connected,
        actions: [
          IconButton(
            tooltip: 'Exercise library',
            onPressed: _openExerciseLibrary,
            icon: const Icon(Icons.menu_book_outlined, size: 20),
            color: IronMindTheme.text2,
          ),
          IconButton(
            tooltip: 'AI session generator',
            onPressed: _showAiWorkoutPrompt,
            icon: const Icon(Icons.auto_awesome, size: 20),
            color: IronMindTheme.accent,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _workoutActive
                ? OutlinedButton(
                    onPressed: _finishWorkout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: IronMindTheme.red,
                      side: BorderSide(
                        color: IronMindTheme.red.withOpacity(0.4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'FINISH',
                      style: GoogleFonts.bebasNeue(
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: _workoutActive
          ? _ActiveWorkoutTab(
              sessionPlan: _sessionPlan,
              exercises: _exercises,
              onNameChanged: (v) => setState(() => _workoutName = v),
              onFocusChanged: (v) => setState(() => _workoutFocus = v),
              onAddExercise: () =>
                  setState(() => _exercises.add(_ExerciseEntry())),
              onUpdate: () => setState(() {}),
              onOpenOneRepMax: () => _showOneRepMaxCalculator(context),
            )
          : _WorkoutHomeTab(
              key: ValueKey('workout-log-$_routineRefreshTick'),
              onStartEmptyWorkout: _showStartWorkoutSheet,
              onCreateRoutine: _showCreateRoutineSheet,
              onStartRoutine: _startRoutine,
              onOpenAiGenerator: _showAiWorkoutPrompt,
            ),
    );
  }
}

// ── Active Workout ────────────────────────────────────────────────────────────
Future<void> _showOneRepMaxCalculator(BuildContext context) async {
  final wC = TextEditingController();
  final rC = TextEditingController();
  const formulas = {
    'Epley': 'epley',
    'Brzycki': 'brzycki',
    'McGlothin': 'mcglothin',
    'Lombardi': 'lombardi',
  };
  Map<String, int> results = {};

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        void calc() {
          final w = double.tryParse(wC.text) ?? 0;
          final r = int.tryParse(rC.text) ?? 0;
          if (w > 0 && r > 0) {
            set(() {
              results = {
                for (final entry in formulas.entries)
                  entry.key: ApiService.calculate1RM(w, r, entry.value).round(),
              };
            });
          } else {
            set(() => results = {});
          }
        }

        return Dialog(
          backgroundColor: IronMindTheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '1RM CALCULATOR',
                            style: GoogleFonts.bebasNeue(
                              color: IronMindTheme.textPrimary,
                              fontSize: 22,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                          color: IronMindTheme.text2,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wC,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Weight (lbs)',
                            ),
                            onChanged: (_) => calc(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: rC,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(labelText: 'Reps'),
                            onChanged: (_) => calc(),
                          ),
                        ),
                      ],
                    ),
                    if (results.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'ESTIMATED 1RM RANGE',
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.text3,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '~${results.values.reduce((a, b) => a > b ? a : b)}lb',
                              style: GoogleFonts.bebasNeue(
                                color: IronMindTheme.accent,
                                fontSize: 52,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              'Highest estimate from the formulas below',
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.text3,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...results.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: IronMindTheme.surface2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: IronMindTheme.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: GoogleFonts.dmSans(
                                      color: IronMindTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '~${entry.value}lb',
                                  style: GoogleFonts.dmMono(
                                    color: IronMindTheme.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _OneRepMaxBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _OneRepMaxBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10202F), Color(0xFF173C56)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IronMindTheme.accent.withOpacity(0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: IronMindTheme.accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: IronMindTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1RM CALCULATOR',
                      style: GoogleFonts.bebasNeue(
                        color: IronMindTheme.textPrimary,
                        fontSize: 19,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check your estimated max anytime while you plan or log a session.',
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.text2,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'OPEN',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiWorkoutBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _AiWorkoutBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF24111F), Color(0xFF442659)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: IronMindTheme.purple.withOpacity(0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: IronMindTheme.purple.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: IronMindTheme.purple,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI SUGGESTED WORKOUT',
                      style: GoogleFonts.bebasNeue(
                        color: IronMindTheme.textPrimary,
                        fontSize: 22,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Build a session around your goal, target muscle groups, and available equipment.',
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.text2,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrHighlight {
  final String exercise;
  final double weight;
  final int reps;
  final int estimatedOneRepMax;

  const _PrHighlight({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.estimatedOneRepMax,
  });
}

class _ActiveWorkoutTab extends StatelessWidget {
  final String sessionPlan;
  final List<_ExerciseEntry> exercises;
  final ValueChanged<String> onNameChanged, onFocusChanged;
  final VoidCallback onAddExercise, onUpdate;
  final VoidCallback? onOpenOneRepMax;
  const _ActiveWorkoutTab({
    required this.sessionPlan,
    required this.exercises,
    required this.onNameChanged,
    required this.onFocusChanged,
    required this.onAddExercise,
    required this.onUpdate,
    this.onOpenOneRepMax,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onNameChanged,
                style: GoogleFonts.dmSans(
                  color: IronMindTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  labelText: 'Workout Name',
                  hintText: 'e.g. Squat Day',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: onFocusChanged,
                style: GoogleFonts.dmSans(
                  color: IronMindTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  labelText: 'Focus',
                  hintText: 'e.g. Squat',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sessionPlan.isNotEmpty) ...[
          IronCard2(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('AI Session Plan'),
                const SizedBox(height: 8),
                SelectableText(
                  sessionPlan,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ...exercises.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ExerciseCard(
              entry: e.value,
              onUpdate: onUpdate,
              onPr: (highlight) {
                final weightLabel = highlight.weight.truncateToDouble() ==
                        highlight.weight
                    ? highlight.weight.toStringAsFixed(0)
                    : highlight.weight.toStringAsFixed(1);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'New PR: ${highlight.exercise} ${weightLabel}lb x ${highlight.reps} | e1RM ~${highlight.estimatedOneRepMax}lb',
                    ),
                    backgroundColor: IronMindTheme.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              onRemove: exercises.length > 1
                  ? () {
                      exercises.removeAt(e.key);
                      onUpdate();
                    }
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        IronButton(label: '+ ADD EXERCISE', onPressed: onAddExercise),
      ],
    ),
  );
}

class _ExerciseEntry {
  String name;
  List<_SetEntry> sets;
  _ExerciseEntry({this.name = '', List<_SetEntry>? sets})
    : sets = sets ?? [_SetEntry()];
}

class _SetEntry {
  double weight = 0;
  int reps = 0;
  bool done = false;
  bool prTracked = false;
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController repsCtrl = TextEditingController();
}

class _ExerciseCard extends StatefulWidget {
  final _ExerciseEntry entry;
  final VoidCallback onUpdate;
  final ValueChanged<_PrHighlight> onPr;
  final VoidCallback? onRemove;
  const _ExerciseCard({
    required this.entry,
    required this.onUpdate,
    required this.onPr,
    this.onRemove,
  });
  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _resting = false;

  Future<void> _handleCompletedSet(_SetEntry set) async {
    final exercise = widget.entry.name.trim();
    if (set.prTracked || exercise.isEmpty || set.weight <= 0 || set.reps <= 0) {
      return;
    }

    final isNewPr = await ApiService.checkAndSavePR(exercise, set.weight, set.reps);
    set.prTracked = true;
    if (!mounted || !isNewPr) return;

    widget.onPr(
      _PrHighlight(
        exercise: exercise,
        weight: set.weight,
        reps: set.reps,
        estimatedOneRepMax: ApiService.calculate1RM(set.weight, set.reps).round(),
      ),
    );
  }

  void _startRest(int s) {
    _restTimer?.cancel();
    setState(() {
      _resting = true;
      _restSeconds = s;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restSeconds <= 0) {
        t.cancel();
        setState(() => _resting = false);
        HapticFeedback.heavyImpact();
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return IronCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => e.name = v,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Exercise name',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.onRemove != null)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(
                    Icons.close,
                    color: IronMindTheme.text3,
                    size: 18,
                  ),
                ),
            ],
          ),
          if (_resting) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: IronMindTheme.accentDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REST',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.accent,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '${_restSeconds}s',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.accent,
                      fontSize: 22,
                      letterSpacing: 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _restTimer?.cancel();
                      setState(() => _resting = false);
                    },
                    child: const Icon(
                      Icons.close,
                      color: IronMindTheme.accent,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 28,
                child: Text(
                  'SET',
                  style: TextStyle(
                    color: IronMindTheme.text3,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PREV',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'LBS',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'REPS',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 4),
          ...e.sets.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final prev = i > 0
                ? '${e.sets[i - 1].weight.toInt()}×${e.sets[i - 1].reps}'
                : '—';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text3,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      prev,
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text3,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: s.weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmMono(
                        color: s.done
                            ? IronMindTheme.green
                            : IronMindTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.dmMono(
                          color: IronMindTheme.text3,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => s.weight = double.tryParse(v) ?? 0,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: s.repsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmMono(
                        color: s.done
                            ? IronMindTheme.green
                            : IronMindTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.dmMono(
                          color: IronMindTheme.text3,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => s.reps = int.tryParse(v) ?? 0,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      setState(() => s.done = !s.done);
                      if (s.done) {
                        HapticFeedback.mediumImpact();
                        _startRest(90);
                        if (s.weight > 0 && s.reps > 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'e1RM: ~${ApiService.calculate1RM(s.weight, s.reps).round()}lb',
                                style: GoogleFonts.dmMono(fontSize: 12),
                              ),
                              backgroundColor: IronMindTheme.surface2,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          await _handleCompletedSet(s);
                        }
                      } else {
                        s.prTracked = false;
                      }
                    },
                    child: SizedBox(
                      width: 36,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.done
                                ? IronMindTheme.green
                                : Colors.transparent,
                            border: Border.all(
                              color: s.done
                                  ? IronMindTheme.green
                                  : IronMindTheme.border2,
                              width: 1.5,
                            ),
                          ),
                          child: s.done
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 13,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => e.sets.add(_SetEntry())),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IronMindTheme.text2,
                    side: const BorderSide(color: IronMindTheme.border2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text('+ Set', style: GoogleFonts.dmMono(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showRestPicker(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: IronMindTheme.accent,
                  side: BorderSide(
                    color: IronMindTheme.accent.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Rest',
                      style: GoogleFonts.dmMono(
                        fontSize: 10,
                        color: IronMindTheme.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRestPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REST TIMER',
              style: GoogleFonts.bebasNeue(
                color: IronMindTheme.textPrimary,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [60, 90, 120, 180, 240, 300]
                  .map(
                    (s) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _startRest(s);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: IronMindTheme.surface2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: IronMindTheme.border2),
                        ),
                        child: Text(
                          s >= 60
                              ? '${s ~/ 60}m${s % 60 > 0 ? "${s % 60}s" : ""}'
                              : '${s}s',
                          style: GoogleFonts.bebasNeue(
                            color: IronMindTheme.accent,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Log History ───────────────────────────────────────────────────────────────
class _WorkoutHomeTab extends StatefulWidget {
  final VoidCallback onStartEmptyWorkout;
  final VoidCallback onCreateRoutine;
  final ValueChanged<Map<String, dynamic>> onStartRoutine;
  final VoidCallback onOpenAiGenerator;

  const _WorkoutHomeTab({
    super.key,
    required this.onStartEmptyWorkout,
    required this.onCreateRoutine,
    required this.onStartRoutine,
    required this.onOpenAiGenerator,
  });

  @override
  State<_WorkoutHomeTab> createState() => _WorkoutHomeTabState();
}

class _WorkoutHomeTabState extends State<_WorkoutHomeTab> {
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final routines = await ApiService.getRoutines();
      setState(() {
        _routines = routines;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: IronMindTheme.accent),
      );
    }

    return RefreshIndicator(
      color: IronMindTheme.accent,
      backgroundColor: IronMindTheme.surface2,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _AiWorkoutBanner(onTap: widget.onOpenAiGenerator),
          const SizedBox(height: 12),
          _OneRepMaxBanner(onTap: () => _showOneRepMaxCalculator(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onStartEmptyWorkout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IronMindTheme.textPrimary,
                    side: BorderSide(color: IronMindTheme.border2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'START EMPTY WORKOUT',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCreateRoutine,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IronMindTheme.accent,
                    side: BorderSide(
                      color: IronMindTheme.accent.withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'NEW ROUTINE',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Routines'),
          const SizedBox(height: 10),
          if (_routines.isEmpty)
            IronCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No routines yet',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a routine from the exercise library to keep your go-to sessions here.',
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.text2,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._routines.map(
              (routine) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoutineCard(
                  routine: routine,
                  onStart: () => widget.onStartRoutine(routine),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogHistoryTab extends StatefulWidget {
  final VoidCallback onStartEmptyWorkout;
  final VoidCallback onCreateRoutine;
  final ValueChanged<Map<String, dynamic>> onStartRoutine;

  const _LogHistoryTab({
    super.key,
    required this.onStartEmptyWorkout,
    required this.onCreateRoutine,
    required this.onStartRoutine,
  });

  @override
  State<_LogHistoryTab> createState() => _LogHistoryTabState();
}

class _LogHistoryTabState extends State<_LogHistoryTab> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await ApiService.getLogs();
      final routines = await ApiService.getRoutines();
      setState(() {
        _logs = l;
        _routines = routines;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: IronMindTheme.accent),
      );
    return RefreshIndicator(
      color: IronMindTheme.accent,
      backgroundColor: IronMindTheme.surface2,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _AiWorkoutBanner(onTap: widget.onStartEmptyWorkout),
          const SizedBox(height: 12),
          _OneRepMaxBanner(onTap: () => _showOneRepMaxCalculator(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onStartEmptyWorkout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IronMindTheme.textPrimary,
                    side: BorderSide(color: IronMindTheme.border2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'START EMPTY',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCreateRoutine,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IronMindTheme.accent,
                    side: BorderSide(
                      color: IronMindTheme.accent.withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'NEW ROUTINE',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Routines'),
          const SizedBox(height: 10),
          if (_routines.isEmpty)
            IronCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No routines yet',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a routine to keep your go-to sessions here.',
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.text2,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._routines.map(
              (routine) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoutineCard(
                  routine: routine,
                  onStart: () => widget.onStartRoutine(routine),
                ),
              ),
            ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Recent Sessions'),
          const SizedBox(height: 8),
          if (_logs.isEmpty)
            const EmptyState(
              icon: '◎',
              title: 'No Workouts Yet',
              sub: 'Use START EMPTY WORKOUT to log your first session',
            )
          else
            ..._logs.map((log) {
              final exs = log['exercises'] as List? ?? [];
              return Dismissible(
                key: Key('log-${log['id']}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: IronMindTheme.redDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: IronMindTheme.red,
                  ),
                ),
                onDismissed: (_) => ApiService.deleteLog(log['id']),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IronCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log['day_name'] ?? 'Workout',
                                style: GoogleFonts.bebasNeue(
                                  color: IronMindTheme.textPrimary,
                                  fontSize: 18,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            IronBadge(
                              log['date'] ?? '',
                              color: IronMindTheme.text3,
                            ),
                          ],
                        ),
                        if ((log['focus'] ?? '').isNotEmpty)
                          Text(
                            log['focus'],
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.accent,
                              fontSize: 10,
                            ),
                          ),
                        if (exs.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...exs
                              .take(3)
                              .map(
                                (ex) => Text(
                                  '• ${ex['name']} — ${ex['weight']}lb × ${ex['sets']}×${ex['reps']}',
                                  style: GoogleFonts.dmMono(
                                    color: IronMindTheme.text2,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          if (exs.length > 3)
                            Text(
                              '+ ${exs.length - 3} more exercises',
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.text3,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Routines ──────────────────────────────────────────────────────────────────
class _RoutinesTab extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onStartRoutine;
  final VoidCallback onCreateRoutine;
  final VoidCallback onChanged;

  const _RoutinesTab({
    required this.onStartRoutine,
    required this.onCreateRoutine,
    required this.onChanged,
  });

  @override
  State<_RoutinesTab> createState() => _RoutinesTabState();
}

class _RoutinesTabState extends State<_RoutinesTab> {
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ApiService.getRoutines();
    setState(() {
      _routines = r;
      _loading = false;
    });
  }

  void _importCSV() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV import is disabled in this demo build.'),
        backgroundColor: IronMindTheme.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: IronMindTheme.accent),
      );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: IronButton(
                  label: '+ CREATE ROUTINE',
                  onPressed: widget.onCreateRoutine,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _importCSV,
                style: ElevatedButton.styleFrom(
                  backgroundColor: IronMindTheme.accent,
                  foregroundColor: IronMindTheme.bg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  elevation: 0,
                ),
                child: const Icon(Icons.upload_file, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._routines.asMap().entries.map((entry) {
            final r = entry.value;
            final exs = (r['exercises'] as List? ?? []);
            return Dismissible(
              key: Key('routine-${r['id']}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: IronMindTheme.redDim,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: IronMindTheme.red,
                ),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: IronMindTheme.surface2,
                    title: Text(
                      'Delete Routine?',
                      style: GoogleFonts.bebasNeue(
                        color: IronMindTheme.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    content: Text(
                      'This cannot be undone.',
                      style: GoogleFonts.dmSans(color: IronMindTheme.text2),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmMono(color: IronMindTheme.text2),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.dmMono(color: IronMindTheme.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) async {
                await ApiService.deleteRoutine(r['id']);
                widget.onChanged();
                _load();
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: IronCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r['name'] ?? '',
                              style: GoogleFonts.dmSans(
                                color: IronMindTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IronGhostButton(
                            label: 'START',
                            color: IronMindTheme.accent,
                            onPressed: () => widget.onStartRoutine(r),
                          ),
                        ],
                      ),
                      if (exs.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          exs.take(3).join(' · '),
                          style: GoogleFonts.dmMono(
                            color: IronMindTheme.text3,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (exs.length > 3)
                          Text(
                            '+ ${exs.length - 3} more',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.text3,
                              fontSize: 9,
                            ),
                          ),
                      ],
                      if ((r['primary'] as List? ?? []).isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: [
                            ...(r['primary'] as List).map(
                              (m) => MuscleTag(m as String, primary: true),
                            ),
                            ...(r['secondary'] as List? ?? []).map(
                              (m) => MuscleTag(m as String, primary: false),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Records ───────────────────────────────────────────────────────────────────
class _RecordsTab extends StatefulWidget {
  const _RecordsTab();
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String, dynamic>> _prs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ApiService.getPRList();
      setState(() {
        _prs = p;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _show1RM() {
    final wC = TextEditingController();
    final rC = TextEditingController();
    const formulas = {
      'Epley': 'epley',
      'Brzycki': 'brzycki',
      'McGlothin': 'mcglothin',
      'Lombardi': 'lombardi',
    };
    Map<String, int> results = {};
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          void calc() {
            final w = double.tryParse(wC.text) ?? 0;
            final r = int.tryParse(rC.text) ?? 0;
            if (w > 0 && r > 0) {
              set(() {
                results = {
                  for (final entry in formulas.entries)
                    entry.key: ApiService.calculate1RM(
                      w,
                      r,
                      entry.value,
                    ).round(),
                };
              });
            } else {
              set(() => results = {});
            }
          }

          return Dialog(
            backgroundColor: IronMindTheme.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '1RM CALCULATOR',
                              style: GoogleFonts.bebasNeue(
                                color: IronMindTheme.textPrimary,
                                fontSize: 22,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                            color: IronMindTheme.text2,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: wC,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Weight (lbs)',
                              ),
                              onChanged: (_) => calc(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: rC,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Reps',
                              ),
                              onChanged: (_) => calc(),
                            ),
                          ),
                        ],
                      ),
                      if (results.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'ESTIMATED 1RM RANGE',
                                style: GoogleFonts.dmMono(
                                  color: IronMindTheme.text3,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                '~${results.values.reduce((a, b) => a > b ? a : b)}lb',
                                style: GoogleFonts.bebasNeue(
                                  color: IronMindTheme.accent,
                                  fontSize: 52,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Highest estimate from the formulas below',
                                style: GoogleFonts.dmMono(
                                  color: IronMindTheme.text3,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...results.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: IronMindTheme.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: IronMindTheme.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: GoogleFonts.dmSans(
                                        color: IronMindTheme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '~${entry.value}lb',
                                    style: GoogleFonts.dmMono(
                                      color: IronMindTheme.accent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddPR() {
    final eC = TextEditingController();
    final wC = TextEditingController();
    final rC = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Map<String, dynamic>? lastPR;
          bool isNewPR = false;

          void checkPR() async {
            final exercise = eC.text.trim();
            final weight = double.tryParse(wC.text) ?? 0;

            if (exercise.isNotEmpty && weight > 0) {
              lastPR = await ApiService.getLastPRForExercise(exercise);
              isNewPR = weight > ((lastPR?['weight'] as num?) ?? 0);
              set(() {});
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOG PR',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: eC,
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(labelText: 'Exercise'),
                    onChanged: (_) => checkPR(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: wC,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GoogleFonts.dmMono(
                            color: IronMindTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weight (lbs)',
                          ),
                          onChanged: (_) => checkPR(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: rC,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.dmMono(
                            color: IronMindTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(labelText: 'Reps'),
                          onChanged: (_) => checkPR(),
                        ),
                      ),
                    ],
                  ),
                  if (lastPR != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isNewPR
                            ? IronMindTheme.greenDim
                            : IronMindTheme.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isNewPR
                              ? IronMindTheme.green
                              : IronMindTheme.border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNewPR ? '🔥 NEW PR!' : 'Previous PR',
                            style: GoogleFonts.bebasNeue(
                              color: isNewPR
                                  ? IronMindTheme.green
                                  : IronMindTheme.text2,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${lastPR!['weight']}lb × ${lastPR!['reps']}',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'From ${_daysSince(lastPR!['date'] as String)}',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.text3,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  IronButton(
                    label: 'SAVE PR',
                    onPressed: () async {
                      if (eC.text.isEmpty || wC.text.isEmpty || rC.text.isEmpty)
                        return;
                      try {
                        await ApiService.savePR({
                          'exercise': eC.text,
                          'weight': double.parse(wC.text),
                          'reps': int.parse(rC.text),
                          'date': DateTime.now().toIso8601String().split(
                            'T',
                          )[0],
                          'notes': '',
                        });
                        Navigator.pop(ctx);
                        _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isNewPR ? '🔥 New PR!' : 'PR logged!',
                              ),
                              backgroundColor: isNewPR
                                  ? IronMindTheme.green
                                  : IronMindTheme.accent,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: IronMindTheme.red,
                            ),
                          );
                        }
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _daysSince(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return 'today';
      if (diff == 1) return 'yesterday';
      if (diff < 7) return '$diff days ago';
      if (diff < 30) return '${(diff / 7).ceil()} weeks ago';
      return '${(diff / 30).ceil()} months ago';
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: IronMindTheme.accent),
      );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: IronButton(label: '+ LOG PR', onPressed: _showAddPR),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _show1RM,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: IronMindTheme.accent,
                    side: BorderSide(
                      color: IronMindTheme.accent.withOpacity(0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    '1RM CALC',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      letterSpacing: 1,
                      color: IronMindTheme.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _prs.isEmpty
              ? const EmptyState(
                  icon: '🏆',
                  title: 'No Records Yet',
                  sub: 'Log workouts or add PRs manually',
                )
              : IronCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: _prs.asMap().entries.map((e) {
                      final pr = e.value;
                      final isLast = e.key == _prs.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(
                                  bottom: BorderSide(
                                    color: IronMindTheme.border,
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pr['exercise'] ?? '',
                                    style: GoogleFonts.dmSans(
                                      color: IronMindTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    pr['date'] ?? '',
                                    style: GoogleFonts.dmMono(
                                      color: IronMindTheme.text3,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 5,
                              children: [
                                IronBadge(
                                  '${pr['weight']}lb × ${pr['reps']}',
                                  color: IronMindTheme.accent,
                                ),
                                if (pr['estimated_1rm'] != null)
                                  IronBadge(
                                    '~${pr['estimated_1rm']}lb e1RM',
                                    color: IronMindTheme.green,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Lifter Profile (moved from Profile screen) ────────────────────────────────
class _LifterProfileTab extends StatefulWidget {
  const _LifterProfileTab();
  @override
  State<_LifterProfileTab> createState() => _LifterProfileTabState();
}

class _LifterProfileTabState extends State<_LifterProfileTab> {
  Map<String, dynamic> _p = {};
  bool _loaded = false, _saving = false;
  final _nameCtrl = TextEditingController();
  final _bwCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _squatCtrl = TextEditingController();
  final _benchCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();
  final _ohpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ApiService.getLifterProfile();
    setState(() {
      _p = p;
      _nameCtrl.text = p['name'] ?? '';
      _bwCtrl.text = p['bodyweight'] ?? '';
      _targetWeightCtrl.text = p['goalWeight'] ?? '';
      _squatCtrl.text = p['squat'] ?? '';
      _benchCtrl.text = p['bench'] ?? '';
      _dlCtrl.text = p['deadlift'] ?? '';
      _ohpCtrl.text = p['ohp'] ?? '';
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _p['name'] = _nameCtrl.text;
    _p['bodyweight'] = _bwCtrl.text;
    _p['weight'] = _bwCtrl.text;
    _p['goalWeight'] = _targetWeightCtrl.text;
    _p['squat'] = _squatCtrl.text;
    _p['bench'] = _benchCtrl.text;
    _p['deadlift'] = _dlCtrl.text;
    _p['ohp'] = _ohpCtrl.text;
    _p['currentSquat'] = double.tryParse(_squatCtrl.text) ?? 0;
    _p['currentBench'] = double.tryParse(_benchCtrl.text) ?? 0;
    _p['currentDeadlift'] = double.tryParse(_dlCtrl.text) ?? 0;
    _p['currentOhp'] = double.tryParse(_ohpCtrl.text) ?? 0;
    await ApiService.saveLifterProfile(_p);
    setState(() => _saving = false);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved! AI will now use your stats.'),
          backgroundColor: IronMindTheme.green,
        ),
      );
  }

  Widget _drop(String label, String key, Map<String, String> items) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: IronDropdown(
      label: label,
      value: _p[key] ?? items.keys.first,
      items: items,
      onChanged: (v) => setState(() => _p[key] = v),
    ),
  );

  Widget _maxField(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: GoogleFonts.dmMono(
          color: IronMindTheme.textPrimary,
          fontSize: 14,
        ),
        decoration: const InputDecoration(suffixText: 'lb'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_loaded)
      return const Center(
        child: CircularProgressIndicator(color: IronMindTheme.accent),
      );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: IronMindTheme.accentDim,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: IronMindTheme.accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: IronMindTheme.accent,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your profile is used by the AI generator to create personalized workouts.',
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.accent,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('Personal'),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bwCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Current Weight (lbs)',
                    suffixText: 'lbs',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _targetWeightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target Weight',
                    suffixText: 'lbs',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('Training Style'),
                const SizedBox(height: 10),
                _drop('Training Focus', 'style', {
                  'powerlifting': 'Powerlifting (SBD)',
                  'powerbuilding': 'Powerbuilding',
                  'strength': 'General Strength',
                  'hypertrophy': 'Hypertrophy / Bodybuilding',
                  'olympic': 'Olympic Lifting',
                  'crossfit': 'CrossFit / Functional',
                  'athletic': 'Athletic Performance',
                }),
                _drop('Experience Level', 'experience', {
                  'beginner': 'Beginner (0–1 yr)',
                  'intermediate': 'Intermediate (1–3 yr)',
                  'advanced': 'Advanced (3+ yr)',
                  'elite': 'Elite / Competitor',
                }),
                IronSlider(
                  label: 'Training Days / Week',
                  value: (_p['trainingDays'] as num?)?.toDouble() ?? 4,
                  min: 2,
                  max: 7,
                  divisions: 5,
                  format: (v) => '${v.toInt()} days',
                  onChanged: (v) => setState(() => _p['trainingDays'] = v),
                ),
                IronSlider(
                  label: 'Session Length',
                  value: (_p['sessionLength'] as num?)?.toDouble() ?? 75,
                  min: 30,
                  max: 120,
                  divisions: 6,
                  format: (v) => '${v.toInt()} min',
                  onChanged: (v) => setState(() => _p['sessionLength'] = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('Current Maxes (lbs)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _maxField('Squat 1RM', _squatCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _maxField('Bench 1RM', _benchCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _maxField('Deadlift 1RM', _dlCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _maxField('OHP 1RM', _ohpCtrl)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('Goals'),
                const SizedBox(height: 10),
                _drop('Primary Goal', 'goal', {
                  'peak-strength': 'Peak Strength / Meet Prep',
                  'hypertrophy': 'Add Muscle Mass',
                  'total': 'Increase Total',
                  'weak-points': 'Bring Up Weak Points',
                  'fitness': 'General Fitness',
                  'lose-fat': 'Lose Body Fat',
                  'athletic': 'Athletic Performance',
                }),
                _drop('Weak Point', 'weakpoint', {
                  'none': 'None / Balanced',
                  'squat-depth': 'Squat — depth',
                  'squat-lockout': 'Squat — lockout',
                  'bench-bottom': 'Bench — off chest',
                  'bench-lockout': 'Bench — lockout',
                  'deadlift-floor': 'Deadlift — off floor',
                  'deadlift-lockout': 'Deadlift — lockout',
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('Equipment Available'),
                const SizedBox(height: 8),
                ...[
                  'Barbell',
                  'Dumbbells',
                  'Cable Machine',
                  'Safety Squat Bar',
                  'Bands / Chains',
                  'Leg Press',
                  'Smith Machine',
                  'Kettlebells',
                ].map((eq) {
                  final equip = List<String>.from(_p['equipment'] ?? []);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: equip.contains(eq),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                equip.add(eq);
                              } else {
                                equip.remove(eq);
                              }
                              _p['equipment'] = equip;
                            }),
                            activeColor: IronMindTheme.accent,
                            checkColor: IronMindTheme.bg,
                            side: const BorderSide(
                              color: IronMindTheme.border2,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          eq,
                          style: GoogleFonts.dmSans(
                            color: IronMindTheme.text2,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          IronButton(label: 'SAVE PROFILE', onPressed: _save, loading: _saving),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bwCtrl.dispose();
    _targetWeightCtrl.dispose();
    _squatCtrl.dispose();
    _benchCtrl.dispose();
    _dlCtrl.dispose();
    _ohpCtrl.dispose();
    super.dispose();
  }
}

// ── AI Tab ────────────────────────────────────────────────────────────────────
class _AITab extends StatefulWidget {
  const _AITab();
  @override
  State<_AITab> createState() => _AITabState();
}

class _AITabState extends State<_AITab> {
  final _ctrl = TextEditingController();
  String _output = '';
  bool _loading = false;
  Map<String, dynamic> _profile = {};

  final _chips = [
    'Squat Day',
    'Bench Day',
    'Pull Day',
    'Full Body',
    'Deload',
    'Hypertrophy',
    'Accessory Work',
    'GPP',
  ];
  final _prompts = {
    'Squat Day':
        'Generate a squat-focused training day with warm-up, main work, and accessories.',
    'Bench Day':
        'Generate a bench press focused day with competition-style work and upper body accessories.',
    'Pull Day':
        'Generate a pull day with deadlifts or rows as main lift, plus lat and bicep work.',
    'Full Body':
        'Generate a full body training day hitting all major muscle groups with compound movements.',
    'Deload':
        'Generate a deload week at 50-60% intensity with reduced volume for recovery.',
    'Hypertrophy':
        'Generate a hypertrophy day with 8-15 rep ranges, higher volume, and muscle isolation.',
    'Accessory Work':
        'Generate a light accessory session targeting weak points and muscle balance.',
    'GPP':
        'Generate a general physical preparedness session for conditioning and movement quality.',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await ApiService.getLifterProfile();
    setState(() => _profile = p);
  }

  String _buildPrompt(String base) {
    final parts = <String>[];
    if ((_profile['name'] ?? '').isNotEmpty)
      parts.add('Name: ${_profile['name']}');
    if ((_profile['bodyweight'] ?? '').isNotEmpty)
      parts.add('Bodyweight: ${_profile['bodyweight']}lb');
    if ((_profile['goalWeight'] ?? '').isNotEmpty)
      parts.add('Target weight: ${_profile['goalWeight']}lb');
    if ((_profile['squat'] ?? '').isNotEmpty)
      parts.add('Squat 1RM: ${_profile['squat']}lb');
    if ((_profile['bench'] ?? '').isNotEmpty)
      parts.add('Bench 1RM: ${_profile['bench']}lb');
    if ((_profile['deadlift'] ?? '').isNotEmpty)
      parts.add('Deadlift 1RM: ${_profile['deadlift']}lb');
    if ((_profile['ohp'] ?? '').isNotEmpty)
      parts.add('OHP 1RM: ${_profile['ohp']}lb');
    parts.add('Experience: ${_profile['experience'] ?? 'intermediate'}');
    parts.add('Style: ${_profile['style'] ?? 'general strength'}');
    parts.add('Goal: ${_profile['goal'] ?? 'general fitness'}');
    if ((_profile['weakpoint'] ?? 'none') != 'none')
      parts.add('Weak point: ${_profile['weakpoint']}');
    final equip = List<String>.from(_profile['equipment'] ?? []);
    if (equip.isNotEmpty) parts.add('Equipment: ${equip.join(', ')}');
    return '$base\n\nAthlete profile: ${parts.join(' | ')}';
  }

  bool get _profileComplete =>
      (_profile['squat'] ?? '').isNotEmpty ||
      (_profile['bench'] ?? '').isNotEmpty;

  Future<void> _generate() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _output = '';
    });
    try {
      final result = await ApiService.generateWorkout(
        _buildPrompt(_ctrl.text.trim()),
      );
      setState(() => _output = result);
    } catch (_) {
      setState(
        () => _output =
            'Cannot connect to server. Start your backend and update the URL in Profile → Settings.',
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_profileComplete)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: IronMindTheme.blueDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IronMindTheme.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: IronMindTheme.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fill out your Lifter Profile tab to get personalized AI workouts.',
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.blue,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_profileComplete)
            IronCard2(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IronLabel('Using Your Profile'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if ((_profile['squat'] ?? '').isNotEmpty)
                        IronBadge(
                          'Squat: ${_profile['squat']}lb',
                          color: IronMindTheme.accent,
                        ),
                      if ((_profile['bench'] ?? '').isNotEmpty)
                        IronBadge(
                          'Bench: ${_profile['bench']}lb',
                          color: IronMindTheme.green,
                        ),
                      if ((_profile['deadlift'] ?? '').isNotEmpty)
                        IronBadge(
                          'DL: ${_profile['deadlift']}lb',
                          color: IronMindTheme.blue,
                        ),
                      IronBadge(
                        _profile['style'] ?? 'strength',
                        color: IronMindTheme.purple,
                      ),
                      IronBadge(
                        _profile['experience'] ?? 'intermediate',
                        color: IronMindTheme.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IronLabel('Quick Prompts'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _chips
                      .map(
                        (c) => GestureDetector(
                          onTap: () =>
                              setState(() => _ctrl.text = _prompts[c] ?? c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: IronMindTheme.surface2,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: IronMindTheme.border2),
                            ),
                            child: Text(
                              c,
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.text2,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  maxLines: 4,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe the workout you want...',
                    hintStyle: GoogleFonts.dmSans(
                      color: IronMindTheme.text3,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
                IronButton(
                  label: 'GENERATE',
                  onPressed: _generate,
                  loading: _loading,
                ),
              ],
            ),
          ),
          if (_output.isNotEmpty) ...[
            const SizedBox(height: 12),
            IronCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IronLabel('Generated Workout'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: IronMindTheme.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _output,
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.textPrimary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

Future<void> _showRoutineBuilderSheet(
  BuildContext context, {
  required VoidCallback onCreated,
}) async {
  final nameCtrl = TextEditingController();
  final selectedExercises = <String>[];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: IronMindTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CREATE ROUTINE',
                style: GoogleFonts.bebasNeue(
                  color: IronMindTheme.textPrimary,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.dmSans(
                  color: IronMindTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  labelText: 'Routine Name',
                  hintText: 'e.g. Push Day',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (libraryCtx) => FractionallySizedBox(
                      heightFactor: 0.92,
                      child: ExerciseLibraryScreen(
                        onAddToWorkout: (exerciseName) {
                          if (!selectedExercises.contains(exerciseName)) {
                            setModalState(() => selectedExercises.add(exerciseName));
                          }
                          Navigator.pop(libraryCtx);
                        },
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: IronMindTheme.accent,
                  side: BorderSide(
                    color: IronMindTheme.accent.withOpacity(0.35),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(
                  'ADD FROM LIBRARY',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedExercises.isEmpty)
                Text(
                  'Pick exercises from the library to build this routine.',
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.text2,
                    fontSize: 12,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedExercises
                      .map(
                        (exercise) => InputChip(
                          label: Text(exercise),
                          onDeleted: () {
                            setModalState(() => selectedExercises.remove(exercise));
                          },
                          deleteIconColor: IronMindTheme.text2,
                          selected: true,
                          selectedColor: IronMindTheme.accentDim,
                          side: BorderSide(
                            color: IronMindTheme.accent.withOpacity(0.35),
                          ),
                          labelStyle: GoogleFonts.dmSans(
                            color: IronMindTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 16),
              IronButton(
                label: 'CREATE ROUTINE',
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || selectedExercises.isEmpty) {
                    return;
                  }
                  await ApiService.saveRoutine({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameCtrl.text.trim(),
                    'exercises': selectedExercises,
                    'primary': [],
                    'secondary': [],
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  onCreated();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );

  nameCtrl.dispose();
}

class _RoutineCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onStart;

  const _RoutineCard({required this.routine, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final exercises = (routine['exercises'] as List? ?? []);
    final primary = (routine['primary'] as List? ?? []);
    final secondary = (routine['secondary'] as List? ?? []);

    return IronCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  routine['name'] ?? '',
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              IronGhostButton(
                label: 'START',
                color: IronMindTheme.accent,
                onPressed: onStart,
              ),
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              exercises.take(3).join(' · '),
              style: GoogleFonts.dmMono(
                color: IronMindTheme.text3,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (exercises.length > 3)
              Text(
                '+ ${exercises.length - 3} more',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.text3,
                  fontSize: 9,
                ),
              ),
          ],
          if (primary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                ...primary.map(
                  (muscle) => MuscleTag(muscle as String, primary: true),
                ),
                ...secondary.map(
                  (muscle) => MuscleTag(muscle as String, primary: false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
