import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_keys.dart';

class ExerciseDbService {
  static const String _baseUrl = 'https://exercisedb.p.rapidapi.com';

  // Get all exercises
  static Future<List<Map<String, dynamic>>> getAllExercises() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exercises'),
        headers: {
          'x-rapidapi-key': exerciseDbApiKey,
          'x-rapidapi-host': exerciseDbApiHost,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load exercises: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exercises: $e');
    }
  }

  // Get exercises by target muscle
  static Future<List<Map<String, dynamic>>> getExercisesByMuscle(
    String muscle,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exercises/target/$muscle'),
        headers: {
          'x-rapidapi-key': exerciseDbApiKey,
          'x-rapidapi-host': exerciseDbApiHost,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load exercises: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exercises: $e');
    }
  }

  // Get exercises by equipment
  static Future<List<Map<String, dynamic>>> getExercisesByEquipment(
    String equipment,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exercises/equipment/$equipment'),
        headers: {
          'x-rapidapi-key': exerciseDbApiKey,
          'x-rapidapi-host': exerciseDbApiHost,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load exercises: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exercises: $e');
    }
  }

  // Search exercises by name
  static Future<List<Map<String, dynamic>>> searchExercises(
    String query,
  ) async {
    try {
      final allExercises = await getAllExercises();
      final lowerQuery = query.toLowerCase();
      
      return allExercises
          .where((exercise) =>
              exercise['name']
                  .toString()
                  .toLowerCase()
                  .contains(lowerQuery) ||
              exercise['target']
                  .toString()
                  .toLowerCase()
                  .contains(lowerQuery))
          .toList();
    } catch (e) {
      throw Exception('Error searching exercises: $e');
    }
  }

  // Get unique muscle groups
  static Future<List<String>> getMuscleGroups() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exercises/targetList'),
        headers: {
          'x-rapidapi-key': exerciseDbApiKey,
          'x-rapidapi-host': exerciseDbApiHost,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      } else {
        throw Exception('Failed to load muscles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching muscles: $e');
    }
  }

  // Get unique equipment types
  static Future<List<String>> getEquipmentTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/exercises/equipmentList'),
        headers: {
          'x-rapidapi-key': exerciseDbApiKey,
          'x-rapidapi-host': exerciseDbApiHost,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      } else {
        throw Exception('Failed to load equipment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching equipment: $e');
    }
  }
}
