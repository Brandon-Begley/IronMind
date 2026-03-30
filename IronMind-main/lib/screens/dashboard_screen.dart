import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _prs = {};
  Map<String, dynamic> _goals = {};
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _bodyweightLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ApiService.getProfile();
    final prs = await ApiService.getPRs();
    final goals = await ApiService.getStrengthGoals();
    final logs = await ApiService.getLogs();
    final bwLogs = await ApiService.getBodyweightLogs();
    setState(() {
      _profile = profile;
      _prs = prs;
      _goals = goals;
      _logs = logs;
      _bodyweightLogs = bwLogs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: IronMindColors.accent))
            : RefreshIndicator(
                color: IronMindColors.accent,
                backgroundColor: IronMindColors.surface,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildQuickStats(),
                    const SizedBox(height: 20),
                    _buildStrengthGoals(),
                    const SizedBox(height: 20),
                    _buildBodyweightChart(),
                    const SizedBox(height: 20),
                    _buildRecentPRs(),
                    const SizedBox(height: 20),
                    _buildRecentWorkouts(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile['name'] as String? ?? '';
    final greeting = _getGreeting();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? greeting.toUpperCase() : '$greeting,'.toUpperCase(),
                style: GoogleFonts.dmSans(
                    color: IronMindColors.textSecondary, fontSize: 13),
              ),
              if (name.isNotEmpty)
                Text(name.toUpperCase(),
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textPrimary,
                        fontSize: 28,
                        letterSpacing: 1.5)),
            ],
          ),
        ),
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: 'IRON',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.accent,
                    fontSize: 22,
                    letterSpacing: 2)),
            TextSpan(
                text: 'MIND',
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 2)),
          ]),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final thisWeek = _logs.where((l) {
      final ts = DateTime.tryParse(l['timestamp'] ?? '');
      if (ts == null) return false;
      return DateTime.now().difference(ts).inDays <= 7;
    }).toList();

    int totalVolume = 0;
    for (final log in _logs.take(10)) {
      for (final ex in List<Map<String, dynamic>>.from(
          log['exercises'] ?? [])) {
        for (final set
            in List<Map<String, dynamic>>.from(ex['sets'] ?? [])) {
          final w = double.tryParse(set['weight']?.toString() ?? '0') ?? 0;
          final r = int.tryParse(set['reps']?.toString() ?? '0') ?? 0;
          totalVolume += (w * r).toInt();
        }
      }
    }

    return Row(
      children: [
        _StatCard(
          label: 'THIS WEEK',
          value: '${thisWeek.length}',
          unit: 'workouts',
          icon: Icons.calendar_today_outlined,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'TOTAL WORKOUTS',
          value: '${_logs.length}',
          unit: 'logged',
          icon: Icons.fitness_center,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'VOLUME',
          value: totalVolume > 999
              ? '${(totalVolume / 1000).toStringAsFixed(1)}k'
              : '$totalVolume',
          unit: 'lbs',
          icon: Icons.bar_chart,
        ),
      ],
    );
  }

  Widget _buildStrengthGoals() {
    final squat = (_prs['squat']?['weight'] as num?)?.toDouble() ??
        (_profile['currentSquat'] as num?)?.toDouble() ?? 0;
    final bench = (_prs['bench press']?['weight'] as num?)?.toDouble() ??
        (_profile['currentBench'] as num?)?.toDouble() ?? 0;
    final deadlift = (_prs['deadlift']?['weight'] as num?)?.toDouble() ??
        (_profile['currentDeadlift'] as num?)?.toDouble() ?? 0;
    final ohp = (_prs['overhead press']?['weight'] as num?)?.toDouble() ??
        (_profile['currentOhp'] as num?)?.toDouble() ?? 0;

    final goalSquat = (_goals['squat'] as num?)?.toDouble() ?? 315;
    final goalBench = (_goals['bench'] as num?)?.toDouble() ?? 225;
    final goalDead = (_goals['deadlift'] as num?)?.toDouble() ?? 405;
    final goalOhp = (_goals['ohp'] as num?)?.toDouble() ?? 135;

    return _SectionCard(
      title: 'STRENGTH GOALS',
      trailing: GestureDetector(
        onTap: _editGoals,
        child: Text('EDIT',
            style: GoogleFonts.bebasNeue(
                color: IronMindColors.accent,
                fontSize: 14,
                letterSpacing: 1.5)),
      ),
      child: Column(
        children: [
          _GoalBar(
              label: 'SQUAT',
              current: squat,
              goal: goalSquat,
              color: IronMindColors.accent),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'BENCH',
              current: bench,
              goal: goalBench,
              color: IronMindColors.success),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'DEADLIFT',
              current: deadlift,
              goal: goalDead,
              color: IronMindColors.accent),
          const SizedBox(height: 12),
          _GoalBar(
              label: 'OHP',
              current: ohp,
              goal: goalOhp,
              color: IronMindColors.warning),
          const SizedBox(height: 8),
          Text('Progress bars show current PR vs goal',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBodyweightChart() {
    if (_bodyweightLogs.isEmpty) return const SizedBox.shrink();

    final spots = _bodyweightLogs.asMap().entries.map((e) {
      final w = (e.value['weight'] as num).toDouble();
      return FlSpot(e.key.toDouble(), w);
    }).toList();

    final weights = _bodyweightLogs.map((e) => (e['weight'] as num).toDouble());
    final minW = weights.reduce((a, b) => a < b ? a : b) - 5;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 5;

    return _SectionCard(
      title: 'BODYWEIGHT',
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: GoogleFonts.dmMono(
                            color: IronMindColors.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: minW,
                maxY: maxW,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: IronMindColors.warning,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: IronMindColors.warning,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: IronMindColors.warning.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Track your bodyweight progress over time.',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRecentPRs() {
    if (_prs.isEmpty) return const SizedBox.shrink();
    final entries = _prs.entries.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.value['date'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b.value['date'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate); // Most recent first
      });

    return _SectionCard(
      title: 'PERSONAL RECORDS',
      trailing: Text('${entries.length} total',
          style: GoogleFonts.dmSans(
              color: IronMindColors.textMuted, fontSize: 12)),
      child: Column(
        children: entries.take(6).map((e) {
          final pr = e.value as Map<String, dynamic>;
          final weight = (pr['weight'] as num?)?.toDouble() ?? 0;
          final reps = (pr['reps'] as int?) ?? 0;
          final estimated1rm = ApiService.calculate1RM(weight, reps);
          final date = DateTime.tryParse(pr['date'] ?? '');
          final dateStr = date != null
              ? '${date.month}/${date.day}/${date.year}'
              : 'Recent';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: IronMindColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: IronMindColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: IronMindColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _capitalize(e.key),
                        style: GoogleFonts.dmSans(
                            color: IronMindColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '~${estimated1rm.toStringAsFixed(0)} lb 1RM',
                      style: GoogleFonts.dmMono(
                          color: IronMindColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${weight.toStringAsFixed(1)} lbs × ${reps} reps',
                      style: GoogleFonts.dmMono(
                          color: IronMindColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      dateStr,
                      style: GoogleFonts.dmSans(
                          color: IronMindColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentWorkouts() {
    if (_logs.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      title: 'RECENT WORKOUTS',
      child: Column(
        children: _logs.take(3).map((log) {
          final date = DateTime.tryParse(log['timestamp'] ?? '');
          final dateStr = date != null
              ? '${date.month}/${date.day}'
              : '';
          final exCount =
              (log['exercises'] as List? ?? []).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: IronMindColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: IronMindColors.border),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: IronMindColors.accent, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['name'] ?? 'Workout',
                          style: GoogleFonts.dmSans(
                              color: IronMindColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Text('$exCount exercises',
                          style: GoogleFonts.dmSans(
                              color: IronMindColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Text(dateStr,
                    style: GoogleFonts.dmMono(
                        color: IronMindColors.textSecondary, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _editGoals() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditGoalsSheet(
        goals: _goals,
        onSaved: (updated) async {
          await ApiService.saveStrengthGoals(updated);
          _load();
        },
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Edit Goals Sheet ──────────────────────────────────────

class _EditGoalsSheet extends StatefulWidget {
  final Map<String, dynamic> goals;
  final ValueChanged<Map<String, dynamic>> onSaved;
  const _EditGoalsSheet({required this.goals, required this.onSaved});

  @override
  State<_EditGoalsSheet> createState() => _EditGoalsSheetState();
}

class _EditGoalsSheetState extends State<_EditGoalsSheet> {
  late TextEditingController _squatC;
  late TextEditingController _benchC;
  late TextEditingController _deadC;
  late TextEditingController _ohpC;

  @override
  void initState() {
    super.initState();
    _squatC = TextEditingController(text: '${widget.goals['squat'] ?? 315}');
    _benchC = TextEditingController(text: '${widget.goals['bench'] ?? 225}');
    _deadC = TextEditingController(text: '${widget.goals['deadlift'] ?? 405}');
    _ohpC = TextEditingController(text: '${widget.goals['ohp'] ?? 135}');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('EDIT GOALS',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textPrimary,
                        fontSize: 22,
                        letterSpacing: 2)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    widget.onSaved({
                      'squat': int.tryParse(_squatC.text) ?? 315,
                      'bench': int.tryParse(_benchC.text) ?? 225,
                      'deadlift': int.tryParse(_deadC.text) ?? 405,
                      'ohp': int.tryParse(_ohpC.text) ?? 135,
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('SAVE',
                      style: GoogleFonts.bebasNeue(fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _GoalField(label: 'SQUAT GOAL (lbs)', controller: _squatC,
                color: IronMindColors.accent),
            const SizedBox(height: 12),
            _GoalField(label: 'BENCH GOAL (lbs)', controller: _benchC,
                color: IronMindColors.success),
            const SizedBox(height: 12),
            _GoalField(label: 'DEADLIFT GOAL (lbs)', controller: _deadC,
                color: IronMindColors.accent),
            const SizedBox(height: 12),
            _GoalField(label: 'OHP GOAL (lbs)', controller: _ohpC,
                color: IronMindColors.warning),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  const _GoalField(
      {required this.label, required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: GoogleFonts.bebasNeue(
                  color: color, fontSize: 13, letterSpacing: 1.2)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: GoogleFonts.dmMono(
                color: IronMindColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              suffixText: 'lbs',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable Widgets ──────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: GoogleFonts.bebasNeue(
                      color: IronMindColors.textPrimary,
                      fontSize: 18,
                      letterSpacing: 1.5)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: IronMindColors.accent, size: 18),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 26,
                    letterSpacing: 1)),
            Text(unit,
                style: GoogleFonts.dmSans(
                    color: IronMindColors.textMuted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: IronMindColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final Color color;
  const _GoalBar(
      {required this.label,
      required this.current,
      required this.goal,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    color: IronMindColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              current > 0
                  ? '${current.toInt()} / ${goal.toInt()} lbs'
                  : '— / ${goal.toInt()} lbs',
              style: GoogleFonts.dmMono(
                  color: IronMindColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(width: 8),
            Text('$pct%',
                style: GoogleFonts.dmMono(color: color, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: IronMindColors.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
