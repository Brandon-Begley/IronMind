import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _wellnessLogs = [];
  List<Map<String, dynamic>> _bodyweightLogs = [];
  List<Map<String, dynamic>> _measurements = [];
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final wellness = await ApiService.getWellnessLogs();
    final bodyweight = await ApiService.getBodyweightLogs();
    final measurements = await ApiService.getMeasurements();
    final profile = await ApiService.getProfile();
    if (!mounted) return;
    setState(() {
      _wellnessLogs = wellness;
      _bodyweightLogs = bodyweight;
      _measurements = measurements;
      _profile = profile;
      _loading = false;
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _goalWeight() => _toDouble(_profile['goalWeight']);

  String _goalDistanceLabel(double? latestWeight) {
    final goalWeight = _goalWeight();
    if (latestWeight == null || goalWeight <= 0) return 'Set a target weight';
    final delta = goalWeight - latestWeight;
    if (delta.abs() < 0.1) return 'Goal reached';
    return '${delta.abs().toStringAsFixed(1)} lbs away from goal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      appBar: IronMindAppBar(
        subtitle: 'Wellness',
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IronMindTheme.accent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1.5),
          labelColor: IronMindTheme.textPrimary,
          unselectedLabelColor: IronMindTheme.text3,
          tabs: const [
            Tab(text: 'BODY METRICS'),
            Tab(text: 'CHECK-IN'),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: IronMindColors.accent),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildBodyMetricsTab(),
                  _buildCheckInTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildCheckInTab() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CheckInHero(
            latestLog: _wellnessLogs.isEmpty ? null : _wellnessLogs.first,
            onLog: _logWellness,
          ),
          const SizedBox(height: 18),
          Text(
            'RECENT CHECK-INS',
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textSecondary,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_wellnessLogs.isNotEmpty) ...[
            ..._wellnessLogs.take(5).map((log) => _WellnessCard(log: log)),
          ] else
            const _EmptyMetricPanel(
              icon: Icons.favorite_border,
              text: 'No wellness data yet',
            ),
        ],
      );

  Widget _buildBodyMetricsTab() {
    final sortedWeights = [..._bodyweightLogs]
      ..sort(
        (a, b) => DateTime.parse(
          a['date'],
        ).compareTo(DateTime.parse(b['date'])),
      );
    final latestWeight = sortedWeights.isNotEmpty
        ? (sortedWeights.last['weight'] as num?)?.toDouble()
        : null;
    final previousWeight = sortedWeights.length > 1
        ? (sortedWeights[sortedWeights.length - 2]['weight'] as num?)
              ?.toDouble()
        : null;
    final delta = latestWeight != null && previousWeight != null
        ? latestWeight - previousWeight
        : null;
    final latestMeasurement =
        _measurements.isNotEmpty ? _measurements.first : null;
    final goalWeight = _goalWeight();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BodyMetricsHero(
          latestWeight: latestWeight,
          goalWeight: goalWeight,
          delta: delta,
          onLogWeight: _logBodyweight,
          onLogMeasurements: _logMeasurements,
          goalLabel: _goalDistanceLabel(latestWeight),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IronMindColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IronMindColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BODYWEIGHT GOAL',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textSecondary,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _goalDistanceLabel(latestWeight),
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 28,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                latestWeight == null || goalWeight <= 0
                    ? 'Log your current weight and set a target to track progress here.'
                    : 'Current: ${latestWeight.toStringAsFixed(1)} lbs   Target: ${goalWeight.toStringAsFixed(1)} lbs',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                label: 'Current Weight',
                value: latestWeight == null
                    ? '-'
                    : '${latestWeight.toStringAsFixed(1)} lbs',
                sub: delta == null
                    ? 'No previous entry'
                    : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} lbs',
                accent: IronMindColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OverviewCard(
                label: 'Target Weight',
                value: goalWeight <= 0
                    ? '-'
                    : '${goalWeight.toStringAsFixed(1)} lbs',
                sub: _goalDistanceLabel(latestWeight),
                accent: IronMindColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OverviewCard(
                label: 'Latest Waist',
                value: latestMeasurement?['waist'] == null
                    ? '-'
                    : '${latestMeasurement!['waist']}"',
                sub: _measurements.isEmpty
                    ? 'No measurement logs'
                    : '${_measurements.length} saved logs',
                accent: IronMindColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'WEIGHT TREND',
          style: GoogleFonts.bebasNeue(
            color: IronMindColors.textSecondary,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _ChartCard(child: _buildWeightChart(sortedWeights)),
        const SizedBox(height: 20),
        Text(
          'RECENT BODYWEIGHT',
          style: GoogleFonts.bebasNeue(
            color: IronMindColors.textSecondary,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (sortedWeights.isEmpty)
          const _EmptyMetricPanel(
            icon: Icons.monitor_weight_outlined,
            text: 'No bodyweight data yet',
          )
        else
          ...sortedWeights.reversed
              .take(6)
              .map((log) => _BodyweightCard(log: log)),
        const SizedBox(height: 26),
        Text(
          'LATEST MEASUREMENTS',
          style: GoogleFonts.bebasNeue(
            color: IronMindColors.textSecondary,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        if (_measurements.isEmpty)
          const _EmptyMetricPanel(
            icon: Icons.straighten,
            text: 'No measurements logged yet',
          )
        else
          ..._measurements.take(6).map((log) => _MeasurementCard(log: log)),
      ],
    );
  }

  Widget _buildWeightChart(List<Map<String, dynamic>> sortedWeights) {
    if (sortedWeights.isEmpty) {
      return Center(
        child: Text(
          'Log your weight to see the trend line',
          style: GoogleFonts.dmSans(
            color: IronMindColors.textMuted,
            fontSize: 13,
          ),
        ),
      );
    }

    final spots = sortedWeights.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        (entry.value['weight'] as num).toDouble(),
      );
    }).toList();
    final minY = spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    final chartMin = (minY - 2).floorToDouble();
    final proposedMax = (maxY + 2).ceilToDouble();
    final chartMax = proposedMax == chartMin
        ? (maxY + 4).ceilToDouble()
        : proposedMax;

    return LineChart(
      LineChartData(
        minY: chartMin,
        maxY: chartMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: IronMindColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 2,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: GoogleFonts.dmMono(
                  color: IronMindColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedWeights.length) {
                  return const SizedBox.shrink();
                }
                final show = index == 0 ||
                    index == sortedWeights.length - 1 ||
                    index == sortedWeights.length ~/ 2;
                if (!show) return const SizedBox.shrink();
                final date = DateTime.parse(sortedWeights[index]['date']);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: GoogleFonts.dmMono(
                      color: IronMindColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: IronMindColors.border),
            bottom: BorderSide(color: IronMindColors.border),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: IronMindColors.accent,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: IronMindColors.accent.withValues(alpha: 0.12),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, xPercent, bar, index) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: IronMindColors.accent,
                strokeWidth: 2,
                strokeColor: IronMindColors.surface,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => IronMindColors.surfaceElevated,
            getTooltipItems: (items) => items
                .map(
                  (item) => LineTooltipItem(
                    '${item.y.toStringAsFixed(1)} lbs',
                    GoogleFonts.dmMono(
                      color: IronMindColors.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _logWellness() {
    int sleep = 7;
    int stress = 3;
    int mood = 7;
    int energy = 7;
    int recovery = 7;
    String notes = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: IronMindColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOG WELLNESS',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              _SliderRow(
                label: 'SLEEP (hours)',
                value: sleep.toDouble(),
                min: 3,
                max: 12,
                divisions: 9,
                color: IronMindColors.accent,
                displayValue: '$sleep hrs',
                onChanged: (value) => setSt(() => sleep = value.toInt()),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'ENERGY (1-10)',
                value: energy.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                color: IronMindColors.success,
                displayValue: '$energy / 10',
                onChanged: (value) => setSt(() => energy = value.toInt()),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'STRESS (1-10)',
                value: stress.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                color: IronMindColors.alert,
                displayValue: '$stress / 10',
                onChanged: (value) => setSt(() => stress = value.toInt()),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'RECOVERY (1-10)',
                value: recovery.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                color: IronMindColors.warning,
                displayValue: '$recovery / 10',
                onChanged: (value) => setSt(() => recovery = value.toInt()),
              ),
              const SizedBox(height: 16),
              _SliderRow(
                label: 'MOOD (1-10)',
                value: mood.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                color: IronMindColors.success,
                displayValue: '$mood / 10',
                onChanged: (value) => setSt(() => mood = value.toInt()),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) => notes = value,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await ApiService.saveWellness({
                    'sleep': sleep,
                    'energy': energy,
                    'stress': stress,
                    'recovery': recovery,
                    'mood': mood,
                    'notes': notes,
                  });
                  await _load();
                  if (mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  'SAVE',
                  style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logBodyweight() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOG BODYWEIGHT',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Weight in lbs',
                suffixText: 'lbs',
              ),
              style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final weight = double.tryParse(controller.text);
                if (weight != null) {
                  await ApiService.logBodyweight(weight);
                  await _load();
                  if (mounted) Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                'SAVE',
                style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logMeasurements() {
    final waist = TextEditingController();
    final chest = TextEditingController();
    final arms = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text(
                'LOG MEASUREMENTS',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 22,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              _MeasurementField(ctrl: waist, label: 'Waist'),
              const SizedBox(height: 12),
              _MeasurementField(ctrl: chest, label: 'Chest'),
              const SizedBox(height: 12),
              _MeasurementField(ctrl: arms, label: 'Arms'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await ApiService.saveMeasurement({
                    if (waist.text.isNotEmpty)
                      'waist': double.tryParse(waist.text),
                    if (chest.text.isNotEmpty)
                      'chest': double.tryParse(chest.text),
                    if (arms.text.isNotEmpty)
                      'arms': double.tryParse(arms.text),
                  });
                  await _load();
                  if (mounted) Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  'SAVE',
                  style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyMetricsHero extends StatelessWidget {
  final double? latestWeight;
  final double goalWeight;
  final double? delta;
  final String goalLabel;
  final VoidCallback onLogWeight;
  final VoidCallback onLogMeasurements;

  const _BodyMetricsHero({
    required this.latestWeight,
    required this.goalWeight,
    required this.delta,
    required this.goalLabel,
    required this.onLogWeight,
    required this.onLogMeasurements,
  });

  @override
  Widget build(BuildContext context) {
    return IronCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'BODY METRICS',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 24,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              Text(
                goalLabel,
                style: GoogleFonts.dmMono(
                  color: IronMindColors.accent,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewCard(
                  label: 'Current',
                  value: latestWeight == null
                      ? '-'
                      : '${latestWeight!.toStringAsFixed(1)} lbs',
                  sub: delta == null
                      ? 'no previous entry'
                      : '${delta! >= 0 ? '+' : ''}${delta!.toStringAsFixed(1)} lbs',
                  accent: IronMindColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewCard(
                  label: 'Target',
                  value: goalWeight <= 0
                      ? '-'
                      : '${goalWeight.toStringAsFixed(1)} lbs',
                  sub: goalWeight <= 0 ? 'set in profile' : 'goal weight',
                  accent: IronMindColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onLogWeight,
                  icon: const Icon(Icons.monitor_weight, size: 18),
                  label: Text(
                    'LOG BODYWEIGHT',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 17,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onLogMeasurements,
                  icon: const Icon(
                    Icons.straighten,
                    size: 18,
                    color: IronMindColors.accent,
                  ),
                  label: Text(
                    'MEASUREMENTS',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindColors.accent,
                      fontSize: 17,
                      letterSpacing: 1.3,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: IronMindColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInHero extends StatelessWidget {
  final Map<String, dynamic>? latestLog;
  final VoidCallback onLog;

  const _CheckInHero({required this.latestLog, required this.onLog});

  @override
  Widget build(BuildContext context) {
    return IronCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW ARE YOU FEELING TODAY?',
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textPrimary,
              fontSize: 24,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latestLog == null
                ? 'Log a quick wellness check-in so IronMind has a better read on recovery, mood, and readiness.'
                : 'Latest mood ${latestLog!['mood']}/10, energy ${latestLog!['energy']}/10, recovery ${latestLog!['recovery']}/10.',
            style: GoogleFonts.dmSans(
              color: IronMindColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLog,
              icon: const Icon(Icons.favorite_outline, size: 18),
              label: Text(
                'LOG CHECK-IN',
                style: GoogleFonts.bebasNeue(
                  fontSize: 18,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                displayValue,
                style: GoogleFonts.dmMono(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: IronMindColors.border,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      );
}

class _WellnessCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _WellnessCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(log['date']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${date.month}/${date.day}/${date.year}',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '${log['mood']}/10 mood',
                style: GoogleFonts.dmMono(
                  color: IronMindColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Sleep',
                value: '${log['sleep']}h',
                color: IronMindColors.accent,
              ),
              _MetricChip(
                label: 'Energy',
                value: '${log['energy']}/10',
                color: IronMindColors.success,
              ),
              _MetricChip(
                label: 'Stress',
                value: '${log['stress']}/10',
                color: IronMindColors.alert,
              ),
              _MetricChip(
                label: 'Recovery',
                value: '${log['recovery']}/10',
                color: IronMindColors.warning,
              ),
            ],
          ),
          if (log['notes']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              '"${log['notes']}"',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BodyweightCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _BodyweightCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(log['date']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bodyweight',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${date.month}/${date.day}/${date.year}',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            '${log['weight']} lbs',
            style: GoogleFonts.dmMono(
              color: IronMindColors.accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _MeasurementCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(log['date']);
    final metrics = <_MetricValue>[];
    if (log['waist'] != null) {
      metrics.add(
        _MetricValue('Waist', '${log['waist']}"', IronMindColors.warning),
      );
    }
    if (log['chest'] != null) {
      metrics.add(
        _MetricValue('Chest', '${log['chest']}"', IronMindColors.success),
      );
    }
    if (log['arms'] != null) {
      metrics.add(
        _MetricValue('Arms', '${log['arms']}"', IronMindColors.accent),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Measurements',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${date.month}/${date.day}/${date.year}',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (metrics.isEmpty)
            Text(
              'No measurements saved',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textMuted,
                fontSize: 13,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metrics
                  .map(
                    (metric) => _MetricPill(
                      label: metric.label,
                      value: metric.value,
                      color: metric.color,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          '$label: $value',
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

class _MeasurementField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;

  const _MeasurementField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.dmMono(
          color: IronMindColors.textPrimary,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'in',
          suffixStyle: GoogleFonts.dmMono(
            color: IronMindColors.textMuted,
            fontSize: 11,
          ),
        ),
      );
}

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color accent;

  const _OverviewCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IronMindColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.dmMono(
                color: IronMindColors.textMuted,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.bebasNeue(
                color: accent,
                fontSize: 24,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: GoogleFonts.dmSans(
                color: IronMindColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class _ChartCard extends StatelessWidget {
  final Widget child;

  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        height: 230,
        padding: const EdgeInsets.fromLTRB(12, 16, 18, 8),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IronMindColors.border),
        ),
        child: child,
      );
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              TextSpan(
                text: value,
                style: GoogleFonts.dmMono(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyMetricPanel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyMetricPanel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: IronMindColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MetricValue {
  final String label;
  final String value;
  final Color color;

  const _MetricValue(this.label, this.value, this.color);
}
