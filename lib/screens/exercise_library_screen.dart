import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/ironmind_theme.dart';
import '../shared/widgets/common.dart';
import '../services/api_service.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  /// Called when the user confirms their selection.
  /// Receives all selected exercise names at once.
  final Function(List<String> exerciseNames)? onAddMultipleToWorkout;

  const ExerciseLibraryScreen({super.key, this.onAddMultipleToWorkout});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<String> _bodyParts = [];
  List<String> _equipment = [];
  Map<String, String> _muscleGroupMedia = {};
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = false;
  bool _loadingFilters = true;
  String _selectedBodyPart = '';
  String _selectedEquipment = '';
  final _searchCtrl = TextEditingController();
  int _offset = 0;
  bool _hasMore = true;

  // Multi-select state
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadExercises();
  }

  Future<void> _loadFilters() async {
    final bp = await ApiService.getBodyParts();
    final eq = await ApiService.getEquipmentList();
    final media = await ApiService.getMuscleGroupMedia();
    setState(() {
      _bodyParts = bp;
      _equipment = eq;
      _muscleGroupMedia = media;
      _loadingFilters = false;
    });
  }

  Future<void> _loadExercises({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _exercises = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    setState(() => _loading = true);
    final allResults = await ApiService.getExercises(
      bodyPart: _selectedBodyPart.isNotEmpty ? _selectedBodyPart : null,
      equipment: _selectedEquipment.isNotEmpty ? _selectedEquipment : null,
      query: _searchCtrl.text,
    );
    final start = _offset.clamp(0, allResults.length);
    final end = (start + 20).clamp(0, allResults.length);
    final results = allResults.sublist(start, end);
    setState(() {
      _exercises.addAll(results);
      _offset += results.length;
      _hasMore = results.length == 20;
      _loading = false;
    });
  }

  void _search() => _loadExercises(reset: true);

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedBodyPart = '';
      _selectedEquipment = '';
    });
    _loadExercises(reset: true);
  }

  void _toggleSelection(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  void _confirmSelection() {
    if (_selected.isEmpty) return;
    widget.onAddMultipleToWorkout?.call(_selected.toList());
    Navigator.pop(context);
  }

  String _filterLabel(String value, String fallback) {
    return value.isEmpty ? fallback : _capitalize(value);
  }

  Future<void> _showFilterSheet({
    required String title,
    required List<String> options,
    required String selected,
    Map<String, String> mediaByOption = const {},
    required ValueChanged<String> onSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 18),
                  color: IronMindTheme.text2,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.56,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FilterListItem(
                      label: 'All',
                      selected: selected.isEmpty,
                      onTap: () {
                        onSelected('');
                        Navigator.pop(ctx);
                      },
                    );
                  }

                  final option = options[index - 1];
                  final isSelected = selected == option;
                  return _FilterListItem(
                    label: _capitalize(option),
                    imageUrl: mediaByOption[option],
                    selected: isSelected,
                    onTap: () {
                      onSelected(isSelected ? '' : option);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty
      ? s
      : s
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');

  @override
  Widget build(BuildContext context) {
    final isModal = widget.onAddMultipleToWorkout != null;

    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: AppBar(
        backgroundColor: IronMindTheme.surface,
        title: Row(
          children: [
            Text(
              'IRON',
              style: GoogleFonts.bebasNeue(
                color: IronMindTheme.accent,
                fontSize: 20,
                letterSpacing: 3,
              ),
            ),
            Text(
              'MIND',
              style: GoogleFonts.bebasNeue(
                color: IronMindTheme.textPrimary,
                fontSize: 20,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 14, color: IronMindTheme.border2),
            const SizedBox(width: 8),
            Text(
              'LIBRARY',
              style: GoogleFonts.bebasNeue(
                color: IronMindTheme.text3,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        leading: isModal
            ? IconButton(
                icon: const Icon(Icons.close, color: IronMindTheme.text2),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: _selected.isNotEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      '${_selected.length} selected',
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Container(
                color: IronMindTheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.dmSans(
                          color: IronMindTheme.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search exercises...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: IronMindTheme.text3,
                            size: 18,
                          ),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    _loadExercises(reset: true);
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: IronMindTheme.text3,
                                    size: 18,
                                  ),
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _search,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IronMindTheme.accent,
                        foregroundColor: IronMindTheme.bg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'GO',
                        style: GoogleFonts.bebasNeue(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter chips
              if (!_loadingFilters)
                Container(
                  color: IronMindTheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FilterButton(
                          icon: Icons.accessibility_new_rounded,
                          label: _filterLabel(
                            _selectedBodyPart,
                            'Muscle Group',
                          ),
                          selected: _selectedBodyPart.isNotEmpty,
                          onTap: () => _showFilterSheet(
                            title: 'MUSCLE GROUP',
                            options: _bodyParts,
                            selected: _selectedBodyPart,
                            mediaByOption: _muscleGroupMedia,
                            onSelected: (value) {
                              setState(() {
                                _selectedBodyPart = value;
                                _selectedEquipment = '';
                              });
                              _loadExercises(reset: true);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterButton(
                          icon: Icons.fitness_center_rounded,
                          label: _filterLabel(_selectedEquipment, 'Equipment'),
                          selected: _selectedEquipment.isNotEmpty,
                          onTap: () => _showFilterSheet(
                            title: 'EQUIPMENT',
                            options: _equipment,
                            selected: _selectedEquipment,
                            onSelected: (value) {
                              setState(() {
                                _selectedEquipment = value;
                                _selectedBodyPart = '';
                              });
                              _loadExercises(reset: true);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear filters',
                        onPressed:
                            _selectedBodyPart.isEmpty &&
                                _selectedEquipment.isEmpty &&
                                _searchCtrl.text.isEmpty
                            ? null
                            : _clearFilters,
                        style: IconButton.styleFrom(
                          backgroundColor: IronMindTheme.surface2,
                          disabledBackgroundColor: IronMindTheme.surface2,
                          foregroundColor: IronMindTheme.text2,
                          disabledForegroundColor: IronMindTheme.text3,
                          side: BorderSide(color: IronMindTheme.border2),
                          fixedSize: const Size(42, 42),
                        ),
                        icon: const Icon(
                          Icons.filter_alt_off_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),

              Container(height: 1, color: IronMindTheme.border),

              // Exercise list
              Expanded(
                child: _exercises.isEmpty && !_loading
                    ? const EmptyState(
                        icon: '💪',
                        title: 'No Exercises Found',
                        sub: 'Try a different search or filter',
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          _selected.isNotEmpty ? 100 : 24,
                        ),
                        itemCount: _exercises.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _exercises.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: IronMindTheme.accent,
                                      )
                                    : OutlinedButton(
                                        onPressed: () => _loadExercises(),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: IronMindTheme.accent,
                                          side: BorderSide(
                                            color: IronMindTheme.accent
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          'Load More',
                                          style: GoogleFonts.dmMono(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          }
                          final ex = _exercises[i];
                          final name = _capitalize(ex['name'] as String? ?? '');
                          return _ExerciseCard(
                            exercise: ex,
                            isSelected: _selected.contains(name),
                            isSelectMode: isModal,
                            onToggle: isModal
                                ? () => _toggleSelection(name)
                                : null,
                            onAddMultipleToWorkout:
                                widget.onAddMultipleToWorkout,
                          );
                        },
                      ),
              ),

              if (_loading && _exercises.isEmpty)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: IronMindTheme.accent,
                    ),
                  ),
                ),
            ],
          ),

          // Sticky "Add X Exercises" button
          if (_selected.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: IronMindTheme.surface,
                  border: Border(top: BorderSide(color: IronMindTheme.border)),
                ),
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IronMindTheme.accent,
                    foregroundColor: IronMindTheme.bg,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ADD ${_selected.length} EXERCISE${_selected.length > 1 ? 'S' : ''}',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 18,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

class _FilterListItem extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _FilterListItem({
    required this.label,
    this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediaUrl = imageUrl?.trim() ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? IronMindTheme.accentDim : IronMindTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? IronMindTheme.accent.withValues(alpha: 0.45)
                : IronMindTheme.border2,
          ),
        ),
        child: Row(
          children: [
            _FilterLeading(imageUrl: mediaUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: selected
                      ? IronMindTheme.accent
                      : IronMindTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? IronMindTheme.accent : IronMindTheme.text3,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterLeading extends StatelessWidget {
  final String imageUrl;

  const _FilterLeading({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IronMindTheme.border2),
        ),
        child: const Icon(
          Icons.fitness_center_rounded,
          color: IronMindTheme.text3,
          size: 18,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 38,
        height: 38,
        color: IronMindTheme.surface,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(
            Icons.fitness_center_rounded,
            color: IronMindTheme.text3,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? IronMindTheme.accentDim : IronMindTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? IronMindTheme.accent : IronMindTheme.border2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? IronMindTheme.accent : IronMindTheme.text3,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: selected ? IronMindTheme.accent : IronMindTheme.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool isSelected;
  final bool isSelectMode;
  final VoidCallback? onToggle;
  final Function(List<String>)? onAddMultipleToWorkout;

  const _ExerciseCard({
    required this.exercise,
    required this.isSelected,
    required this.isSelectMode,
    this.onToggle,
    this.onAddMultipleToWorkout,
  });

  String _capitalize(String s) => s.isEmpty
      ? s
      : s
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');

  @override
  Widget build(BuildContext context) {
    final name = _capitalize(exercise['name'] as String? ?? '');
    final bodyPart = exercise['bodyPart'] as String? ?? '';
    final target = exercise['target'] as String? ?? '';
    final equipment = exercise['equipment'] as String? ?? '';
    final gifUrl = exercise['gifUrl']?.toString().trim() ?? '';
    final variants = exercise['variants'] as List? ?? [];
    final hasVariants = variants.isNotEmpty;

    return GestureDetector(
      onTap: isSelectMode && !hasVariants
          ? onToggle
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ExerciseDetailScreen(
                  exercise: exercise,
                  onAddMultipleToWorkout: onAddMultipleToWorkout,
                ),
              ),
            ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? IronMindTheme.accentDim : IronMindTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? IronMindTheme.accent.withValues(alpha: 0.6)
                : IronMindTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                color: IronMindTheme.surface2,
                child: gifUrl.isNotEmpty
                    ? Image.network(
                        gifUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: IronMindTheme.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.fitness_center,
                          color: IronMindTheme.text3,
                          size: 24,
                        ),
                      )
                    : const Icon(
                        Icons.fitness_center,
                        color: IronMindTheme.text3,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(name),
                    style: GoogleFonts.dmSans(
                      color: isSelected
                          ? IronMindTheme.accent
                          : IronMindTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: [
                      if (bodyPart.isNotEmpty)
                        _tag(_capitalize(bodyPart), IronMindTheme.accent),
                      if (target.isNotEmpty)
                        _tag(_capitalize(target), IronMindTheme.blue),
                      if (equipment.isNotEmpty)
                        _tag(_capitalize(equipment), IronMindTheme.text3),
                      if (hasVariants)
                        _tag(
                          '${variants.length} variations',
                          IronMindTheme.green,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right-side indicator
            if (isSelectMode && !hasVariants)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? IronMindTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? IronMindTheme.accent
                        : IronMindTheme.border2,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 18,
                      )
                    : const Icon(
                        Icons.add_rounded,
                        color: IronMindTheme.text3,
                        size: 18,
                      ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color: IronMindTheme.text3,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(label, style: GoogleFonts.dmMono(color: color, fontSize: 8)),
  );
}

// ── Exercise Detail Screen ────────────────────────────────────────────────────
class _VariantTile extends StatelessWidget {
  final String name;
  final String equipment;
  final String modifier;
  final bool canAdd;
  final VoidCallback onAdd;

  const _VariantTile({
    required this.name,
    required this.equipment,
    required this.modifier,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: IronMindTheme.accentDim,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: IronMindTheme.accent.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: IronMindTheme.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (equipment.isNotEmpty)
                      IronBadge(equipment, color: IronMindTheme.blue),
                    if (modifier.isNotEmpty)
                      IronBadge(modifier, color: IronMindTheme.green),
                  ],
                ),
              ],
            ),
          ),
          if (canAdd) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: onAdd,
              style: IconButton.styleFrom(
                backgroundColor: IronMindTheme.accent,
                foregroundColor: IronMindTheme.bg,
                fixedSize: const Size(36, 36),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final Function(List<String>)? onAddMultipleToWorkout;
  const _ExerciseDetailScreen({
    required this.exercise,
    this.onAddMultipleToWorkout,
  });

  String _cap(String s) => s.isEmpty
      ? s
      : s
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');

  @override
  Widget build(BuildContext context) {
    final name = _cap(exercise['name'] as String? ?? '');
    final bodyPart = _cap(exercise['bodyPart'] as String? ?? '');
    final target = _cap(exercise['target'] as String? ?? '');
    final equipment = _cap(exercise['equipment'] as String? ?? '');
    final gifUrl = exercise['gifUrl']?.toString().trim() ?? '';
    final instructions = exercise['instructions'] as List? ?? [];
    final secondaryMuscles = exercise['secondaryMuscles'] as List? ?? [];
    final variants = exercise['variants'] as List? ?? [];

    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: AppBar(
        backgroundColor: IronMindTheme.surface,
        title: Text(
          name,
          style: GoogleFonts.bebasNeue(
            color: IronMindTheme.textPrimary,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: IronMindTheme.text2),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gifUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 240,
                  color: IronMindTheme.surface2,
                  child: Image.network(
                    gifUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: IronMindTheme.accent,
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.fitness_center,
                        color: IronMindTheme.text3,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (bodyPart.isNotEmpty)
                  IronBadge(bodyPart, color: IronMindTheme.accent),
                if (target.isNotEmpty)
                  IronBadge(target, color: IronMindTheme.green),
                if (equipment.isNotEmpty)
                  IronBadge(equipment, color: IronMindTheme.blue),
              ],
            ),
            const SizedBox(height: 16),

            if (secondaryMuscles.isNotEmpty) ...[
              const IronLabel('Secondary Muscles'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: secondaryMuscles
                    .map(
                      (m) => IronBadge(
                        _cap(m.toString()),
                        color: IronMindTheme.text2,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (variants.isNotEmpty) ...[
              const IronLabel('Variations'),
              const SizedBox(height: 10),
              ...variants.map((raw) {
                final variant = Map<String, dynamic>.from(raw as Map);
                final variantName = _cap(variant['name']?.toString() ?? name);
                final variantEquipment = _cap(
                  variant['equipment']?.toString() ?? equipment,
                );
                final modifier = _cap(variant['modifier']?.toString() ?? '');
                return _VariantTile(
                  name: variantName,
                  equipment: variantEquipment,
                  modifier: modifier,
                  canAdd: onAddMultipleToWorkout != null,
                  onAdd: () {
                    onAddMultipleToWorkout!([variantName]);
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],

            if (instructions.isNotEmpty) ...[
              const IronLabel('Instructions'),
              const SizedBox(height: 10),
              ...instructions.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: IronMindTheme.accentDim,
                          border: Border.all(
                            color: IronMindTheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: GoogleFonts.bebasNeue(
                              color: IronMindTheme.accent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value.toString(),
                          style: GoogleFonts.dmSans(
                            color: IronMindTheme.text2,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (onAddMultipleToWorkout != null)
              IronButton(
                label: '+ ADD TO WORKOUT',
                onPressed: () {
                  onAddMultipleToWorkout!([name]);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
