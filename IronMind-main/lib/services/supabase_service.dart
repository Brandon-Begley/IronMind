import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Auth methods
  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? getCurrentUser() {
    return client.auth.currentUser;
  }

  // Database methods
  Future<List<Map<String, dynamic>>> getFromTable(String tableName) async {
    return await client.from(tableName).select();
  }

  Future<Map<String, dynamic>> insertIntoTable(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    return await client.from(tableName).insert(data).select().single();
  }

  Future<void> updateTable(
    String tableName,
    Map<String, dynamic> data,
    String id,
  ) async {
    await client.from(tableName).update(data).eq('id', id);
  }

  Future<void> deleteFromTable(String tableName, String id) async {
    await client.from(tableName).delete().eq('id', id);
  }

  // Storage methods
  Future<String> uploadFile(
    String bucket,
    String path,
    Uint8List fileBytes,
  ) async {
    await client.storage.from(bucket).uploadBinary(path, fileBytes);
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    await client.storage.from(bucket).remove([path]);
  }

  // Workout logging
  Future<Map<String, dynamic>> logWorkout({
    required String userId,
    required String exerciseName,
    required String targetMuscle,
    required int weight,
    required int reps,
    required int sets,
    required DateTime date,
  }) async {
    try {
      return await client.from('workouts').insert({
        'user_id': userId,
        'exercise_name': exerciseName,
        'target_muscle': targetMuscle,
        'weight': weight,
        'reps': reps,
        'sets': sets,
        'date': date.toIso8601String(),
      }).select().single();
    } catch (e) {
      throw Exception('Error logging workout: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserWorkouts(String userId) async {
    try {
      return await client
          .from('workouts')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
    } catch (e) {
      throw Exception('Error fetching workouts: $e');
    }
  }

  // Nutrition logging
  Future<Map<String, dynamic>> logMeal({
    required String userId,
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    required double servingSize,
    required DateTime date,
  }) async {
    try {
      return await client.from('nutrition').insert({
        'user_id': userId,
        'food_name': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'serving_size': servingSize,
        'date': date.toIso8601String(),
      }).select().single();
    } catch (e) {
      throw Exception('Error logging meal: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserMeals(String userId) async {
    try {
      return await client
          .from('nutrition')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
    } catch (e) {
      throw Exception('Error fetching meals: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserMealsByDate(
    String userId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      return await client
          .from('nutrition')
          .select()
          .eq('user_id', userId)
          .ilike('date', '$dateStr%')
          .order('date', ascending: true);
    } catch (e) {
      throw Exception('Error fetching meals: $e');
    }
  }
