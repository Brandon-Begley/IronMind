import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = 'http://10.0.20.93:3000';

  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('base_url') ?? 'http://10.0.20.93:3000';
  }

  static Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', baseUrl);
  }

  static Future<bool> testConnection() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/logs')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Workout Logs ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getLogs() async {
    final res = await http.get(Uri.parse('$baseUrl/api/logs'));
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load logs');
  }

  static Future<Map<String, dynamic>> saveLog(Map<String, dynamic> log) async {
    final res = await http.post(Uri.parse('$baseUrl/api/logs'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(log));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to save log');
  }

  static Future<void> deleteLog(int id) async {
    await http.delete(Uri.parse('$baseUrl/api/logs/$id'));
  }

  // ── Personal Records ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getPRs() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/prs')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    } catch (_) {}
    
    // Fallback to local storage
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('prs') ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<Map<String, dynamic>> savePR(Map<String, dynamic> pr) async {
    // Save locally first
    final prefs = await SharedPreferences.getInstance();
    final existing = await getPRs();
    existing.add(pr);
    await prefs.setString('prs', jsonEncode(existing));
    
    // Try to sync to server
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/prs'), 
        headers: {'Content-Type': 'application/json'}, 
        body: jsonEncode(pr)
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    
    return pr;
  }
  
  // Get last PR for a specific exercise
  static Future<Map<String, dynamic>?> getLastPRForExercise(String exercise) async {
    final prs = await getPRs();
    final matching = prs.where((p) => (p['exercise'] as String?)?.toLowerCase() == exercise.toLowerCase()).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return matching.first;
  }
  
  // Check if a weight is a new PR
  static Future<bool> isNewPR(String exercise, double weight) async {
    final lastPR = await getLastPRForExercise(exercise);
    return lastPR == null || weight > (lastPR['weight'] as num);
  }

  // ── Progress ─────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getProgress(String exercise) async {
    final res = await http.get(Uri.parse('$baseUrl/api/progress/${Uri.encodeComponent(exercise)}'));
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load progress');
  }

  // ── Wellness ─────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getWellness() async {
    final res = await http.get(Uri.parse('$baseUrl/api/wellness'));
    if (res.statusCode == 200) return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    throw Exception('Failed to load wellness');
  }

  static Future<Map<String, dynamic>?> getWellnessToday() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/wellness/today'));
      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (body == 'null') return null;
        return jsonDecode(body);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveWellness(Map<String, dynamic> data) async {
    await http.post(Uri.parse('$baseUrl/api/wellness'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(data));
  }

  // ── AI Generate ──────────────────────────────────────────────────────────────
  static Future<String> generateWorkout(String prompt) async {
    final res = await http.post(Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'prompt': prompt}));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final content = data['content'] as List;
      return content.firstWhere((b) => b['type'] == 'text')['text'] ?? '';
    }
    throw Exception('Failed to generate');
  }

  // ── Nutrition ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> generateMealPlan({String? goal, int days = 7, String? preferences}) async {
    final res = await http.post(Uri.parse('$baseUrl/api/nutrition/generate'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'goal': goal, 'days': days, 'preferences': preferences}));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to generate meal plan');
  }

  static Future<Map<String, dynamic>?> getLatestNutrition() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/nutrition/latest'));
      if (res.statusCode == 200) {
        final body = res.body.trim();
        if (body == 'null') return null;
        return jsonDecode(body);
      }
    } catch (_) {}
    return null;
  }

  // ── Open Food Facts ───────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> searchFood(String query) async {
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

  // ── Nutrition Targets (user-configurable) ─────────────────────────────────────
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

  // ── Bodyweight (local) ────────────────────────────────────────────────────────
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
    // Default routines
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
    if (idx >= 0) {
      routines[idx] = routine;
    } else {
      routines.add(routine);
    }
    await saveRoutines(routines);
  }

  // ── Lifter Profile (local) ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLifterProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('lifter_profile');
    if (raw != null) return jsonDecode(raw);
    return {
      'name': '',
      'experience': 'intermediate',
      'style': 'powerlifting',
      'trainingDays': 4.0,
      'sessionLength': 75.0,
      'squat': '',
      'bench': '',
      'deadlift': '',
      'ohp': '',
      'goal': 'peak-strength',
      'weakpoint': 'none',
      'equipment': ['Barbell', 'Dumbbells', 'Cable Machine'],
      'bodyweight': '',
    };
  }

  static Future<void> saveLifterProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lifter_profile', jsonEncode(profile));
  }

  // ── 1RM Calculator ────────────────────────────────────────────────────────────
  static double calculate1RM(double weight, int reps) {
    if (reps <= 0) return weight;
    if (reps == 1) return weight;
    return weight / (1.0278 - 0.0278 * reps);
  }
}
