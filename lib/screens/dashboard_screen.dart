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
  int _monthSessions = 0;
  double _weekVolume = 0;
  double _monthVolume = 0;
  double _avgSessionVolume = 0;

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
      ]);
      _logs = results[0] as List<Map<String, dynamic>>;
      _prs = results[1] as List<Map<String, dynamic>>;
      _wellness = results[2] as Map<String, dynamic>?;
      _profile = results[3] as Map<String, dynamic>;
      _goals = results[4] as Map<String, dynamic>;
      _bodyweightLogs = results[5] as List<Map<String, dynamic>>;
      _calcMetrics();
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _calcMetrics() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = now.subtract(const Duration(days: 30));
    final weekLogs = _logs.where((log) {
      final date = DateTime.tryParse(log['date']?.toString() ?? '');
      if (date == null) return false;
      return date.isAfter(weekStart.subtract(const Duration(days: 1)));
    }).toList();
    final monthLogs = _logs.where((log) {
      final date = DateTime.tryParse(log['date']?.toString() ?? '');
      if (date == null) return false;
      return date.isAfter(monthStart);
    }).toList();

    _weekSessions = weekLogs.length;
    _monthSessions = monthLogs.length;
    _weekVolume = weekLogs.fold<double>(0, (sum, log) => sum + _logVolume(log));
    _monthVolume = monthLogs.fold<double>(
      0,
      (sum, log) => sum + _logVolume(log),
    );
    _avgSessionVolume = _logs.isEmpty
        ? 0
        : _logs.fold<double>(0, (sum, log) => sum + _logVolume(log)) /
              _logs.length;
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

  int _exerciseCount() {
    return _logs.fold<int>(0, (sum, log) {
      final exercises = log['exercises'] as List? ?? [];
      return sum + exercises.length;
    });
  }

  int _totalSets() {
    return _logs.fold<int>(0, (sum, log) {
      final exercises = log['exercises'] as List? ?? [];
      return sum +
          exercises.fold<int>(0, (exerciseSum, exercise) {
            return exerciseSum + ((exercise['sets'] ?? 0) as num).toInt();
          });
    });
  }

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

  double _startBodyweight() => _toDouble(_profile['startWeight']);

  double _goalBodyweight() => _toDouble(_profile['goalWeight']);

  String _weightDeltaLabel() {
    final current = _currentBodyweight();
    final start = _startBodyweight();
    if (current <= 0 || start <= 0) return 'No baseline yet';
    final delta = current - start;
    if (delta.abs() < 0.1) return 'No change yet';
    final prefix = delta > 0 ? '+' : '';
    return '$prefix${delta.toStringAsFixed(1)} lbs from start';
  }

  String _weightGoalLabel() {
    final current = _currentBodyweight();
    final goal = _goalBodyweight();
    if (current <= 0 || goal <= 0) return 'Set a target weight';
    final delta = goal - current;
    if (delta.abs() < 0.1) return 'Goal reached';
    if (delta > 0) return '${delta.toStringAsFixed(1)} lbs to target';
    return '${delta.abs().toStringAsFixed(1)} lbs above target';
  }

  double _bodyweightProgress() {
    final start = _startBodyweight();
    final goal = _goalBodyweight();
    final current = _currentBodyweight();
    final span = (goal - start).abs();
    if (start <= 0 || goal <= 0 || current <= 0 || span == 0) return 0;
    return ((current - start).abs() / span).clamp(0.0, 1.0);
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
                    const SectionHeader(title: 'This Week'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Sessions',
                            value: '$_weekSessions',
                            valueColor: IronMindTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Volume',
                            value: _formatVol(_weekVolume),
                            sub: 'lbs lifted',
                            valueColor: IronMindTheme.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Mood',
                            value: _wellness != null
                                ? '${_wellness!['mood']}/10'
                                : '—',
                            valueColor: IronMindTheme.blue,
                            sub: _wellness != null ? 'today' : 'not logged',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Workout Stats'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: '30 Days',
                            value: '$_monthSessions',
                            sub: 'sessions',
                            valueColor: IronMindTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Avg Volume',
                            value: _formatVol(_avgSessionVolume),
                            sub: 'per session',
                            valueColor: IronMindTheme.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Total Sets',
                            value: '${_totalSets()}',
                            sub: '${_exerciseCount()} exercises',
                            valueColor: IronMindTheme.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    IronCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _DashboardMetric(
                              label: 'Lifetime Sessions',
                              value: '${_logs.length}',
                              sub: _logs.isEmpty
                                  ? 'Start logging workouts'
                                  : 'All logged workouts',
                              color: IronMindTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardMetric(
                              label: '30 Day Volume',
                              value: _formatVol(_monthVolume),
                              sub: 'lbs moved',
                              color: IronMindTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Strength Progress'),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Bodyweight'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Current',
                            value: _currentBodyweight() > 0
                                ? _currentBodyweight().toStringAsFixed(1)
                                : '—',
                            sub: _currentBodyweight() > 0
                                ? 'lbs'
                                : 'not logged',
                            valueColor: IronMindTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Start',
                            value: _startBodyweight() > 0
                                ? _startBodyweight().toStringAsFixed(1)
                                : '—',
                            sub: _startBodyweight() > 0
                                ? 'lbs'
                                : 'set in onboarding',
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
                            sub: _goalBodyweight() > 0 ? 'lbs' : 'set a target',
                            valueColor: IronMindTheme.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    IronCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DashboardMetric(
                            label: 'Progress',
                            value: _weightDeltaLabel(),
                            sub: _weightGoalLabel(),
                            color: IronMindTheme.textPrimary,
                          ),
                          if (_bodyweightProgress() > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: _bodyweightProgress(),
                                minHeight: 8,
                                backgroundColor: IronMindTheme.border2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  IronMindTheme.accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_prs.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Top Records',
                        trailing: IronGhostButton(
                          label: 'View All',
                          color: IronMindTheme.text2,
                          onPressed: () {},
                        ),
                      ),
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
                    SectionHeader(
                      title: 'Recent Workouts',
                      trailing: IronGhostButton(
                        label: 'View All',
                        color: IronMindTheme.text2,
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_logs.isEmpty)
                      const EmptyState(
                        icon: '◎',
                        title: 'No Workouts Yet',
                        sub: 'Start logging in the Workout tab',
                      )
                    else
                      ..._logs.take(3).map((log) {
                        final exercises = log['exercises'] as List? ?? [];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IronCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        log['day_name'] ?? 'Workout',
                                        style: GoogleFonts.bebasNeue(
                                          color: IronMindTheme.textPrimary,
                                          fontSize: 18,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    IronBadge(
                                      log['date'] ?? '',
                                      color: IronMindTheme.text3,
                                    ),
                                  ],
                                ),
                                if ((log['focus'] ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      log['focus'],
                                      style: GoogleFonts.dmMono(
                                        color: IronMindTheme.accent,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                if (exercises.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    exercises
                                        .take(3)
                                        .map((exercise) => exercise['name'])
                                        .join(' · '),
                                    style: GoogleFonts.dmMono(
                                      color: IronMindTheme.text3,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmMono(
            color: IronMindTheme.text3,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            color: color,
            fontSize: 28,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 11),
        ),
      ],
    );
  }
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
    final currentLabel = current > 0
        ? '${current.toStringAsFixed(0)} lbs'
        : '—';
    final goalLabel = goal > 0
        ? '${goal.toStringAsFixed(0)} lbs goal'
        : 'set a goal';

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
              style: GoogleFonts.dmMono(
                color: IronMindTheme.text3,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: IronMindTheme.border2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
