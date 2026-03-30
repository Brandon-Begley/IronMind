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
    if (usdaFoodApiKey.trim().isEmpty) {
      return _fallbackFoods(query, pageSize: pageSize);
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search?query=$query&pageSize=$pageSize&api_key=$usdaFoodApiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> foods = data['foods'] ?? [];
        if (foods.isEmpty) {
          return _fallbackFoods(query, pageSize: pageSize);
        }
        return foods.cast<Map<String, dynamic>>();
      } else {
        return _fallbackFoods(query, pageSize: pageSize);
      }
    } catch (_) {
      return _fallbackFoods(query, pageSize: pageSize);
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

  static List<Map<String, dynamic>> _fallbackFoods(
    String query, {
    int pageSize = 20,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    final matches = _sampleFoods.where((food) {
      final description = (food['description'] ?? '').toString().toLowerCase();
      final brand = (food['brandOwner'] ?? '').toString().toLowerCase();
      return description.contains(normalized) || brand.contains(normalized);
    }).toList();

    final source = matches.isEmpty ? _sampleFoods : matches;
    return source.take(pageSize).map((food) => Map<String, dynamic>.from(food)).toList();
  }

  static const List<Map<String, dynamic>> _sampleFoods = [
    {
      'description': 'Chicken Breast, grilled',
      'brandOwner': 'IronMind',
      'fdcId': 1,
      'foodNutrients': [
        {'nutrientName': 'Energy', 'value': 165},
        {'nutrientName': 'Protein', 'value': 31},
        {'nutrientName': 'Carbohydrate, by difference', 'value': 0},
        {'nutrientName': 'Total lipid (fat)', 'value': 3.6},
      ],
    },
    {
      'description': 'White Rice, cooked',
      'brandOwner': 'IronMind',
      'fdcId': 2,
      'foodNutrients': [
        {'nutrientName': 'Energy', 'value': 130},
        {'nutrientName': 'Protein', 'value': 2.7},
        {'nutrientName': 'Carbohydrate, by difference', 'value': 28},
        {'nutrientName': 'Total lipid (fat)', 'value': 0.3},
      ],
    },
    {
      'description': 'Whole Egg',
      'brandOwner': 'IronMind',
      'fdcId': 3,
      'foodNutrients': [
        {'nutrientName': 'Energy', 'value': 72},
        {'nutrientName': 'Protein', 'value': 6.3},
        {'nutrientName': 'Carbohydrate, by difference', 'value': 0.4},
        {'nutrientName': 'Total lipid (fat)', 'value': 4.8},
      ],
    },
    {
      'description': 'Greek Yogurt, nonfat',
      'brandOwner': 'IronMind',
      'fdcId': 4,
      'foodNutrients': [
        {'nutrientName': 'Energy', 'value': 59},
        {'nutrientName': 'Protein', 'value': 10.3},
        {'nutrientName': 'Carbohydrate, by difference', 'value': 3.6},
        {'nutrientName': 'Total lipid (fat)', 'value': 0.4},
      ],
    },
    {
      'description': 'Banana',
      'brandOwner': 'IronMind',
      'fdcId': 5,
      'foodNutrients': [
        {'nutrientName': 'Energy', 'value': 89},
        {'nutrientName': 'Protein', 'value': 1.1},
        {'nutrientName': 'Carbohydrate, by difference', 'value': 22.8},
        {'nutrientName': 'Total lipid (fat)', 'value': 0.3},
      ],
    },
    {
      'description': 'Salmon, baked',
      'brandOwner': 'IronMind',
      'fdcId': 6,
      'foodNutrients': [
        {'nutrientName': 'Energy', 'value': 208},
        {'nutrientName': 'Protein', 'value': 20},
        {'nutrientName': 'Carbohydrate, by difference', 'value': 0},
        {'nutrientName': 'Total lipid (fat)', 'value': 13},
      ],
    },
  ];
}
