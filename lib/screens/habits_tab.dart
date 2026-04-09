import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ── Built-in auto-tracked habit definitions ───────────────────────────────────
class _BuiltInHabit {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final Future<Set<String>> Function() getDates;

  const _BuiltInHabit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.getDates,
  });
}

final List<_BuiltInHabit> _builtInHabits = [
  _BuiltInHabit(
    id: '__workout__',
    name: 'Log a workout',
    icon: '🏋️',
    color: IronMindColors.accent,
    getDates: ApiService.getWorkoutLoggedDates,
  ),
  _BuiltInHabit(
    id: '__nutrition__',
    name: 'Log meals',
    icon: '🥗',
    color: IronMindColors.success,
    getDates: () => ApiService.getNutritionLoggedDates(lookbackDays: 91),
  ),
  _BuiltInHabit(
    id: '__checkin__',
    name: 'Daily check-in',
    icon: '💙',
    color: const Color(0xFF9B8AFB),
    getDates: ApiService.getCheckInLoggedDates,
  ),
];

// ── Colour palette for custom habits ─────────────────────────────────────────
const List<Color> _habitColors = [
  Color(0xFF47B4FF),
  Color(0xFF47FF8A),
  Color(0xFFFFB347),
  Color(0xFFFF6B6B),
  Color(0xFF9B8AFB),
  Color(0xFFFF8EC8),
  Color(0xFF4ECDC4),
  Color(0xFFFFE66D),
];

const List<String> _habitIcons = [
  '💧', '🧘', '📚', '🚶', '🍎', '😴', '🧠', '🏃',
  '🚴', '🎯', '✍️', '🌅', '🧘‍♂️', '🥤', '🎵', '🌿',
];

// ── Main widget ───────────────────────────────────────────────────────────────
class HabitsTab extends StatefulWidget {
  const HabitsTab({super.key});

  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  List<Map<String, dynamic>> _habits = [];
  // habitId → completed dates set
  final Map<String, Set<String>> _completedDates = {};
  bool _loading = true;
  final String _today = ApiService.todayDateStr();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habits = await ApiService.getHabits();
    final Map<String, Set<String>> dates = {};

    // Load built-in habits
    for (final b in _builtInHabits) {
      dates[b.id] = await b.getDates();
    }

    // Load custom habits
    for (final h in habits) {
      final id = h['id'] as String;
      dates[id] = await ApiService.getHabitCompletedDates(id);
    }

    if (!mounted) return;
    setState(() {
      _habits = habits;
      _completedDates.addAll(dates);
      _loading = false;
    });
  }

  Future<void> _toggleCustom(String id) async {
    HapticFeedback.lightImpact();
    await ApiService.toggleHabitLog(id, _today);
    final updated = await ApiService.getHabitCompletedDates(id);
    setState(() => _completedDates[id] = updated);
  }

  Future<void> _addHabit(Map<String, dynamic> habit) async {
    await ApiService.saveHabit(habit);
    await _load();
  }

  Future<void> _deleteHabit(String id) async {
    await ApiService.deleteHabit(id);
    setState(() {
      _habits.removeWhere((h) => h['id'] == id);
      _completedDates.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: IronMindColors.accent));
    }

    final allStreaks = <String, Map<String, int>>{};
    for (final b in _builtInHabits) {
      final dates = _completedDates[b.id] ?? {};
      allStreaks[b.id] = ApiService.computeStreak(dates);
    }
    for (final h in _habits) {
      final id = h['id'] as String;
      allStreaks[id] = ApiService.computeStreak(_completedDates[id] ?? {});
    }

    // Weekly consistency score (0–100): % of active habits hit today this week
    final score = _weeklyScore(allStreaks);

    return RefreshIndicator(
      color: IronMindColors.accent,
      backgroundColor: IronMindColors.surface,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _ConsistencyScoreCard(score: score),
          const SizedBox(height: 20),
          SectionHeader(title: 'Auto-Tracked'),
          const SizedBox(height: 10),
          ..._builtInHabits.map((b) {
            final dates = _completedDates[b.id] ?? {};
            final streak = allStreaks[b.id]!;
            final doneToday = dates.contains(_today);
            return _HabitCard(
              icon: b.icon,
              name: b.name,
              color: b.color,
              currentStreak: streak['current']!,
              longestStreak: streak['longest']!,
              doneToday: doneToday,
              grid: ApiService.buildHabitGrid(dates),
              isBuiltIn: true,
              onTap: null, // read-only
              onDelete: null,
            );
          }),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SectionHeader(title: 'My Habits'),
              GestureDetector(
                onTap: () => _showAddHabitSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: IronMindColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: IronMindColors.accent.withOpacity(0.4)),
                  ),
                  child: Text(
                    '+ ADD',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindColors.accent,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_habits.isEmpty)
            const EmptyState(
              icon: '🎯',
              title: 'No Custom Habits',
              sub: 'Tap + ADD to create a habit and start building your streak.',
            )
          else
            ..._habits.map((h) {
              final id = h['id'] as String;
              final dates = _completedDates[id] ?? {};
              final streak = allStreaks[id]!;
              final colorHex = h['color'] as String? ?? '#47B4FF';
              final color = _hexColor(colorHex);
              return _HabitCard(
                icon: h['icon'] as String? ?? '🎯',
                name: h['name'] as String? ?? 'Habit',
                color: color,
                currentStreak: streak['current']!,
                longestStreak: streak['longest']!,
                doneToday: dates.contains(_today),
                grid: ApiService.buildHabitGrid(dates),
                isBuiltIn: false,
                onTap: () => _toggleCustom(id),
                onDelete: () => _confirmDelete(context, id, h['name'] as String? ?? 'Habit'),
              );
            }),
          const SizedBox(height: 20),
          _MilestoneRow(allStreaks: allStreaks, habits: _habits),
        ],
      ),
    );
  }

  int _weeklyScore(Map<String, Map<String, int>> allStreaks) {
    // Score based on what % of all habits were completed at some point this week
    final now = DateTime.now();
    int total = 0;
    int completed = 0;
    for (final b in _builtInHabits) {
      final dates = _completedDates[b.id] ?? {};
      total += 7;
      for (int i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: i));
        final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (dates.contains(ds)) completed++;
      }
    }
    for (final h in _habits) {
      final id = h['id'] as String;
      final dates = _completedDates[id] ?? {};
      total += 7;
      for (int i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: i));
        final ds = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (dates.contains(ds)) completed++;
      }
    }
    if (total == 0) return 0;
    return ((completed / total) * 100).round();
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: IronMindColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: IronMindColors.border),
        ),
        title: Text(
          'Delete Habit',
          style: GoogleFonts.bebasNeue(color: IronMindColors.textPrimary, fontSize: 20, letterSpacing: 1.5),
        ),
        content: Text(
          'Delete "$name"? This will remove all streak history.',
          style: GoogleFonts.dmSans(color: IronMindColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.bebasNeue(color: IronMindColors.textSecondary, letterSpacing: 1.2)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteHabit(id);
            },
            child: Text('DELETE', style: GoogleFonts.bebasNeue(color: IronMindColors.alert, letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  void _showAddHabitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHabitSheet(onAdd: _addHabit),
    );
  }

  static Color _hexColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return IronMindColors.accent;
    }
  }
}

// ── Consistency Score Card ────────────────────────────────────────────────────
class _ConsistencyScoreCard extends StatelessWidget {
  final int score;
  const _ConsistencyScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? IronMindColors.success
        : score >= 50
            ? IronMindColors.warning
            : IronMindColors.alert;
    final label = score >= 80
        ? 'Crushing It'
        : score >= 60
            ? 'Solid Week'
            : score >= 40
                ? 'Keep Going'
                : score > 0
                    ? 'Get Back On Track'
                    : 'Start Your Streak';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [IronMindColors.surface, color.withOpacity(0.06)],
        ),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: IronMindColors.border,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text(
                  '$score',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEKLY CONSISTENCY',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.bebasNeue(
                    color: color,
                    fontSize: 22,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on all habits tracked this week',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual Habit Card ─────────────────────────────────────────────────────
class _HabitCard extends StatelessWidget {
  final String icon;
  final String name;
  final Color color;
  final int currentStreak;
  final int longestStreak;
  final bool doneToday;
  final List<bool> grid;
  final bool isBuiltIn;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _HabitCard({
    required this.icon,
    required this.name,
    required this.color,
    required this.currentStreak,
    required this.longestStreak,
    required this.doneToday,
    required this.grid,
    required this.isBuiltIn,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: doneToday ? color.withOpacity(0.5) : IronMindColors.border,
        ),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.dmSans(
                          color: IronMindColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('🔥', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 3),
                          Text(
                            '$currentStreak day streak',
                            style: GoogleFonts.dmSans(
                              color: currentStreak > 0 ? color : IronMindColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Best: $longestStreak',
                            style: GoogleFonts.dmSans(
                              color: IronMindColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isBuiltIn) ...[
                  // Check-off button
                  GestureDetector(
                    onTap: onTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: doneToday ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: doneToday ? color : IronMindColors.border,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: doneToday
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 18)
                          : Icon(Icons.add_rounded, color: IronMindColors.textSecondary, size: 18),
                    ),
                  ),
                ] else ...[
                  // Built-in: just a status dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: doneToday ? color : IronMindColors.border,
                    ),
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.more_vert_rounded, color: IronMindColors.textSecondary, size: 18),
                  ),
                ],
              ],
            ),
          ),
          // Heat-map grid
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _HeatGrid(grid: grid, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Heat-map grid (13 weeks × 7 days = 91 cells) ─────────────────────────────
class _HeatGrid extends StatelessWidget {
  final List<bool> grid; // 91 bools, oldest first
  final Color color;

  const _HeatGrid({required this.grid, required this.color});

  @override
  Widget build(BuildContext context) {
    // Pad to exactly 91 if needed
    final cells = grid.length >= 91 ? grid.sublist(grid.length - 91) : [...List<bool>.filled(91 - grid.length, false), ...grid];
    const cols = 13;
    const rows = 7;

    return LayoutBuilder(builder: (context, constraints) {
      final cellSize = ((constraints.maxWidth - (cols - 1) * 3) / cols).clamp(6.0, 14.0);
      return Wrap(
        spacing: 3,
        runSpacing: 3,
        children: List.generate(cols * rows, (i) {
          final col = i % cols;
          final row = i ~/ cols;
          final idx = col * rows + row;
          final done = idx < cells.length && cells[idx];
          return Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: done ? color.withOpacity(0.85) : IronMindColors.border.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      );
    });
  }
}

// ── Milestone row ─────────────────────────────────────────────────────────────
class _MilestoneRow extends StatelessWidget {
  final Map<String, Map<String, int>> allStreaks;
  final List<Map<String, dynamic>> habits;

  const _MilestoneRow({required this.allStreaks, required this.habits});

  static const _milestones = [7, 14, 30, 60, 100];

  @override
  Widget build(BuildContext context) {
    // Find the best streak across all habits
    int best = 0;
    for (final s in allStreaks.values) {
      if ((s['longest'] ?? 0) > best) best = s['longest']!;
    }

    final next = _milestones.firstWhere((m) => best < m, orElse: () => 0);

    if (best == 0 && habits.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MILESTONES',
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textSecondary,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _milestones.map((m) {
              final unlocked = best >= m;
              return _MilestoneBadge(days: m, unlocked: unlocked);
            }).toList(),
          ),
          if (next > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: best / next,
                minHeight: 4,
                backgroundColor: IronMindColors.border,
                valueColor: const AlwaysStoppedAnimation(IronMindColors.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${next - best} more days to $next-day badge',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  final int days;
  final bool unlocked;

  const _MilestoneBadge({required this.days, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? IronMindColors.accent.withOpacity(0.15) : IronMindColors.border.withOpacity(0.3),
            border: Border.all(
              color: unlocked ? IronMindColors.accent : IronMindColors.border,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            unlocked ? '🔥' : '🔒',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${days}d',
          style: GoogleFonts.bebasNeue(
            color: unlocked ? IronMindColors.textPrimary : IronMindColors.textSecondary,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ── Add Habit Bottom Sheet ────────────────────────────────────────────────────
class _AddHabitSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onAdd;
  const _AddHabitSheet({required this.onAdd});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _nameController = TextEditingController();
  String _selectedIcon = _habitIcons[0];
  Color _selectedColor = _habitColors[0];
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final hex = '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
    await widget.onAdd({
      'name': name,
      'icon': _selectedIcon,
      'color': hex,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: IronMindColors.border),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: IronMindColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'NEW HABIT',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              // Name field
              TextField(
                controller: _nameController,
                autofocus: true,
                style: GoogleFonts.dmSans(color: IronMindColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Drink 2L water',
                  hintStyle: GoogleFonts.dmSans(color: IronMindColors.textSecondary),
                  filled: true,
                  fillColor: IronMindColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: IronMindColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: IronMindColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: IronMindColors.accent),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              // Icon picker
              Text(
                'ICON',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _habitIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final icon = _habitIcons[i];
                    final selected = icon == _selectedIcon;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = icon),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected ? IronMindColors.accent.withOpacity(0.15) : IronMindColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? IronMindColors.accent : IronMindColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(icon, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Color picker
              Text(
                'COLOR',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _habitColors.map((c) {
                  final selected = c.value == _selectedColor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: IronMindColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'CREATE HABIT',
                          style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 2),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
