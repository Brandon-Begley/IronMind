import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/health_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  final bool connected;
  const DashboardScreen({super.key, this.connected = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _prs = [];
  List<Map<String, dynamic>> _bodyweightLogs = [];
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _goals = {};
  Map<String, dynamic>? _wellness;
  bool _loading = true;

  // Week stats
  int _weekSessions = 0;
  double _weekVolume = 0;
  int _currentStreak = 0;

  // Consistency X/7 counts
  int _workoutCount = 0;
  int _foodLogCount = 0;
  int _checkInCount = 0;
  int _habitCount = 0;

  // Today status
  bool _todayWorkout = false;
  bool _todayFood = false;
  bool _todayCheckIn = false;

  // Health data
  int? _healthSteps;
  double? _healthActiveCalories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getLogs(),
        ApiService.getPRList(),
        ApiService.getWellnessToday(),
        ApiService.getProfile(),
        ApiService.getStrengthGoals(),
        ApiService.getBodyweightLogs(),
        ApiService.getCheckInLoggedDates(),
        ApiService.getNutritionLoggedDates(lookbackDays: 7),
        ApiService.getHabits(),
        ApiService.getWorkoutLoggedDates(),
      ]);

      _logs           = results[0] as List<Map<String, dynamic>>;
      _prs            = results[1] as List<Map<String, dynamic>>;
      _wellness       = results[2] as Map<String, dynamic>?;
      _profile        = results[3] as Map<String, dynamic>;
      _goals          = results[4] as Map<String, dynamic>;
      _bodyweightLogs = results[5] as List<Map<String, dynamic>>;
      final checkInDates   = results[6] as Set<String>;
      final nutritionDates = results[7] as Set<String>;
      final habits         = results[8] as List<Map<String, dynamic>>;
      final workoutDates   = results[9] as Set<String>;

      _calcMetrics();
      await _calcConsistency(checkInDates, nutritionDates, habits, workoutDates);
    } catch (_) {}
    setState(() => _loading = false);

    // Load health data after the main paint so it doesn't block the screen
    if (HealthService.instance.isConnected) {
      final steps = await HealthService.instance.getTodaySteps();
      final cals  = await HealthService.instance.getTodayActiveCalories();
      if (mounted) {
        setState(() {
          _healthSteps = steps;
          _healthActiveCalories = cals;
        });
      }
    }
  }

  void _calcMetrics() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekLogs = _logs.where((log) {
      final date = DateTime.tryParse(log['date']?.toString() ?? '');
      if (date == null) return false;
      return !date.isBefore(weekStart.subtract(const Duration(days: 1)));
    }).toList();
    _weekSessions = weekLogs.length;
    _weekVolume   = weekLogs.fold(0, (s, l) => s + _logVolume(l));
  }

  Future<void> _calcConsistency(
    Set<String> checkInDates,
    Set<String> nutritionDates,
    List<Map<String, dynamic>> habits,
    Set<String> workoutDates,
  ) async {
    final now      = DateTime.now();
    final todayStr = _dateStr(now);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final week7 = List.generate(7, (i) => _dateStr(weekStart.add(Duration(days: i))));

    // X/7 counts
    _workoutCount  = week7.where((d) => workoutDates.contains(d)).length;
    _foodLogCount  = week7.where((d) => nutritionDates.contains(d)).length;
    _checkInCount  = week7.where((d) => checkInDates.contains(d)).length;

    final allHabitDays = <String>{};
    for (final h in habits) {
      final completed = await ApiService.getHabitCompletedDates(h['id'] as String);
      allHabitDays.addAll(completed);
    }
    _habitCount = week7.where((d) => allHabitDays.contains(d)).length;

    // Today status
    _todayWorkout  = workoutDates.contains(todayStr);
    _todayFood     = nutritionDates.contains(todayStr);
    _todayCheckIn  = checkInDates.contains(todayStr);

    // Current workout streak (consecutive days ending today or yesterday)
    int streak = 0;
    DateTime cursor = now;
    while (true) {
      if (workoutDates.contains(_dateStr(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (streak == 0 && _dateStr(cursor) == todayStr) {
        // today not yet done — check from yesterday
        cursor = cursor.subtract(const Duration(days: 1));
        if (!workoutDates.contains(_dateStr(cursor))) break;
      } else {
        break;
      }
    }
    _currentStreak = streak;
  }

  double _logVolume(Map<String, dynamic> log) {
    final exercises = log['exercises'] as List? ?? [];
    return exercises.fold(0.0, (s, e) =>
      s + ((e['weight'] ?? 0) as num).toDouble() *
          ((e['sets'] ?? 1) as num).toDouble() *
          ((e['reps'] ?? 1) as num).toDouble());
  }

  String _formatVol(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toInt().toString();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _currentLift(String key, String fallback) {
    final v = _toDouble(_profile[key]);
    return v > 0 ? v : _toDouble(_profile[fallback]);
  }

  double _goalLift(String key) => _toDouble(_goals[key]);

  double _currentBodyweight() {
    if (_bodyweightLogs.isNotEmpty) {
      final sorted = [..._bodyweightLogs]
        ..sort((a, b) {
          final aD = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
          final bD = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
          return aD.compareTo(bD);
        });
      return _toDouble(sorted.last['weight']);
    }
    return _toDouble(_profile['bodyweight'] ?? _profile['weight']);
  }

  double _goalBodyweight() => _toDouble(_profile['goalWeight']);

  /// Returns 0.0–1.0 progress toward the bodyweight goal, regardless of
  /// whether the goal is a bulk (current < goal) or a cut (current > goal).
  double? _bodyweightProgress() {
    final current = _currentBodyweight();
    final goal = _goalBodyweight();
    if (current <= 0 || goal <= 0 || current == goal) return null;
    if (current > goal) {
      // Cutting: need to lose (current - goal) lbs from some starting point.
      // Use the heaviest logged bodyweight as the starting baseline.
      final heaviest = _bodyweightLogs.fold<double>(current, (max, log) {
        final w = _toDouble(log['weight']);
        return w > max ? w : max;
      });
      if (heaviest <= goal) return 1.0;
      return ((heaviest - current) / (heaviest - goal)).clamp(0.0, 1.0);
    } else {
      // Bulking: simple ratio
      return (current / goal).clamp(0.0, 1.0);
    }
  }

  String _weightGoalLabel() {
    final c = _currentBodyweight(), g = _goalBodyweight();
    if (c <= 0 || g <= 0) return 'Set a target weight';
    final delta = (g - c).abs();
    if (delta < 0.1) return 'Goal reached';
    return '${delta.toStringAsFixed(1)} lbs away from goal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: 'Dashboard',
        connected: widget.connected,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: IronMindTheme.text2,
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: IronMindTheme.accent))
          : RefreshIndicator(
              color: IronMindTheme.accent,
              backgroundColor: IronMindTheme.surface2,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 1. Date header ─────────────────────────────────────
                    _DateHeader(),
                    const SizedBox(height: 20),

                    // ── 2. Today ───────────────────────────────────────────
                    const SectionHeader(title: 'Today'),
                    const SizedBox(height: 10),
                    _TodayCard(
                      workout:  _todayWorkout,
                      food:     _todayFood,
                      checkIn:  _todayCheckIn,
                      mood:     _wellness?['mood'],
                    ),
                    if (HealthService.instance.isConnected &&
                        (_healthSteps != null || _healthActiveCalories != null)) ...[
                      const SizedBox(height: 10),
                      _HealthSummaryRow(
                        steps: _healthSteps,
                        activeCalories: _healthActiveCalories,
                      ),
                    ],
                    const SizedBox(height: 18),

                    // ── 3. This Week ───────────────────────────────────────
                    const SectionHeader(title: 'This Week'),
                    const SizedBox(height: 10),
                    _ThisWeekCard(
                      sessions:      _weekSessions,
                      volume:        _weekVolume,
                      streak:        _currentStreak,
                      formatVol:     _formatVol,
                      workoutCount:  _workoutCount,
                      foodLogCount:  _foodLogCount,
                      checkInCount:  _checkInCount,
                      habitCount:    _habitCount,
                    ),
                    const SizedBox(height: 18),

                    // ── 4. Strength Progress ───────────────────────────────
                    const SectionHeader(title: 'Strength Progress'),
                    const SizedBox(height: 10),
                    IronCard(
                      child: Column(children: [
                        _StrengthProgressRow(label: 'Squat',    current: _currentLift('squat', 'currentSquat'),       goal: _goalLift('squat'),    color: IronMindTheme.accent),
                        const SizedBox(height: 12),
                        _StrengthProgressRow(label: 'Bench',    current: _currentLift('bench', 'currentBench'),       goal: _goalLift('bench'),    color: IronMindTheme.green),
                        const SizedBox(height: 12),
                        _StrengthProgressRow(label: 'Deadlift', current: _currentLift('deadlift', 'currentDeadlift'), goal: _goalLift('deadlift'), color: IronMindTheme.blue),
                        const SizedBox(height: 12),
                        _StrengthProgressRow(label: 'OHP',      current: _currentLift('ohp', 'currentOhp'),           goal: _goalLift('ohp'),      color: IronMindTheme.orange),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    // ── 5. Bodyweight ──────────────────────────────────────
                    const SectionHeader(title: 'Bodyweight'),
                    const SizedBox(height: 10),
                    IronCard(
                      child: Column(children: [
                        _StrengthProgressRow(
                          label: 'Bodyweight',
                          current: _currentBodyweight(),
                          goal: _goalBodyweight(),
                          color: IronMindTheme.accent,
                          progressOverride: _bodyweightProgress(),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _weightGoalLabel(),
                            style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 11),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    // ── 6. Top Records ─────────────────────────────────────
                    if (_prs.isNotEmpty) ...[
                      const SectionHeader(title: 'Top Records'),
                      const SizedBox(height: 10),
                      IronCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: _prs.take(4).toList().asMap().entries.map((entry) {
                            final pr = entry.value;
                            final isLast = entry.key == (_prs.take(4).length - 1);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border)),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(pr['exercise'] ?? '',
                                    style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                                ),
                                IronBadge('${pr['weight']}lb x ${pr['reps']}', color: IronMindTheme.accent),
                                const SizedBox(width: 6),
                                if (pr['estimated_1rm'] != null)
                                  IronBadge('~${pr['estimated_1rm']}lb', color: IronMindTheme.green),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Date Header ───────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  static const _days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _days[now.weekday - 1].toUpperCase(),
          style: GoogleFonts.bebasNeue(
            color: IronMindTheme.accent,
            fontSize: 30,
            letterSpacing: 2,
            height: 1,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            '${_months[now.month - 1]} ${now.day}, ${now.year}',
            style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ── Today Card ────────────────────────────────────────────────────────────────
class _TodayCard extends StatelessWidget {
  final bool workout;
  final bool food;
  final bool checkIn;
  final dynamic mood;

  const _TodayCard({
    required this.workout,
    required this.food,
    required this.checkIn,
    required this.mood,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Row(children: [
        Expanded(child: _TodayChip(label: 'Workout',  done: workout,  color: IronMindTheme.accent)),
        const SizedBox(width: 8),
        Expanded(child: _TodayChip(label: 'Food Log', done: food,     color: IronMindTheme.green)),
        const SizedBox(width: 8),
        Expanded(child: _TodayChip(label: 'Check-In', done: checkIn,  color: const Color(0xFF9B8AFB))),
        if (mood != null) ...[
          const SizedBox(width: 8),
          Expanded(child: _TodayChip(label: 'Mood $mood/10', done: true, color: IronMindTheme.blue)),
        ],
      ]),
    );
  }
}

class _TodayChip extends StatelessWidget {
  final String label;
  final bool done;
  final Color color;

  const _TodayChip({required this.label, required this.done, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.12) : IronMindTheme.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: done ? color.withValues(alpha: 0.4) : IronMindTheme.border,
        ),
      ),
      child: Column(children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? color : IronMindTheme.text3,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: done ? color : IronMindTheme.text3,
            fontSize: 9,
            fontWeight: done ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}

// ── This Week Card ────────────────────────────────────────────────────────────
class _ThisWeekCard extends StatelessWidget {
  final int sessions;
  final double volume;
  final int streak;
  final String Function(double) formatVol;
  final int workoutCount;
  final int foodLogCount;
  final int checkInCount;
  final int habitCount;

  const _ThisWeekCard({
    required this.sessions,
    required this.volume,
    required this.streak,
    required this.formatVol,
    required this.workoutCount,
    required this.foodLogCount,
    required this.checkInCount,
    required this.habitCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Snap stats
        IntrinsicHeight(
          child: Row(children: [
            Expanded(child: _SnapStat(label: 'Sessions', value: '$sessions',               sub: 'this week',   color: IronMindTheme.accent)),
            VerticalDivider(color: IronMindTheme.border, width: 24, thickness: 1),
            Expanded(child: _SnapStat(label: 'Volume',   value: '${formatVol(volume)} lbs', sub: 'lifted',      color: IronMindTheme.green)),
            VerticalDivider(color: IronMindTheme.border, width: 24, thickness: 1),
            Expanded(child: _SnapStat(label: 'Streak',   value: '${streak}d',               sub: 'current run', color: IronMindTheme.orange)),
          ]),
        ),
        const SizedBox(height: 14),
        Divider(color: IronMindTheme.border, height: 1),
        const SizedBox(height: 14),
        // Consistency rows
        Text('CONSISTENCY', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        _ConsistencyRow(label: 'Workouts',  count: workoutCount, color: IronMindTheme.accent),
        const SizedBox(height: 8),
        _ConsistencyRow(label: 'Food Log',  count: foodLogCount, color: IronMindTheme.green),
        const SizedBox(height: 8),
        _ConsistencyRow(label: 'Check-Ins', count: checkInCount, color: const Color(0xFF9B8AFB)),
        const SizedBox(height: 8),
        _ConsistencyRow(label: 'Habits',    count: habitCount,   color: IronMindTheme.orange),
      ]),
    );
  }
}

class _SnapStat extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _SnapStat({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 15, letterSpacing: 0.8)),
      Text(sub, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
    ],
  );
}

class _ConsistencyRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _ConsistencyRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = (count / 7).clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(
        width: 68,
        child: Text(label, style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 10)),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: IronMindTheme.surface3,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        '$count/7',
        style: GoogleFonts.bebasNeue(color: color, fontSize: 13, letterSpacing: 0.5),
      ),
    ]);
  }
}

// ── Strength Progress Row ─────────────────────────────────────────────────────
class _StrengthProgressRow extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  final double? progressOverride;

  const _StrengthProgressRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    this.progressOverride,
  });

  @override
  Widget build(BuildContext context) {
    final progress = progressOverride ??
        (goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0);
    final pct = (progress * 100).round();
    final currentLabel = current > 0 ? '${current.toStringAsFixed(0)} lbs' : '—';
    final goalLabel = goal > 0 ? '${goal.toStringAsFixed(0)} lbs goal' : 'set a goal';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(label, style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 15, letterSpacing: 1.2)),
        ),
        Text(currentLabel, style: GoogleFonts.dmMono(color: color, fontSize: 11)),
        const SizedBox(width: 8),
        Text(goalLabel, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
        if (goal > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$pct%', style: GoogleFonts.dmMono(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 7,
          backgroundColor: IronMindTheme.border2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

class _HealthSummaryRow extends StatelessWidget {
  final int? steps;
  final double? activeCalories;

  const _HealthSummaryRow({this.steps, this.activeCalories});

  String _formatSteps(int s) {
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}k';
    return '$s';
  }

  @override
  Widget build(BuildContext context) {
    return IronCard(
      child: Row(
        children: [
          if (steps != null) ...[
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.directions_walk, color: IronMindTheme.green, size: 16),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSteps(steps!),
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Steps',
                        style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (activeCalories != null) ...[
            if (steps != null)
              Container(
                width: 1,
                height: 32,
                color: IronMindTheme.border,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.local_fire_department, color: IronMindTheme.orange, size: 16),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activeCalories!.toInt()} kcal',
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Active',
                        style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
