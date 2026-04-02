import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'local_store.dart';
import 'usda_food_service.dart';

class ApiService {
  static const String _logsKey = 'workout_logs';
  static const String _prsKey = 'personal_records';
  static const String _wellnessKey = 'wellness_data';
  static const String _routinesKey = 'routines';
  static const String _profileKey = 'user_profile';
  static const String _goalsKey = 'strength_goals';
  static const String _bodyweightKey = 'bodyweight_logs';
  static const String _measurementsKey = 'measurements_logs';
  static const String _nutritionTargetsKey = 'nutrition_targets';
  static const String _nutritionPlansKey = 'nutrition_plans';
  static const String _exerciseDbBase = 'https://exercisedb-api.vercel.app/api/v1';

  static Future<String> _scopedKey(String key) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) return key;
    return 'user_${userId}_$key';
  }

  static String _foodEntriesKey(String date) => 'food_entries_$date';

  static Future<List<Map<String, dynamic>>> searchExercises(String query) async {
    try {
      final encoded = Uri.encodeComponent(query.toLowerCase());
      final url = '$_exerciseDbBase/exercises?name=$encoded&limit=30&offset=0';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final exercises = data['data'] as List<dynamic>? ?? [];
        return exercises
            .map((e) => {
                  'name': e['name'] ?? '',
                  'bodyPart': e['bodyPart'] ?? '',
                  'target': e['target'] ?? '',
                  'equipment': e['equipment'] ?? '',
                })
            .toList();
      }
    } catch (_) {}

    final normalized = query.toLowerCase();
    return _fallbackExercises
        .where((e) =>
            e['name']!.toLowerCase().contains(normalized) ||
            e['bodyPart']!.toLowerCase().contains(normalized) ||
            e['equipment']!.toLowerCase().contains(normalized))
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getExercisesByBodyPart(String bodyPart) async {
    try {
      final encoded = Uri.encodeComponent(bodyPart.toLowerCase());
      final url = '$_exerciseDbBase/exercises/bodyPart/$encoded?limit=40&offset=0';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final exercises = data['data'] as List<dynamic>? ?? [];
        return exercises
            .map((e) => {
                  'name': e['name'] ?? '',
                  'bodyPart': e['bodyPart'] ?? '',
                  'target': e['target'] ?? '',
                  'equipment': e['equipment'] ?? '',
                })
            .toList();
      }
    } catch (_) {}

    return _fallbackExercises
        .where((e) => e['bodyPart']!.toLowerCase() == bodyPart.toLowerCase())
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<String>> getBodyParts() async {
    final bodyParts = _fallbackExercises
        .map((exercise) => exercise['bodyPart']!)
        .toSet()
        .toList()
      ..sort();
    return bodyParts;
  }

  static Future<List<String>> getEquipmentList() async {
    final equipment = _fallbackExercises
        .map((exercise) => exercise['equipment']!)
        .toSet()
        .toList()
      ..sort();
    return equipment;
  }

  static Future<List<Map<String, dynamic>>> getExercises({
    String query = '',
    String? bodyPart,
    String? equipment,
  }) async {
    Iterable<Map<String, String>> results = _fallbackExercises;

    if (query.trim().isNotEmpty) {
      final normalized = query.trim().toLowerCase();
      results = results.where((exercise) => exercise['name']!.toLowerCase().contains(normalized));
    }
    if (bodyPart != null && bodyPart.isNotEmpty) {
      results = results.where((exercise) => exercise['bodyPart']!.toLowerCase() == bodyPart.toLowerCase());
    }
    if (equipment != null && equipment.isNotEmpty) {
      results = results.where((exercise) => exercise['equipment']!.toLowerCase() == equipment.toLowerCase());
    }

    return results.map((exercise) => Map<String, dynamic>.from(exercise)).toList();
  }

  static Future<List<Map<String, dynamic>>> getLogs() async {
    final raw = await localStore.getString(await _scopedKey(_logsKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveLog(Map<String, dynamic> log) async {
    final logs = await getLogs();
    log['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    log['timestamp'] = DateTime.now().toIso8601String();
    logs.insert(0, log);
    await localStore.setString(await _scopedKey(_logsKey), jsonEncode(logs));
  }

  static Future<void> deleteLog(String id) async {
    final logs = await getLogs();
    logs.removeWhere((log) => log['id'] == id);
    await localStore.setString(await _scopedKey(_logsKey), jsonEncode(logs));
  }

  static Future<Map<String, dynamic>> getPRs() async {
    final raw = await localStore.getString(await _scopedKey(_prsKey));
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<List<Map<String, dynamic>>> getPRList() async {
    final prs = await getPRs();
    final list = prs.values.map((entry) {
      final item = Map<String, dynamic>.from(entry as Map);
      if (item['estimated_1rm'] == null && item['estimated1rm'] != null) {
        item['estimated_1rm'] = item['estimated1rm'];
      }
      return item;
    }).toList();
    list.sort((a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    return list;
  }

  static Future<Map<String, dynamic>> savePR(Map<String, dynamic> pr) async {
    final prs = await getPRs();
    final exercise = (pr['exercise'] ?? '').toString().trim();
    if (exercise.isEmpty) {
      throw Exception('Exercise is required.');
    }

    final weight = (pr['weight'] as num?)?.toDouble() ?? double.tryParse('${pr['weight']}') ?? 0;
    final reps = (pr['reps'] as num?)?.toInt() ?? int.tryParse('${pr['reps']}') ?? 0;
    final key = exercise.toLowerCase();

    final saved = <String, dynamic>{
      ...pr,
      'exercise': exercise,
      'weight': weight,
      'reps': reps,
      'estimated_1rm': calculate1RM(weight, reps).round(),
      'date': (pr['date'] ?? DateTime.now().toIso8601String().split('T')[0]).toString(),
    };

    prs[key] = saved;
    await localStore.setString(await _scopedKey(_prsKey), jsonEncode(prs));
    await _syncProfileLiftFromPr(exercise, weight);
    return saved;
  }

  static Future<Map<String, dynamic>?> getLastPRForExercise(String exercise) async {
    final prs = await getPRs();
    return prs[exercise.toLowerCase()] is Map
        ? Map<String, dynamic>.from(prs[exercise.toLowerCase()] as Map)
        : null;
  }

  static double _prScore(Map<String, dynamic>? pr) {
    if (pr == null) return 0;
    final estimated =
        (pr['estimated1rm'] as num?)?.toDouble() ??
        (pr['estimated_1rm'] as num?)?.toDouble();
    if (estimated != null && estimated > 0) return estimated;

    final weight =
        (pr['weight'] as num?)?.toDouble() ??
        double.tryParse('${pr['weight']}') ??
        0;
    final reps =
        (pr['reps'] as num?)?.toInt() ?? int.tryParse('${pr['reps']}') ?? 0;
    return calculate1RM(weight, reps);
  }

  static Future<bool> checkAndSavePR(String exercise, double weight, int reps) async {
    final prs = await getPRs();
    final key = exercise.toLowerCase();
    final estimated1rm = calculate1RM(weight, reps);
    final current = prs[key];

    if (current == null || estimated1rm > _prScore(Map<String, dynamic>.from(current as Map))) {
      prs[key] = {
        'exercise': exercise,
        'weight': weight,
        'reps': reps,
        'estimated_1rm': estimated1rm.round(),
        'estimated1rm': estimated1rm,
        'date': DateTime.now().toIso8601String(),
      };
      await localStore.setString(await _scopedKey(_prsKey), jsonEncode(prs));
      await _syncProfileLiftFromPr(exercise, weight);
      return true;
    }
    return false;
  }

  static Future<void> _syncProfileLiftFromPr(String exercise, double weight) async {
    if (weight <= 0) return;

    final mapping = _profileLiftFieldForExercise(exercise);
    if (mapping == null) return;

    final profile = await getProfile();
    final currentValue =
        (profile[mapping.currentKey] as num?)?.toDouble() ??
        double.tryParse('${profile[mapping.currentKey]}') ??
        0;

    if (weight <= currentValue) return;

    final formatted = weight % 1 == 0 ? weight.toInt().toString() : weight.toString();
    profile[mapping.primaryKey] = formatted;
    profile[mapping.currentKey] = weight;
    await saveProfile(profile);
  }

  static _LiftProfileMapping? _profileLiftFieldForExercise(String exercise) {
    final normalized = exercise.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (normalized.contains('deadlift')) {
      return const _LiftProfileMapping(
        primaryKey: 'deadlift',
        currentKey: 'currentDeadlift',
      );
    }
    if (normalized.contains('bench')) {
      return const _LiftProfileMapping(
        primaryKey: 'bench',
        currentKey: 'currentBench',
      );
    }
    if (normalized.contains('overhead press') ||
        normalized == 'ohp' ||
        normalized.contains('shoulder press')) {
      return const _LiftProfileMapping(
        primaryKey: 'ohp',
        currentKey: 'currentOhp',
      );
    }
    if (normalized.contains('squat')) {
      return const _LiftProfileMapping(
        primaryKey: 'squat',
        currentKey: 'currentSquat',
      );
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> getRoutines() async {
    final raw = await localStore.getString(await _scopedKey(_routinesKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveRoutine(Map<String, dynamic> routine) async {
    final routines = await getRoutines();
    routine['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    routine['createdAt'] = DateTime.now().toIso8601String();
    routines.add(routine);
    await localStore.setString(await _scopedKey(_routinesKey), jsonEncode(routines));
  }

  static Future<void> deleteRoutine(String id) async {
    final routines = await getRoutines();
    routines.removeWhere((routine) => routine['id'] == id);
    await localStore.setString(await _scopedKey(_routinesKey), jsonEncode(routines));
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final raw = await localStore.getString(await _scopedKey(_profileKey));
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    await localStore.setString(await _scopedKey(_profileKey), jsonEncode(profile));
  }

  static Future<Map<String, dynamic>> getLifterProfile() async => getProfile();

  static Future<void> saveLifterProfile(Map<String, dynamic> profile) async {
    await saveProfile(profile);
  }

  static Future<Map<String, dynamic>> getStrengthGoals() async {
    final raw = await localStore.getString(await _scopedKey(_goalsKey));
    if (raw == null) {
      return {
        'squat': 315,
        'bench': 225,
        'deadlift': 405,
        'ohp': 135,
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveStrengthGoals(Map<String, dynamic> goals) async {
    await localStore.setString(await _scopedKey(_goalsKey), jsonEncode(goals));
  }

  static Future<List<Map<String, dynamic>>> getBodyweightLogs() async {
    final raw = await localStore.getString(await _scopedKey(_bodyweightKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> logBodyweight(double weight) async {
    final logs = await getBodyweightLogs();
    logs.add({
      'weight': weight,
      'date': DateTime.now().toIso8601String(),
    });
    await localStore.setString(await _scopedKey(_bodyweightKey), jsonEncode(logs));
  }

  static Future<List<Map<String, dynamic>>> getMeasurements() async {
    final raw = await localStore.getString(await _scopedKey(_measurementsKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveMeasurement(Map<String, dynamic> measurement) async {
    final logs = await getMeasurements();
    measurement['date'] = DateTime.now().toIso8601String();
    logs.insert(0, measurement);
    await localStore.setString(await _scopedKey(_measurementsKey), jsonEncode(logs));
  }

  static Future<List<Map<String, dynamic>>> getWellnessLogs() async {
    final raw = await localStore.getString(await _scopedKey(_wellnessKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveWellness(Map<String, dynamic> entry) async {
    final logs = await getWellnessLogs();
    entry['date'] = DateTime.now().toIso8601String();
    logs.insert(0, entry);
    await localStore.setString(await _scopedKey(_wellnessKey), jsonEncode(logs));
  }

  static Future<bool> isOnboardingComplete() async => !(await AuthService.needsOnboarding());

  static Future<void> completeOnboarding() async {
    await AuthService.completeOnboarding();
  }

  static Future<void> resetOnboarding() async {
    await AuthService.requireOnboarding();
  }

  static Future<Map<String, dynamic>> getNutritionTargets() async {
    final raw = await localStore.getString(await _scopedKey(_nutritionTargetsKey));
    if (raw == null) {
      return {
        'calories': 2300,
        'protein': 260,
        'carbs': 200,
        'fat': 55,
      };
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveNutritionTargets(Map<String, dynamic> targets) async {
    await localStore.setString(await _scopedKey(_nutritionTargetsKey), jsonEncode(targets));
  }

  static Future<List<Map<String, dynamic>>> getFoodEntries(String date) async {
    final raw = await localStore.getString(await _scopedKey(_foodEntriesKey(date)));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveFoodEntry(String date, Map<String, dynamic> food) async {
    final entries = await getFoodEntries(date);
    entries.add({
      'name': food['name'] ?? '',
      'brand': food['brand'] ?? '',
      'serving': food['serving'] ?? '1 serving',
      'calories': (food['calories'] as num?)?.toInt() ?? 0,
      'protein': (food['protein'] as num?)?.toDouble() ?? 0.0,
      'carbs': (food['carbs'] as num?)?.toDouble() ?? 0.0,
      'fat': ((food['fat'] ?? food['fats']) as num?)?.toDouble() ?? 0.0,
      'date': DateTime.now().toIso8601String(),
    });
    await localStore.setString(await _scopedKey(_foodEntriesKey(date)), jsonEncode(entries));
  }

  static Future<void> deleteFoodEntry(String date, int index) async {
    final entries = await getFoodEntries(date);
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await localStore.setString(await _scopedKey(_foodEntriesKey(date)), jsonEncode(entries));
  }

  static Future<List<Map<String, dynamic>>> searchFood(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final foods = await UsdaFoodService.searchFoods(query, pageSize: 12);
      return foods.map((food) {
        final formatted = UsdaFoodService.formatFoodResult(food);
        return {
          'name': formatted['name'] ?? '',
          'brand': food['brandOwner'] ?? '',
          'serving': '100g',
          'calories': (formatted['calories'] as num?)?.toInt() ?? 0,
          'protein': (formatted['protein'] as num?)?.toDouble() ?? 0.0,
          'carbs': (formatted['carbs'] as num?)?.toDouble() ?? 0.0,
          'fat': (formatted['fats'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> generateMealPlan({
    required String? goal,
    required int days,
    required int mealsPerDay,
    required String preferences,
  }) async {
    final targets = await getNutritionTargets();
    final plans = await _getNutritionPlans();
    final plan = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'goal': goal ?? 'Maintain current weight',
      'days': days,
      'mealsPerDay': mealsPerDay,
      'preferences': preferences,
      'createdAt': DateTime.now().toIso8601String(),
      'targets': targets,
      'dailyMeals': _buildMealPlanDays(days, mealsPerDay, targets, preferences),
    };
    plans.insert(0, plan);
    await localStore.setString(await _scopedKey(_nutritionPlansKey), jsonEncode(plans));
  }

  static Future<Map<String, dynamic>?> getLatestNutrition() async {
    final plans = await _getNutritionPlans();
    if (plans.isEmpty) return null;
    return plans.first;
  }

  static Future<Map<String, dynamic>?> getWellnessToday() async {
    final logs = await getWellnessLogs();
    if (logs.isEmpty) return null;
    return logs.first;
  }

  static Future<String> generateWorkout(String prompt) async {
    final profile = await getProfile();
    final focus = (profile['goal'] ?? 'strength').toString();
    final experience = (profile['experience'] ?? 'intermediate').toString();
    final equipment = List<String>.from(profile['equipment'] ?? const []);
    final equipmentText = equipment.isEmpty ? 'Standard gym equipment' : equipment.join(', ');

    return [
      'IRONMIND AI DEMO',
      '',
      'Prompt: $prompt',
      '',
      'Suggested Focus: $focus',
      'Experience Level: $experience',
      'Equipment: $equipmentText',
      '',
      '1. Warm up for 8-10 minutes with light cardio and dynamic mobility.',
      '2. Main lift: 4 working sets of 4-6 reps at a challenging but clean effort.',
      '3. Secondary lift: 3 sets of 6-8 reps with controlled tempo.',
      '4. Accessories: 3 movements for 3 sets of 10-15 reps each.',
      '5. Finish with core work or conditioning for 8-12 minutes.',
      '',
      'Use this as a presentation preview. We can reconnect live generation later.',
    ].join('\n');
  }

  static Future<List<Map<String, dynamic>>> _getNutritionPlans() async {
    final raw = await localStore.getString(await _scopedKey(_nutritionPlansKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static List<Map<String, dynamic>> _buildMealPlanDays(
    int days,
    int mealsPerDay,
    Map<String, dynamic> targets,
    String preferences,
  ) {
    final calories = (targets['calories'] as num?)?.toInt() ?? 2300;
    final protein = (targets['protein'] as num?)?.toInt() ?? 260;
    final carbs = (targets['carbs'] as num?)?.toInt() ?? 200;
    final fat = (targets['fat'] as num?)?.toInt() ?? 55;
    final notes = preferences.trim();

    return List<Map<String, dynamic>>.generate(days, (index) {
      final selectedMeals = List<String>.generate(mealsPerDay, (mealIndex) {
        final template = _mealTemplates[(index + mealIndex) % _mealTemplates.length];
        return '${template['label']}: ${template['meal']}';
      });

      return {
        'day': index + 1,
        'summary': 'Target $calories kcal, $protein P / $carbs C / $fat F',
        'notes': notes.isEmpty ? 'No specific restrictions' : notes,
        'meals': selectedMeals,
      };
    });
  }

  static const List<Map<String, String>> _mealTemplates = [
    {'label': 'Breakfast', 'meal': 'eggs, oats, and fruit'},
    {'label': 'Breakfast', 'meal': 'Greek yogurt, berries, and granola'},
    {'label': 'Lunch', 'meal': 'lean protein, rice, and vegetables'},
    {'label': 'Lunch', 'meal': 'turkey wrap, potatoes, and salad'},
    {'label': 'Snack', 'meal': 'protein shake and banana'},
    {'label': 'Snack', 'meal': 'cottage cheese and rice cakes'},
    {'label': 'Dinner', 'meal': 'salmon, potatoes, and greens'},
    {'label': 'Dinner', 'meal': 'steak, jasmine rice, and broccoli'},
  ];

  static double calculate1RM(double weight, int reps, [String formula = 'Epley']) {
    if (weight <= 0 || reps <= 0) return 0;
    if (reps == 1) return weight;

    switch (formula.toLowerCase()) {
      case 'epley':
        return weight * (1 + reps / 30.0);
      case 'brzycki':
        return weight * (36 / (37 - reps));
      case 'mcglothin':
        return (100 * weight) / (101.3 - 2.67123 * reps);
      case 'lombardi':
        return weight * pow(reps, 0.10);
      default:
        return weight * (1 + reps / 30.0);
    }
  }

  static const List<Map<String, String>> _fallbackExercises = [
    {'name': 'Back Squat', 'bodyPart': 'upper legs', 'target': 'quads', 'equipment': 'barbell'},
    {'name': 'Front Squat', 'bodyPart': 'upper legs', 'target': 'quads', 'equipment': 'barbell'},
    {'name': 'Leg Press', 'bodyPart': 'upper legs', 'target': 'quads', 'equipment': 'machine'},
    {'name': 'Romanian Deadlift', 'bodyPart': 'upper legs', 'target': 'hamstrings', 'equipment': 'barbell'},
    {'name': 'Leg Curl', 'bodyPart': 'upper legs', 'target': 'hamstrings', 'equipment': 'machine'},
    {'name': 'Bench Press', 'bodyPart': 'chest', 'target': 'pectorals', 'equipment': 'barbell'},
    {'name': 'Incline Bench Press', 'bodyPart': 'chest', 'target': 'pectorals', 'equipment': 'barbell'},
    {'name': 'Dumbbell Fly', 'bodyPart': 'chest', 'target': 'pectorals', 'equipment': 'dumbbell'},
    {'name': 'Cable Crossover', 'bodyPart': 'chest', 'target': 'pectorals', 'equipment': 'cable'},
    {'name': 'Push Up', 'bodyPart': 'chest', 'target': 'pectorals', 'equipment': 'body weight'},
    {'name': 'Deadlift', 'bodyPart': 'back', 'target': 'spine', 'equipment': 'barbell'},
    {'name': 'Pull Up', 'bodyPart': 'back', 'target': 'lats', 'equipment': 'body weight'},
    {'name': 'Barbell Row', 'bodyPart': 'back', 'target': 'lats', 'equipment': 'barbell'},
    {'name': 'Lat Pulldown', 'bodyPart': 'back', 'target': 'lats', 'equipment': 'cable'},
    {'name': 'Seated Cable Row', 'bodyPart': 'back', 'target': 'lats', 'equipment': 'cable'},
    {'name': 'Overhead Press', 'bodyPart': 'shoulders', 'target': 'delts', 'equipment': 'barbell'},
    {'name': 'Lateral Raise', 'bodyPart': 'shoulders', 'target': 'delts', 'equipment': 'dumbbell'},
    {'name': 'Face Pull', 'bodyPart': 'shoulders', 'target': 'delts', 'equipment': 'cable'},
    {'name': 'Barbell Curl', 'bodyPart': 'upper arms', 'target': 'biceps', 'equipment': 'barbell'},
    {'name': 'Dumbbell Curl', 'bodyPart': 'upper arms', 'target': 'biceps', 'equipment': 'dumbbell'},
    {'name': 'Hammer Curl', 'bodyPart': 'upper arms', 'target': 'biceps', 'equipment': 'dumbbell'},
    {'name': 'Tricep Pushdown', 'bodyPart': 'upper arms', 'target': 'triceps', 'equipment': 'cable'},
    {'name': 'Skull Crusher', 'bodyPart': 'upper arms', 'target': 'triceps', 'equipment': 'barbell'},
    {'name': 'Close Grip Bench', 'bodyPart': 'upper arms', 'target': 'triceps', 'equipment': 'barbell'},
    {'name': 'Plank', 'bodyPart': 'waist', 'target': 'abs', 'equipment': 'body weight'},
    {'name': 'Crunch', 'bodyPart': 'waist', 'target': 'abs', 'equipment': 'body weight'},
    {'name': 'Leg Raise', 'bodyPart': 'waist', 'target': 'abs', 'equipment': 'body weight'},
    {'name': 'Calf Raise', 'bodyPart': 'lower legs', 'target': 'calves', 'equipment': 'barbell'},
    {'name': 'Hip Thrust', 'bodyPart': 'upper legs', 'target': 'glutes', 'equipment': 'barbell'},
    {'name': 'Lunge', 'bodyPart': 'upper legs', 'target': 'quads', 'equipment': 'body weight'},
  ];
}

class _LiftProfileMapping {
  final String primaryKey;
  final String currentKey;

  const _LiftProfileMapping({
    required this.primaryKey,
    required this.currentKey,
  });
}
