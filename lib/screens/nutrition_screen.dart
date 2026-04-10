import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

class NutritionScreen extends StatefulWidget {
  final bool connected;
  const NutritionScreen({super.key, this.connected = false});
  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final String _today = DateTime.now().toIso8601String().split('T')[0];
  Map<String, dynamic> _targets = {'calories': 2300, 'protein': 260, 'carbs': 200, 'fat': 55};
  int _refreshTick = 0;
  int _plansRefreshTick = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    ApiService.getNutritionTargets().then((t) => setState(() => _targets = t));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _showTargetSetup() {
    final calCtrl = TextEditingController(text: '${_targets['calories']}');
    final protCtrl = TextEditingController(text: '${_targets['protein']}');
    final carbCtrl = TextEditingController(text: '${_targets['carbs']}');
    final fatCtrl = TextEditingController(text: '${_targets['fat']}');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NUTRITION TARGETS', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text('Set your daily calorie and macro goals', style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(controller: calCtrl, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Daily Calories', suffixText: 'kcal')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: protCtrl, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(labelText: 'Protein', suffixText: 'g', labelStyle: GoogleFonts.dmMono(color: IronMindTheme.green)))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: carbCtrl, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(labelText: 'Carbs', suffixText: 'g', labelStyle: GoogleFonts.dmMono(color: IronMindTheme.blue)))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: fatCtrl, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(labelText: 'Fat', suffixText: 'g', labelStyle: GoogleFonts.dmMono(color: IronMindTheme.orange)))),
          ]),
          const SizedBox(height: 16),
          IronButton(label: 'SAVE TARGETS', onPressed: () async {
            final targets = {
              'calories': int.tryParse(calCtrl.text) ?? 2300,
              'protein': int.tryParse(protCtrl.text) ?? 260,
              'carbs': int.tryParse(carbCtrl.text) ?? 200,
              'fat': int.tryParse(fatCtrl.text) ?? 55,
            };
            await ApiService.saveNutritionTargets(targets);
            setState(() => _targets = targets);
            Navigator.pop(ctx);
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: 'Food Log',
        connected: widget.connected,
        actions: [
          IconButton(icon: const Icon(Icons.tune, size: 20), color: IronMindTheme.text2, onPressed: _showTargetSetup, tooltip: 'Set targets'),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () => _showAddFood(),
              style: ElevatedButton.styleFrom(backgroundColor: IronMindTheme.accent, foregroundColor: IronMindTheme.bg, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), minimumSize: Size.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: Text('+ LOG', style: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: IronMindTheme.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: IronMindTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: IronMindTheme.accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: IronMindTheme.bg,
                unselectedLabelColor: IronMindTheme.text2,
                labelStyle: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 10, fontWeight: FontWeight.w500),
                padding: const EdgeInsets.all(4),
                tabs: const [Tab(text: 'Today'), Tab(text: 'New Plan'), Tab(text: 'My Plans')],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _TodayTab(key: ValueKey(_refreshTick), date: _today, targets: _targets, onAddFood: _showAddFood),
        _NewPlanTab(
          targets: _targets,
          onPlanCreated: () {
            if (!mounted) return;
            setState(() => _plansRefreshTick++);
            _tabs.animateTo(2);
          },
        ),
        _MyPlansTab(
          key: ValueKey(_plansRefreshTick),
          onGenerateNew: () => _tabs.animateTo(1),
        ),
      ]),
    );
  }

  Future<void> _showAddFood() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFoodSheet(date: _today),
    );
    if (!mounted) return;
    setState(() => _refreshTick++);
  }
}

// ── Meal slot ordering ────────────────────────────────────────────────────────
const _kMealOrder = ['Breakfast', 'Lunch', 'Dinner', 'Snacks', 'Pre-Workout', 'Post-Workout', 'Other'];
const _kMealIcons = {
  'Breakfast': '🌅',
  'Lunch': '☀️',
  'Dinner': '🌙',
  'Snacks': '🍎',
  'Pre-Workout': '⚡',
  'Post-Workout': '💪',
  'Other': '🍽️',
};

// ── Today Tab ─────────────────────────────────────────────────────────────────
class _TodayTab extends StatefulWidget {
  final String date;
  final Map<String, dynamic> targets;
  final VoidCallback onAddFood;
  const _TodayTab({
    super.key,
    required this.date,
    required this.targets,
    required this.onAddFood,
  });
  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  List<Map<String, dynamic>> _foods = [];
  int _waterGlasses = 0;
  static const int _waterGoal = 8;
  bool _loading = true;

  int get _totalCals => _foods.fold(0, (s, f) => s + ((f['calories'] as num?) ?? 0).toInt());
  double get _totalP => _foods.fold(0.0, (s, f) => s + ((f['protein'] as num?) ?? 0).toDouble());
  double get _totalC => _foods.fold(0.0, (s, f) => s + ((f['carbs'] as num?) ?? 0).toDouble());
  double get _totalF => _foods.fold(0.0, (s, f) => s + ((f['fat'] as num?) ?? 0).toDouble());

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final meals = await ApiService.getFoodEntries(widget.date);
    final water = await ApiService.getWaterGlasses(widget.date);
    if (!mounted) return;
    setState(() { _foods = meals; _waterGlasses = water; _loading = false; });
  }

  Future<void> _setWater(int glasses) async {
    await ApiService.setWaterGlasses(widget.date, glasses);
    setState(() => _waterGlasses = glasses.clamp(0, 20));
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final food in _foods) {
      final meal = (food['meal'] as String?)?.isNotEmpty == true ? food['meal'] as String : 'Other';
      map.putIfAbsent(meal, () => []).add(food);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final targetCal = (widget.targets['calories'] as num).toInt();
    final targetP = (widget.targets['protein'] as num).toDouble();
    final targetC = (widget.targets['carbs'] as num).toDouble();
    final targetF = (widget.targets['fat'] as num).toDouble();
    final calPct = targetCal > 0 ? (_totalCals / targetCal).clamp(0.0, 1.0) : 0.0;
    final over = _totalCals > targetCal;
    final remaining = (targetCal - _totalCals).abs();

    return RefreshIndicator(
      color: IronMindTheme.accent, backgroundColor: IronMindTheme.surface2, onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Calorie hero ───────────────────────────────────────────────────
          Text('CALORIES', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              '$_totalCals',
              style: GoogleFonts.bebasNeue(
                color: over ? IronMindTheme.red : IronMindTheme.textPrimary,
                fontSize: 56,
                letterSpacing: 1,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 8),
              child: Text(
                '/ $targetCal',
                style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 12),
              ),
            ),
          ]),
          Text(
            over ? '$remaining kcal over budget' : '$remaining kcal remaining',
            style: GoogleFonts.dmSans(
              color: over ? IronMindTheme.red : IronMindTheme.text2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: calPct,
              minHeight: 5,
              backgroundColor: IronMindTheme.surface3,
              valueColor: AlwaysStoppedAnimation(over ? IronMindTheme.red : IronMindTheme.accent),
            ),
          ),

          const SizedBox(height: 24),

          // ── Macros ─────────────────────────────────────────────────────────
          Row(children: [
            Expanded(child: _MacroColumn(label: 'PROTEIN', current: _totalP, target: targetP, color: IronMindTheme.green)),
            const SizedBox(width: 16),
            Expanded(child: _MacroColumn(label: 'CARBS', current: _totalC, target: targetC, color: IronMindTheme.blue)),
            const SizedBox(width: 16),
            Expanded(child: _MacroColumn(label: 'FAT', current: _totalF, target: targetF, color: IronMindTheme.orange)),
          ]),

          const SizedBox(height: 24),

          // ── Water tracker ──────────────────────────────────────────────────
          _WaterWidget(
            glasses: _waterGlasses,
            goal: _waterGoal,
            onAdd: () => _setWater(_waterGlasses + 1),
            onRemove: () => _setWater(_waterGlasses - 1),
          ),

          const SizedBox(height: 20),

          // ── Log food button ────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onAddFood,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: IronMindTheme.accentDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IronMindTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add, color: IronMindTheme.accent, size: 16),
                const SizedBox(width: 6),
                Text('LOG FOOD', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 14, letterSpacing: 1.5)),
              ]),
            ),
          ),

          const SizedBox(height: 28),

          // ── Grouped food list ──────────────────────────────────────────────
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: IronMindTheme.accent)))
          else if (_foods.isEmpty)
            const EmptyState(icon: '🥗', title: 'No Food Logged', sub: 'Tap above to search and log food')
          else
            for (final meal in _kMealOrder) ...[
              if (_grouped.containsKey(meal)) ...[
                _MealGroupHeader(
                  meal: meal,
                  totalCals: _grouped[meal]!.fold(0, (s, f) => s + ((f['calories'] as num?) ?? 0).toInt()),
                ),
                const SizedBox(height: 8),
                ..._grouped[meal]!.asMap().entries.map((entry) {
                  final globalIdx = _foods.indexWhere((f) => identical(f, entry.value));
                  return Dismissible(
                    key: Key('food-$meal-${entry.key}-${widget.date}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: IronMindTheme.redDim, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.delete_outline, color: IronMindTheme.red),
                    ),
                    onDismissed: (_) async {
                      await ApiService.deleteFoodEntry(widget.date, globalIdx);
                      _load();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              entry.value['name'] ?? '',
                              style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text('${(entry.value['protein'] as num?)?.toStringAsFixed(0) ?? 0}g P', style: GoogleFonts.dmMono(color: IronMindTheme.green, fontSize: 10)),
                              const SizedBox(width: 8),
                              Text('${(entry.value['carbs'] as num?)?.toStringAsFixed(0) ?? 0}g C', style: GoogleFonts.dmMono(color: IronMindTheme.blue, fontSize: 10)),
                              const SizedBox(width: 8),
                              Text('${(entry.value['fat'] as num?)?.toStringAsFixed(0) ?? 0}g F', style: GoogleFonts.dmMono(color: IronMindTheme.orange, fontSize: 10)),
                            ]),
                          ]),
                        ),
                        Text(
                          '${entry.value['calories'] ?? 0}',
                          style: GoogleFonts.bebasNeue(color: IronMindTheme.text2, fontSize: 18, letterSpacing: 1),
                        ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Divider(color: IronMindTheme.border, height: 1),
                const SizedBox(height: 16),
              ],
            ],
        ]),
      ),
    );
  }
}

// ── Macro column (MacroFactor-style) ─────────────────────────────────────────
class _MacroColumn extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;

  const _MacroColumn({required this.label, required this.current, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - current).clamp(0.0, double.infinity);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
      const SizedBox(height: 4),
      Text(
        '${current.toStringAsFixed(0)}g',
        style: GoogleFonts.bebasNeue(color: color, fontSize: 22, letterSpacing: 1, height: 1),
      ),
      Text(
        '${remaining.toStringAsFixed(0)}g left',
        style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9),
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 4,
          backgroundColor: IronMindTheme.surface3,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
      const SizedBox(height: 2),
      Text('/ ${target.toStringAsFixed(0)}g', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
    ]);
  }
}

// ── Water widget ──────────────────────────────────────────────────────────────
class _WaterWidget extends StatelessWidget {
  final int glasses;
  final int goal;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _WaterWidget({
    required this.glasses,
    required this.goal,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (glasses / goal).clamp(0.0, 1.0);
    final done = glasses >= goal;
    final color = done ? IronMindTheme.green : IronMindTheme.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: done ? IronMindTheme.green.withOpacity(0.4) : IronMindTheme.border),
      ),
      child: Column(children: [
        Row(children: [
          Text('💧', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('HYDRATION', style: GoogleFonts.bebasNeue(color: IronMindTheme.text3, fontSize: 11, letterSpacing: 1.5)),
            Text(
              done ? 'Goal reached! 🎉' : '$glasses of $goal glasses',
              style: GoogleFonts.dmSans(color: done ? IronMindTheme.green : IronMindTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ])),
          // Remove button
          GestureDetector(
            onTap: glasses > 0 ? onRemove : null,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: IronMindTheme.border)),
              alignment: Alignment.center,
              child: Icon(Icons.remove, size: 16, color: glasses > 0 ? IronMindTheme.text2 : IronMindTheme.border),
            ),
          ),
          const SizedBox(width: 8),
          // Glass count badge
          Container(
            width: 36, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text('$glasses', style: GoogleFonts.bebasNeue(color: color, fontSize: 18, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          // Add button
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: IronMindTheme.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: IronMindTheme.blue.withOpacity(0.4))),
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 16, color: IronMindTheme.blue),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: IronMindTheme.surface3,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ── Meal group header ─────────────────────────────────────────────────────────
class _MealGroupHeader extends StatelessWidget {
  final String meal;
  final int totalCals;

  const _MealGroupHeader({required this.meal, required this.totalCals});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(_kMealIcons[meal] ?? '🍽️', style: const TextStyle(fontSize: 14)),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        meal.toUpperCase(),
        style: GoogleFonts.bebasNeue(color: IronMindTheme.text2, fontSize: 14, letterSpacing: 1.5),
      ),
    ),
    Text(
      '$totalCals cal',
      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10),
    ),
  ]);
}

// ── Add Food Sheet ────────────────────────────────────────────────────────────
enum _FoodMode { search, photo, barcode, manual }

class _AddFoodSheet extends StatefulWidget {
  final String date;
  const _AddFoodSheet({required this.date});
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  _FoodMode _mode = _FoodMode.search;
  String _selectedMeal = 'Breakfast';

  // Search
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  // Manual
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _servCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose(); _calCtrl.dispose(); _protCtrl.dispose();
    _carbCtrl.dispose(); _fatCtrl.dispose(); _servCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() { _searching = true; _results = []; });
    final r = await ApiService.searchFood(_searchCtrl.text.trim());
    setState(() { _results = r; _searching = false; });
  }

  Future<void> _add(Map<String, dynamic> food) async {
    await ApiService.saveFoodEntry(widget.date, {...food, 'meal': _selectedMeal});
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addManual() async {
    if (_nameCtrl.text.isEmpty) return;
    await ApiService.saveFoodEntry(widget.date, {
      'name': _nameCtrl.text,
      'brand': '',
      'serving': _servCtrl.text.isEmpty ? '1 serving' : _servCtrl.text,
      'calories': int.tryParse(_calCtrl.text) ?? 0,
      'protein': double.tryParse(_protCtrl.text) ?? 0.0,
      'carbs': double.tryParse(_carbCtrl.text) ?? 0.0,
      'fat': double.tryParse(_fatCtrl.text) ?? 0.0,
      'meal': _selectedMeal,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 12),
            decoration: BoxDecoration(color: IronMindTheme.border2, borderRadius: BorderRadius.circular(2))),

          // Meal picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MEAL', style: GoogleFonts.bebasNeue(color: IronMindTheme.text3, fontSize: 11, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kMealOrder.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final meal = _kMealOrder[i];
                    final selected = meal == _selectedMeal;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMeal = meal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: selected ? IronMindTheme.accentDim : IronMindTheme.surface2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? IronMindTheme.accent.withOpacity(0.5) : IronMindTheme.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${_kMealIcons[meal]} $meal',
                          style: GoogleFonts.dmSans(
                            color: selected ? IronMindTheme.accent : IronMindTheme.text2,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),

          // Mode selector (4 tabs)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: IronMindTheme.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IronMindTheme.border),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(children: [
                _ModeTab(label: '🔍 Search', active: _mode == _FoodMode.search, onTap: () => setState(() => _mode = _FoodMode.search)),
                _ModeTab(label: '📷 Photo', active: _mode == _FoodMode.photo, onTap: () => setState(() => _mode = _FoodMode.photo)),
                _ModeTab(label: '〣 Barcode', active: _mode == _FoodMode.barcode, onTap: () => setState(() => _mode = _FoodMode.barcode)),
                _ModeTab(label: '✏️ Manual', active: _mode == _FoodMode.manual, onTap: () => setState(() => _mode = _FoodMode.manual)),
              ]),
            ),
          ),

          // Mode content
          Expanded(child: switch (_mode) {
            _FoodMode.search => _buildSearch(scroll),
            _FoodMode.photo  => _buildPhotoMode(),
            _FoodMode.barcode => _buildBarcodeMode(),
            _FoodMode.manual => _buildManual(scroll),
          }),
        ]),
      ),
    );
  }

  // ── Search mode ─────────────────────────────────────────────────────────────
  Widget _buildSearch(ScrollController scroll) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(children: [
      Expanded(child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12),
        decoration: const InputDecoration(labelText: 'Search food...', prefixIcon: Icon(Icons.search, size: 18)),
        onSubmitted: (_) => _search(),
      )),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: _search,
        style: ElevatedButton.styleFrom(backgroundColor: IronMindTheme.accent, foregroundColor: IronMindTheme.bg, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text('GO', style: GoogleFonts.bebasNeue(fontSize: 14)),
      ),
    ])),
    if (_searching) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: IronMindTheme.accent)),
    Expanded(child: _results.isEmpty && !_searching
        ? Center(child: Text('Search the USDA food database above', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 12)))
        : ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: _results.length,
            itemBuilder: (ctx, i) {
              final food = _results[i];
              return GestureDetector(
                onTap: () => _add(food),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: IronMindTheme.border)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(food['name'] ?? '', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${food['brand']} · ${food['serving']}', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('${(food['protein'] as num?)?.toStringAsFixed(0)}g P', style: GoogleFonts.dmMono(color: IronMindTheme.green, fontSize: 10)),
                        const SizedBox(width: 6),
                        Text('${(food['carbs'] as num?)?.toStringAsFixed(0)}g C', style: GoogleFonts.dmMono(color: IronMindTheme.blue, fontSize: 10)),
                        const SizedBox(width: 6),
                        Text('${(food['fat'] as num?)?.toStringAsFixed(0)}g F', style: GoogleFonts.dmMono(color: IronMindTheme.orange, fontSize: 10)),
                      ]),
                    ])),
                    Column(children: [
                      Text('${food['calories']}', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 24)),
                      Text('cal', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                    ]),
                  ]),
                ),
              );
            },
          )),
  ]);

  // ── Photo AI mode ────────────────────────────────────────────────────────────
  Widget _buildPhotoMode() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          color: IronMindTheme.accentDim,
          shape: BoxShape.circle,
          border: Border.all(color: IronMindTheme.accent.withOpacity(0.4), width: 2),
        ),
        alignment: Alignment.center,
        child: const Text('📷', style: TextStyle(fontSize: 48)),
      ),
      const SizedBox(height: 24),
      Text('AI Food Analysis', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 26, letterSpacing: 1.5)),
      const SizedBox(height: 8),
      Text(
        'Take a photo of your meal and IronMind AI will identify the food and estimate calories and macros automatically.',
        style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: IronMindTheme.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IronMindTheme.orange.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.construction_rounded, color: IronMindTheme.orange, size: 14),
          const SizedBox(width: 6),
          Text('Coming in a future update', style: GoogleFonts.dmSans(color: IronMindTheme.orange, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
      const SizedBox(height: 20),
      // Scaffold button — disabled for now
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text('ANALYZE PHOTO', style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.5)),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: IronMindTheme.surface2,
            disabledForegroundColor: IronMindTheme.text3,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]),
  );

  // ── Barcode mode ─────────────────────────────────────────────────────────────
  Widget _buildBarcodeMode() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 120, height: 120,
        decoration: BoxDecoration(
          color: IronMindTheme.surface2,
          shape: BoxShape.circle,
          border: Border.all(color: IronMindTheme.border, width: 2),
        ),
        alignment: Alignment.center,
        child: const Text('〣', style: TextStyle(fontSize: 52, color: Colors.white)),
      ),
      const SizedBox(height: 24),
      Text('Barcode Scanner', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 26, letterSpacing: 1.5)),
      const SizedBox(height: 8),
      Text(
        'Scan any food product barcode to instantly pull up its nutrition information from the product database.',
        style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: IronMindTheme.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IronMindTheme.orange.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.construction_rounded, color: IronMindTheme.orange, size: 14),
          const SizedBox(width: 6),
          Text('Coming in a future update', style: GoogleFonts.dmSans(color: IronMindTheme.orange, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
          label: Text('SCAN BARCODE', style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.5)),
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: IronMindTheme.surface2,
            disabledForegroundColor: IronMindTheme.text3,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    ]),
  );

  // ── Manual entry mode ────────────────────────────────────────────────────────
  Widget _buildManual(ScrollController scroll) => SingleChildScrollView(
    controller: scroll,
    padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
    child: Column(children: [
      TextField(controller: _nameCtrl, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Food Name')),
      const SizedBox(height: 10),
      TextField(controller: _servCtrl, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Serving Size', hintText: 'e.g. 8 oz, 1 cup')),
      const SizedBox(height: 10),
      TextField(controller: _calCtrl, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Calories', suffixText: 'kcal')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: _protCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(labelText: 'Protein', suffixText: 'g', labelStyle: GoogleFonts.dmMono(color: IronMindTheme.green)))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _carbCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(labelText: 'Carbs', suffixText: 'g', labelStyle: GoogleFonts.dmMono(color: IronMindTheme.blue)))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _fatCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(labelText: 'Fat', suffixText: 'g', labelStyle: GoogleFonts.dmMono(color: IronMindTheme.orange)))),
      ]),
      const SizedBox(height: 16),
      IronButton(label: 'ADD FOOD', onPressed: _addManual),
    ]),
  );
}

// ── Mode selector tab ─────────────────────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? IronMindTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: active ? IronMindTheme.bg : IronMindTheme.text3,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

// ── New Plan Tab ──────────────────────────────────────────────────────────────
class _NewPlanTab extends StatefulWidget {
  final Map<String, dynamic> targets;
  final VoidCallback onPlanCreated;
  const _NewPlanTab({required this.targets, required this.onPlanCreated});
  @override
  State<_NewPlanTab> createState() => _NewPlanTabState();
}
class _NewPlanTabState extends State<_NewPlanTab> {
  String _goal = 'maintain', _duration = '7', _meals = '4';
  final _prefsCtrl = TextEditingController();
  bool _loading = false;

  final _goals = {'maintain': 'Maintain current weight', 'cut': 'Cut — caloric deficit', 'bulk': 'Bulk — caloric surplus', 'peak': 'Peak Week — meet prep', 'recomp': 'Recomp — same weight, build muscle'};
  final _durations = {'3': '3 days', '5': '5 days', '7': '7 days', '14': '14 days', '28': '28 days'};
  final _mealCounts = {'3': '3 meals', '4': '4 meals', '5': '5 meals', '6': '6 meals'};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Based On Your Targets'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MacroChip('Protein', '${widget.targets['protein']}g', IronMindTheme.green)),
            const SizedBox(width: 6),
            Expanded(child: _MacroChip('Carbs', '${widget.targets['carbs']}g', IronMindTheme.blue)),
            const SizedBox(width: 6),
            Expanded(child: _MacroChip('Fat', '${widget.targets['fat']}g', IronMindTheme.orange)),
          ]),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.only(top: 10), decoration: const BoxDecoration(border: Border(top: BorderSide(color: IronMindTheme.border))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Daily Total', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 11)),
              Text('${widget.targets['calories']} cal', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 22, letterSpacing: 1)),
            ])),
        ])),
        const SizedBox(height: 10),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Plan Details'),
          const SizedBox(height: 12),
          IronDropdown(label: 'Goal / Purpose', value: _goal, items: _goals, onChanged: (v) => setState(() => _goal = v!)),
          const SizedBox(height: 10),
          IronDropdown(label: 'Plan Duration', value: _duration, items: _durations, onChanged: (v) => setState(() => _duration = v!)),
          const SizedBox(height: 10),
          IronDropdown(label: 'Meals Per Day', value: _meals, items: _mealCounts, onChanged: (v) => setState(() => _meals = v!)),
          const SizedBox(height: 10),
          TextField(controller: _prefsCtrl, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Preferences / Notes', hintText: 'e.g. no fish, dairy free, high protein breakfast')),
        ])),
        const SizedBox(height: 12),
        IronButton(label: 'GENERATE MEAL PLAN', loading: _loading, onPressed: () async {
          setState(() => _loading = true);
          try {
            await ApiService.generateMealPlan(
              goal: _goals[_goal],
              days: int.parse(_duration),
              mealsPerDay: int.parse(_meals),
              preferences: _prefsCtrl.text,
            );
            widget.onPlanCreated();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meal plan generated!'), backgroundColor: IronMindTheme.green));
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server offline'), backgroundColor: IronMindTheme.orange));
          } finally { setState(() => _loading = false); }
        }),
      ]),
    );
  }

  @override
  void dispose() { _prefsCtrl.dispose(); super.dispose(); }
}

class _MacroChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroChip(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(label.toUpperCase(), style: GoogleFonts.dmMono(color: color, fontSize: 8, letterSpacing: 1)),
      const SizedBox(height: 3),
      Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 20, letterSpacing: 1)),
    ]),
  );
}

// ── My Plans Tab ──────────────────────────────────────────────────────────────
class _MyPlansTab extends StatefulWidget {
  final VoidCallback onGenerateNew;
  const _MyPlansTab({super.key, required this.onGenerateNew});
  @override
  State<_MyPlansTab> createState() => _MyPlansTabState();
}
class _MyPlansTabState extends State<_MyPlansTab> {
  Map<String, dynamic>? _plan;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final d = await ApiService.getLatestNutrition(); setState(() { _plan = d; _loading = false; }); }
    catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    final preferences = (_plan?['preferences'] ?? '').toString().trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_plan == null)
          const EmptyState(icon: '🍽️', title: 'No Plans Yet', sub: 'Go to New Plan to generate your first meal plan')
        else
          IronCard2(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Latest Plan', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
              IronBadge('Active', color: IronMindTheme.green),
            ]),
            const SizedBox(height: 10),
            Text(
              _plan!['goal'] ?? 'Custom plan',
              style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 24, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Text(
              '${_plan!['days'] ?? 0} days • ${_plan!['mealsPerDay'] ?? 4} meals/day',
              style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10),
            ),
            if (preferences.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                preferences,
                style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            IronGhostButton(
              label: 'VIEW FULL PLAN',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MealPlanDetailsScreen(plan: _plan!),
                ),
              ),
              color: IronMindTheme.text2,
            ),
          ])),
        const SizedBox(height: 12),
        IronButton(label: '+ GENERATE NEW PLAN', onPressed: widget.onGenerateNew),
      ]),
    );
  }
}

class _MealPlanDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _MealPlanDetailsScreen({required this.plan});

  @override
  Widget build(BuildContext context) {
    final targets = Map<String, dynamic>.from(plan['targets'] as Map? ?? {});
    final dailyMeals = List<Map<String, dynamic>>.from(plan['dailyMeals'] as List? ?? const []);
    final preferences = (plan['preferences'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: AppBar(
        backgroundColor: IronMindTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Meal Plan',
          style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, letterSpacing: 2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          IronCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (plan['goal'] ?? 'Custom plan').toString(),
                  style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 28, letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Text(
                  '${plan['days'] ?? 0} days • ${plan['mealsPerDay'] ?? 4} meals/day',
                  style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _MacroChip('Protein', '${targets['protein'] ?? 0}g', IronMindTheme.green)),
                    const SizedBox(width: 6),
                    Expanded(child: _MacroChip('Carbs', '${targets['carbs'] ?? 0}g', IronMindTheme.blue)),
                    const SizedBox(width: 6),
                    Expanded(child: _MacroChip('Fat', '${targets['fat'] ?? 0}g', IronMindTheme.orange)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${targets['calories'] ?? 0} cal target',
                  style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 1),
                ),
                if (preferences.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    preferences,
                    style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...dailyMeals.map((day) {
            final meals = List<String>.from(day['meals'] as List? ?? const []);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IronCard2(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${day['day'] ?? ''}',
                      style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (day['summary'] ?? '').toString(),
                      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    ...meals.map((meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 6, color: IronMindTheme.accent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              meal,
                              style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )),
                    Text(
                      'Notes: ${(day['notes'] ?? 'No specific restrictions').toString()}',
                      style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
