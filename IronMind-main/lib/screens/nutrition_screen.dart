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
        subtitle: 'Nutrition',
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
        bottom: TabBar(
          controller: _tabs,
          labelColor: IronMindTheme.accent, unselectedLabelColor: IronMindTheme.text3,
          indicatorColor: IronMindTheme.accent, indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.dmMono(fontSize: 10), unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 10),
          tabs: const [Tab(text: 'Today'), Tab(text: 'New Plan'), Tab(text: 'My Plans')],
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
  bool _loading = true;

  int get _totalCals => _foods.fold(0, (s, f) => s + ((f['calories'] as num?) ?? 0).toInt());
  double get _totalP => _foods.fold(0.0, (s, f) => s + ((f['protein'] as num?) ?? 0).toDouble());
  double get _totalC => _foods.fold(0.0, (s, f) => s + ((f['carbs'] as num?) ?? 0).toDouble());
  double get _totalF => _foods.fold(0.0, (s, f) => s + ((f['fat'] as num?) ?? 0).toDouble());

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final meals = await ApiService.getFoodEntries(widget.date);
    if (!mounted) return;
    setState(() { _foods = meals; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final targetCal = (widget.targets['calories'] as num).toInt();
    final targetP = (widget.targets['protein'] as num).toDouble();
    final targetC = (widget.targets['carbs'] as num).toDouble();
    final targetF = (widget.targets['fat'] as num).toDouble();
    final calPct = targetCal > 0 ? (_totalCals / targetCal).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      color: IronMindTheme.accent, backgroundColor: IronMindTheme.surface2, onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IronCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IronLabel('Today'),
              const SizedBox(height: 6),
              Text('$_totalCals', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 32, letterSpacing: 1)),
              Text('of $targetCal cal', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
              const SizedBox(height: 10),
              MacroBar(label: 'Protein', value: _totalP, target: targetP, color: IronMindTheme.green),
              MacroBar(label: 'Carbs', value: _totalC, target: targetC, color: IronMindTheme.blue),
              MacroBar(label: 'Fat', value: _totalF, target: targetF, color: IronMindTheme.orange),
            ])),
            const SizedBox(width: 12),
            SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: 1.0, strokeWidth: 7, color: IronMindTheme.surface3, backgroundColor: Colors.transparent),
              CircularProgressIndicator(value: calPct, strokeWidth: 7, color: calPct >= 1.0 ? IronMindTheme.red : IronMindTheme.accent, backgroundColor: Colors.transparent, strokeCap: StrokeCap.round),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(calPct * 100).round()}%', style: GoogleFonts.bebasNeue(color: calPct >= 1.0 ? IronMindTheme.red : IronMindTheme.accent, fontSize: 16)),
                Text('of goal', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 7)),
              ]),
            ])),
          ])),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: widget.onAddFood,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: IronMindTheme.accentDim, borderRadius: BorderRadius.circular(8), border: Border.all(color: IronMindTheme.accent.withOpacity(0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_circle_outline, color: IronMindTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text('SEARCH & LOG FOOD', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 14, letterSpacing: 1)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading) const Center(child: CircularProgressIndicator(color: IronMindTheme.accent))
          else if (_foods.isEmpty)
            const EmptyState(icon: '🥗', title: 'No Food Logged', sub: 'Tap above to search and log food')
          else ...[
            const SectionHeader(title: 'Logged Today'),
            const SizedBox(height: 10),
            ..._foods.asMap().entries.map((entry) => Dismissible(
              key: Key('food-${entry.key}-${widget.date}'),
              direction: DismissDirection.endToStart,
              background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: IronMindTheme.redDim, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: IronMindTheme.red)),
              onDismissed: (_) async { await ApiService.deleteFoodEntry(widget.date, entry.key); _load(); },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IronCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.value['name'] ?? '', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(entry.value['serving'] ?? '1 serving', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text('${(entry.value['protein'] as num?)?.toStringAsFixed(0) ?? 0}g P', style: GoogleFonts.dmMono(color: IronMindTheme.green, fontSize: 10)),
                      const SizedBox(width: 8),
                      Text('${(entry.value['carbs'] as num?)?.toStringAsFixed(0) ?? 0}g C', style: GoogleFonts.dmMono(color: IronMindTheme.blue, fontSize: 10)),
                      const SizedBox(width: 8),
                      Text('${(entry.value['fat'] as num?)?.toStringAsFixed(0) ?? 0}g F', style: GoogleFonts.dmMono(color: IronMindTheme.orange, fontSize: 10)),
                    ]),
                  ])),
                  Text('${entry.value['calories'] ?? 0}', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 24, letterSpacing: 1)),
                ])),
              ),
            )),
          ],
        ]),
      ),
    );
  }
}

// ── Add Food Sheet ────────────────────────────────────────────────────────────
class _AddFoodSheet extends StatefulWidget {
  final String date;
  const _AddFoodSheet({required this.date});
  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}
class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _manual = false;
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _servCtrl = TextEditingController();

  Future<void> _search() async {
    if (_searchCtrl.text.trim().isEmpty) return;
    setState(() { _searching = true; _results = []; });
    final r = await ApiService.searchFood(_searchCtrl.text.trim());
    setState(() { _results = r; _searching = false; });
  }

  Future<void> _add(Map<String, dynamic> food) async {
    await ApiService.saveFoodEntry(widget.date, food);
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
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(color: IronMindTheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: IronMindTheme.border2, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Row(children: [
            Expanded(child: GestureDetector(onTap: () => setState(() => _manual = false),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: !_manual ? IronMindTheme.accentDim : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: !_manual ? IronMindTheme.accent.withOpacity(0.3) : IronMindTheme.border2)),
                child: Text('Search Food', style: GoogleFonts.dmMono(color: !_manual ? IronMindTheme.accent : IronMindTheme.text3, fontSize: 11), textAlign: TextAlign.center)))),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(onTap: () => setState(() => _manual = true),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: _manual ? IronMindTheme.accentDim : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _manual ? IronMindTheme.accent.withOpacity(0.3) : IronMindTheme.border2)),
                child: Text('Manual Entry', style: GoogleFonts.dmMono(color: _manual ? IronMindTheme.accent : IronMindTheme.text3, fontSize: 11), textAlign: TextAlign.center)))),
          ])),
          if (!_manual) ...[
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Row(children: [
              Expanded(child: TextField(controller: _searchCtrl, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12),
                  decoration: const InputDecoration(labelText: 'Search food...', prefixIcon: Icon(Icons.search, size: 18)),
                  onSubmitted: (_) => _search())),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _search, style: ElevatedButton.styleFrom(backgroundColor: IronMindTheme.accent, foregroundColor: IronMindTheme.bg, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Text('GO', style: GoogleFonts.bebasNeue(fontSize: 14))),
            ])),
            if (_searching) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: IronMindTheme.accent)),
            Expanded(child: _results.isEmpty && !_searching
                ? Center(child: Text('Search for food above', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 12)))
                : ListView.builder(
                    controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
          ] else
            Expanded(child: SingleChildScrollView(
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
            )),
        ]),
      ),
    );
  }
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
