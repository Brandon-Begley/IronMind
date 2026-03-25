import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ── Supabase ──────────────────────────────────────────────────────────────────
  static const String _supabaseUrl = 'https://ksbosztywxazcbvmfwpo.supabase.co';
  static const String _supabaseKey = 'TwcqLBanG6vAYXvrZ0BiG33gc8mwMzBW9OOaU90m';

  static Map<String, String> get _supaHeaders => {
    'Content-Type': 'application/json',
    'apikey': _supabaseKey,
    'Authorization': 'Bearer $_supabaseKey',
    'Prefer': 'return=representation',
  };

  // ── ExerciseDB (RapidAPI) ─────────────────────────────────────────────────────
  static const String _exerciseDbKey = '04c1239e23msh7a29fc15df9d5c4p178ec0jsn2854acf5e719';
  static const String _exerciseDbHost = 'exercisedb.p.rapidapi.com';

  static Map<String, String> get _exerciseHeaders => {
    'X-RapidAPI-Key': _exerciseDbKey,
    'X-RapidAPI-Host': _exerciseDbHost,
  };

  // ── USDA Food API ─────────────────────────────────────────────────────────────
  static const String _usdaKey = 'PASTE_YOUR_USDA_KEY_HERE';

  // ── Connection check ──────────────────────────────────────────────────────────
  static Future<bool> testConnection() async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/workout_logs?limit=1'),
        headers: _supaHeaders,
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Workout Logs ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getLogs() async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/workout_logs?order=created_at.desc&limit=50'),
        headers: _supaHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    // Fallback to local
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('workout_logs') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<Map<String, dynamic>> saveLog(Map<String, dynamic> log) async {
    // Always save locally first
    final prefs = await SharedPreferences.getInstance();
    final existing = await getLogs();
    final localLog = {...log, 'id': DateTime.now().millisecondsSinceEpoch};
    existing.insert(0, localLog);
    await prefs.setString('workout_logs', jsonEncode(existing));

    // Sync to Supabase
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/workout_logs'),
        headers: _supaHeaders,
        body: jsonEncode(log),
      );
      if (res.statusCode == 201) return jsonDecode(res.body)[0];
    } catch (_) {}
    return localLog;
  }

  static Future<void> deleteLog(dynamic id) async {
    // Remove from local
    final prefs = await SharedPreferences.getInstance();
    final logs = await getLogs();
    logs.removeWhere((l) => l['id'].toString() == id.toString());
    await prefs.setString('workout_logs', jsonEncode(logs));

    // Delete from Supabase
    try {
      await http.delete(
        Uri.parse('$_supabaseUrl/rest/v1/workout_logs?id=eq.$id'),
        headers: _supaHeaders,
      );
    } catch (_) {}
  }

  // ── Personal Records ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPRs() async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/personal_records?order=date.desc'),
        headers: _supaHeaders,
      );
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    // Fallback to local
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('prs') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<Map<String, dynamic>> savePR(Map<String, dynamic> pr) async {
    // Calculate e1RM before saving
    final weight = (pr['weight'] as num).toDouble();
    final reps = (pr['reps'] as num).toInt();
    pr['estimated_1rm'] = calculate1RM(weight, reps).round();

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    final existing = await getPRs();
    existing.insert(0, pr);
    await prefs.setString('prs', jsonEncode(existing));

    // Sync to Supabase
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/personal_records'),
        headers: _supaHeaders,
        body: jsonEncode(pr),
      );
      if (res.statusCode == 201) return jsonDecode(res.body)[0];
    } catch (_) {}
    return pr;
  }

  static Future<Map<String, dynamic>?> getLastPRForExercise(String exercise) async {
    try {
      final encoded = Uri.encodeComponent(exercise);
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/personal_records?exercise=ilike.$encoded&order=date.desc&limit=1'),
        headers: _supaHeaders,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.isNotEmpty ? list.first : null;
      }
    } catch (_) {}
    final prs = await getPRs();
    final matching = prs.where((p) => (p['exercise'] as String?)?.toLowerCase() == exercise.toLowerCase()).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return matching.first;
  }

  static Future<bool> isNewPR(String exercise, double weight) async {
    final last = await getLastPRForExercise(exercise);
    return last == null || weight > (last['weight'] as num);
  }

  // ── Wellness ──────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getWellness() async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/wellness_logs?order=date.desc&limit=30'),
        headers: _supaHeaders,
      );
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> getWellnessToday() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/wellness_logs?date=eq.$today&limit=1'),
        headers: _supaHeaders,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.isNotEmpty ? list.first : null;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveWellness(Map<String, dynamic> data) async {
    try {
      // Upsert — update if today's entry exists, insert if not
      await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/wellness_logs'),
        headers: {..._supaHeaders, 'Prefer': 'resolution=merge-duplicates,return=representation'},
        body: jsonEncode(data),
      );
    } catch (_) {}
  }

  // ── AI Generate ───────────────────────────────────────────────────────────────
  // AI generation still needs your backend running — pointing to Supabase Edge Functions
  // For now keeps working if backend is available, gracefully fails if not
  static Future<String> generateWorkout(String prompt) async {
    // Try Supabase Edge Function first (set up in Supabase → Edge Functions)
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/generate-workout'),
        headers: {..._supaHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['text'] ?? data['content'] ?? '';
      }
    } catch (_) {}
    return 'AI generation requires a backend connection. Set up a Supabase Edge Function or connect your server in Settings.';
  }

  // ── Nutrition Plans ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateMealPlan({String? goal, int days = 7, String? preferences}) async {
    try {
      final res = await http.post(
        Uri.parse('$_supabaseUrl/functions/v1/generate-meal-plan'),
        headers: {..._supaHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'goal': goal, 'days': days, 'preferences': preferences}),
      ).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    throw Exception('Could not generate meal plan');
  }

  static Future<Map<String, dynamic>?> getLatestNutrition() async {
    try {
      final res = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/nutrition_plans?order=created_at.desc&limit=1'),
        headers: _supaHeaders,
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.isNotEmpty ? list.first : null;
      }
    } catch (_) {}
    return null;
  }

  // ── USDA Food Search ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchFood(String query) async {
    // Try USDA first
    try {
      final res = await http.get(
        Uri.parse('https://api.nal.usda.gov/fdc/v1/foods/search?query=${Uri.encodeComponent(query)}&pageSize=20&api_key=$_usdaKey'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final foods = data['foods'] as List? ?? [];
        return foods.map<Map<String, dynamic>>((f) {
          final nutrients = f['foodNutrients'] as List? ?? [];
          double getNutrient(String name) {
            final n = nutrients.firstWhere(
              (n) => (n['nutrientName'] as String?)?.toLowerCase().contains(name.toLowerCase()) == true,
              orElse: () => {'value': 0},
            );
            return (n['value'] as num?)?.toDouble() ?? 0;
          }
          return {
            'name': f['description'] ?? 'Unknown',
            'brand': f['brandOwner'] ?? f['brandName'] ?? '',
            'serving': '${f['servingSize'] ?? 100}${f['servingSizeUnit'] ?? 'g'}',
            'calories': getNutrient('Energy').round(),
            'protein': getNutrient('Protein'),
            'carbs': getNutrient('Carbohydrate'),
            'fat': getNutrient('Total lipid'),
          };
        }).where((f) => f['calories'] as int > 0).toList();
      }
    } catch (_) {}

    // Fallback to Open Food Facts
    try {
      final encoded = Uri.encodeComponent(query);
      final res = await http.get(Uri.parse(
          'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$encoded&search_simple=1&action=process&json=1&page_size=20'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final products = data['products'] as List? ?? [];
        return products
            .where((p) => p['product_name'] != null && (p['product_name'] as String).isNotEmpty && p['nutriments'] != null)
            .map<Map<String, dynamic>>((p) {
          final n = p['nutriments'] as Map;
          return {
            'name': p['product_name'] ?? 'Unknown',
            'brand': p['brands'] ?? '',
            'serving': p['serving_size'] ?? '100g',
            'calories': ((n['energy-kcal_serving'] ?? n['energy-kcal_100g'] ?? 0) as num).round(),
            'protein': ((n['proteins_serving'] ?? n['proteins_100g'] ?? 0) as num).roundToDouble(),
            'carbs': ((n['carbohydrates_serving'] ?? n['carbohydrates_100g'] ?? 0) as num).roundToDouble(),
            'fat': ((n['fat_serving'] ?? n['fat_100g'] ?? 0) as num).roundToDouble(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── ExerciseDB ────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getExercises({
    String? muscle,
    String? equipment,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      String url;
      if (search != null && search.isNotEmpty) {
        url = 'https://exercisedb.p.rapidapi.com/exercises/name/${Uri.encodeComponent(search.toLowerCase())}?limit=$limit&offset=$offset';
      } else if (muscle != null && muscle.isNotEmpty) {
        url = 'https://exercisedb.p.rapidapi.com/exercises/bodyPart/${Uri.encodeComponent(muscle.toLowerCase())}?limit=$limit&offset=$offset';
      } else if (equipment != null && equipment.isNotEmpty) {
        url = 'https://exercisedb.p.rapidapi.com/exercises/equipment/${Uri.encodeComponent(equipment.toLowerCase())}?limit=$limit&offset=$offset';
      } else {
        url = 'https://exercisedb.p.rapidapi.com/exercises?limit=$limit&offset=$offset';
      }
      final res = await http.get(Uri.parse(url), headers: _exerciseHeaders);
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  static Future<List<String>> getBodyParts() async {
    try {
      final res = await http.get(
        Uri.parse('https://exercisedb.p.rapidapi.com/exercises/bodyPartList'),
        headers: _exerciseHeaders,
      );
      if (res.statusCode == 200) {
        return List<String>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return ['back', 'cardio', 'chest', 'lower arms', 'lower legs', 'neck', 'shoulders', 'upper arms', 'upper legs', 'waist'];
  }

  static Future<List<String>> getEquipmentList() async {
    try {
      final res = await http.get(
        Uri.parse('https://exercisedb.p.rapidapi.com/exercises/equipmentList'),
        headers: _exerciseHeaders,
      );
      if (res.statusCode == 200) {
        return List<String>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return ['barbell', 'dumbbell', 'cable', 'machine', 'body weight', 'kettlebell', 'band', 'smith machine'];
  }

  static Future<Map<String, dynamic>?> getExerciseById(String id) async {
    try {
      final res = await http.get(
        Uri.parse('https://exercisedb.p.rapidapi.com/exercises/exercise/$id'),
        headers: _exerciseHeaders,
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // ── Food log (local) ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getFoodLog(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('food_log_$date') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveFoodEntry(String date, Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final log = await getFoodLog(date);
    log.add(entry);
    await prefs.setString('food_log_$date', jsonEncode(log));
  }

  static Future<void> deleteFoodEntry(String date, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final log = await getFoodLog(date);
    if (index < log.length) log.removeAt(index);
    await prefs.setString('food_log_$date', jsonEncode(log));
  }

  // ── Nutrition Targets ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getNutritionTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nutrition_targets');
    if (raw != null) return jsonDecode(raw);
    return {'calories': 2300, 'protein': 260, 'carbs': 200, 'fat': 55};
  }

  static Future<void> saveNutritionTargets(Map<String, dynamic> targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nutrition_targets', jsonEncode(targets));
  }

  // ── Bodyweight (local + Supabase future) ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getBodyweightLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bodyweight_log') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> logBodyweight(double weight, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final log = await getBodyweightLog();
    log.removeWhere((e) => e['date'] == date);
    log.add({'date': date, 'weight': weight});
    log.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    await prefs.setString('bodyweight_log', jsonEncode(log));
  }

  static Future<void> deleteBodyweightEntry(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final log = await getBodyweightLog();
    log.removeWhere((e) => e['date'] == date);
    await prefs.setString('bodyweight_log', jsonEncode(log));
  }

  // ── Measurements (local) ──────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getMeasurements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('measurements') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> saveMeasurement(Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final log = await getMeasurements();
    log.add(entry);
    log.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    await prefs.setString('measurements', jsonEncode(log));
  }

  // ── Routines (local) ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('routines');
    if (raw != null) return List<Map<String, dynamic>>.from(jsonDecode(raw));
    return [
      {'id': '1', 'name': 'Squat Day', 'primary': ['Quads', 'Glutes'], 'secondary': ['Hamstrings'], 'exercises': ['Back Squat', 'Leg Press', 'Romanian Deadlift', 'Leg Curl', 'Calf Raise']},
      {'id': '2', 'name': 'Bench Day', 'primary': ['Chest'], 'secondary': ['Triceps', 'Front Delts'], 'exercises': ['Bench Press', 'Incline DB Press', 'Tricep Pushdown', 'Lateral Raise']},
      {'id': '3', 'name': 'Deadlift Day', 'primary': ['Glutes', 'Hamstrings'], 'secondary': ['Lats', 'Traps'], 'exercises': ['Deadlift', 'Barbell Row', 'Lat Pulldown', 'Face Pull']},
    ];
  }

  static Future<void> saveRoutines(List<Map<String, dynamic>> routines) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('routines', jsonEncode(routines));
  }

  static Future<void> deleteRoutine(String id) async {
    final routines = await getRoutines();
    routines.removeWhere((r) => r['id'] == id);
    await saveRoutines(routines);
  }

  static Future<void> saveRoutine(Map<String, dynamic> routine) async {
    final routines = await getRoutines();
    final idx = routines.indexWhere((r) => r['id'] == routine['id']);
    if (idx >= 0) routines[idx] = routine; else routines.add(routine);
    await saveRoutines(routines);
  }

  // ── Lifter Profile (local) ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLifterProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lifter_profile');
    if (raw != null) return jsonDecode(raw);
    return {
      'name': '', 'experience': 'intermediate', 'style': 'powerlifting',
      'trainingDays': 4.0, 'sessionLength': 75.0,
      'squat': '', 'bench': '', 'deadlift': '', 'ohp': '',
      'goal': 'peak-strength', 'weakpoint': 'none',
      'equipment': ['Barbell', 'Dumbbells', 'Cable Machine'], 'bodyweight': '',
    };
  }

  static Future<void> saveLifterProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lifter_profile', jsonEncode(profile));
  }

  // ── 1RM Calculator (Brzycki formula) ─────────────────────────────────────────
  static double calculate1RM(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight / (1.0278 - 0.0278 * reps);
  }
}
