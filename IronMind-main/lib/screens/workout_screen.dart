import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final logs = await ApiService.getLogs();
    final routines = await ApiService.getRoutines();
    setState(() {
      _logs = logs;
      _routines = routines;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: IronMindColors.accent))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLogTab(),
                        _buildRoutinesTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'IRON',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.accent,
                        fontSize: 24,
                        letterSpacing: 2)),
                TextSpan(
                    text: 'MIND',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textPrimary,
                        fontSize: 24,
                        letterSpacing: 2)),
                TextSpan(
                    text: '  •  WORKOUT',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textSecondary,
                        fontSize: 20,
                        letterSpacing: 2)),
              ]),
            ),
          ),
          IconButton(
            onPressed: _show1RMCalculator,
            icon: const Icon(Icons.calculate, size: 24),
            color: IronMindColors.accent,
            tooltip: '1RM Calculator',
          ),
          IconButton(
            onPressed: _showAIWorkoutGenerator,
            icon: const Icon(Icons.auto_awesome, size: 24),
            color: IronMindColors.accent,
            tooltip: 'AI Workout Generator',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: IronMindColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindColors.border),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: IronMindColors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 15, letterSpacing: 1.5),
          labelColor: IronMindColors.background,
          unselectedLabelColor: IronMindColors.textSecondary,
          padding: const EdgeInsets.all(4),
          tabs: const [
            Tab(text: 'LOG'),
            Tab(text: 'ROUTINES'),
          ],
        ),
      ),
    );
  }

  // ─── LOG TAB ───────────────────────────────────

  Widget _buildLogTab() {
    if (_logs.isEmpty) {
      return _buildEmptyLogState();
    }
    return RefreshIndicator(
      color: IronMindColors.accent,
      backgroundColor: IronMindColors.surface,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (ctx, i) => _LogCard(
          log: _logs[i],
          onDelete: () async {
            await ApiService.deleteLog(_logs[i]['id']);
            _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyLogState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏋️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text('NO WORKOUTS YET',
              style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textSecondary,
                  fontSize: 24,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Start your first workout below',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textMuted, fontSize: 14)),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: ElevatedButton(
              onPressed: _startWorkout,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: Text('START WORKOUT',
                  style:
                      GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ROUTINES TAB ──────────────────────────────

  Widget _buildRoutinesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startWorkout,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text('START WORKOUT',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 18, letterSpacing: 1.5)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _IconButton(
                icon: Icons.add,
                onTap: _createRoutine,
                tooltip: 'Create Routine',
              ),
            ],
          ),
        ),
        Expanded(
          child: _routines.isEmpty
              ? _buildEmptyRoutinesState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _routines.length,
                  itemBuilder: (ctx, i) => _RoutineCard(
                    routine: _routines[i],
                    onStart: () => _startWithRoutine(_routines[i]),
                    onDelete: () async {
                      await ApiService.deleteRoutine(_routines[i]['id']);
                      _loadData();
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyRoutinesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.view_list_rounded,
              color: IronMindColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text('NO ROUTINES YET',
              style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textSecondary,
                  fontSize: 22,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Create a routine to speed up your logging',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _createRoutine,
            icon: const Icon(Icons.add, color: IronMindColors.accent),
            label: Text('CREATE ROUTINE',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.accent,
                    fontSize: 16,
                    letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  // ─── ACTIONS ───────────────────────────────────

  void _startWorkout() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => const ActiveWorkoutScreen(routine: null),
        ))
        .then((_) => _loadData());
  }

  void _startWithRoutine(Map<String, dynamic> routine) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(routine: routine),
        ))
        .then((_) => _loadData());
  }

  void _createRoutine() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRoutineSheet(onSaved: _loadData),
    );
  }

  void _show1RMCalculator() {
    double weight = 0;
    int reps = 1;
    String formula = 'Epley';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: IronMindColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1RM CALCULATOR',
                  style: GoogleFonts.bebasNeue(
                      color: IronMindColors.textPrimary,
                      fontSize: 22,
                      letterSpacing: 2)),
              const SizedBox(height: 20),
              TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (lbs)',
                  hintText: 'Enter weight lifted',
                ),
                onChanged: (v) => weight = double.tryParse(v) ?? 0,
                style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  hintText: 'Number of reps',
                ),
                onChanged: (v) => reps = int.tryParse(v) ?? 1,
                style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: formula,
                decoration: const InputDecoration(
                  labelText: 'Formula',
                ),
                items: ['Epley', 'Brzycki', 'McGlothin', 'Lombardi']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setSt(() => formula = v!),
                style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: IronMindColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: IronMindColors.border),
                ),
                child: Column(
                  children: [
                    Text('ESTIMATED 1RM',
                        style: GoogleFonts.bebasNeue(
                            color: IronMindColors.textSecondary,
                            fontSize: 16,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),
                    Text('${ApiService.calculate1RM(weight, reps, formula).toStringAsFixed(1)} lbs',
                        style: GoogleFonts.dmMono(
                            color: IronMindColors.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: IronMindColors.border),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text('CLOSE',
                          style: GoogleFonts.bebasNeue(
                              color: IronMindColors.textSecondary,
                              fontSize: 16,
                              letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAIWorkoutGenerator() {
    String goal = 'Strength';
    String experience = 'Intermediate';
    int duration = 45;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: IronMindColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI WORKOUT GENERATOR',
                  style: GoogleFonts.bebasNeue(
                      color: IronMindColors.textPrimary,
                      fontSize: 22,
                      letterSpacing: 2)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: goal,
                decoration: const InputDecoration(
                  labelText: 'Training Goal',
                ),
                items: ['Strength', 'Hypertrophy', 'Endurance', 'Power', 'General Fitness']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setSt(() => goal = v!),
                style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: experience,
                decoration: const InputDecoration(
                  labelText: 'Experience Level',
                ),
                items: ['Beginner', 'Intermediate', 'Advanced']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setSt(() => experience = v!),
                style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: 'Workout length',
                ),
                controller: TextEditingController(text: duration.toString()),
                onChanged: (v) => duration = int.tryParse(v) ?? 45,
                style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _generateWorkout(goal, experience, duration),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48)),
                child: Text('GENERATE WORKOUT',
                    style: GoogleFonts.bebasNeue(
                        fontSize: 18, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: IronMindColors.border),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text('CLOSE',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textSecondary,
                        fontSize: 16,
                        letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateWorkout(String goal, String experience, int duration) {
    Navigator.of(context).pop(); // Close the generator modal

    // Generate workout based on parameters
    final workout = _createWorkoutPlan(goal, experience, duration);

    // Navigate to active workout screen with generated workout
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(routine: workout),
      ),
    );
  }

  Map<String, dynamic> _createWorkoutPlan(String goal, String experience, int duration) {
    final exercises = <String>[];

    // Base exercises by goal
    final baseExercises = {
      'Strength': ['Bench Press', 'Squat', 'Deadlift', 'Overhead Press', 'Barbell Row'],
      'Hypertrophy': ['Bench Press', 'Incline Dumbbell Press', 'Squat', 'Leg Press', 'Lat Pulldown', 'Bicep Curl', 'Tricep Extension'],
      'Endurance': ['Push-ups', 'Bodyweight Squats', 'Plank', 'Burpees', 'Mountain Climbers', 'Jumping Jacks'],
      'Power': ['Clean and Jerk', 'Snatch', 'Box Jumps', 'Medicine Ball Throws', 'Kettlebell Swings'],
      'General Fitness': ['Bench Press', 'Squat', 'Pull-ups', 'Deadlift', 'Overhead Press', 'Lunges'],
    };

    // Adjust exercise count based on experience and duration
    final baseCount = experience == 'Beginner' ? 3 : experience == 'Intermediate' ? 4 : 5;
    final exerciseCount = (duration / 10).clamp(baseCount, baseCount + 2).toInt();

    final goalExercises = baseExercises[goal] ?? baseExercises['General Fitness']!;
    exercises.addAll(goalExercises.take(exerciseCount));

    return {
      'name': '$goal Workout ($experience)',
      'exercises': exercises,
      'goal': goal,
      'experience': experience,
      'duration': duration,
    };
  }
}

// ─────────────────────────────────────────────────────────────
//  ACTIVE WORKOUT SCREEN
// ─────────────────────────────────────────────────────────────

class ActiveWorkoutScreen extends StatefulWidget {
  final Map<String, dynamic>? routine;
  const ActiveWorkoutScreen({super.key, required this.routine});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final List<Map<String, dynamic>> _exercises = [];
  final _workoutNameController = TextEditingController();
  late Stopwatch _stopwatch;
  late Timer _timer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

    if (widget.routine != null) {
      _workoutNameController.text = widget.routine!['name'] ?? '';
      final exercises =
          List<String>.from(widget.routine!['exercises'] ?? []);
      for (final name in exercises) {
        _addExercise(name);
      }
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    _workoutNameController.dispose();
    super.dispose();
  }

  void _addExercise(String name) {
    setState(() {
      _exercises.add({
        'name': name,
        'sets': <Map<String, dynamic>>[
          {'weight': '', 'reps': '', 'done': false}
        ],
      });
    });
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      _exercises[exerciseIndex]['sets'].add(
        {'weight': '', 'reps': '', 'done': false},
      );
    });
  }

  Future<void> _finishWorkout() async {
    setState(() => _saving = true);
    final log = {
      'name': _workoutNameController.text.isEmpty
          ? 'Workout ${DateTime.now().toString().substring(0, 10)}'
          : _workoutNameController.text,
      'duration': _stopwatch.elapsed.inMinutes,
      'exercises': _exercises
          .map((e) => {
                'name': e['name'],
                'sets': (e['sets'] as List)
                    .where((s) => s['done'] == true)
                    .toList(),
              })
          .where((e) => (e['sets'] as List).isNotEmpty)
          .toList(),
    };
    await ApiService.saveLog(log);

    // Check PRs for each exercise
    for (final ex in log['exercises'] as List) {
      for (final set in ex['sets'] as List) {
        final weight = double.tryParse(set['weight'].toString()) ?? 0;
        final reps = int.tryParse(set['reps'].toString()) ?? 0;
        if (weight > 0 && reps > 0) {
          await ApiService.checkAndSavePR(ex['name'], weight, reps);
        }
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  String get _elapsed {
    final e = _stopwatch.elapsed;
    return '${e.inHours.toString().padLeft(2, '0')}:'
        '${(e.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(e.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      appBar: AppBar(
        backgroundColor: IronMindColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close, color: IronMindColors.textSecondary),
          onPressed: () => _confirmDiscard(),
        ),
        title: Text(_elapsed,
            style: GoogleFonts.dmMono(
                color: IronMindColors.accent, fontSize: 18)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _finishWorkout,
            child: Text('FINISH',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.success,
                    fontSize: 18,
                    letterSpacing: 1.5)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _workoutNameController,
              style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 20,
                  letterSpacing: 1),
              decoration: InputDecoration(
                hintText: 'Workout name (optional)',
                hintStyle: GoogleFonts.bebasNeue(
                    color: IronMindColors.textMuted,
                    fontSize: 20,
                    letterSpacing: 1),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
              children: [
                ..._exercises.asMap().entries.map(
                      (entry) => _ExerciseBlock(
                        exerciseData: entry.value,
                        index: entry.key,
                        onAddSet: () => _addSet(entry.key),
                        onUpdate: () => setState(() {}),
                      ),
                    ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickExercise,
                  icon: const Icon(Icons.add,
                      color: IronMindColors.accent, size: 18),
                  label: Text('ADD EXERCISE',
                      style: GoogleFonts.bebasNeue(
                          color: IronMindColors.accent,
                          fontSize: 16,
                          letterSpacing: 1.5)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: IronMindColors.accent),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickExercise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExercisePickerSheet(
        onSelected: (name) => _addExercise(name),
      ),
    );
  }

  void _confirmDiscard() {
    if (_exercises.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: IronMindColors.surface,
        title: Text('Discard workout?',
            style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary, fontSize: 22)),
        content: Text('Your progress will not be saved.',
            style:
                GoogleFonts.dmSans(color: IronMindColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('KEEP GOING',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.accent,
                    fontSize: 16,
                    letterSpacing: 1)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('DISCARD',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.alert,
                    fontSize: 16,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EXERCISE BLOCK (within active workout)
// ─────────────────────────────────────────────────────────────

class _ExerciseBlock extends StatelessWidget {
  final Map<String, dynamic> exerciseData;
  final int index;
  final VoidCallback onAddSet;
  final VoidCallback onUpdate;

  const _ExerciseBlock({
    required this.exerciseData,
    required this.index,
    required this.onAddSet,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final sets = exerciseData['sets'] as List<Map<String, dynamic>>;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(exerciseData['name'],
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 18,
                    letterSpacing: 1)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                    width: 28,
                    child: Text('SET',
                        style: GoogleFonts.dmMono(
                            color: IronMindColors.textMuted, fontSize: 11))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('WEIGHT (lbs)',
                        style: GoogleFonts.dmMono(
                            color: IronMindColors.textMuted, fontSize: 11))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('REPS',
                        style: GoogleFonts.dmMono(
                            color: IronMindColors.textMuted, fontSize: 11))),
                const SizedBox(width: 36),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...sets.asMap().entries.map((entry) => _SetRow(
                setNumber: entry.key + 1,
                setData: entry.value,
                onUpdate: onUpdate,
              )),
          TextButton.icon(
            onPressed: onAddSet,
            icon: const Icon(Icons.add, size: 16, color: IronMindColors.accent),
            label: Text('ADD SET',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.accent,
                    fontSize: 13,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int setNumber;
  final Map<String, dynamic> setData;
  final VoidCallback onUpdate;

  const _SetRow(
      {required this.setNumber,
      required this.setData,
      required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('$setNumber',
                style: GoogleFonts.dmMono(
                    color: IronMindColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setData['weight'] = v,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: GoogleFonts.dmMono(
                  color: IronMindColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmMono(
                    color: IronMindColors.textMuted, fontSize: 15),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setData['reps'] = v,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.dmMono(
                  color: IronMindColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmMono(
                    color: IronMindColors.textMuted, fontSize: 15),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StatefulBuilder(
            builder: (ctx, setSt) => GestureDetector(
              onTap: () {
                setSt(() => setData['done'] = !(setData['done'] ?? false));
                onUpdate();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: setData['done'] == true
                      ? IronMindColors.success
                      : IronMindColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: setData['done'] == true
                        ? IronMindColors.success
                        : IronMindColors.border,
                  ),
                ),
                child: setData['done'] == true
                    ? const Icon(Icons.check,
                        color: IronMindColors.background, size: 16)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EXERCISE PICKER SHEET (ExerciseDB)
// ─────────────────────────────────────────────────────────────

class ExercisePickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelected;
  const ExercisePickerSheet({super.key, required this.onSelected});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String _selectedBodyPart = 'All';
  Timer? _debounce;

  final List<String> _bodyParts = [
    'All', 'chest', 'back', 'shoulders', 'upper arms',
    'upper legs', 'lower legs', 'waist'
  ];

  @override
  void initState() {
    super.initState();
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    setState(() => _searching = true);
    final results = await ApiService.searchExercises('');
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    List<Map<String, dynamic>> results;
    if (query.isEmpty && _selectedBodyPart == 'All') {
      results = await ApiService.searchExercises('');
    } else if (_selectedBodyPart != 'All') {
      results = await ApiService.getExercisesByBodyPart(_selectedBodyPart);
      if (query.isNotEmpty) {
        results = results
            .where((e) => (e['name'] as String)
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();
      }
    } else {
      results = await ApiService.searchExercises(query);
    }
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: IronMindColors.border,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('ADD EXERCISE',
                  style: GoogleFonts.bebasNeue(
                      color: IronMindColors.textPrimary,
                      fontSize: 22,
                      letterSpacing: 2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: Icon(Icons.search, color: IronMindColors.textMuted),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _bodyParts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final bp = _bodyParts[i];
                    final sel = bp == _selectedBodyPart;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedBodyPart = bp);
                        _search(_searchController.text);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel
                              ? IronMindColors.accent
                              : IronMindColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? IronMindColors.accent
                                  : IronMindColors.border),
                        ),
                        child: Text(
                          bp,
                          style: GoogleFonts.dmSans(
                            color: sel
                                ? IronMindColors.background
                                : IronMindColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: IronMindColors.accent))
                  : _results.isEmpty
                      ? Center(
                          child: Text('No exercises found',
                              style: GoogleFonts.dmSans(
                                  color: IronMindColors.textSecondary)))
                      : ListView.builder(
                          controller: controller,
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final ex = _results[i];
                            return ListTile(
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelected(ex['name'] as String);
                              },
                              title: Text(
                                _capitalize(ex['name'] as String),
                                style: GoogleFonts.dmSans(
                                    color: IronMindColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${_capitalize(ex['target'] ?? '')}  •  ${ex['equipment'] ?? ''}',
                                style: GoogleFonts.dmSans(
                                    color: IronMindColors.textMuted,
                                    fontSize: 12),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: IronMindColors.accentDim,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _capitalize(ex['bodyPart'] ?? ''),
                                  style: GoogleFonts.dmMono(
                                      color: IronMindColors.accent,
                                      fontSize: 10),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────
//  CREATE ROUTINE SHEET
// ─────────────────────────────────────────────────────────────

class CreateRoutineSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const CreateRoutineSheet({super.key, required this.onSaved});

  @override
  State<CreateRoutineSheet> createState() => _CreateRoutineSheetState();
}

class _CreateRoutineSheetState extends State<CreateRoutineSheet> {
  final _nameController = TextEditingController();
  final List<String> _exercises = [];
  bool _saving = false;

  void _pickExercise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExercisePickerSheet(
        onSelected: (name) => setState(() => _exercises.add(name)),
      ),
    );
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add a name and at least one exercise',
              style: GoogleFonts.dmSans()),
          backgroundColor: IronMindColors.alert,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await ApiService.saveRoutine({
      'name': _nameController.text.trim(),
      'exercises': _exercises,
    });
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: IronMindColors.border,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('CREATE ROUTINE',
                      style: GoogleFonts.bebasNeue(
                          color: IronMindColors.textPrimary,
                          fontSize: 22,
                          letterSpacing: 2)),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text('SAVE',
                        style: GoogleFonts.bebasNeue(
                            color: IronMindColors.success,
                            fontSize: 18,
                            letterSpacing: 1.5)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Routine Name',
                  hintText: 'e.g. Push Day',
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  ..._exercises.asMap().entries.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: IronMindColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: IronMindColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.drag_handle,
                                color: IronMindColors.textMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _capitalize(e.value),
                                style: GoogleFonts.dmSans(
                                    color: IronMindColors.textPrimary,
                                    fontSize: 14),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                  () => _exercises.removeAt(e.key)),
                              child: const Icon(Icons.close,
                                  color: IronMindColors.textMuted, size: 18),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickExercise,
                    icon: const Icon(Icons.add,
                        color: IronMindColors.accent, size: 18),
                    label: Text('ADD EXERCISE',
                        style: GoogleFonts.bebasNeue(
                            color: IronMindColors.accent,
                            fontSize: 16,
                            letterSpacing: 1.5)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: IronMindColors.accent),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─────────────────────────────────────────────────────────────
//  REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback onDelete;
  const _LogCard({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final exercises = List<Map<String, dynamic>>.from(log['exercises'] ?? []);
    final date = log['timestamp'] != null
        ? DateTime.tryParse(log['timestamp'])?.toLocal()
        : null;
    final dateStr = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : '';

    return Dismissible(
      key: Key(log['id'] ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: IronMindColors.alert,
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(log['name'] ?? 'Workout',
                      style: GoogleFonts.bebasNeue(
                          color: IronMindColors.textPrimary,
                          fontSize: 18,
                          letterSpacing: 1)),
                ),
                Text(dateStr,
                    style: GoogleFonts.dmMono(
                        color: IronMindColors.textMuted, fontSize: 11)),
              ],
            ),
            if (log['duration'] != null) ...[
              const SizedBox(height: 4),
              Text('${log['duration']} min',
                  style: GoogleFonts.dmSans(
                      color: IronMindColors.textSecondary, fontSize: 12)),
            ],
            if (exercises.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: exercises
                    .take(4)
                    .map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: IronMindColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: IronMindColors.border),
                          ),
                          child: Text(
                            e['name'] ?? '',
                            style: GoogleFonts.dmSans(
                                color: IronMindColors.textSecondary,
                                fontSize: 11),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onStart;
  final VoidCallback onDelete;
  const _RoutineCard(
      {required this.routine, required this.onStart, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final exercises = List<String>.from(routine['exercises'] ?? []);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routine['name'] ?? 'Routine',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textPrimary,
                        fontSize: 18,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('${exercises.length} exercises',
                    style: GoogleFonts.dmSans(
                        color: IronMindColors.textSecondary, fontSize: 12)),
                if (exercises.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    exercises.take(3).join(' · ') +
                        (exercises.length > 3 ? ' ...' : ''),
                    style: GoogleFonts.dmSans(
                        color: IronMindColors.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(72, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text('START',
                    style:
                        GoogleFonts.bebasNeue(fontSize: 15, letterSpacing: 1)),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline,
                    color: IronMindColors.textMuted, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconButton(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: IronMindColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: IronMindColors.border),
          ),
          child: Icon(icon, color: IronMindColors.accent, size: 22),
        ),
      ),
    );
  }
}
