import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/exercise_db_service.dart';
import '../services/supabase_service.dart';

class LogWorkoutDialog extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>) onWorkoutLogged;

  const LogWorkoutDialog({
    required this.userId,
    required this.onWorkoutLogged,
  });

  @override
  State<LogWorkoutDialog> createState() => _LogWorkoutDialogState();
}

class _LogWorkoutDialogState extends State<LogWorkoutDialog> {
  late TextEditingController _exerciseController;
  late TextEditingController _muscleController;
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late TextEditingController _setsController;

  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _exerciseSuggestions = [];

  @override
  void initState() {
    super.initState();
    _exerciseController = TextEditingController();
    _muscleController = TextEditingController();
    _weightController = TextEditingController();
    _repsController = TextEditingController();
    _setsController = TextEditingController();
  }

  @override
  void dispose() {
    _exerciseController.dispose();
    _muscleController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  Future<void> _searchExercises(String query) async {
    if (query.isEmpty) {
      setState(() => _exerciseSuggestions = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final exercises = await ExerciseDbService.searchExercises(query);
      setState(() => _exerciseSuggestions = exercises);
    } catch (e) {
      print('Error searching exercises: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectExercise(Map<String, dynamic> exercise) {
    setState(() {
      _exerciseController.text = exercise['name'] ?? '';
      _muscleController.text = exercise['target'] ?? '';
      _exerciseSuggestions = [];
    });
  }

  Future<void> _logWorkout() async {
    if (_exerciseController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _repsController.text.isEmpty ||
        _setsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final workout = await SupabaseService().logWorkout(
        userId: widget.userId,
        exerciseName: _exerciseController.text,
        targetMuscle: _muscleController.text,
        weight: int.parse(_weightController.text),
        reps: int.parse(_repsController.text),
        sets: int.parse(_setsController.text),
        date: DateTime.now(),
      );

      widget.onWorkoutLogged(workout);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Workout logged!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: IronMindTheme.surface,
    title: Text(
      'Log Workout',
      style: GoogleFonts.bebasNeue(
        color: IronMindTheme.accent,
        fontSize: 24,
        letterSpacing: 2,
      ),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Exercise search field
          TextField(
            controller: _exerciseController,
            onChanged: _searchExercises,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search Exercise',
              hintStyle: const TextStyle(color: IronMindTheme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: IronMindTheme.border),
              ),
              filled: true,
              fillColor: IronMindTheme.surface2,
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            IronMindTheme.accent,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          if (_exerciseSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: IronMindTheme.surface2,
                border: Border.all(color: IronMindTheme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _exerciseSuggestions.length,
                itemBuilder: (context, index) {
                  final exercise = _exerciseSuggestions[index];
                  return ListTile(
                    title: Text(
                      exercise['name'] ?? '',
                      style: const TextStyle(
                        color: IronMindTheme.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      exercise['target'] ?? '',
                      style: const TextStyle(
                        color: IronMindTheme.text3,
                        fontSize: 10,
                      ),
                    ),
                    onTap: () => _selectExercise(exercise),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Muscle/Target field
          TextField(
            controller: _muscleController,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Target Muscle',
              hintStyle: const TextStyle(color: IronMindTheme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: IronMindTheme.border),
              ),
              filled: true,
              fillColor: IronMindTheme.surface2,
            ),
          ),
          const SizedBox(height: 12),
          // Weight field
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Weight (lbs)',
              hintStyle: const TextStyle(color: IronMindTheme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: IronMindTheme.border),
              ),
              filled: true,
              fillColor: IronMindTheme.surface2,
            ),
          ),
          const SizedBox(height: 12),
          // Reps field
          TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Reps',
              hintStyle: const TextStyle(color: IronMindTheme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: IronMindTheme.border),
              ),
              filled: true,
              fillColor: IronMindTheme.surface2,
            ),
          ),
          const SizedBox(height: 12),
          // Sets field
          TextField(
            controller: _setsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Sets',
              hintStyle: const TextStyle(color: IronMindTheme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: IronMindTheme.border),
              ),
              filled: true,
              fillColor: IronMindTheme.surface2,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel', style: TextStyle(color: IronMindTheme.text2)),
      ),
      ElevatedButton(
        onPressed: _isLoading ? null : _logWorkout,
        style: ElevatedButton.styleFrom(
          backgroundColor: IronMindTheme.accent,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(IronMindTheme.bg),
                ),
              )
            : const Text(
                'Log',
                style: TextStyle(color: IronMindTheme.bg),
              ),
      ),
    ],
  );
}
