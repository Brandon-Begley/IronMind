import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_keys.dart';

class UsdaFoodService {
  static const String _baseUrl = 'https://fdc.nal.usda.gov/api/food';

  // Search foods by name
  static Future<List<Map<String, dynamic>>> searchFoods(
    String query, {
    int pageSize = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search?query=$query&pageSize=$pageSize&api_key=$usdaFoodApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> foods = data['foods'] ?? [];
        return foods.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to search foods: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching foods: $e');
    }
  }

  // Get detailed food information by FDC ID
  static Future<Map<String, dynamic>> getFoodDetails(String fdcId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/details/$fdcId?api_key=$usdaFoodApiKey'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get food details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching food details: $e');
    }
  }

  // Extract nutrition info from food details
  static Map<String, double> extractNutrition(
    Map<String, dynamic> foodDetails,
  ) {
    final nutrients = foodDetails['foodNutrients'] as List? ?? [];
    
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fats = 0;

    for (var nutrient in nutrients) {
      final nutrientName = nutrient['nutrientName']?.toString().toLowerCase() ?? '';
      final value = (nutrient['value'] as num?)?.toDouble() ?? 0;

      if (nutrientName.contains('energy') || nutrientName.contains('calorie')) {
        calories = value;
      } else if (nutrientName.contains('protein')) {
        protein = value;
      } else if (nutrientName.contains('carbohydrate')) {
        carbs = value;
      } else if (nutrientName.contains('total lipid') || nutrientName.contains('fat')) {
        fats = value;
      }
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };
  }

  // Format food search result with basic nutrition
  static Map<String, dynamic> formatFoodResult(
    Map<String, dynamic> foodData,
  ) {
    final description = foodData['description'] ?? '';
    final fdcId = foodData['fdcId'] ?? '';
    
    // Try to extract macros if available
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fats = 0;

    final foodNutrients = foodData['foodNutrients'] as List? ?? [];
    for (var nutrient in foodNutrients) {
      final nutrientName = nutrient['nutrientName']?.toString().toLowerCase() ?? '';
      final value = (nutrient['value'] as num?)?.toDouble() ?? 0;

      if (nutrientName.contains('energy')) {
        calories = value;
      } else if (nutrientName.contains('protein')) {
        protein = value;
      } else if (nutrientName.contains('carbohydrate')) {
        carbs = value;
      } else if (nutrientName.contains('total lipid')) {
        fats = value;
      }
    }

    return {
      'name': description,
      'fdc_id': fdcId,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };
  }
}
