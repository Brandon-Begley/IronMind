import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
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
  int _weekSessions = 0;
  double _weekVolume = 0;

  // Consistency score components (0–100)
  int _consistencyScore = 0;
  int _workoutScore = 0;    // workouts this week vs goal
  int _nutritionScore = 0;  // days with meals logged (last 7)
  int _checkInScore = 0;    // days with wellness check-in (last 7)
  int _habitScore = 0;      // habit completion % (last 7 days)

  @override
  void initState() {
    super.initState();
    _load();
  }

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
      ]);
      _logs = results[0] as List<Map<String, dynamic>>;
      _prs = results[1] as List<Map<String, dynamic>>;
      _wellness = results[2] as Map<String, dynamic>?;
      _profile = results[3] as Map<String, dynamic>;
      _goals = results[4] as Map<String, dynamic>;
      _bodyweightLogs = results[5] as List<Map<String, dynamic>>;
      final checkInDates = results[6] as Set<String>;
      final nutritionDates = results[7] as Set<String>;
      final habits = results[8] as List<Map<String, dynamic>>;
      _calcMetrics();
      await _calcConsistency(checkInDates, nutritionDates, habits);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _calcMetrics() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekLogs = _logs.where((log) {
      final date = DateTime.tryParse(log['date']?.toString() ?? '');
      if (date == null) return false;
      return date.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).toList();

    _weekSessions = weekLogs.length;
    _weekVolume = weekLogs.fold<double>(0, (sum, log) => sum + _logVolume(log));
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _calcConsistency(
    Set<String> checkInDates,
    Set<String> nutritionDates,
    List<Map<String, dynamic>> habits,
  ) async {
    final now = DateTime.now();
    final last7 = List.generate(7, (i) => _dateStr(now.subtract(Duration(days: i)))).toSet();

    // Workout score: sessions this week vs training-days-per-week goal (default 3)
    final trainingGoal = ((_profile['trainingDays'] as num?)?.toInt() ?? 3).clamp(1, 7);
    _workoutScore = ((_weekSessions / trainingGoal) * 100).round().clamp(0, 100);

    // Check-in score: % of last 7 days with a wellness log
    final checkInHit = last7.where((d) => checkInDates.contains(d)).length;
    _checkInScore = ((checkInHit / 7) * 100).round();

    // Nutrition score: % of last 7 days with at least one meal logged
    final nutritionHit = last7.where((d) => nutritionDates.contains(d)).length;
    _nutritionScore = ((nutritionHit / 7) * 100).round();

    // Habit score: across all custom habits, % of possible completions this week
    if (habits.isEmpty) {
      _habitScore = 100; // don't penalise for not having set up habits yet
    } else {
      int possible = habits.length * 7;
      int hit = 0;
      for (final h in habits) {
        final id = h['id'] as String;
        final completed = await ApiService.getHabitCompletedDates(id);
        hit += last7.where((d) => completed.contains(d)).length;
      }
      _habitScore = possible > 0 ? ((hit / possible) * 100).round() : 100;
    }

    // Weighted average: workouts 35%, nutrition 25%, check-ins 20%, habits 20%
    _consistencyScore = (
      _workoutScore  * 0.35 +
      _nutritionScore * 0.25 +
      _checkInScore  * 0.20 +
      _habitScore    * 0.20
    ).round().clamp(0, 100);
  }

  double _logVolume(Map<String, dynamic> log) {
    final exercises = log['exercises'] as List? ?? [];
    return exercises.fold<double>(0, (sum, exercise) {
      return sum +
          ((exercise['weight'] ?? 0) as num).toDouble() *
              ((exercise['sets'] ?? 1) as num).toDouble() *
              ((exercise['reps'] ?? 1) as num).toDouble();
    });
  }

  String _formatVol(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toInt().toString();
  }

  String _monthAbbr(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _currentLift(String key, String fallbackKey) {
    final primary = _toDouble(_profile[key]);
    if (primary > 0) return primary;
    return _toDouble(_profile[fallbackKey]);
  }

  double _goalLift(String key) => _toDouble(_goals[key]);

  double _currentBodyweight() {
    if (_bodyweightLogs.isNotEmpty) {
      final sorted = [..._bodyweightLogs]
        ..sort((a, b) {
          final aDate =
              DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(1970);
          final bDate =
              DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(1970);
          return aDate.compareTo(bDate);
        });
      return _toDouble(sorted.last['weight']);
    }
    return _toDouble(_profile['bodyweight'] ?? _profile['weight']);
  }

  double _goalBodyweight() => _toDouble(_profile['goalWeight']);

  String _weightGoalLabel() {
    final current = _currentBodyweight();
    final goal = _goalBodyweight();
    if (current <= 0 || goal <= 0) return 'Set a target weight';
    final delta = goal - current;
    if (delta.abs() < 0.1) return 'Goal reached';
    if (delta > 0) return '${delta.toStringAsFixed(1)} lbs away from goal';
    return '${delta.abs().toStringAsFixed(1)} lbs away from goal';
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
          ? const Center(
              child: CircularProgressIndicator(color: IronMindTheme.accent),
            )
          : RefreshIndicator(
              color: IronMindTheme.accent,
              backgroundColor: IronMindTheme.surface2,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Weekly Overview'),
                    const SizedBox(height: 10),
                    _WeeklyOverviewCard(
                      score: _consistencyScore,
                      workoutScore: _workoutScore,
                      nutritionScore: _nutritionScore,
                      checkInScore: _checkInScore,
                      habitScore: _habitScore,
                      weekSessions: _weekSessions,
                      weekVolume: _weekVolume,
                      formatVol: _formatVol,
                      wellness: _wellness,
                      trainingGoal: ((_profile['trainingDays'] as num?)?.toInt() ?? 3).clamp(1, 7),
                    ),
                    const SizedBox(height: 14),
                    const SectionHeader(title: 'Strength Progress'),
                    const SizedBox(height: 8),
                    IronCard(
                      child: Column(
                        children: [
                          _StrengthProgressRow(
                            label: 'Squat',
                            current: _currentLift('squat', 'currentSquat'),
                            goal: _goalLift('squat'),
                            color: IronMindTheme.accent,
                          ),
                          const SizedBox(height: 12),
                          _StrengthProgressRow(
                            label: 'Bench',
                            current: _currentLift('bench', 'currentBench'),
                            goal: _goalLift('bench'),
                            color: IronMindTheme.green,
                          ),
                          const SizedBox(height: 12),
                          _StrengthProgressRow(
                            label: 'Deadlift',
                            current: _currentLift(
                              'deadlift',
                              'currentDeadlift',
                            ),
                            goal: _goalLift('deadlift'),
                            color: IronMindTheme.blue,
                          ),
                          const SizedBox(height: 12),
                          _StrengthProgressRow(
                            label: 'OHP',
                            current: _currentLift('ohp', 'currentOhp'),
                            goal: _goalLift('ohp'),
                            color: IronMindTheme.orange,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SectionHeader(title: 'Bodyweight Progress'),
                    const SizedBox(height: 8),
                    /*
                    IronCard(
                      child: Column(
                        children: [
                        Expanded(
                          child: StatCard(
                            label: 'Current',
                            value: _currentBodyweight() > 0
                                ? _currentBodyweight().toStringAsFixed(1)
                                : '—',
                            sub: _currentBodyweight() > 0
                                ? 'latest entry'
                                : 'not logged',
                            valueColor: IronMindTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Progress',
                            value: _currentBodyweight() > 0 && _goalBodyweight() > 0
                                ? _weightGoalLabel()
                                : '—',
                            sub: _currentBodyweight() > 0
                                ? 'full tracking in wellness'
                                : 'log current weight',
                            valueColor: IronMindTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Target',
                            value: _goalBodyweight() > 0
                                ? _goalBodyweight().toStringAsFixed(1)
                                : '—',
                            sub: _goalBodyweight() > 0 ? 'target' : 'set a target',
                            valueColor: IronMindTheme.green,
                          ),
                        ),
                        ],
                      ),
                    ),
                    */
                    IronCard(
                      child: Column(
                        children: [
                          _StrengthProgressRow(
                            label: 'Bodyweight',
                            current: _currentBodyweight(),
                            goal: _goalBodyweight(),
                            color: IronMindTheme.accent,
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _currentBodyweight() > 0 && _goalBodyweight() > 0
                                  ? _weightGoalLabel()
                                  : 'Track the full bodyweight trend in Wellness',
                              style: GoogleFonts.dmSans(
                                color: IronMindTheme.text2,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_prs.isNotEmpty) ...[
                      const SectionHeader(title: 'Top Records'),
                      const SizedBox(height: 10),
                      IronCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: _prs.take(4).toList().asMap().entries.map((
                            entry,
                          ) {
                            final pr = entry.value;
                            final isLast =
                                entry.key == (_prs.take(4).length - 1);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : const Border(
                                        bottom: BorderSide(
                                          color: IronMindTheme.border,
                                        ),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      pr['exercise'] ?? '',
                                      style: GoogleFonts.dmSans(
                                        color: IronMindTheme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  IronBadge(
                                    '${pr['weight']}lb x ${pr['reps']}',
                                    color: IronMindTheme.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  if (pr['estimated_1rm'] != null)
                                    IronBadge(
                                      '~${pr['estimated_1rm']}lb',
                                      color: IronMindTheme.green,
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Weekly Overview Card ──────────────────────────────────────────────────────
class _WeeklyOverviewCard extends StatelessWidget {
  final int score;
  final int workoutScore;
  final int nutritionScore;
  final int checkInScore;
  final int habitScore;
  final int weekSessions;
  final double weekVolume;
  final String Function(double) formatVol;
  final Map<String, dynamic>? wellness;
  final int trainingGoal;

  const _WeeklyOverviewCard({
    required this.score,
    required this.workoutScore,
    required this.nutritionScore,
    required this.checkInScore,
    required this.habitScore,
    required this.weekSessions,
    required this.weekVolume,
    required this.formatVol,
    required this.wellness,
    required this.trainingGoal,
  });

  Color get _scoreColor {
    if (score >= 80) return IronMindTheme.green;
    if (score >= 55) return IronMindTheme.orange;
    return IronMindTheme.red;
  }

  String get _scoreLabel {
    if (score >= 80) return 'Crushing It';
    if (score >= 65) return 'Solid Week';
    if (score >= 45) return 'Keep Going';
    if (score > 0)   return 'Get Back On Track';
    return 'Start Strong';
  }

  @override
  Widget build(BuildContext context) {
    final moodVal = wellness?['mood'];
    final moodStr = moodVal != null ? '$moodVal/10' : '—';
    final moodSub = moodVal != null ? 'today' : 'not logged';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Snapshot row ──────────────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _SnapStat(
                  label: 'Sessions',
                  value: '$weekSessions / $trainingGoal',
                  sub: 'this week',
                  color: IronMindTheme.accent,
                )),
                VerticalDivider(color: IronMindTheme.border, width: 24, thickness: 1),
                Expanded(child: _SnapStat(
                  label: 'Volume',
                  value: '${formatVol(weekVolume)} lbs',
                  sub: 'lifted',
                  color: IronMindTheme.green,
                )),
                VerticalDivider(color: IronMindTheme.border, width: 24, thickness: 1),
                Expanded(child: _SnapStat(
                  label: 'Mood',
                  value: moodStr,
                  sub: moodSub,
                  color: IronMindTheme.blue,
                )),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: IronMindTheme.border, height: 1),
          const SizedBox(height: 14),
          // ── Consistency breakdown ──────────────────────────────────────────
          Row(
            children: [
              SizedBox(
                width: 56, height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 5,
                    backgroundColor: IronMindTheme.border2,
                    valueColor: AlwaysStoppedAnimation(_scoreColor),
                  ),
                  Text(
                    '$score',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.textPrimary,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONSISTENCY',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindTheme.text3,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    _scoreLabel,
                    style: GoogleFonts.bebasNeue(
                      color: _scoreColor,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScoreBar(label: 'Workouts',  value: workoutScore,   color: IronMindTheme.accent),
          const SizedBox(height: 7),
          _ScoreBar(label: 'Nutrition', value: nutritionScore, color: IronMindTheme.green),
          const SizedBox(height: 7),
          _ScoreBar(label: 'Check-Ins', value: checkInScore,   color: const Color(0xFF9B8AFB)),
          const SizedBox(height: 7),
          _ScoreBar(label: 'Habits',    value: habitScore,     color: IronMindTheme.orange),
        ],
      ),
    );
  }
}

class _SnapStat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _SnapStat({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: GoogleFonts.bebasNeue(color: color, fontSize: 18, letterSpacing: 0.8),
      ),
      Text(
        sub,
        style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9),
      ),
    ],
  );
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ScoreBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 72,
        child: Text(
          label,
          style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 11),
        ),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor: IronMindTheme.border2,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 32,
        child: Text(
          '$value%',
          style: GoogleFonts.dmMono(color: color, fontSize: 10, fontWeight: FontWeight.w700),
          textAlign: TextAlign.right,
        ),
      ),
    ],
  );
}

class _StrengthProgressRow extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;

  const _StrengthProgressRow({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();
    final currentLabel = current > 0 ? '${current.toStringAsFixed(0)} lbs' : '—';
    final goalLabel = goal > 0 ? '${goal.toStringAsFixed(0)} lbs goal' : 'set a goal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.bebasNeue(
                  color: IronMindTheme.textPrimary,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              currentLabel,
              style: GoogleFonts.dmMono(color: color, fontSize: 11),
            ),
            const SizedBox(width: 8),
            Text(
              goalLabel,
              style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10),
            ),
            if (goal > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$pct%',
                  style: GoogleFonts.dmMono(color: color, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
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
      ],
    );
  }
}

