import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'exercise_library_screen.dart';
import 'workout_summary_screen.dart';
import '../theme.dart';
import '../widgets/muscle_body_map.dart' show computeMuscleSetMap;
import '../widgets/common.dart';
import '../widgets/import_program_sheet.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../models/bar_type.dart';

void _doShowImportSheet(BuildContext context, {required VoidCallback onRefresh}) {
  showImportProgramSheet(
    context,
    onRoutinesSaved: onRefresh,
  );
}

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
  String _sessionPlan = '';
  final List<_ExerciseEntry> _exercises = [];

  // Global rest timer
  bool _resting = false;
  int _restSeconds = 0;
  int _restTotal = 0;
  String _restExercise = '';
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startGlobalRest(int seconds, String exercise) {
    _restTimer?.cancel();
    setState(() {
      _resting = true;
      _restSeconds = seconds;
      _restTotal = seconds;
      _restExercise = exercise.trim();
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_restSeconds <= 0) {
        t.cancel();
        setState(() => _resting = false);
        HapticFeedback.heavyImpact();
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  void _stopRest() {
    _restTimer?.cancel();
    if (mounted) setState(() => _resting = false);
  }

  String get _timerLabel {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _beginWorkout({
    String name = '',
    String sessionPlan = '',
    List<_ExerciseEntry>? exercises,
  }) {
    _timer?.cancel();
    _stopRest();
    final nextExercises = exercises == null || exercises.isEmpty
        ? <_ExerciseEntry>[_ExerciseEntry()]
        : exercises;
    setState(() {
      _workoutActive = true;
      _elapsed = 0;
      _workoutName = name;
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
      exercises: exerciseNames,
    );
  }

  void _addExercisesFromLibrary(List<String> names) {
    if (_workoutActive) {
      setState(() {
        for (final name in names) {
          _exercises.add(_ExerciseEntry(name: name));
        }
      });
      return;
    }
    _beginWorkout(exercises: names.map((n) => _ExerciseEntry(name: n)).toList());
  }

  void _openExerciseLibrary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ExerciseLibraryScreen(onAddMultipleToWorkout: _addExercisesFromLibrary),
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

  void _showImportProgramSheet() {
    // Import via the shared import widget — routines land in local storage
    // and refresh the tab via _routineRefreshTick.
    _doShowImportSheet(context, onRefresh: () {
      setState(() => _routineRefreshTick++);
    });
  }

  List<String> _detectMuscleGroups(List<_ExerciseEntry> exercises) =>
      detectMuscleGroupsFromNames(exercises.map((e) => e.name).toList());

  void _finishWorkout() async {
    _timer?.cancel();
    _stopRest();

    final now = DateTime.now();
    final summaryExercises = _exercises.where((e) => e.name.isNotEmpty).toList();
    final capturedElapsed  = _elapsed;
    final capturedName     = _workoutName;
    final muscleGroups     = _detectMuscleGroups(summaryExercises);

    // Capture full set-by-set data before clearing state
    final summaryExerciseList = summaryExercises.map((e) {
      final completedSets = e.sets
          .where((s) => s.done && s.reps > 0)
          .map((s) => SummarySet(
            weight: s.weight,
            reps:   s.reps,
            isPR:   s.prTracked,
          ))
          .toList();
      return SummaryExercise(name: e.name, completedSets: completedSets);
    }).where((e) => e.completedSets.isNotEmpty).toList();

    final summaryData = WorkoutSummaryData(
      name:           capturedName,
      date:           now,
      elapsedSeconds: capturedElapsed,
      muscleGroups:   muscleGroups,
      exercises:      summaryExerciseList,
      muscleSetMap:   computeMuscleSetMap(summaryExerciseList),
    );

    // Simplified log data for storage (last completed set per exercise)
    final logData = summaryExercises.map((e) {
      final done = e.sets.where((s) => s.done && s.reps > 0).toList();
      return {
        'name':   e.name,
        'sets':   done.length,
        'reps':   done.isNotEmpty ? done.last.reps   : 0,
        'weight': done.isNotEmpty ? done.last.weight : 0,
      };
    }).where((d) => (d['sets'] as int) > 0).toList();

    if (logData.isNotEmpty) {
      try {
        await ApiService.saveLog({
          'date':         now.toIso8601String().split('T')[0],
          'program_name': capturedName,
          'day_name':     capturedName.isEmpty ? 'Workout' : capturedName,
          'focus':        muscleGroups.join(', '),
          'exercises':    logData,
          'notes':        _sessionPlan,
        });
        await HealthService.instance.writeWorkout({
          'exercises': logData,
          'elapsed':   capturedElapsed,
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Server offline — workout not saved'),
              backgroundColor: IronMindTheme.orange,
            ),
          );
        }
      }
    }

    setState(() {
      _workoutActive = false;
      _elapsed       = 0;
      _exercises.clear();
      _workoutName   = '';
      _sessionPlan   = '';
    });

    if (mounted && summaryData.exercises.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(data: summaryData),
          fullscreenDialog: true,
        ),
      );
    }
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
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            color: IronMindTheme.text2,
          ),
          IconButton(
            tooltip: '1RM Calculator',
            onPressed: () => _showOneRepMaxCalculator(context),
            icon: const Icon(Icons.calculate_outlined, size: 18),
            color: IronMindTheme.text2,
          ),
          IconButton(
            tooltip: 'AI session generator',
            onPressed: _showAiWorkoutPrompt,
            icon: const Icon(Icons.auto_awesome, size: 18),
            color: IronMindTheme.accent,
          ),
          if (_workoutActive)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: OutlinedButton(
                onPressed: _finishWorkout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: IronMindTheme.red,
                  side: BorderSide(color: IronMindTheme.red.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text('FINISH', style: GoogleFonts.bebasNeue(fontSize: 13, letterSpacing: 1)),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_workoutActive)
          _ActiveWorkoutTab(
              sessionPlan: _sessionPlan,
              exercises: _exercises,
              onRestStart: _startGlobalRest,
              onNameChanged: (v) => setState(() => _workoutName = v),
              onAddExercise: () =>
                  setState(() => _exercises.add(_ExerciseEntry())),
              onUpdate: () => setState(() {}),
              onOpenOneRepMax: () => _showOneRepMaxCalculator(context),
              openLibrary: (onSelect) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: 0.92,
                    child: ExerciseLibraryScreen(
                      onAddMultipleToWorkout: (names) {
                        if (names.isEmpty) return;
                        // First selection fills the current empty slot
                        onSelect(names.first);
                        // Any additional selections become new exercise entries
                        if (names.length > 1) {
                          setState(() {
                            for (final name in names.skip(1)) {
                              _exercises.add(_ExerciseEntry(name: name));
                            }
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            )
          else
            _WorkoutHomeTab(
              key: ValueKey('workout-log-$_routineRefreshTick'),
              onStartEmptyWorkout: _startEmptyWorkout,
              onCreateRoutine:  _showCreateRoutineSheet,
              onImportProgram:  _showImportProgramSheet,
              onStartRoutine:   _startRoutine,
              onOpenAiGenerator: _showAiWorkoutPrompt,
            ),
          if (_resting)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _RestTimerOverlay(
                seconds: _restSeconds,
                total: _restTotal,
                exercise: _restExercise,
                onSkip: _stopRest,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Muscle group detection (top-level so both state & builder sheet can use it)
List<String> detectMuscleGroupsFromNames(List<String> names) {
  final groups = <String>{};
  for (final name in names) {
    final n = name.toLowerCase();
    if (n.contains('squat') || n.contains('leg press') || n.contains('lunge') ||
        n.contains('romanian') || n.contains('rdl') || n.contains('leg curl') ||
        n.contains('leg extension') || n.contains('hack squat') || n.contains('goblet')) { groups.add('Legs'); }
    if (n.contains('bench') || n.contains('chest') || n.contains('fly') ||
        n.contains('push up') || n.contains('pushup') || n.contains('dip') || n.contains('pec')) { groups.add('Chest'); }
    if (n.contains('row') || n.contains('pull') || n.contains('deadlift') ||
        n.contains('lat ') || n.contains('lats') || n.contains('pulldown') ||
        n.contains('t-bar') || n.contains('back') || n.contains('rhomboid') ||
        n.contains('trap')) { groups.add('Back'); }
    if (n.contains('shoulder') || n.contains('overhead press') || n.contains('ohp') ||
        n.contains('military') || n.contains('lateral raise') || n.contains('delt') ||
        n.contains('face pull') || n.contains('upright row')) { groups.add('Shoulders'); }
    if (n.contains('curl') || n.contains('bicep') || n.contains('hammer') ||
        n.contains('preacher')) { groups.add('Biceps'); }
    if (n.contains('tricep') || n.contains('pushdown') || n.contains('skull') ||
        (n.contains('extension') && !n.contains('leg'))) { groups.add('Triceps'); }
    if (n.contains('abs') || n.contains('core') || n.contains('crunch') ||
        n.contains('plank') || n.contains('sit up') || n.contains('oblique')) { groups.add('Core'); }
    if (n.contains('calf') || n.contains('calves') || n.contains('soleus')) { groups.add('Calves'); }
    if (n.contains('glute') || n.contains('hip thrust') || n.contains('abductor') ||
        n.contains('adductor')) { groups.add('Glutes'); }
  }
  return groups.toList()..sort();
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
  final ValueChanged<String> onNameChanged;
  final VoidCallback onAddExercise, onUpdate;
  final VoidCallback? onOpenOneRepMax;
  final void Function(Function(String) onSelect) openLibrary;
  final void Function(int seconds, String exercise) onRestStart;
  const _ActiveWorkoutTab({
    required this.sessionPlan,
    required this.exercises,
    required this.onNameChanged,
    required this.onAddExercise,
    required this.onUpdate,
    required this.openLibrary,
    required this.onRestStart,
    this.onOpenOneRepMax,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    child: Column(
      children: [
        TextField(
          onChanged: onNameChanged,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: GoogleFonts.dmSans(
            color: IronMindTheme.textPrimary,
            fontSize: 13,
          ),
          decoration: const InputDecoration(
            labelText: 'Workout Name (optional)',
            hintText: 'e.g. Squat Day',
          ),
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
              openLibrary: openLibrary,
              onRestStart: onRestStart,
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
        IronButton(
          label: '+ ADD EXERCISE',
          onPressed: () => openLibrary((name) {
            exercises.add(_ExerciseEntry(name: name));
            onUpdate();
          }),
        ),
      ],
    ),
  );
}

class _ExerciseEntry {
  String name;
  List<_SetEntry> sets;
  BarType? barType;
  final TextEditingController nameCtrl;
  _ExerciseEntry({this.name = '', List<_SetEntry>? sets, this.barType})
      : nameCtrl = TextEditingController(text: name),
        sets = sets ?? [_SetEntry()];
}

class _SetEntry {
  double weight = 0;
  int reps = 0;
  double? rpe;
  bool done = false;
  bool prTracked = false;
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController repsCtrl = TextEditingController();
  final TextEditingController rpeCtrl = TextEditingController();
}

// ── Set Schemes ───────────────────────────────────────────────────────────────

class _SchemePreset {
  final String label;
  final String category;
  final List<int> repsPerSet;
  final double? suggestedPct;
  const _SchemePreset(this.label, this.category, this.repsPerSet, {this.suggestedPct});
}

const _strengthSchemes = <_SchemePreset>[
  _SchemePreset('5×5',        'Strength',   [5,5,5,5,5],     suggestedPct: 0.80),
  _SchemePreset('5×3',        'Strength',   [3,3,3,3,3],     suggestedPct: 0.875),
  _SchemePreset('3×3',        'Strength',   [3,3,3],         suggestedPct: 0.90),
  _SchemePreset('5/3/1',      'Wendler',    [5,3,1],         suggestedPct: null),
  _SchemePreset('Wave 5-3-1', 'Wave',       [5,3,1,5,3,1],   suggestedPct: null),
  _SchemePreset('5-4-3-2-1',  'Ladder',     [5,4,3,2,1],     suggestedPct: null),
  _SchemePreset('3×1 Singles','Max Effort', [1,1,1],         suggestedPct: 0.94),
];

const _hypertrophySchemes = <_SchemePreset>[
  _SchemePreset('4×8',   'Hypertrophy',  [8,8,8,8],       suggestedPct: 0.72),
  _SchemePreset('4×10',  'Hypertrophy',  [10,10,10,10],   suggestedPct: 0.67),
  _SchemePreset('3×12',  'Hypertrophy',  [12,12,12],      suggestedPct: 0.63),
  _SchemePreset('5×8',   'Volume',       [8,8,8,8,8],     suggestedPct: 0.70),
  _SchemePreset('4×12',  'Volume',       [12,12,12,12],   suggestedPct: 0.63),
  _SchemePreset('4×15',  'Endurance',    [15,15,15,15],   suggestedPct: 0.58),
];

const _peakingSchemes = <_SchemePreset>[
  _SchemePreset('4×2',        'Peaking',    [2,2,2,2],       suggestedPct: 0.90),
  _SchemePreset('5×2',        'Peaking',    [2,2,2,2,2],     suggestedPct: 0.88),
  _SchemePreset('3×1',        'Singles',    [1,1,1],         suggestedPct: 0.93),
  _SchemePreset('2-2-2-1-1',  'Comp Prep', [2,2,2,1,1],     suggestedPct: null),
];

class _ExerciseCard extends StatefulWidget {
  final _ExerciseEntry entry;
  final VoidCallback onUpdate;
  final ValueChanged<_PrHighlight> onPr;
  final VoidCallback? onRemove;
  final void Function(Function(String) onSelect) openLibrary;
  final void Function(int seconds, String exercise) onRestStart;
  const _ExerciseCard({
    required this.entry,
    required this.onUpdate,
    required this.onPr,
    required this.openLibrary,
    required this.onRestStart,
    this.onRemove,
  });
  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
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
                  controller: e.nameCtrl,
                  onChanged: (v) => e.name = v,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: GoogleFonts.dmSans(
                      color: IronMindTheme.text3,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Icon(
                    Icons.close,
                    color: IronMindTheme.text3,
                    size: 18,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showBarPicker(context, e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: e.barType != null
                        ? IronMindTheme.accent.withValues(alpha: 0.08)
                        : IronMindTheme.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: e.barType != null
                          ? IronMindTheme.accent.withValues(alpha: 0.3)
                          : IronMindTheme.border2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 11, color: IronMindTheme.text3),
                      const SizedBox(width: 5),
                      Text(
                        e.barType != null
                            ? '${barSpecFor(e.barType!).shortName}  ·  ${barSpecFor(e.barType!).weightLb.toInt()} lb'
                            : 'Select bar',
                        style: GoogleFonts.dmMono(
                          color: e.barType != null
                              ? IronMindTheme.accent
                              : IronMindTheme.text3,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 13,
                          color: e.barType != null
                              ? IronMindTheme.accent
                              : IronMindTheme.text3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showLoadCalc(context, e),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: IronMindTheme.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: IronMindTheme.border2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.percent_rounded, size: 11, color: IronMindTheme.text3),
                      const SizedBox(width: 4),
                      Text('Load Calc',
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.text3, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              Expanded(
                flex: 2,
                child: Text(
                  'RPE',
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.dmMono(
                        color: s.done ? IronMindTheme.green : IronMindTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 14),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => s.weight = double.tryParse(v) ?? 0,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: s.repsCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.dmMono(
                        color: s.done ? IronMindTheme.green : IronMindTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 14),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => s.reps = int.tryParse(v) ?? 0,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: s.rpeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      style: GoogleFonts.dmMono(
                        color: s.done
                            ? (s.rpe != null ? IronMindTheme.accent : IronMindTheme.green)
                            : IronMindTheme.text2,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: '—',
                        hintStyle: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 13),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) => s.rpe = double.tryParse(v),
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      setState(() => s.done = !s.done);
                      if (s.done) {
                        HapticFeedback.mediumImpact();
                        widget.onRestStart(90, widget.entry.name.trim());
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
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _showSchemePicker(context, e),
                style: OutlinedButton.styleFrom(
                  foregroundColor: IronMindTheme.green,
                  side: BorderSide(color: IronMindTheme.green.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 13),
                    const SizedBox(width: 4),
                    Text('Scheme', style: GoogleFonts.dmMono(fontSize: 10, color: IronMindTheme.green)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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

  void _showLoadCalc(BuildContext context, _ExerciseEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LoadCalcSheet(
        exerciseName: entry.name,
        barType: entry.barType,
      ),
    );
  }

  void _showBarPicker(BuildContext context, _ExerciseEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: IronMindTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: IronMindTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BAR TYPE', style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                  const SizedBox(height: 2),
                  Text('Select the bar for this exercise', style: GoogleFonts.dmSans(
                    color: IronMindTheme.text2, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // "No bar" option to clear selection
                  _BarOptionTile(
                    selected: entry.barType == null,
                    name: 'Default / No Bar',
                    shortName: '—',
                    weightLb: null,
                    benefit: 'Use for dumbbell, cable, machine, or bodyweight exercises.',
                    bestFor: 'Dumbbells · Cables · Machines',
                    onTap: () {
                      setState(() => entry.barType = null);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 6),
                  ...BarType.values.map((t) {
                    final spec = barSpecFor(t);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _BarOptionTile(
                        selected: entry.barType == t,
                        name: spec.name,
                        shortName: spec.shortName,
                        weightLb: spec.weightLb,
                        benefit: spec.benefit,
                        bestFor: spec.bestFor,
                        onTap: () {
                          setState(() => entry.barType = t);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSchemePicker(BuildContext context, _ExerciseEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchemePickerSheet(
        exerciseName: entry.name,
        onApply: (scheme, est1rm) {
          setState(() {
            entry.sets = scheme.repsPerSet.map((r) {
              final s = _SetEntry();
              s.repsCtrl.text = '$r';
              s.reps = r;
              if (est1rm != null && scheme.suggestedPct != null) {
                final w = _roundToNearest(est1rm * scheme.suggestedPct!, 2.5);
                s.weightCtrl.text = w.toInt().toString();
                s.weight = w;
              }
              return s;
            }).toList();
          });
        },
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
                        widget.onRestStart(s, widget.entry.name.trim());
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
  final VoidCallback onImportProgram;
  final ValueChanged<Map<String, dynamic>> onStartRoutine;
  final VoidCallback onOpenAiGenerator;

  const _WorkoutHomeTab({
    super.key,
    required this.onStartEmptyWorkout,
    required this.onCreateRoutine,
    required this.onImportProgram,
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
      return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    }

    return RefreshIndicator(
      color: IronMindTheme.accent,
      backgroundColor: IronMindTheme.surface2,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [

          // ── Start button ─────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onStartEmptyWorkout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    IronMindTheme.accent,
                    const Color(0xFF2D8FD4),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: IronMindTheme.accent.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.78,
                    child: const Icon(Icons.fitness_center,
                      color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('START WORKOUT',
                    style: GoogleFonts.bebasNeue(
                      color: Colors.black,
                      fontSize: 20,
                      letterSpacing: 2,
                    )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Secondary actions ────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _QuickStartButton(
                label: 'NEW ROUTINE',
                icon: Icons.edit_outlined,
                onTap: widget.onCreateRoutine,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickStartButton(
                label: 'EXERCISES',
                icon: Icons.search,
                onTap: () => _showExploreSheet(context, onAdded: _load),
              ),
            ),
            const SizedBox(width: 8),
            _QuickStartButton(
              label: 'IMPORT',
              icon: Icons.upload_file_outlined,
              onTap: widget.onImportProgram,
              compact: true,
            ),
          ]),
          // ── Routines ─────────────────────────────────────────────────────
          SectionHeader(
            title: 'My Routines',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: widget.onImportProgram,
                  child: Text('IMPORT',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.blue, fontSize: 10, letterSpacing: 1)),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onCreateRoutine,
                  child: Text('+ NEW',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.accent, fontSize: 10, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (_routines.isEmpty)
            _EmptyRoutinesCard(onCreateRoutine: widget.onCreateRoutine)
          else
            ..._routines.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey(r['id'] ?? r['name']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 22),
                ),
                confirmDismiss: (_) async {
                  final id = r['id']?.toString() ?? '';
                  if (id.isNotEmpty) await ApiService.deleteRoutine(id);
                  await _load();
                  return false; // _load rebuilds list, no need for Dismissible to remove
                },
                child: _RoutineCard(
                  routine: r,
                  onStart: () => widget.onStartRoutine(r),
                ),
              ),
            )),

        ],
      ),
    );
  }
}

class _QuickStartButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  final bool compact;

  const _QuickStartButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent  = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color  = accent  ? IronMindTheme.accent : IronMindTheme.textPrimary;
    final bg     = accent  ? IronMindTheme.accentDim : IronMindTheme.surface;
    final border = accent
        ? IronMindTheme.accent.withValues(alpha: 0.35)
        : IronMindTheme.border2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: compact
            ? const EdgeInsets.symmetric(vertical: 12, horizontal: 14)
            : const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: compact
            ? Icon(icon, color: IronMindTheme.blue, size: 16)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.bebasNeue(
                      color: color, fontSize: 13, letterSpacing: 1.2),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyRoutinesCard extends StatelessWidget {
  final VoidCallback onCreateRoutine;
  const _EmptyRoutinesCard({required this.onCreateRoutine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCreateRoutine,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: IronMindTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: IronMindTheme.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Create your first routine',
                style: GoogleFonts.dmSans(
                  color: IronMindTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Save exercises, sets, and order for your go-to sessions.',
                style: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 11, height: 1.4),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right, color: IronMindTheme.text3, size: 16),
        ]),
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
                child: Dismissible(
                  key: ValueKey('2_${routine['id'] ?? routine['name']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 22),
                  ),
                  confirmDismiss: (_) async {
                    final id = routine['id']?.toString() ?? '';
                    if (id.isNotEmpty) await ApiService.deleteRoutine(id);
                    _load();
                    return false;
                  },
                  child: _RoutineCard(
                    routine: routine,
                    onStart: () => widget.onStartRoutine(routine),
                  ),
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
                        onAddMultipleToWorkout: (names) {
                          setModalState(() {
                            for (final name in names) {
                              if (!selectedExercises.contains(name)) {
                                selectedExercises.add(name);
                              }
                            }
                          });
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
                  // Auto-detect muscle groups from exercise names
                  final detected = detectMuscleGroupsFromNames(selectedExercises);
                  final primary = detected.take(2).toList();
                  final secondary = detected.skip(2).toList();
                  await ApiService.saveRoutine({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameCtrl.text.trim(),
                    'exercises': selectedExercises,
                    'primary': primary,
                    'secondary': secondary,
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
  final VoidCallback? onDelete;

  const _RoutineCard({required this.routine, required this.onStart, this.onDelete});

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

// ── Explore Banner ────────────────────────────────────────────────────────────
class _ExploreBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ExploreBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: IronMindTheme.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.explore_outlined, color: IronMindTheme.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EXPLORE ROUTINES',
                  style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 14, letterSpacing: 1.4)),
              Text('5x5, PPL, Upper/Lower, and more',
                  style: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 10)),
            ]),
          ),
          Text('BROWSE', style: GoogleFonts.dmMono(color: IronMindTheme.green, fontSize: 9, letterSpacing: 1)),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right, color: IronMindTheme.green, size: 14),
        ]),
      ),
    );
  }
}

// ── Explore Sheet ─────────────────────────────────────────────────────────────
void _showExploreSheet(BuildContext context, {required VoidCallback onAdded}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _ExploreSheet(onAdded: onAdded),
    ),
  );
}

class _ExploreSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _ExploreSheet({required this.onAdded});

  @override
  State<_ExploreSheet> createState() => _ExploreSheetState();
}

class _ExploreSheetState extends State<_ExploreSheet> {
  String _selectedCategory = 'All';
  final Set<String> _added = {};

  static const _categories = ['All', 'Strength', 'Hypertrophy', 'PPL', 'Full Body', 'Upper/Lower', 'Beginner'];

  static const _library = <Map<String, dynamic>>[
    // ── Strength ──────────────────────────────────────────────────────────
    {
      'name': 'StrongLifts 5×5',
      'category': 'Strength',
      'difficulty': 'Beginner',
      'days': '3 days/week',
      'description': 'Classic barbell program alternating Workout A and B. Adds weight every session.',
      'primary': ['Chest', 'Back', 'Legs'],
      'secondary': ['Shoulders', 'Core'],
      'exercises': ['Squat', 'Bench Press', 'Barbell Row', 'Overhead Press', 'Deadlift'],
    },
    {
      'name': 'Starting Strength',
      'category': 'Strength',
      'difficulty': 'Beginner',
      'days': '3 days/week',
      'description': 'Mark Rippetoe\'s foundational barbell program. Focus on the big 4 compound lifts.',
      'primary': ['Legs', 'Back', 'Chest'],
      'secondary': ['Shoulders'],
      'exercises': ['Squat', 'Press', 'Deadlift', 'Bench Press', 'Power Clean'],
    },
    {
      'name': '5/3/1 Full Body',
      'category': 'Strength',
      'difficulty': 'Intermediate',
      'days': '4 days/week',
      'description': 'Jim Wendler\'s 5/3/1 structured around the squat, bench, deadlift, and OHP with assistance work.',
      'primary': ['Legs', 'Chest', 'Back', 'Shoulders'],
      'secondary': ['Biceps', 'Triceps'],
      'exercises': ['Squat', 'Bench Press', 'Deadlift', 'Overhead Press', 'Pull-Up', 'Dip'],
    },
    {
      'name': 'Texas Method',
      'category': 'Strength',
      'difficulty': 'Intermediate',
      'days': '3 days/week',
      'description': 'Volume, recovery, and intensity days built around squatting 3x per week.',
      'primary': ['Legs', 'Back', 'Chest'],
      'secondary': ['Shoulders'],
      'exercises': ['Squat', 'Bench Press', 'Deadlift', 'Overhead Press', 'Power Clean'],
    },
    // ── PPL ───────────────────────────────────────────────────────────────
    {
      'name': 'PPL — Push A',
      'category': 'PPL',
      'difficulty': 'Intermediate',
      'days': 'Push day',
      'description': 'Chest, shoulders, and triceps focused push session.',
      'primary': ['Chest', 'Shoulders'],
      'secondary': ['Triceps'],
      'exercises': ['Bench Press', 'Overhead Press', 'Incline Dumbbell Press', 'Lateral Raise', 'Tricep Pushdown', 'Overhead Tricep Extension'],
    },
    {
      'name': 'PPL — Pull A',
      'category': 'PPL',
      'difficulty': 'Intermediate',
      'days': 'Pull day',
      'description': 'Back, rear delts, and biceps pull session.',
      'primary': ['Back', 'Biceps'],
      'secondary': ['Shoulders'],
      'exercises': ['Deadlift', 'Pull-Up', 'Barbell Row', 'Face Pull', 'Hammer Curl', 'Barbell Curl'],
    },
    {
      'name': 'PPL — Legs A',
      'category': 'PPL',
      'difficulty': 'Intermediate',
      'days': 'Leg day',
      'description': 'Squat-focused leg day with quad, hamstring, and calf work.',
      'primary': ['Legs', 'Glutes'],
      'secondary': ['Calves', 'Core'],
      'exercises': ['Squat', 'Romanian Deadlift', 'Leg Press', 'Leg Curl', 'Leg Extension', 'Calf Raise'],
    },
    // ── Upper/Lower ───────────────────────────────────────────────────────
    {
      'name': 'Upper Body A',
      'category': 'Upper/Lower',
      'difficulty': 'Intermediate',
      'days': 'Upper day',
      'description': 'Strength-focused upper day with heavy compounds.',
      'primary': ['Chest', 'Back'],
      'secondary': ['Shoulders', 'Biceps', 'Triceps'],
      'exercises': ['Bench Press', 'Barbell Row', 'Overhead Press', 'Pull-Up', 'Barbell Curl', 'Tricep Pushdown'],
    },
    {
      'name': 'Lower Body A',
      'category': 'Upper/Lower',
      'difficulty': 'Intermediate',
      'days': 'Lower day',
      'description': 'Squat and deadlift lower day with accessory volume.',
      'primary': ['Legs', 'Glutes'],
      'secondary': ['Calves', 'Core'],
      'exercises': ['Squat', 'Deadlift', 'Leg Press', 'Leg Curl', 'Calf Raise', 'Plank'],
    },
    {
      'name': 'Upper Body B',
      'category': 'Upper/Lower',
      'difficulty': 'Intermediate',
      'days': 'Upper day',
      'description': 'Hypertrophy-focused upper day with dumbbell and cable volume.',
      'primary': ['Chest', 'Back', 'Shoulders'],
      'secondary': ['Biceps', 'Triceps'],
      'exercises': ['Incline Dumbbell Press', 'Cable Row', 'Lateral Raise', 'Dumbbell Row', 'Incline Curl', 'Skull Crusher'],
    },
    {
      'name': 'Lower Body B',
      'category': 'Upper/Lower',
      'difficulty': 'Intermediate',
      'days': 'Lower day',
      'description': 'Pause squats, Romanian deadlifts, and isolation accessory work.',
      'primary': ['Legs', 'Glutes'],
      'secondary': ['Calves'],
      'exercises': ['Pause Squat', 'Romanian Deadlift', 'Hack Squat', 'Leg Curl', 'Leg Extension', 'Seated Calf Raise'],
    },
    // ── Hypertrophy ───────────────────────────────────────────────────────
    {
      'name': 'Chest & Triceps',
      'category': 'Hypertrophy',
      'difficulty': 'Intermediate',
      'days': 'Push day',
      'description': 'High-volume chest and triceps session for muscle growth.',
      'primary': ['Chest'],
      'secondary': ['Triceps'],
      'exercises': ['Bench Press', 'Incline Dumbbell Press', 'Cable Fly', 'Dip', 'Tricep Pushdown', 'Skull Crusher'],
    },
    {
      'name': 'Back & Biceps',
      'category': 'Hypertrophy',
      'difficulty': 'Intermediate',
      'days': 'Pull day',
      'description': 'High-volume back and biceps session with compound and isolation work.',
      'primary': ['Back'],
      'secondary': ['Biceps'],
      'exercises': ['Pull-Up', 'Barbell Row', 'Lat Pulldown', 'Cable Row', 'Barbell Curl', 'Hammer Curl'],
    },
    {
      'name': 'Shoulders & Arms',
      'category': 'Hypertrophy',
      'difficulty': 'Intermediate',
      'days': 'Accessory day',
      'description': 'Dedicated shoulder and arm hypertrophy session.',
      'primary': ['Shoulders'],
      'secondary': ['Biceps', 'Triceps'],
      'exercises': ['Overhead Press', 'Lateral Raise', 'Rear Delt Fly', 'Face Pull', 'Barbell Curl', 'Tricep Pushdown'],
    },
    {
      'name': 'Legs Hypertrophy',
      'category': 'Hypertrophy',
      'difficulty': 'Intermediate',
      'days': 'Leg day',
      'description': 'High-volume leg day prioritising quad and hamstring growth.',
      'primary': ['Legs', 'Glutes'],
      'secondary': ['Calves'],
      'exercises': ['Squat', 'Hack Squat', 'Leg Press', 'Romanian Deadlift', 'Leg Curl', 'Leg Extension', 'Seated Calf Raise'],
    },
    // ── Full Body ─────────────────────────────────────────────────────────
    {
      'name': 'Full Body A',
      'category': 'Full Body',
      'difficulty': 'Beginner',
      'days': 'Full body',
      'description': 'Balanced full body session hitting every major muscle group.',
      'primary': ['Chest', 'Back', 'Legs'],
      'secondary': ['Shoulders', 'Core'],
      'exercises': ['Squat', 'Bench Press', 'Barbell Row', 'Overhead Press', 'Romanian Deadlift', 'Plank'],
    },
    {
      'name': 'Full Body B',
      'category': 'Full Body',
      'difficulty': 'Beginner',
      'days': 'Full body',
      'description': 'Alternate with Full Body A for a complete 3-day program.',
      'primary': ['Legs', 'Back', 'Chest'],
      'secondary': ['Shoulders', 'Biceps'],
      'exercises': ['Deadlift', 'Pull-Up', 'Dumbbell Press', 'Goblet Squat', 'Dumbbell Row', 'Barbell Curl'],
    },
    {
      'name': 'Minimalist Full Body',
      'category': 'Full Body',
      'difficulty': 'Beginner',
      'days': '2–3 days/week',
      'description': '5 key movements. Perfect for time-limited training or travel.',
      'primary': ['Chest', 'Back', 'Legs'],
      'secondary': ['Shoulders', 'Core'],
      'exercises': ['Squat', 'Deadlift', 'Bench Press', 'Pull-Up', 'Overhead Press'],
    },
    // ── Beginner ──────────────────────────────────────────────────────────
    {
      'name': 'Beginner Push Day',
      'category': 'Beginner',
      'difficulty': 'Beginner',
      'days': 'Push day',
      'description': 'Simple push session for those just starting out.',
      'primary': ['Chest', 'Shoulders'],
      'secondary': ['Triceps'],
      'exercises': ['Bench Press', 'Overhead Press', 'Push-Up', 'Lateral Raise', 'Tricep Pushdown'],
    },
    {
      'name': 'Beginner Pull Day',
      'category': 'Beginner',
      'difficulty': 'Beginner',
      'days': 'Pull day',
      'description': 'Simple pull session for those just starting out.',
      'primary': ['Back', 'Biceps'],
      'secondary': ['Shoulders'],
      'exercises': ['Lat Pulldown', 'Dumbbell Row', 'Face Pull', 'Barbell Curl', 'Hammer Curl'],
    },
    {
      'name': 'Beginner Leg Day',
      'category': 'Beginner',
      'difficulty': 'Beginner',
      'days': 'Leg day',
      'description': 'Simple leg session to build the movement patterns.',
      'primary': ['Legs', 'Glutes'],
      'secondary': ['Calves', 'Core'],
      'exercises': ['Goblet Squat', 'Leg Press', 'Leg Curl', 'Leg Extension', 'Calf Raise', 'Plank'],
    },
  ];

  List<Map<String, dynamic>> get _filtered => _selectedCategory == 'All'
      ? _library
      : _library.where((r) => r['category'] == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: IronMindTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          width: 36, height: 4,
          decoration: BoxDecoration(color: IronMindTheme.border2, borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EXPLORE ROUTINES',
                    style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
                Text('Tap a routine to preview and add it to My Routines.',
                    style: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 11)),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 18),
              color: IronMindTheme.text2,
            ),
          ]),
        ),
        // Category chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length,
            separatorBuilder: (context, i) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final selected = _selectedCategory == cat;
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? IronMindTheme.accent : IronMindTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? IronMindTheme.accent : IronMindTheme.border2,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.dmMono(
                      color: selected ? IronMindTheme.bg : IronMindTheme.text2,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final r = _filtered[i];
              final alreadyAdded = _added.contains(r['name']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ExploreRoutineCard(
                  routine: r,
                  added: alreadyAdded,
                  onAdd: alreadyAdded ? null : () async {
                    await ApiService.saveRoutine({
                      'name': r['name'],
                      'exercises': List<String>.from(r['exercises'] as List),
                      'primary': List<String>.from(r['primary'] as List),
                      'secondary': List<String>.from(r['secondary'] as List),
                    });
                    setState(() => _added.add(r['name'] as String));
                    widget.onAdded();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${r['name']} added to My Routines'),
                        backgroundColor: IronMindTheme.green,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ExploreRoutineCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final bool added;
  final VoidCallback? onAdd;

  const _ExploreRoutineCard({required this.routine, required this.added, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final primary = List<String>.from(routine['primary'] as List? ?? []);
    final secondary = List<String>.from(routine['secondary'] as List? ?? []);
    final exercises = List<String>.from(routine['exercises'] as List? ?? []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                routine['name'] ?? '',
                style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 16, letterSpacing: 1.2),
              ),
              const SizedBox(height: 2),
              Row(children: [
                IronBadge(routine['difficulty'] ?? '', color: IronMindTheme.accent),
                const SizedBox(width: 6),
                IronBadge(routine['days'] ?? '', color: IronMindTheme.text3),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAdd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: added
                    ? IronMindTheme.green.withValues(alpha: 0.12)
                    : IronMindTheme.accentDim,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: added
                      ? IronMindTheme.green.withValues(alpha: 0.4)
                      : IronMindTheme.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  added ? Icons.check : Icons.add,
                  size: 12,
                  color: added ? IronMindTheme.green : IronMindTheme.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  added ? 'ADDED' : 'ADD',
                  style: GoogleFonts.dmMono(
                    color: added ? IronMindTheme.green : IronMindTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          routine['description'] ?? '',
          style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          exercises.join(' · '),
          style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (primary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, runSpacing: 4, children: [
            ...primary.map((m) => MuscleTag(m, primary: true)),
            ...secondary.map((m) => MuscleTag(m, primary: false)),
          ]),
        ],
      ]),
    );
  }
}

// ── Rest Timer Overlay ────────────────────────────────────────────────────────
class _RestTimerOverlay extends StatelessWidget {
  final int seconds;
  final int total;
  final String exercise;
  final VoidCallback onSkip;

  const _RestTimerOverlay({
    required this.seconds,
    required this.total,
    required this.exercise,
    required this.onSkip,
  });

  String get _label {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? seconds / total : 0.0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1E2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: IronMindTheme.accent.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: _ArcPainter(progress: progress),
                    child: Center(
                      child: Text(
                        _label,
                        style: GoogleFonts.bebasNeue(
                          color: IronMindTheme.accent,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'REST',
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.accent,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (exercise.isNotEmpty)
                        Text(
                          exercise,
                          style: GoogleFonts.dmSans(
                            color: IronMindTheme.text2,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSkip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: IronMindTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: IronMindTheme.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.bebasNeue(
                        color: IronMindTheme.accent,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 4;
    const strokeWidth = 3.5;

    final trackPaint = Paint()
      ..color = IronMindTheme.accent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = IronMindTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Bar Option Tile ───────────────────────────────────────────────────────────

class _BarOptionTile extends StatelessWidget {
  final bool selected;
  final String name;
  final String shortName;
  final double? weightLb;
  final String benefit;
  final String bestFor;
  final VoidCallback onTap;

  const _BarOptionTile({
    required this.selected,
    required this.name,
    required this.shortName,
    required this.weightLb,
    required this.benefit,
    required this.bestFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? IronMindTheme.accent.withValues(alpha: 0.08)
              : IronMindTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? IronMindTheme.accent.withValues(alpha: 0.5)
                : IronMindTheme.border2,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.dmSans(
                          color: selected
                              ? IronMindTheme.textPrimary
                              : IronMindTheme.text2,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (weightLb != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: IronMindTheme.surface2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${weightLb!.toInt()} lb',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.text3,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    benefit,
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.text3,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bestFor,
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.accent.withValues(alpha: 0.7),
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 10, top: 2),
                child: Icon(Icons.check_circle_rounded,
                    color: IronMindTheme.accent, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _roundToNearest(double value, double step) =>
    (value / step).round() * step;

// ── Load Calculator Sheet ─────────────────────────────────────────────────────

class _LoadCalcSheet extends StatefulWidget {
  final String exerciseName;
  final BarType? barType;
  const _LoadCalcSheet({required this.exerciseName, this.barType});

  @override
  State<_LoadCalcSheet> createState() => _LoadCalcSheetState();
}

class _LoadCalcSheetState extends State<_LoadCalcSheet> {
  double? _est1rm;
  bool _loading = true;
  late BarType? _barType;
  double _pct = 0.80;

  static const _pctSteps = [0.50, 0.575, 0.60, 0.65, 0.70, 0.75, 0.80,
    0.85, 0.875, 0.90, 0.925, 0.95];

  @override
  void initState() {
    super.initState();
    _barType = widget.barType;
    _fetchPr();
  }

  Future<void> _fetchPr() async {
    try {
      final prs = await ApiService.getPRList();
      final key = widget.exerciseName.trim().toLowerCase();
      final matches = prs.where(
          (p) => (p['exercise'] as String? ?? '').toLowerCase() == key);
      if (matches.isNotEmpty) {
        final m = matches.first;
        final e1rm = (m['estimated_1rm'] as num?)?.toDouble()
            ?? ApiService.calculate1RM(
                (m['weight'] as num?)?.toDouble() ?? 0,
                (m['reps'] as num?)?.toInt() ?? 1);
        if (mounted) setState(() => _est1rm = e1rm);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double get _barWeight =>
      _barType != null ? barSpecFor(_barType!).weightLb : 45.0;

  double get _targetWeight =>
      _est1rm != null ? _roundToNearest(_est1rm! * _pct, 2.5) : 0;

  double get _plates => (_targetWeight - _barWeight).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: IronMindTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: IronMindTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text('LOAD CALCULATOR', style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                  Text(
                    widget.exerciseName.isNotEmpty
                        ? widget.exerciseName
                        : 'Exercise',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary, fontSize: 24, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),

                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_est1rm == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: IronMindTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: IronMindTheme.border2),
                      ),
                      child: Text(
                        'No PR found for this exercise. Log a set to auto-calculate, or record a PR manually.',
                        style: GoogleFonts.dmSans(
                          color: IronMindTheme.text2, fontSize: 12, height: 1.5),
                      ),
                    )
                  else ...[
                    // e1RM badge
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: IronMindTheme.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: IronMindTheme.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(children: [
                          Text('e1RM', style: GoogleFonts.dmMono(
                            color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1)),
                          Text('${_est1rm!.round()} lb', style: GoogleFonts.bebasNeue(
                            color: IronMindTheme.green, fontSize: 22)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // Bar type selector row
                    Text('BAR', style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _CalcBarChip(
                          label: 'Stiff 45',
                          selected: _barType == null,
                          onTap: () => setState(() => _barType = null),
                        ),
                        ...BarType.values.map((t) {
                          final s = barSpecFor(t);
                          return _CalcBarChip(
                            label: '${s.shortName} ${s.weightLb.toInt()}',
                            selected: _barType == t,
                            onTap: () => setState(() => _barType = t),
                          );
                        }),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Percentage slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('INTENSITY', style: GoogleFonts.dmMono(
                          color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                        Text('${(_pct * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.bebasNeue(
                            color: IronMindTheme.accent, fontSize: 20)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: IronMindTheme.accent,
                        inactiveTrackColor: IronMindTheme.border2,
                        thumbColor: IronMindTheme.accent,
                        overlayColor: IronMindTheme.accent.withValues(alpha: 0.1),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        min: 0.50,
                        max: 1.05,
                        divisions: 22,
                        value: _pct,
                        onChanged: (v) => setState(() => _pct = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Result card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: IronMindTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: IronMindTheme.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ResultCell('TOTAL', '${_targetWeight.toInt()} lb',
                            IronMindTheme.textPrimary),
                          Container(width: 1, height: 40, color: IronMindTheme.border2),
                          _ResultCell('BAR', '${_barWeight.toInt()} lb',
                            IronMindTheme.text3),
                          Container(width: 1, height: 40, color: IronMindTheme.border2),
                          _ResultCell('PLATES', '${_plates.toInt()} lb',
                            IronMindTheme.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick-select percentage grid
                    Text('QUICK SELECT', style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _pctSteps.map((p) {
                        final w = _roundToNearest(_est1rm! * p, 2.5);
                        final isSelected = (_pct - p).abs() < 0.001;
                        return GestureDetector(
                          onTap: () => setState(() => _pct = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? IronMindTheme.accent.withValues(alpha: 0.12)
                                  : IronMindTheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? IronMindTheme.accent
                                    : IronMindTheme.border2,
                              ),
                            ),
                            child: Column(children: [
                              Text('${(p * 100).toStringAsFixed(p * 100 == (p * 100).roundToDouble() ? 0 : 1)}%',
                                style: GoogleFonts.dmMono(
                                  color: isSelected
                                      ? IronMindTheme.accent
                                      : IronMindTheme.text2,
                                  fontSize: 10)),
                              Text('${w.toInt()} lb',
                                style: GoogleFonts.bebasNeue(
                                  color: isSelected
                                      ? IronMindTheme.textPrimary
                                      : IronMindTheme.text3,
                                  fontSize: 14)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ResultCell(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: GoogleFonts.dmMono(
        color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 20)),
    ],
  );
}

class _CalcBarChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CalcBarChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? IronMindTheme.accent.withValues(alpha: 0.12)
            : IronMindTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? IronMindTheme.accent : IronMindTheme.border2,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label, style: GoogleFonts.dmMono(
        color: selected ? IronMindTheme.accent : IronMindTheme.text2,
        fontSize: 10)),
    ),
  );
}

// ── Scheme Picker Sheet ───────────────────────────────────────────────────────

class _SchemePickerSheet extends StatefulWidget {
  final String exerciseName;
  final void Function(_SchemePreset scheme, double? est1rm) onApply;

  const _SchemePickerSheet({required this.exerciseName, required this.onApply});

  @override
  State<_SchemePickerSheet> createState() => _SchemePickerSheetState();
}

class _SchemePickerSheetState extends State<_SchemePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  double? _est1rm;
  bool _loadingPr = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _fetchPr();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchPr() async {
    try {
      final prs = await ApiService.getPRList();
      final key = widget.exerciseName.trim().toLowerCase();
      final matches = prs.where(
        (p) => (p['exercise'] as String? ?? '').toLowerCase() == key,
      );
      if (matches.isNotEmpty) {
        final match = matches.first;
        final e1rm = (match['estimated_1rm'] as num?)?.toDouble()
            ?? ApiService.calculate1RM(
                (match['weight'] as num?)?.toDouble() ?? 0,
                (match['reps'] as num?)?.toInt() ?? 1);
        if (mounted) setState(() => _est1rm = e1rm);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingPr = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: IronMindTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: IronMindTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SET SCHEME',
                          style: GoogleFonts.dmMono(
                            color: IronMindTheme.text3,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.exerciseName.isNotEmpty
                              ? widget.exerciseName
                              : 'Exercise',
                          style: GoogleFonts.bebasNeue(
                            color: IronMindTheme.textPrimary,
                            fontSize: 22,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_loadingPr && _est1rm != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: IronMindTheme.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: IronMindTheme.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'e1RM',
                            style: GoogleFonts.dmMono(
                              color: IronMindTheme.text3,
                              fontSize: 8,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${_est1rm!.round()} lb',
                            style: GoogleFonts.bebasNeue(
                              color: IronMindTheme.green,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            TabBar(
              controller: _tab,
              labelColor: IronMindTheme.accent,
              unselectedLabelColor: IronMindTheme.text3,
              indicatorColor: IronMindTheme.accent,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: GoogleFonts.dmMono(fontSize: 11, letterSpacing: 1),
              tabs: const [
                Tab(text: 'STRENGTH'),
                Tab(text: 'HYPERTROPHY'),
                Tab(text: 'PEAKING'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _SchemeList(
                    schemes: _strengthSchemes,
                    est1rm: _est1rm,
                    onApply: (s) {
                      Navigator.pop(context);
                      widget.onApply(s, _est1rm);
                    },
                  ),
                  _SchemeList(
                    schemes: _hypertrophySchemes,
                    est1rm: _est1rm,
                    onApply: (s) {
                      Navigator.pop(context);
                      widget.onApply(s, _est1rm);
                    },
                  ),
                  _SchemeList(
                    schemes: _peakingSchemes,
                    est1rm: _est1rm,
                    onApply: (s) {
                      Navigator.pop(context);
                      widget.onApply(s, _est1rm);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemeList extends StatelessWidget {
  final List<_SchemePreset> schemes;
  final double? est1rm;
  final void Function(_SchemePreset) onApply;

  const _SchemeList({
    required this.schemes,
    required this.est1rm,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: schemes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = schemes[i];
        final suggestedWeight = (est1rm != null && s.suggestedPct != null)
            ? _roundToNearest(est1rm! * s.suggestedPct!, 2.5)
            : null;
        return GestureDetector(
          onTap: () => onApply(s),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: IronMindTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IronMindTheme.border2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.label,
                            style: GoogleFonts.bebasNeue(
                              color: IronMindTheme.textPrimary,
                              fontSize: 20,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: IronMindTheme.surface2,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              s.category,
                              style: GoogleFonts.dmMono(
                                color: IronMindTheme.text3,
                                fontSize: 8,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${s.repsPerSet.length} sets: ${s.repsPerSet.map((r) => r == 1 ? '1 rep' : '$r reps').join(' → ')}',
                        style: GoogleFonts.dmSans(
                          color: IronMindTheme.text2,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (s.suggestedPct != null)
                      Text(
                        '${(s.suggestedPct! * 100).toStringAsFixed(s.suggestedPct! * 100 == (s.suggestedPct! * 100).roundToDouble() ? 0 : 1)}% 1RM',
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.accent,
                          fontSize: 11,
                        ),
                      ),
                    if (suggestedWeight != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '~${suggestedWeight.toInt()} lb',
                        style: GoogleFonts.bebasNeue(
                          color: IronMindTheme.green,
                          fontSize: 16,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: IronMindTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                IronMindTheme.accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'APPLY',
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.accent,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
