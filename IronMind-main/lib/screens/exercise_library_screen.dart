import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final Function(String exerciseName)? onAddToWorkout;
  const ExerciseLibraryScreen({super.key, this.onAddToWorkout});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<String> _bodyParts = [];
  List<String> _equipment = [];
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = false;
  bool _loadingFilters = true;
  String _selectedBodyPart = '';
  String _selectedEquipment = '';
  final _searchCtrl = TextEditingController();
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadExercises();
  }

  Future<void> _loadFilters() async {
    final bp = await ApiService.getBodyParts();
    final eq = await ApiService.getEquipmentList();
    setState(() {
      _bodyParts = bp;
      _equipment = eq;
      _loadingFilters = false;
    });
  }

  // Ensure the routine-library crash fix is applied
  void _loadExercises({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _exercises = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    setState(() => _loading = true);
    try {
      final results = await ApiService.getExercises(
        muscle: _selectedBodyPart.isNotEmpty ? _selectedBodyPart : null,
        equipment: _selectedEquipment.isNotEmpty ? _selectedEquipment : null,
        search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
        limit: 20,
        offset: _offset,
      );
      setState(() {
        _exercises.addAll(results);
        _offset += results.length;
        _hasMore = results.length == 20;
      });
    } catch (e) {
      setState(() {
        _hasMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exercises: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _search() => _loadExercises(reset: true);

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() { _selectedBodyPart = ''; _selectedEquipment = ''; });
    _loadExercises(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final isModal = widget.onAddToWorkout != null;
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: AppBar(
        backgroundColor: IronMindTheme.surface,
        title: Row(children: [
          Text('IRON', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 20, letterSpacing: 3)),
          Text('MIND', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 3)),
          const SizedBox(width: 8),
          Container(width: 1, height: 14, color: IronMindTheme.border2),
          const SizedBox(width: 8),
          Text('LIBRARY', style: GoogleFonts.bebasNeue(color: IronMindTheme.text3, fontSize: 16, letterSpacing: 2)),
        ]),
        leading: isModal ? IconButton(icon: const Icon(Icons.close, color: IronMindTheme.text2), onPressed: () => Navigator.pop(context)) : null,
      ),
      body: Column(children: [
        // Search bar
        Container(
          color: IronMindTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search, color: IronMindTheme.text3, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(onTap: () { _searchCtrl.clear(); _loadExercises(reset: true); }, child: const Icon(Icons.close, color: IronMindTheme.text3, size: 18))
                    : null,
              ),
              onSubmitted: (_) => _search(),
            )),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _search,
              style: ElevatedButton.styleFrom(backgroundColor: IronMindTheme.accent, foregroundColor: IronMindTheme.bg, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('GO', style: GoogleFonts.bebasNeue(fontSize: 14)),
            ),
          ]),
        ),

        // Filter chips
        if (!_loadingFilters)
          Container(
            color: IronMindTheme.surface,
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              // Body part filter
              SizedBox(height: 36, child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip('All', _selectedBodyPart.isEmpty && _selectedEquipment.isEmpty, () => _clearFilters()),
                  ..._bodyParts.map((bp) => _FilterChip(
                    _capitalize(bp),
                    _selectedBodyPart == bp,
                    () { setState(() { _selectedBodyPart = _selectedBodyPart == bp ? '' : bp; _selectedEquipment = ''; }); _loadExercises(reset: true); },
                  )),
                ],
              )),
              const SizedBox(height: 6),
              // Equipment filter
              SizedBox(height: 32, child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _equipment.map((eq) => _FilterChip(
                  _capitalize(eq),
                  _selectedEquipment == eq,
                  () { setState(() { _selectedEquipment = _selectedEquipment == eq ? '' : eq; _selectedBodyPart = ''; }); _loadExercises(reset: true); },
                  small: true,
                )).toList(),
              )),
            ]),
          ),

        // Divider
        Container(height: 1, color: IronMindTheme.border),

        // Results
        Expanded(child: _exercises.isEmpty && !_loading
            ? const EmptyState(icon: '💪', title: 'No Exercises Found', sub: 'Try a different search or filter')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _exercises.length + (_hasMore ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == _exercises.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: _loading
                          ? const CircularProgressIndicator(color: IronMindTheme.accent)
                          : OutlinedButton(
                              onPressed: () => _loadExercises(),
                              style: OutlinedButton.styleFrom(foregroundColor: IronMindTheme.accent, side: BorderSide(color: IronMindTheme.accent.withOpacity(0.3))),
                              child: Text('Load More', style: GoogleFonts.dmMono(fontSize: 12)),
                            )),
                    );
                  }
                  final ex = _exercises[i];
                  return _ExerciseCard(
                    exercise: ex,
                    onAddToWorkout: widget.onAddToWorkout,
                  );
                },
              )),
        if (_loading && _exercises.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator(color: IronMindTheme.accent))),
      ]),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool small;
  const _FilterChip(this.label, this.selected, this.onTap, {this.small = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: selected ? IronMindTheme.accentDim : IronMindTheme.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? IronMindTheme.accent.withOpacity(0.4) : IronMindTheme.border2),
      ),
      child: Text(label, style: GoogleFonts.dmMono(
        color: selected ? IronMindTheme.accent : IronMindTheme.text2,
        fontSize: small ? 9 : 10,
      )),
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final Function(String)? onAddToWorkout;
  const _ExerciseCard({required this.exercise, this.onAddToWorkout});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] as String? ?? '';
    final bodyPart = exercise['bodyPart'] as String? ?? '';
    final target = exercise['target'] as String? ?? '';
    final equipment = exercise['equipment'] as String? ?? '';
    final gifUrl = exercise['gifUrl'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _ExerciseDetailScreen(exercise: exercise, onAddToWorkout: onAddToWorkout),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Row(children: [
          // Exercise GIF/image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 64, height: 64,
              color: IronMindTheme.surface2,
              child: gifUrl != null
                  ? Image.network(gifUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: IronMindTheme.text3, size: 28))
                  : const Icon(Icons.fitness_center, color: IronMindTheme.text3, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_capitalize(name), style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 4, children: [
              if (bodyPart.isNotEmpty) _tag(_capitalize(bodyPart), IronMindTheme.accent),
              if (target.isNotEmpty) _tag(_capitalize(target), IronMindTheme.blue),
              if (equipment.isNotEmpty) _tag(_capitalize(equipment), IronMindTheme.text3),
            ]),
          ])),
          if (onAddToWorkout != null)
            GestureDetector(
              onTap: () { onAddToWorkout!(_capitalize(name)); Navigator.pop(context); },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: IronMindTheme.accentDim, borderRadius: BorderRadius.circular(8), border: Border.all(color: IronMindTheme.accent.withOpacity(0.3))),
                child: const Icon(Icons.add, color: IronMindTheme.accent, size: 18),
              ),
            )
          else
            const Icon(Icons.chevron_right, color: IronMindTheme.text3, size: 20),
        ]),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: color.withOpacity(0.25))),
    child: Text(label, style: GoogleFonts.dmMono(color: color, fontSize: 8)),
  );

  String _capitalize(String s) => s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}

// ── Exercise Detail Screen ────────────────────────────────────────────────────
class _ExerciseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final Function(String)? onAddToWorkout;
  const _ExerciseDetailScreen({required this.exercise, this.onAddToWorkout});

  String _cap(String s) => s.isEmpty ? s : s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  @override
  Widget build(BuildContext context) {
    final name = _cap(exercise['name'] as String? ?? '');
    final bodyPart = _cap(exercise['bodyPart'] as String? ?? '');
    final target = _cap(exercise['target'] as String? ?? '');
    final equipment = _cap(exercise['equipment'] as String? ?? '');
    final gifUrl = exercise['gifUrl'] as String?;
    final instructions = exercise['instructions'] as List? ?? [];
    final secondaryMuscles = exercise['secondaryMuscles'] as List? ?? [];

    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: AppBar(
        backgroundColor: IronMindTheme.surface,
        title: Text(name, style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 18, letterSpacing: 1)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: IronMindTheme.text2), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // GIF
          if (gifUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity, height: 240,
                color: IronMindTheme.surface2,
                child: Image.network(gifUrl, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.fitness_center, color: IronMindTheme.text3, size: 48))),
              ),
            ),
          const SizedBox(height: 16),

          // Tags
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (bodyPart.isNotEmpty) IronBadge(bodyPart, color: IronMindTheme.accent),
            if (target.isNotEmpty) IronBadge(target, color: IronMindTheme.green),
            if (equipment.isNotEmpty) IronBadge(equipment, color: IronMindTheme.blue),
          ]),
          const SizedBox(height: 16),

          // Secondary muscles
          if (secondaryMuscles.isNotEmpty) ...[
            const IronLabel('Secondary Muscles'),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: secondaryMuscles.map((m) => IronBadge(_cap(m.toString()), color: IronMindTheme.text2)).toList()),
            const SizedBox(height: 16),
          ],

          // Instructions
          if (instructions.isNotEmpty) ...[
            const IronLabel('Instructions'),
            const SizedBox(height: 10),
            ...instructions.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: IronMindTheme.accentDim, border: Border.all(color: IronMindTheme.accent.withOpacity(0.3))),
                  child: Center(child: Text('${e.key + 1}', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 12))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value.toString(), style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13, height: 1.5))),
              ]),
            )),
          ],

          const SizedBox(height: 20),

          // Add to workout button
          if (onAddToWorkout != null)
            IronButton(label: '+ ADD TO WORKOUT', onPressed: () {
              onAddToWorkout!(name);
              Navigator.pop(context);
              Navigator.pop(context);
            }),
        ]),
      ),
    );
  }
}
