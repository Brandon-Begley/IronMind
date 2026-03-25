import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/usda_food_service.dart';
import '../services/supabase_service.dart';

class LogMealDialog extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>) onMealLogged;

  const LogMealDialog({
    required this.userId,
    required this.onMealLogged,
  });

  @override
  State<LogMealDialog> createState() => _LogMealDialogState();
}

class _LogMealDialogState extends State<LogMealDialog> {
  late TextEditingController _foodController;
  late TextEditingController _servingSizeController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatsController;

  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _foodSuggestions = [];

  @override
  void initState() {
    super.initState();
    _foodController = TextEditingController();
    _servingSizeController = TextEditingController(text: '100');
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatsController = TextEditingController();
  }

  @override
  void dispose() {
    _foodController.dispose();
    _servingSizeController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  Future<void> _searchFoods(String query) async {
    if (query.isEmpty) {
      setState(() => _foodSuggestions = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final foods = await UsdaFoodService.searchFoods(query, pageSize: 10);
      setState(() => _foodSuggestions = foods);
    } catch (e) {
      print('Error searching foods: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectFood(Map<String, dynamic> food) {
    final formatted = UsdaFoodService.formatFoodResult(food);
    setState(() {
      _foodController.text = formatted['name'] ?? '';
      _caloriesController.text = formatted['calories'].toString();
      _proteinController.text = formatted['protein'].toString();
      _carbsController.text = formatted['carbs'].toString();
      _fatsController.text = formatted['fats'].toString();
      _foodSuggestions = [];
    });
  }

  Future<void> _logMeal() async {
    if (_foodController.text.isEmpty ||
        _servingSizeController.text.isEmpty ||
        _caloriesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final meal = await SupabaseService().logMeal(
        userId: widget.userId,
        foodName: _foodController.text,
        calories: double.parse(_caloriesController.text),
        protein: double.parse(_proteinController.text),
        carbs: double.parse(_carbsController.text),
        fats: double.parse(_fatsController.text),
        servingSize: double.parse(_servingSizeController.text),
        date: DateTime.now(),
      );

      widget.onMealLogged(meal);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Meal logged!')),
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
      'Log Meal',
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
          // Food search field
          TextField(
            controller: _foodController,
            onChanged: _searchFoods,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search Food',
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
          if (_foodSuggestions.isNotEmpty) ...[
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
                itemCount: _foodSuggestions.length,
                itemBuilder: (context, index) {
                  final food = _foodSuggestions[index];
                  return ListTile(
                    title: Text(
                      food['description'] ?? '',
                      style: const TextStyle(
                        color: IronMindTheme.textPrimary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectFood(food),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Serving size
          TextField(
            controller: _servingSizeController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Serving Size (g)',
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
          // Calories
          TextField(
            controller: _caloriesController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: IronMindTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Calories',
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
          // Macros row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _proteinController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: IronMindTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Protein (g)',
                    hintStyle: const TextStyle(color: IronMindTheme.text3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: IronMindTheme.border),
                    ),
                    filled: true,
                    fillColor: IronMindTheme.surface2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _carbsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: IronMindTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Carbs (g)',
                    hintStyle: const TextStyle(color: IronMindTheme.text3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: IronMindTheme.border),
                    ),
                    filled: true,
                    fillColor: IronMindTheme.surface2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fatsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: IronMindTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Fats (g)',
                    hintStyle: const TextStyle(color: IronMindTheme.text3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: IronMindTheme.border),
                    ),
                    filled: true,
                    fillColor: IronMindTheme.surface2,
                  ),
                ),
              ),
            ],
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
        onPressed: _isLoading ? null : _logMeal,
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
