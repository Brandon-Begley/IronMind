import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'local_store.dart';

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
  static const String _habitsKey = 'habits';
  static const String _habitLogsKey = 'habit_logs';
  static const String _exerciseDbBase = 'https://oss.exercisedb.dev/api/v1';
  static List<Map<String, dynamic>>? _ossExerciseCache;

  static Future<String> _scopedKey(String key) async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null || userId.isEmpty) return key;
    return 'user_${userId}_$key';
  }

  static String _foodEntriesKey(String date) => 'food_entries_$date';

  static Future<List<Map<String, dynamic>>> searchExercises(
    String query,
  ) async {
    final live = await _fetchOssExercises(query: query);
    if (live.isNotEmpty) {
      return _mergeAndSortExercises(live, _fallbackResults(query: query));
    }

    final normalized = query.toLowerCase();
    return _fallbackExercises
        .where((e) => _exerciseMatches(e, normalized))
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort(_compareExerciseNames);
  }

  static Future<List<Map<String, dynamic>>> getExercisesByBodyPart(
    String bodyPart,
  ) async {
    final live = await _fetchOssExercises(bodyPart: bodyPart);
    if (live.isNotEmpty) {
      return _mergeAndSortExercises(live, _fallbackResults(bodyPart: bodyPart));
    }

    return _fallbackExercises
        .where((e) => _exerciseMatchesMuscleGroup(e, bodyPart))
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort(_compareExerciseNames);
  }

  static Future<List<String>> getBodyParts() async {
    return _primaryMuscleGroups;
  }

  static Future<Map<String, String>> getMuscleGroupMedia() async {
    final live = await _fetchOssExercises();
    final media = <String, String>{};
    for (final preferred in _muscleGroupRepresentativeNames.entries) {
      final match = live.firstWhere(
        (exercise) =>
            _exerciseMatchesMuscleGroup(exercise, preferred.key) &&
            exercise['name'].toString().toLowerCase().contains(
              preferred.value,
            ) &&
            exercise['gifUrl'].toString().trim().isNotEmpty,
        orElse: () => const <String, dynamic>{},
      );
      final gifUrl = match['gifUrl']?.toString().trim() ?? '';
      if (gifUrl.isNotEmpty) media[preferred.key] = gifUrl;
    }
    for (final exercise in live) {
      final gifUrl = exercise['gifUrl']?.toString().trim() ?? '';
      if (gifUrl.isEmpty) continue;
      for (final group in _muscleGroupsForExercise(exercise)) {
        media.putIfAbsent(group, () => gifUrl);
      }
    }
    return media;
  }

  static Future<List<String>> getEquipmentList() async {
    final live = await _fetchOssExercises();
    final source = live.isNotEmpty ? live : _fallbackExercises;
    final equipment = <String>{};
    for (final exercise in source) {
      final parentEquipment = exercise['equipment'].toString();
      if (parentEquipment.isNotEmpty) equipment.add(parentEquipment);
      final variants = exercise['variants'];
      if (variants is List) {
        for (final variant in variants) {
          if (variant is Map && variant['equipment'] != null) {
            equipment.add(variant['equipment'].toString());
          }
        }
      }
    }
    final sortedEquipment = equipment.toList()..sort();
    return sortedEquipment;
  }

  static Future<List<Map<String, dynamic>>> getExercises({
    String query = '',
    String? bodyPart,
    String? equipment,
  }) async {
    final live = await _fetchOssExercises(
      query: query,
      bodyPart: bodyPart,
      equipment: equipment,
    );
    if (live.isNotEmpty) {
      return _mergeAndSortExercises(
        live,
        _fallbackResults(
          query: query,
          bodyPart: bodyPart,
          equipment: equipment,
        ),
      );
    }

    final results = _fallbackResults(
      query: query,
      bodyPart: bodyPart,
      equipment: equipment,
    );

    return _sortExercisesByName(results);
  }

  static List<Map<String, dynamic>> _fallbackResults({
    String query = '',
    String? bodyPart,
    String? equipment,
  }) {
    Iterable<Map<String, dynamic>> results = _fallbackExercises;

    if (query.trim().isNotEmpty) {
      final normalized = query.trim().toLowerCase();
      results = results.where(
        (exercise) => _exerciseMatches(exercise, normalized),
      );
    }
    if (bodyPart != null && bodyPart.isNotEmpty) {
      results = results.where(
        (exercise) => _exerciseMatchesMuscleGroup(exercise, bodyPart),
      );
    }
    if (equipment != null && equipment.isNotEmpty) {
      results = results.where(
        (exercise) => _exerciseHasEquipment(exercise, equipment.toLowerCase()),
      );
    }

    return results
        .map((exercise) => Map<String, dynamic>.from(exercise))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchOssExercises({
    String query = '',
    String? bodyPart,
    String? equipment,
    int limit = 1600,
  }) async {
    try {
      final normalized = _ossExerciseCache ??= await _downloadOssExercises(
        limit: limit,
      );
      if (normalized.isEmpty) return [];

      final normalizedQuery = query.trim().toLowerCase();
      final normalizedBodyPart = bodyPart?.trim().toLowerCase() ?? '';
      final normalizedEquipment = equipment?.trim().toLowerCase() ?? '';

      final results = normalized.where((exercise) {
        if (normalizedQuery.isNotEmpty &&
            !_exerciseMatches(exercise, normalizedQuery)) {
          return false;
        }
        if (normalizedBodyPart.isNotEmpty &&
            !_exerciseMatchesMuscleGroup(exercise, normalizedBodyPart)) {
          return false;
        }
        if (normalizedEquipment.isNotEmpty &&
            !_exerciseHasEquipment(exercise, normalizedEquipment)) {
          return false;
        }
        return true;
      }).toList();
      return _sortExercisesByName(results);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _downloadOssExercises({
    required int limit,
  }) async {
    final uri = Uri.parse(
      '$_exerciseDbBase/exercises',
    ).replace(queryParameters: {'limit': '$limit', 'offset': '0'});
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(response.body);
    final rawExercises = decoded is List
        ? decoded
        : (decoded is Map ? decoded['data'] as List? ?? const [] : const []);
    return rawExercises
        .whereType<Map>()
        .map(_normalizeOssExercise)
        .where((exercise) => exercise['name'].toString().isNotEmpty)
        .map(_attachLocalExerciseVariants)
        .toList()
      ..sort(_compareExerciseNames);
  }

  static Map<String, dynamic> _normalizeOssExercise(Map<dynamic, dynamic> raw) {
    final bodyParts = _stringList(raw['bodyParts']);
    final targetMuscles = _stringList(raw['targetMuscles']);
    final equipments = _stringList(raw['equipments']);
    return {
      'id': raw['exerciseId']?.toString() ?? '',
      'name': raw['name']?.toString() ?? '',
      'bodyPart': bodyParts.isNotEmpty ? bodyParts.first : '',
      'target': targetMuscles.isNotEmpty ? targetMuscles.first : '',
      'equipment': equipments.isNotEmpty ? equipments.first : '',
      'bodyParts': bodyParts,
      'targetMuscles': targetMuscles,
      'equipments': equipments,
      'gifUrl': raw['gifUrl']?.toString(),
      'instructions': _stringList(raw['instructions']),
      'secondaryMuscles': _stringList(raw['secondaryMuscles']),
    };
  }

  static Map<String, dynamic> _attachLocalExerciseVariants(
    Map<String, dynamic> exercise,
  ) {
    final exerciseName = exercise['name'].toString().toLowerCase();
    final match = _fallbackExercises.firstWhere((fallback) {
      final fallbackName = fallback['name'].toString().toLowerCase();
      return exerciseName == fallbackName ||
          exerciseName.contains(fallbackName);
    }, orElse: () => const <String, dynamic>{});
    final variants = match['variants'];
    if (variants is! List || variants.isEmpty) return exercise;
    return {...exercise, 'variants': variants};
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }
    if (value == null) return const [];
    final text = value.toString();
    return text.trim().isEmpty ? const [] : [text];
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
    list.sort(
      (a, b) =>
          (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''),
    );
    return list;
  }

  static Future<Map<String, dynamic>> savePR(Map<String, dynamic> pr) async {
    final prs = await getPRs();
    final exercise = (pr['exercise'] ?? '').toString().trim();
    if (exercise.isEmpty) {
      throw Exception('Exercise is required.');
    }

    final weight =
        (pr['weight'] as num?)?.toDouble() ??
        double.tryParse('${pr['weight']}') ??
        0;
    final reps =
        (pr['reps'] as num?)?.toInt() ?? int.tryParse('${pr['reps']}') ?? 0;
    final key = exercise.toLowerCase();

    final saved = <String, dynamic>{
      ...pr,
      'exercise': exercise,
      'weight': weight,
      'reps': reps,
      'estimated_1rm': calculate1RM(weight, reps).round(),
      'date': (pr['date'] ?? DateTime.now().toIso8601String().split('T')[0])
          .toString(),
    };

    prs[key] = saved;
    await localStore.setString(await _scopedKey(_prsKey), jsonEncode(prs));
    await _syncProfileLiftFromPr(exercise, weight);
    return saved;
  }

  static Future<Map<String, dynamic>?> getLastPRForExercise(
    String exercise,
  ) async {
    final prs = await getPRs();
    return prs[exercise.toLowerCase()] is Map
        ? Map<String, dynamic>.from(prs[exercise.toLowerCase()] as Map)
        : null;
  }

  static Future<void> deletePR(String exercise) async {
    final prs = await getPRs();
    prs.remove(exercise.toLowerCase());
    await localStore.setString(await _scopedKey(_prsKey), jsonEncode(prs));
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

  static Future<bool> checkAndSavePR(
    String exercise,
    double weight,
    int reps,
  ) async {
    final prs = await getPRs();
    final key = exercise.toLowerCase();
    final estimated1rm = calculate1RM(weight, reps);
    final current = prs[key];

    if (current == null ||
        estimated1rm > _prScore(Map<String, dynamic>.from(current as Map))) {
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

  static Future<void> _syncProfileLiftFromPr(
    String exercise,
    double weight,
  ) async {
    if (weight <= 0) return;

    final mapping = _profileLiftFieldForExercise(exercise);
    if (mapping == null) return;

    final profile = await getProfile();
    final currentValue =
        (profile[mapping.currentKey] as num?)?.toDouble() ??
        double.tryParse('${profile[mapping.currentKey]}') ??
        0;

    if (weight <= currentValue) return;

    final formatted = weight % 1 == 0
        ? weight.toInt().toString()
        : weight.toString();
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
    await localStore.setString(
      await _scopedKey(_routinesKey),
      jsonEncode(routines),
    );
  }

  static Future<void> deleteRoutine(String id) async {
    final routines = await getRoutines();
    routines.removeWhere((routine) => routine['id'] == id);
    await localStore.setString(
      await _scopedKey(_routinesKey),
      jsonEncode(routines),
    );
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final raw = await localStore.getString(await _scopedKey(_profileKey));
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveProfile(Map<String, dynamic> profile) async {
    await localStore.setString(
      await _scopedKey(_profileKey),
      jsonEncode(profile),
    );
  }

  static Future<Map<String, dynamic>> getLifterProfile() async => getProfile();

  static Future<void> saveLifterProfile(Map<String, dynamic> profile) async {
    await saveProfile(profile);
  }

  static Future<Map<String, dynamic>> getStrengthGoals() async {
    final raw = await localStore.getString(await _scopedKey(_goalsKey));
    if (raw == null) {
      return {'squat': 315, 'bench': 225, 'deadlift': 405, 'ohp': 135};
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
    logs.add({'weight': weight, 'date': DateTime.now().toIso8601String()});
    await localStore.setString(
      await _scopedKey(_bodyweightKey),
      jsonEncode(logs),
    );
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
    await localStore.setString(
      await _scopedKey(_measurementsKey),
      jsonEncode(logs),
    );
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
    await localStore.setString(
      await _scopedKey(_wellnessKey),
      jsonEncode(logs),
    );
  }

  static Future<bool> isOnboardingComplete() async =>
      !(await AuthService.needsOnboarding());

  static Future<void> completeOnboarding() async {
    await AuthService.completeOnboarding();
  }

  static Future<void> resetOnboarding() async {
    await AuthService.requireOnboarding();
  }

  static Future<Map<String, dynamic>> getNutritionTargets() async {
    final raw = await localStore.getString(
      await _scopedKey(_nutritionTargetsKey),
    );
    if (raw == null) {
      return {'calories': 2300, 'protein': 260, 'carbs': 200, 'fat': 55};
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> saveNutritionTargets(Map<String, dynamic> targets) async {
    await localStore.setString(
      await _scopedKey(_nutritionTargetsKey),
      jsonEncode(targets),
    );
  }

  static Future<List<Map<String, dynamic>>> getFoodEntries(String date) async {
    final raw = await localStore.getString(
      await _scopedKey(_foodEntriesKey(date)),
    );
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveFoodEntry(
    String date,
    Map<String, dynamic> food,
  ) async {
    final entries = await getFoodEntries(date);
    entries.add({
      'name': food['name'] ?? '',
      'brand': food['brand'] ?? '',
      'serving': food['serving'] ?? '1 serving',
      'calories': (food['calories'] as num?)?.toInt() ?? 0,
      'protein': (food['protein'] as num?)?.toDouble() ?? 0.0,
      'carbs': (food['carbs'] as num?)?.toDouble() ?? 0.0,
      'fat': ((food['fat'] ?? food['fats']) as num?)?.toDouble() ?? 0.0,
      'meal': food['meal'] ?? 'Other',
      'date': DateTime.now().toIso8601String(),
    });
    await localStore.setString(
      await _scopedKey(_foodEntriesKey(date)),
      jsonEncode(entries),
    );
  }

  // ── Water tracking ───────────────────────────────────────────────────────────

  static Future<int> getWaterGlasses(String date) async {
    final raw = await localStore.getString(await _scopedKey('water_$date'));
    return int.tryParse(raw ?? '0') ?? 0;
  }

  static Future<void> setWaterGlasses(String date, int glasses) async {
    final clamped = glasses.clamp(0, 20);
    await localStore.setString(
      await _scopedKey('water_$date'),
      clamped.toString(),
    );
  }

  static Future<void> deleteFoodEntry(String date, int index) async {
    final entries = await getFoodEntries(date);
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await localStore.setString(
      await _scopedKey(_foodEntriesKey(date)),
      jsonEncode(entries),
    );
  }

  static Future<List<Map<String, dynamic>>> searchFood(String query) async {
    return [];
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
    await localStore.setString(
      await _scopedKey(_nutritionPlansKey),
      jsonEncode(plans),
    );
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
    final equipmentText = equipment.isEmpty
        ? 'Standard gym equipment'
        : equipment.join(', ');

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
    final raw = await localStore.getString(
      await _scopedKey(_nutritionPlansKey),
    );
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
        final template =
            _mealTemplates[(index + mealIndex) % _mealTemplates.length];
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

  // ── Habits & Streaks ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getHabits() async {
    final raw = await localStore.getString(await _scopedKey(_habitsKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveHabit(Map<String, dynamic> habit) async {
    final habits = await getHabits();
    habit['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    habit['createdAt'] = DateTime.now().toIso8601String();
    habits.add(habit);
    await localStore.setString(
      await _scopedKey(_habitsKey),
      jsonEncode(habits),
    );
  }

  static Future<void> deleteHabit(String id) async {
    final habits = await getHabits();
    habits.removeWhere((h) => h['id'] == id);
    await localStore.setString(
      await _scopedKey(_habitsKey),
      jsonEncode(habits),
    );
    // remove logs too
    final logs = await _getRawHabitLogs();
    logs.removeWhere((l) => l['habitId'] == id);
    await localStore.setString(
      await _scopedKey(_habitLogsKey),
      jsonEncode(logs),
    );
  }

  static Future<List<Map<String, dynamic>>> _getRawHabitLogs() async {
    final raw = await localStore.getString(await _scopedKey(_habitLogsKey));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  /// Returns the set of dates (YYYY-MM-DD) on which [habitId] was completed.
  static Future<Set<String>> getHabitCompletedDates(String habitId) async {
    final logs = await _getRawHabitLogs();
    return logs
        .where((l) => l['habitId'] == habitId && l['completed'] == true)
        .map((l) => l['date'] as String)
        .toSet();
  }

  static Future<void> toggleHabitLog(String habitId, String date) async {
    final logs = await _getRawHabitLogs();
    final idx = logs.indexWhere(
      (l) => l['habitId'] == habitId && l['date'] == date,
    );
    if (idx >= 0) {
      // toggle
      logs[idx]['completed'] = !(logs[idx]['completed'] as bool? ?? false);
    } else {
      logs.add({'habitId': habitId, 'date': date, 'completed': true});
    }
    await localStore.setString(
      await _scopedKey(_habitLogsKey),
      jsonEncode(logs),
    );
  }

  /// Computes {currentStreak, longestStreak} for a given set of completed dates.
  /// A streak is consecutive calendar days ending today or yesterday (allows
  /// logging earlier in the day without breaking streak).
  static Map<String, int> computeStreak(Set<String> completedDates) {
    if (completedDates.isEmpty) return {'current': 0, 'longest': 0};

    final today = DateTime.now();
    final todayStr = _dateStr(today);
    final yesterdayStr = _dateStr(today.subtract(const Duration(days: 1)));

    // Sort dates descending
    final sorted = completedDates.toList()..sort((a, b) => b.compareTo(a));

    // Current streak: walk backwards from today
    int current = 0;
    DateTime cursor = completedDates.contains(todayStr)
        ? today
        : (completedDates.contains(yesterdayStr)
              ? today.subtract(const Duration(days: 1))
              : DateTime(1970)); // no active streak

    if (cursor.year > 1970) {
      while (completedDates.contains(_dateStr(cursor))) {
        current++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    // Longest streak: scan all dates
    int longest = 0;
    int run = 1;
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      final diff = prev.difference(curr).inDays;
      if (diff == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        if (run > longest) longest = run;
        run = 1;
      }
    }
    if (run > longest) longest = run;
    if (longest == 0 && completedDates.isNotEmpty) longest = 1;

    return {'current': current, 'longest': longest};
  }

  /// Returns a list of booleans for the last [days] calendar days (oldest first).
  static List<bool> buildHabitGrid(
    Set<String> completedDates, {
    int days = 91,
  }) {
    final today = DateTime.now();
    return List<bool>.generate(days, (i) {
      final d = today.subtract(Duration(days: days - 1 - i));
      return completedDates.contains(_dateStr(d));
    });
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String todayDateStr() => _dateStr(DateTime.now());

  // ── Auto-habit detection ────────────────────────────────────────────────────

  /// Returns dates on which the user logged a workout (from workout logs).
  static Future<Set<String>> getWorkoutLoggedDates() async {
    final logs = await getLogs();
    return logs
        .map((l) {
          final raw = l['date'] ?? l['timestamp'];
          if (raw == null) return null;
          try {
            return _dateStr(DateTime.parse(raw.toString()));
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toSet();
  }

  /// Returns dates on which the user logged at least one food entry.
  static Future<Set<String>> getNutritionLoggedDates({
    int lookbackDays = 91,
  }) async {
    final today = DateTime.now();
    final Set<String> dates = {};
    for (int i = 0; i < lookbackDays; i++) {
      final d = today.subtract(Duration(days: i));
      final dateStr = _dateStr(d);
      final entries = await getFoodEntries(dateStr);
      if (entries.isNotEmpty) dates.add(dateStr);
    }
    return dates;
  }

  /// Returns dates on which the user logged a wellness check-in.
  static Future<Set<String>> getCheckInLoggedDates() async {
    final logs = await getWellnessLogs();
    return logs
        .map((l) {
          final raw = l['date'];
          if (raw == null) return null;
          try {
            return _dateStr(DateTime.parse(raw.toString()));
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toSet();
  }

  static double calculate1RM(
    double weight,
    int reps, [
    String formula = 'Epley',
  ]) {
    if (weight <= 0 || reps <= 0) return 0;
    if (reps == 1) return weight;

    double result;
    switch (formula.toLowerCase()) {
      case 'epley':
        result = weight * (1 + reps / 30.0);
      case 'brzycki':
        if (reps >= 37) {
          // Brzycki formula is undefined at reps >= 37 (denominator <= 0)
          result = weight * (1 + reps / 30.0); // fall back to Epley
        } else {
          result = weight * (36 / (37 - reps));
        }
      case 'mcglothin':
        result = (100 * weight) / (101.3 - 2.67123 * reps);
      case 'lombardi':
        result = weight * pow(reps, 0.10);
      default:
        result = weight * (1 + reps / 30.0);
    }
    if (result.isNaN || result.isInfinite || result < 0) {
      return weight * (1 + reps / 30.0);
    }
    return result;
  }

  static bool _exerciseMatches(
    Map<String, dynamic> exercise,
    String normalized,
  ) {
    final searchable = [
      exercise['name'],
      exercise['bodyPart'],
      exercise['target'],
      exercise['equipment'],
      ..._stringList(exercise['bodyParts']),
      ..._stringList(exercise['targetMuscles']),
      ..._stringList(exercise['secondaryMuscles']),
      ..._stringList(exercise['equipments']),
      ..._muscleGroupsForExercise(exercise),
    ].join(' ').toLowerCase();

    if (searchable.contains(normalized)) return true;

    if (exercise['name'].toString().toLowerCase().contains(normalized) ||
        exercise['bodyPart'].toString().toLowerCase().contains(normalized) ||
        exercise['target'].toString().toLowerCase().contains(normalized) ||
        exercise['equipment'].toString().toLowerCase().contains(normalized)) {
      return true;
    }

    final variants = exercise['variants'];
    if (variants is! List) return false;
    return variants.any((variant) {
      if (variant is! Map) return false;
      return variant.values.any(
        (value) => value.toString().toLowerCase().contains(normalized),
      );
    });
  }

  static bool _exerciseHasEquipment(
    Map<String, dynamic> exercise,
    String normalizedEquipment,
  ) {
    if (exercise['equipment'].toString().toLowerCase() == normalizedEquipment) {
      return true;
    }
    if (_stringList(
      exercise['equipments'],
    ).map((e) => e.toLowerCase()).contains(normalizedEquipment)) {
      return true;
    }
    final variants = exercise['variants'];
    if (variants is! List) return false;
    return variants.any((variant) {
      if (variant is! Map) return false;
      return variant['equipment'].toString().toLowerCase() ==
          normalizedEquipment;
    });
  }

  static List<Map<String, dynamic>> _sortExercisesByName(
    List<Map<String, dynamic>> exercises,
  ) {
    return exercises
        .map((exercise) => Map<String, dynamic>.from(exercise))
        .toList()
      ..sort(_compareExerciseNames);
  }

  static List<Map<String, dynamic>> _mergeAndSortExercises(
    List<Map<String, dynamic>> primary,
    List<Map<String, dynamic>> secondary,
  ) {
    final byName = <String, Map<String, dynamic>>{};
    for (final exercise in [...primary, ...secondary]) {
      final key = exercise['name'].toString().trim().toLowerCase();
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => Map<String, dynamic>.from(exercise));
    }
    return byName.values.toList()..sort(_compareExerciseNames);
  }

  static int _compareExerciseNames(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return a['name'].toString().toLowerCase().compareTo(
      b['name'].toString().toLowerCase(),
    );
  }

  static bool _exerciseMatchesMuscleGroup(
    Map<String, dynamic> exercise,
    String muscleGroup,
  ) {
    final normalized = muscleGroup.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return _muscleGroupsForExercise(
      exercise,
    ).map((group) => group.toLowerCase()).contains(normalized);
  }

  static Set<String> _muscleGroupsForExercise(Map<String, dynamic> exercise) {
    final text = [
      exercise['name'],
      exercise['bodyPart'],
      exercise['target'],
      ..._stringList(exercise['bodyParts']),
      ..._stringList(exercise['targetMuscles']),
      ..._stringList(exercise['secondaryMuscles']),
    ].join(' ').toLowerCase();

    final groups = <String>{};

    if (_containsAny(text, ['bench', 'chest press', 'push-up', 'push up'])) {
      groups.add('chest');
      groups.add('triceps');
    }
    if (_containsAny(text, ['dip']) && !_containsAny(text, ['hip'])) {
      groups.add('chest');
      groups.add('triceps');
    }
    if (_containsAny(text, ['deadlift', 'rdl', 'romanian deadlift'])) {
      groups.add('legs');
      groups.add('back');
      groups.add('glutes');
    }
    if (_containsAny(text, ['squat', 'lunge', 'leg press', 'leg extension'])) {
      groups.add('legs');
      groups.add('glutes');
    }
    if (_containsAny(text, ['leg curl', 'hamstring'])) {
      groups.add('legs');
    }
    if (_containsAny(text, ['hip thrust', 'glute bridge', 'kickback'])) {
      groups.add('glutes');
      groups.add('legs');
    }
    if (_containsAny(text, [
      'row',
      'pulldown',
      'pull down',
      'pull-up',
      'pull up',
      'chin-up',
      'chin up',
    ])) {
      groups.add('back');
      groups.add('biceps');
    }
    if (_containsAny(text, ['curl']) && !_containsAny(text, ['leg curl'])) {
      groups.add('biceps');
    }
    if (_containsAny(text, [
      'tricep',
      'skull crusher',
      'pushdown',
      'overhead extension',
    ])) {
      groups.add('triceps');
    }
    if (_containsAny(text, [
      'overhead press',
      'shoulder press',
      'military press',
      'lateral raise',
      'rear delt',
      'face pull',
    ])) {
      groups.add('shoulders');
    }
    if (_containsAny(text, [
      'plank',
      'crunch',
      'sit-up',
      'sit up',
      'ab ',
      'abs',
      'oblique',
      'leg raise',
    ])) {
      groups.add('core');
    }
    if (_containsAny(text, ['calf'])) {
      groups.add('calves');
      groups.add('legs');
    }

    for (final entry in _muscleGroupAliases.entries) {
      if (entry.value.any((alias) => text.contains(alias))) {
        groups.add(entry.key);
      }
    }
    return groups;
  }

  static bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  static const List<String> _primaryMuscleGroups = [
    'back',
    'biceps',
    'calves',
    'cardio',
    'chest',
    'core',
    'forearms',
    'glutes',
    'legs',
    'shoulders',
    'triceps',
  ];

  static const Map<String, List<String>> _muscleGroupAliases = {
    'back': [
      'back',
      'lat',
      'lats',
      'spine',
      'trap',
      'traps',
      'rhomboid',
      'teres',
    ],
    'biceps': ['bicep', 'biceps', 'brachialis', 'curl', 'chin-up', 'chin up'],
    'calves': ['calf', 'calves', 'gastrocnemius', 'soleus'],
    'cardio': ['cardio', 'cardiovascular'],
    'chest': [
      'chest',
      'pectoral',
      'pectorals',
      'pecs',
      'bench',
      'chest press',
      'push-up',
      'push up',
      'fly',
      'dip',
    ],
    'core': [
      'abs',
      'abdominals',
      'core',
      'oblique',
      'obliques',
      'waist',
      'rectus abdominis',
    ],
    'forearms': ['forearm', 'forearms', 'wrist'],
    'glutes': ['glute', 'glutes', 'gluteus', 'hip thrust'],
    'legs': [
      'leg',
      'legs',
      'quad',
      'quads',
      'quadriceps',
      'hamstring',
      'hamstrings',
      'thigh',
      'upper legs',
      'lower legs',
      'squat',
      'lunge',
      'deadlift',
      'rdl',
      'romanian',
      'leg press',
      'leg extension',
      'leg curl',
    ],
    'shoulders': [
      'shoulder',
      'shoulders',
      'delt',
      'delts',
      'deltoid',
      'overhead press',
      'lateral raise',
      'rear delt',
      'face pull',
    ],
    'triceps': ['tricep', 'triceps', 'pushdown', 'skull crusher'],
  };

  static const Map<String, String> _muscleGroupRepresentativeNames = {
    'back': 'pulldown',
    'biceps': 'curl',
    'calves': 'calf',
    'cardio': 'run',
    'chest': 'bench',
    'core': 'plank',
    'forearms': 'wrist',
    'glutes': 'hip thrust',
    'legs': 'deadlift',
    'shoulders': 'shoulder press',
    'triceps': 'pushdown',
  };

  static const List<Map<String, dynamic>> _fallbackExercises = [
    {
      'name': 'Back Squat',
      'bodyPart': 'upper legs',
      'target': 'quads',
      'equipment': 'barbell',
      'variants': [
        {'name': 'Back Squat', 'equipment': 'barbell', 'modifier': 'standard'},
        {
          'name': 'Pause Back Squat',
          'equipment': 'barbell',
          'modifier': 'pause reps',
        },
        {
          'name': 'Tempo Back Squat',
          'equipment': 'barbell',
          'modifier': 'tempo',
        },
        {'name': 'Box Squat', 'equipment': 'barbell', 'modifier': 'box'},
        {
          'name': 'Pin Squat',
          'equipment': 'barbell',
          'modifier': 'pin / partial',
        },
        {
          'name': 'Safety Squat Bar Squat',
          'equipment': 'ssb',
          'modifier': 'bar variation',
        },
        {
          'name': 'Smith Machine Squat',
          'equipment': 'smith machine',
          'modifier': 'machine',
        },
      ],
    },
    {
      'name': 'Front Squat',
      'bodyPart': 'upper legs',
      'target': 'quads',
      'equipment': 'barbell',
    },
    {
      'name': 'Leg Press',
      'bodyPart': 'upper legs',
      'target': 'quads',
      'equipment': 'machine',
    },
    {
      'name': 'Romanian Deadlift',
      'bodyPart': 'upper legs',
      'target': 'hamstrings',
      'equipment': 'barbell',
    },
    {
      'name': 'Leg Curl',
      'bodyPart': 'upper legs',
      'target': 'hamstrings',
      'equipment': 'machine',
    },
    {
      'name': 'Bench Press',
      'bodyPart': 'chest',
      'target': 'pectorals',
      'equipment': 'barbell',
      'variants': [
        {
          'name': 'Barbell Bench Press',
          'equipment': 'barbell',
          'modifier': 'standard',
        },
        {
          'name': 'Pause Bench Press',
          'equipment': 'barbell',
          'modifier': 'pause reps',
        },
        {
          'name': 'Close Grip Bench Press',
          'equipment': 'barbell',
          'modifier': 'close grip',
        },
        {
          'name': 'Incline Barbell Bench Press',
          'equipment': 'barbell',
          'modifier': 'incline',
        },
        {
          'name': 'Decline Barbell Bench Press',
          'equipment': 'barbell',
          'modifier': 'decline',
        },
        {
          'name': 'Dumbbell Bench Press',
          'equipment': 'dumbbell',
          'modifier': 'dumbbell',
        },
        {
          'name': 'Alternating Dumbbell Bench Press',
          'equipment': 'dumbbell',
          'modifier': 'alternating',
        },
        {
          'name': 'Smith Machine Bench Press',
          'equipment': 'smith machine',
          'modifier': 'smith',
        },
        {
          'name': 'Machine Chest Press',
          'equipment': 'machine',
          'modifier': 'machine',
        },
        {
          'name': 'Tempo Bench Press',
          'equipment': 'barbell',
          'modifier': 'tempo',
        },
      ],
    },
    {
      'name': 'Incline Bench Press',
      'bodyPart': 'chest',
      'target': 'pectorals',
      'equipment': 'barbell',
    },
    {
      'name': 'Dumbbell Fly',
      'bodyPart': 'chest',
      'target': 'pectorals',
      'equipment': 'dumbbell',
    },
    {
      'name': 'Cable Crossover',
      'bodyPart': 'chest',
      'target': 'pectorals',
      'equipment': 'cable',
    },
    {
      'name': 'Push Up',
      'bodyPart': 'chest',
      'target': 'pectorals',
      'equipment': 'body weight',
    },
    {
      'name': 'Deadlift',
      'bodyPart': 'back',
      'target': 'spine',
      'equipment': 'barbell',
      'variants': [
        {
          'name': 'Conventional Deadlift',
          'equipment': 'barbell',
          'modifier': 'standard',
        },
        {'name': 'Sumo Deadlift', 'equipment': 'barbell', 'modifier': 'stance'},
        {
          'name': 'Deficit Deadlift',
          'equipment': 'barbell',
          'modifier': 'deficit',
        },
        {
          'name': 'Pause Deadlift',
          'equipment': 'barbell',
          'modifier': 'pause reps',
        },
        {
          'name': 'Block Pull',
          'equipment': 'barbell',
          'modifier': 'block / partial',
        },
        {
          'name': 'Rack Pull',
          'equipment': 'barbell',
          'modifier': 'rack / partial',
        },
        {
          'name': 'Trap Bar Deadlift',
          'equipment': 'trap bar',
          'modifier': 'bar variation',
        },
        {
          'name': 'Romanian Deadlift',
          'equipment': 'barbell',
          'modifier': 'hinge',
        },
      ],
    },
    {
      'name': 'Pull Up',
      'bodyPart': 'back',
      'target': 'lats',
      'equipment': 'body weight',
      'variants': [
        {'name': 'Pull Up', 'equipment': 'body weight', 'modifier': 'pronated'},
        {
          'name': 'Chin Up',
          'equipment': 'body weight',
          'modifier': 'supinated',
        },
        {
          'name': 'Neutral Grip Pull Up',
          'equipment': 'body weight',
          'modifier': 'neutral grip',
        },
        {
          'name': 'Wide Grip Pull Up',
          'equipment': 'body weight',
          'modifier': 'wide grip',
        },
        {
          'name': 'Assisted Pull Up',
          'equipment': 'machine',
          'modifier': 'assisted',
        },
        {
          'name': 'Weighted Pull Up',
          'equipment': 'body weight',
          'modifier': 'weighted',
        },
      ],
    },
    {
      'name': 'Barbell Row',
      'bodyPart': 'back',
      'target': 'lats',
      'equipment': 'barbell',
      'variants': [
        {'name': 'Barbell Row', 'equipment': 'barbell', 'modifier': 'standard'},
        {
          'name': 'Pendlay Row',
          'equipment': 'barbell',
          'modifier': 'floor reset',
        },
        {
          'name': 'Underhand Barbell Row',
          'equipment': 'barbell',
          'modifier': 'supinated',
        },
        {
          'name': 'Dumbbell Row',
          'equipment': 'dumbbell',
          'modifier': 'unilateral',
        },
        {
          'name': 'Chest Supported Row',
          'equipment': 'machine',
          'modifier': 'supported',
        },
        {'name': 'T-Bar Row', 'equipment': 'machine', 'modifier': 'machine'},
      ],
    },
    {
      'name': 'Lat Pulldown',
      'bodyPart': 'back',
      'target': 'lats',
      'equipment': 'cable',
      'variants': [
        {
          'name': 'Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'normal grip',
        },
        {
          'name': 'Wide Grip Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'wide grip',
        },
        {
          'name': 'Close Grip Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'close grip',
        },
        {
          'name': 'V-Grip Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'v grip',
        },
        {
          'name': 'Supinated Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'supinated grip',
        },
        {
          'name': 'Single-Arm Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'unilateral',
        },
        {
          'name': 'Kneeling Lat Pulldown',
          'equipment': 'cable',
          'modifier': 'kneeling',
        },
      ],
    },
    {
      'name': 'Seated Cable Row',
      'bodyPart': 'back',
      'target': 'lats',
      'equipment': 'cable',
      'variants': [
        {
          'name': 'Seated Cable Row',
          'equipment': 'cable',
          'modifier': 'neutral grip',
        },
        {
          'name': 'Wide Grip Seated Cable Row',
          'equipment': 'cable',
          'modifier': 'wide grip',
        },
        {
          'name': 'Close Grip Seated Cable Row',
          'equipment': 'cable',
          'modifier': 'close grip',
        },
        {
          'name': 'Single-Arm Cable Row',
          'equipment': 'cable',
          'modifier': 'unilateral',
        },
        {
          'name': 'Chest Supported Cable Row',
          'equipment': 'cable',
          'modifier': 'supported',
        },
      ],
    },
    {
      'name': 'Overhead Press',
      'bodyPart': 'shoulders',
      'target': 'delts',
      'equipment': 'barbell',
      'variants': [
        {
          'name': 'Barbell Overhead Press',
          'equipment': 'barbell',
          'modifier': 'strict',
        },
        {'name': 'Push Press', 'equipment': 'barbell', 'modifier': 'leg drive'},
        {
          'name': 'Seated Barbell Press',
          'equipment': 'barbell',
          'modifier': 'seated',
        },
        {
          'name': 'Dumbbell Shoulder Press',
          'equipment': 'dumbbell',
          'modifier': 'dumbbell',
        },
        {
          'name': 'Alternating Dumbbell Shoulder Press',
          'equipment': 'dumbbell',
          'modifier': 'alternating',
        },
        {
          'name': 'Smith Machine Shoulder Press',
          'equipment': 'smith machine',
          'modifier': 'smith',
        },
        {
          'name': 'Machine Shoulder Press',
          'equipment': 'machine',
          'modifier': 'machine',
        },
      ],
    },
    {
      'name': 'Lateral Raise',
      'bodyPart': 'shoulders',
      'target': 'delts',
      'equipment': 'dumbbell',
    },
    {
      'name': 'Face Pull',
      'bodyPart': 'shoulders',
      'target': 'delts',
      'equipment': 'cable',
    },
    {
      'name': 'Barbell Curl',
      'bodyPart': 'upper arms',
      'target': 'biceps',
      'equipment': 'barbell',
    },
    {
      'name': 'Dumbbell Curl',
      'bodyPart': 'upper arms',
      'target': 'biceps',
      'equipment': 'dumbbell',
    },
    {
      'name': 'Hammer Curl',
      'bodyPart': 'upper arms',
      'target': 'biceps',
      'equipment': 'dumbbell',
    },
    {
      'name': 'Tricep Pushdown',
      'bodyPart': 'upper arms',
      'target': 'triceps',
      'equipment': 'cable',
      'variants': [
        {
          'name': 'Rope Tricep Pushdown',
          'equipment': 'cable',
          'modifier': 'rope',
        },
        {
          'name': 'Straight Bar Tricep Pushdown',
          'equipment': 'cable',
          'modifier': 'straight bar',
        },
        {
          'name': 'V-Bar Tricep Pushdown',
          'equipment': 'cable',
          'modifier': 'v bar',
        },
        {
          'name': 'Single-Arm Tricep Pushdown',
          'equipment': 'cable',
          'modifier': 'unilateral',
        },
        {
          'name': 'Reverse Grip Tricep Pushdown',
          'equipment': 'cable',
          'modifier': 'supinated',
        },
      ],
    },
    {
      'name': 'Skull Crusher',
      'bodyPart': 'upper arms',
      'target': 'triceps',
      'equipment': 'barbell',
    },
    {
      'name': 'Close Grip Bench',
      'bodyPart': 'upper arms',
      'target': 'triceps',
      'equipment': 'barbell',
    },
    {
      'name': 'Plank',
      'bodyPart': 'waist',
      'target': 'abs',
      'equipment': 'body weight',
    },
    {
      'name': 'Crunch',
      'bodyPart': 'waist',
      'target': 'abs',
      'equipment': 'body weight',
    },
    {
      'name': 'Leg Raise',
      'bodyPart': 'waist',
      'target': 'abs',
      'equipment': 'body weight',
    },
    {
      'name': 'Calf Raise',
      'bodyPart': 'lower legs',
      'target': 'calves',
      'equipment': 'barbell',
    },
    {
      'name': 'Hip Thrust',
      'bodyPart': 'upper legs',
      'target': 'glutes',
      'equipment': 'barbell',
    },
    {
      'name': 'Lunge',
      'bodyPart': 'upper legs',
      'target': 'quads',
      'equipment': 'body weight',
    },
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
