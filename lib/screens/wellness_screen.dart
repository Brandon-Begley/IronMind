import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/health_service.dart';
import '../core/theme/ironmind_theme.dart';
import '../shared/widgets/common.dart';
import 'habits_tab.dart';

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

  // Health data (null when not connected or unavailable)
  double? _healthSleepHours;
  double? _healthRestingHR;
  double? _healthWeight;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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

    // Load health data independently so it doesn't block the screen paint
    if (HealthService.instance.isConnected) {
      final sleep  = await HealthService.instance.getLastNightSleepHours();
      final hr     = await HealthService.instance.getRestingHeartRate();
      final weight = await HealthService.instance.getLatestWeight();
      if (!mounted) return;
      setState(() {
        _healthSleepHours = sleep;
        _healthRestingHR  = hr;
        _healthWeight     = weight;
      });
    }
  }

  bool _hasLoggedWeightToday() {
    final today = DateTime.now();
    return _bodyweightLogs.any((log) {
      final d = DateTime.tryParse(log['date']?.toString() ?? '');
      return d != null &&
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: IronMindColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: IronMindColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: IronMindColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: GoogleFonts.bebasNeue(fontSize: 12, letterSpacing: 1.2),
                labelColor: IronMindColors.background,
                unselectedLabelColor: IronMindColors.textSecondary,
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'BODY'),
                  Tab(text: 'CHECK-IN'),
                  Tab(text: 'HABITS'),
                  Tab(text: 'NUTRITION'),
                ],
              ),
            ),
          ),
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
                  const HabitsTab(),
                  const _NutritionTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildCheckInTab() {
    // Oldest-first slice of up to 7 logs for the chart
    final chartLogs = _wellnessLogs.take(7).toList().reversed.toList();
    final alreadyToday = _wellnessLogs.isNotEmpty &&
        _isSameDay(DateTime.parse(_wellnessLogs.first['date']), DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (HealthService.instance.isConnected &&
            (_healthSleepHours != null || _healthRestingHR != null)) ...[
          _HealthCheckInBanner(
            sleepHours: _healthSleepHours,
            restingHR: _healthRestingHR,
          ),
          const SizedBox(height: 12),
        ],
        _CheckInHero(
          latestLog: _wellnessLogs.isEmpty ? null : _wellnessLogs.first,
          alreadyToday: alreadyToday,
          onLog: _logWellness,
        ),
        if (chartLogs.length >= 2) ...[
          const SizedBox(height: 20),
          SectionHeader(title: '7-Day Wellness Trend'),
          const SizedBox(height: 10),
          _ChartCard(child: _buildWellnessChart(chartLogs)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LegendDot(color: IronMindColors.success, label: 'Mood'),
                const SizedBox(width: 10),
                _LegendDot(color: IronMindColors.accent, label: 'Energy'),
                const SizedBox(width: 10),
                _LegendDot(color: IronMindColors.warning, label: 'Recovery'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionHeader(title: 'Check-In History'),
            if (_wellnessLogs.isNotEmpty)
              Text(
                '${_wellnessLogs.length} entries',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_wellnessLogs.isNotEmpty) ...[
          ..._wellnessLogs.take(14).map((log) => _WellnessCard(log: log)),
          if (_wellnessLogs.length > 14)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  '+ ${_wellnessLogs.length - 14} older entries',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ] else
          const EmptyState(
            icon: '💙',
            title: 'No Check-Ins Yet',
            sub: 'Log your daily wellness to track mood, sleep, and recovery.',
          ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildWellnessChart(List<Map<String, dynamic>> logs) {
    if (logs.isEmpty) return const SizedBox.shrink();

    FlSpot toSpot(int i, String key) => FlSpot(
          i.toDouble(),
          ((logs[i][key] as num?)?.toDouble() ?? 0).clamp(1, 10),
        );

    final moodSpots = List.generate(logs.length, (i) => toSpot(i, 'mood'));
    final energySpots = List.generate(logs.length, (i) => toSpot(i, 'energy'));
    final recoverySpots = List.generate(logs.length, (i) => toSpot(i, 'recovery'));

    LineChartBarData bar(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3,
              color: color,
              strokeWidth: 1.5,
              strokeColor: IronMindColors.surface,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: IronMindColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 2,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: GoogleFonts.dmMono(color: IronMindColors.textMuted, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= logs.length) return const SizedBox.shrink();
                final date = DateTime.parse(logs[i]['date']);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: GoogleFonts.dmMono(color: IronMindColors.textMuted, fontSize: 9),
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
          bar(moodSpots, IronMindColors.success),
          bar(energySpots, IronMindColors.accent),
          bar(recoverySpots, IronMindColors.warning),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => IronMindColors.surfaceElevated,
            getTooltipItems: (items) => items.map((item) {
              final labels = ['Mood', 'Energy', 'Recovery'];
              final colors = [IronMindColors.success, IronMindColors.accent, IronMindColors.warning];
              final idx = item.barIndex.clamp(0, 2);
              return LineTooltipItem(
                '${labels[idx]}: ${item.y.toStringAsFixed(0)}',
                GoogleFonts.dmMono(color: colors[idx], fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

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
        if (HealthService.instance.isConnected &&
            _healthWeight != null &&
            !_hasLoggedWeightToday()) ...[
          _HealthWeightBanner(
            weight: _healthWeight!,
            onImport: () async {
              await ApiService.logBodyweight(_healthWeight!);
              await HealthService.instance.writeWeight(_healthWeight!);
              await _load();
            },
          ),
          const SizedBox(height: 12),
        ],
        _BodyMetricsHero(
          latestWeight: latestWeight,
          goalWeight: goalWeight,
          delta: delta,
          onLogWeight: _logBodyweight,
          onLogMeasurements: _logMeasurements,
          goalLabel: _goalDistanceLabel(latestWeight),
        ),
        const SizedBox(height: 14),
        if (sortedWeights.isNotEmpty) ...[
          SectionHeader(title: 'Weight Trend'),
          const SizedBox(height: 10),
          _ChartCard(child: _buildWeightChart(sortedWeights)),
          const SizedBox(height: 14),
          ...sortedWeights.reversed
              .take(5)
              .map((log) => _BodyweightCard(log: log)),
        ] else
          const _EmptyMetricPanel(
            icon: Icons.monitor_weight_outlined,
            text: 'No bodyweight entries yet — tap Log Weight to start',
          ),
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
    int sleep = (_healthSleepHours?.round() ?? 7).clamp(3, 12);
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
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _showCheckInQuote(mood: mood, energy: energy, recovery: recovery, sleep: sleep, stress: stress);
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

  void _showCheckInQuote({
    required int mood,
    required int energy,
    required int recovery,
    required int sleep,
    required int stress,
  }) {
    final quote = _generateCheckInQuote(
      mood: mood, energy: energy,
      recovery: recovery, sleep: sleep, stress: stress,
    );
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: IronMindColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(quote.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 16),
              Text(
                quote.headline,
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 22, letterSpacing: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                quote.body,
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary,
                  fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('LET\'S GO',
                    style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.5)),
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                textInputAction: TextInputAction.done,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Weight in lbs',
                  suffixText: 'lbs',
                ),
                style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  FocusScope.of(ctx).unfocus();
                  final weight = double.tryParse(controller.text);
                  if (weight != null) {
                    await ApiService.logBodyweight(weight);
                    await HealthService.instance.writeWeight(weight);
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
                    fontSize: 18,
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
  final bool alreadyToday;
  final VoidCallback onLog;

  const _CheckInHero({
    required this.latestLog,
    required this.alreadyToday,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final log = latestLog;
    return IronCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'HOW ARE YOU FEELING?',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              if (alreadyToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: IronMindColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: IronMindColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: IronMindColors.success, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Logged today',
                        style: GoogleFonts.dmSans(
                          color: IronMindColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (log != null) ...[
            // Full metric grid from latest log
            Row(
              children: [
                Expanded(child: _MiniMetric(label: 'MOOD', value: '${log['mood'] ?? '-'}', color: IronMindColors.success)),
                const SizedBox(width: 8),
                Expanded(child: _MiniMetric(label: 'ENERGY', value: '${log['energy'] ?? '-'}', color: IronMindColors.accent)),
                const SizedBox(width: 8),
                Expanded(child: _MiniMetric(label: 'SLEEP', value: '${log['sleep'] ?? '-'}h', color: const Color(0xFF9B8AFB))),
                const SizedBox(width: 8),
                Expanded(child: _MiniMetric(label: 'STRESS', value: '${log['stress'] ?? '-'}', color: IronMindColors.alert)),
                const SizedBox(width: 8),
                Expanded(child: _MiniMetric(label: 'RECOVERY', value: '${log['recovery'] ?? '-'}', color: IronMindColors.warning)),
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              'Log a quick check-in so IronMind has a better read on your recovery, mood, and readiness.',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onLog,
              icon: Icon(
                alreadyToday ? Icons.edit_outlined : Icons.favorite_outline,
                size: 18,
              ),
              label: Text(
                alreadyToday ? 'UPDATE CHECK-IN' : 'LOG CHECK-IN',
                style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.bebasNeue(color: color, fontSize: 18, letterSpacing: 1),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.dmMono(color: IronMindColors.textMuted, fontSize: 8, letterSpacing: 0.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
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
                fontSize: 20,
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(color: IronMindColors.textSecondary, fontSize: 11),
          ),
        ],
      );
}

// ── Health data banners ────────────────────────────────────────────────────

class _HealthCheckInBanner extends StatelessWidget {
  final double? sleepHours;
  final double? restingHR;

  const _HealthCheckInBanner({this.sleepHours, this.restingHR});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_outlined,
                  color: IronMindColors.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                'FROM HEALTH',
                style: GoogleFonts.dmMono(
                  color: IronMindColors.accent,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (sleepHours != null) ...[
                _HealthChip(
                  icon: Icons.bedtime_outlined,
                  value: '${sleepHours!.toStringAsFixed(1)}h',
                  label: 'Sleep',
                  color: IronMindColors.accent,
                ),
                const SizedBox(width: 10),
              ],
              if (restingHR != null)
                _HealthChip(
                  icon: Icons.favorite_border,
                  value: '${restingHR!.toInt()} bpm',
                  label: 'Resting HR',
                  color: IronMindColors.alert,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthWeightBanner extends StatelessWidget {
  final double weight;
  final VoidCallback onImport;

  const _HealthWeightBanner({required this.weight, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety_outlined,
              color: IronMindColors.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weight.toStringAsFixed(1)} lbs — from Health',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'No weight logged today',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onImport,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: IronMindColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'IMPORT',
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.background,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _HealthChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.dmMono(
                color: IronMindColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: IronMindColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Check-in quote generator ──────────────────────────────────────────────────

class _CheckInQuote {
  final String emoji;
  final String headline;
  final String body;
  const _CheckInQuote(this.emoji, this.headline, this.body);
}

_CheckInQuote _generateCheckInQuote({
  required int mood,
  required int energy,
  required int recovery,
  required int sleep,
  required int stress,
}) {
  final avg = (mood + energy + recovery) / 3.0;
  final lowSleep  = sleep <= 5;
  final highStress = stress >= 7;

  // Peak state
  if (avg >= 8 && !highStress) {
    const quotes = [
      _CheckInQuote('🔥', 'You\'re Locked In', 'Your body and mind are aligned right now. Channel this energy — today is a day to push.'),
      _CheckInQuote('⚡', 'Peak Condition', 'Everything is firing on all cylinders. Trust the process and attack your session.'),
      _CheckInQuote('💪', 'Ready to Dominate', 'High energy, great recovery, strong mindset. This is what you\'ve been building for.'),
      _CheckInQuote('🚀', 'Full Send', 'Your numbers say you\'re ready. Go after it with confidence — performance follows preparation.'),
    ];
    return quotes[DateTime.now().second % quotes.length];
  }

  // Good — high mood but some fatigue
  if (avg >= 6.5) {
    if (lowSleep) {
      const quotes = [
        _CheckInQuote('😤', 'Grit Over Comfort', 'Sleep wasn\'t perfect, but your mindset is solid. Stay focused, manage intensity, and get it done.'),
        _CheckInQuote('🧠', 'Mind Over Mattress', 'Not your best sleep, but champions train anyway. Listen to your body and keep the fire lit.'),
      ];
      return quotes[DateTime.now().second % quotes.length];
    }
    const quotes = [
      _CheckInQuote('💡', 'Feeling Good', 'You\'re in a strong spot today. Stay consistent — this is how progress compounds over time.'),
      _CheckInQuote('🎯', 'On Track', 'Solid numbers across the board. Keep your head down and put in quality work.'),
      _CheckInQuote('📈', 'Building Momentum', 'Another good day in the process. Each session like this stacks into something bigger.'),
    ];
    return quotes[DateTime.now().second % quotes.length];
  }

  // Moderate — high stress or low energy
  if (avg >= 4.5) {
    if (highStress) {
      const quotes = [
        _CheckInQuote('🌊', 'Breathe Through It', 'Stress is high today — that\'s okay. Use your training as an outlet, not a burden. Show up anyway.'),
        _CheckInQuote('🛡️', 'Hold the Line', 'Not every day feels like a win before it starts. Show up, do the work, and let results speak later.'),
      ];
      return quotes[DateTime.now().second % quotes.length];
    }
    const quotes = [
      _CheckInQuote('🔄', 'Steady the Ship', 'A moderate day is still a day of progress. Focus on technique, stay consistent, keep moving.'),
      _CheckInQuote('🏗️', 'Building Days Count', 'Not every session will feel electric. The ones you show up for anyway are the ones that matter most.'),
      _CheckInQuote('⚙️', 'Trust the Process', 'Today is a maintenance day. Protect your streak, do the work, and the gains will come.'),
    ];
    return quotes[DateTime.now().second % quotes.length];
  }

  // Low — recovery day needed
  if (lowSleep && avg < 5) {
    const quotes = [
      _CheckInQuote('😴', 'Rest is Training Too', 'Your body is asking for recovery. Prioritise sleep tonight — the iron will be there tomorrow.'),
      _CheckInQuote('🛌', 'Recharge Mode', 'Listen to what your body is telling you. A strategic rest day is a weapon, not a weakness.'),
    ];
    return quotes[DateTime.now().second % quotes.length];
  }

  const quotes = [
    _CheckInQuote('💙', 'You Showed Up', 'Logging in on a hard day is a form of discipline too. Be gentle with yourself and keep the habit alive.'),
    _CheckInQuote('🌱', 'Recovery is Progress', 'Low days don\'t last. Eat well, rest well, and trust that your body is rebuilding stronger.'),
    _CheckInQuote('🔋', 'Recharge and Return', 'Everyone has low days. The difference is that you tracked it. That awareness is already working in your favour.'),
  ];
  return quotes[DateTime.now().second % quotes.length];
}

// ── Nutrition Tab ─────────────────────────────────────────────────────────────

class _NutritionTab extends StatefulWidget {
  const _NutritionTab();

  @override
  State<_NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<_NutritionTab> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic> _targets = {};
  int _waterGlasses = 0;
  bool _loading = true;
  late String _dateKey;

  static const _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Other'];

  @override
  void initState() {
    super.initState();
    _dateKey = _todayKey();
    _load();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    final entries = await ApiService.getFoodEntries(_dateKey);
    final targets = await ApiService.getNutritionTargets();
    final water   = await ApiService.getWaterGlasses(_dateKey);
    if (!mounted) return;
    setState(() {
      _entries      = entries;
      _targets      = targets;
      _waterGlasses = water;
      _loading      = false;
    });
  }

  int get _totalCalories  => _entries.fold(0, (s, e) => s + ((e['calories'] as num?)?.toInt() ?? 0));
  double get _totalProtein => _entries.fold(0.0, (s, e) => s + ((e['protein'] as num?)?.toDouble() ?? 0));
  double get _totalCarbs   => _entries.fold(0.0, (s, e) => s + ((e['carbs']   as num?)?.toDouble() ?? 0));
  double get _totalFat     => _entries.fold(0.0, (s, e) => s + ((e['fat']     as num?)?.toDouble() ?? 0));

  int get _targetCal  => (_targets['calories'] as num?)?.toInt()  ?? 2300;
  int get _targetPro  => (_targets['protein']  as num?)?.toInt()  ?? 260;
  int get _targetCarb => (_targets['carbs']    as num?)?.toInt()  ?? 200;
  int get _targetFat  => (_targets['fat']      as num?)?.toInt()  ?? 55;

  Future<void> _addEntry() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddFoodSheet(),
    );
    if (result == null) return;
    await ApiService.saveFoodEntry(_dateKey, result);
    _load();
  }

  Future<void> _deleteEntry(int index) async {
    await ApiService.deleteFoodEntry(_dateKey, index);
    _load();
  }

  Future<void> _setWater(int glasses) async {
    await ApiService.setWaterGlasses(_dateKey, glasses);
    setState(() => _waterGlasses = glasses.clamp(0, 20));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: IronMindColors.accent));
    }

    final calPct   = _targetCal  > 0 ? (_totalCalories  / _targetCal).clamp(0.0, 1.0)  : 0.0;
    final proPct   = _targetPro  > 0 ? (_totalProtein   / _targetPro).clamp(0.0, 1.0)  : 0.0;
    final carbPct  = _targetCarb > 0 ? (_totalCarbs     / _targetCarb).clamp(0.0, 1.0) : 0.0;
    final fatPct   = _targetFat  > 0 ? (_totalFat       / _targetFat).clamp(0.0, 1.0)  : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Daily summary card ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: IronMindColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: IronMindColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('TODAY',
                    style: GoogleFonts.dmMono(
                      color: IronMindColors.textMuted, fontSize: 9, letterSpacing: 1.5)),
                  Text(_dateKey,
                    style: GoogleFonts.dmMono(
                      color: IronMindColors.textMuted, fontSize: 9)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroCircle('Calories', _totalCalories, _targetCal, 'kcal', IronMindColors.accent, calPct),
                  _MacroCircle('Protein',  _totalProtein.round(), _targetPro, 'g', IronMindColors.success, proPct),
                  _MacroCircle('Carbs',    _totalCarbs.round(),   _targetCarb, 'g', IronMindColors.accent,  carbPct),
                  _MacroCircle('Fat',      _totalFat.round(),     _targetFat, 'g',  IronMindColors.warning, fatPct),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Water tracker ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: IronMindColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: IronMindColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: IronMindColors.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WATER',
                      style: GoogleFonts.dmMono(
                        color: IronMindColors.textMuted, fontSize: 9, letterSpacing: 1.2)),
                    Text('$_waterGlasses / 8 glasses',
                      style: GoogleFonts.dmSans(
                        color: IronMindColors.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _setWater(_waterGlasses - 1),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: IronMindColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: IronMindColors.border),
                      ),
                      child: const Icon(Icons.remove, size: 14, color: IronMindColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _setWater(_waterGlasses + 1),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: IronMindColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: IronMindColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.add, size: 14, color: IronMindColors.accent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Log food button ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addEntry,
            icon: const Icon(Icons.add, size: 16),
            label: Text('LOG FOOD',
              style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.5)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Meal sections ──────────────────────────────────────────────────
        if (_entries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu_outlined,
                    color: IronMindColors.textMuted, size: 36),
                  const SizedBox(height: 12),
                  Text('No food logged today.',
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textMuted, fontSize: 13)),
                  Text('Tap LOG FOOD to add a meal.',
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ..._meals.where((meal) =>
            _entries.any((e) => (e['meal'] as String? ?? 'Other') == meal)
          ).map((meal) {
            final mealEntries = _entries
                .asMap().entries
                .where((e) => (e.value['meal'] as String? ?? 'Other') == meal)
                .toList();
            final mealCal = mealEntries.fold(0, (s, e) =>
                s + ((e.value['calories'] as num?)?.toInt() ?? 0));

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(meal.toUpperCase(),
                        style: GoogleFonts.dmMono(
                          color: IronMindColors.textMuted,
                          fontSize: 9, letterSpacing: 1.5)),
                      Text('$mealCal kcal',
                        style: GoogleFonts.dmMono(
                          color: IronMindColors.accent, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...mealEntries.map((e) => _FoodEntryTile(
                    entry: e.value,
                    onDelete: () => _deleteEntry(e.key),
                  )),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _MacroCircle extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final String unit;
  final Color color;
  final double pct;

  const _MacroCircle(this.label, this.value, this.target, this.unit, this.color, this.pct);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 56, height: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: pct,
                strokeWidth: 4,
                backgroundColor: IronMindColors.border,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Center(
                child: Text('$value',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
          style: GoogleFonts.dmMono(
            color: IronMindColors.textMuted, fontSize: 8, letterSpacing: 0.5)),
        Text('/ $target$unit',
          style: GoogleFonts.dmMono(
            color: IronMindColors.textMuted, fontSize: 7)),
      ],
    );
  }
}

class _FoodEntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;
  const _FoodEntryTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cal  = (entry['calories'] as num?)?.toInt()    ?? 0;
    final pro  = (entry['protein']  as num?)?.toDouble() ?? 0.0;
    final carb = (entry['carbs']    as num?)?.toDouble() ?? 0.0;
    final fat  = (entry['fat']      as num?)?.toDouble() ?? 0.0;
    final name = entry['name']?.toString() ?? 'Unknown';
    final srv  = entry['serving']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w500)),
                if (srv.isNotEmpty)
                  Text(srv,
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  _MacroBadge('${cal}kcal', IronMindColors.accent),
                  const SizedBox(width: 6),
                  _MacroBadge('P ${pro.toStringAsFixed(0)}g', IronMindColors.success),
                  const SizedBox(width: 6),
                  _MacroBadge('C ${carb.toStringAsFixed(0)}g', IronMindColors.accent),
                  const SizedBox(width: 6),
                  _MacroBadge('F ${fat.toStringAsFixed(0)}g', IronMindColors.warning),
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: IronMindColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MacroBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text,
      style: GoogleFonts.dmMono(color: color, fontSize: 8)),
  );
}

// ── Add Food Sheet ────────────────────────────────────────────────────────────

class _AddFoodSheet extends StatefulWidget {
  const _AddFoodSheet();

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _nameCtrl    = TextEditingController();
  final _servingCtrl = TextEditingController(text: '1 serving');
  final _calCtrl     = TextEditingController();
  final _proCtrl     = TextEditingController();
  final _carbCtrl    = TextEditingController();
  final _fatCtrl     = TextEditingController();
  String _meal = 'Other';

  static const _meals = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Other'];

  @override
  void dispose() {
    _nameCtrl.dispose(); _servingCtrl.dispose();
    _calCtrl.dispose();  _proCtrl.dispose();
    _carbCtrl.dispose(); _fatCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final cal  = int.tryParse(_calCtrl.text.trim()) ?? 0;
    if (name.isEmpty || cal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and calories are required.')));
      return;
    }
    Navigator.pop(context, {
      'name':     name,
      'serving':  _servingCtrl.text.trim(),
      'calories': cal,
      'protein':  double.tryParse(_proCtrl.text.trim())  ?? 0.0,
      'carbs':    double.tryParse(_carbCtrl.text.trim())  ?? 0.0,
      'fat':      double.tryParse(_fatCtrl.text.trim())   ?? 0.0,
      'meal':     _meal,
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: IronMindColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
                children: [
                  Text('LOG FOOD', style: GoogleFonts.dmMono(
                    color: IronMindColors.textMuted, fontSize: 9, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('Add what you ate',
                    style: GoogleFonts.bebasNeue(
                      color: IronMindColors.textPrimary, fontSize: 22, letterSpacing: 1.5)),
                  const SizedBox(height: 16),

                  // Meal picker
                  Text('MEAL', style: GoogleFonts.dmMono(
                    color: IronMindColors.textMuted, fontSize: 9, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _meals.map((m) => GestureDetector(
                        onTap: () => setState(() => _meal = m),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: _meal == m
                                ? IronMindColors.accent.withValues(alpha: 0.12)
                                : IronMindColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _meal == m
                                  ? IronMindColors.accent
                                  : IronMindColors.border,
                              width: _meal == m ? 1.5 : 1,
                            ),
                          ),
                          child: Text(m, style: GoogleFonts.dmSans(
                            color: _meal == m
                                ? IronMindColors.accent
                                : IronMindColors.textSecondary,
                            fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name + serving
                  _nutField('Food name', _nameCtrl, TextInputType.text),
                  const SizedBox(height: 10),
                  _nutField('Serving (e.g. 200g, 1 cup)', _servingCtrl, TextInputType.text),
                  const SizedBox(height: 16),

                  // Macros row
                  Text('MACROS', style: GoogleFonts.dmMono(
                    color: IronMindColors.textMuted, fontSize: 9, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _nutField('Calories', _calCtrl,
                      const TextInputType.numberWithOptions(decimal: false))),
                    const SizedBox(width: 8),
                    Expanded(child: _nutField('Protein g', _proCtrl,
                      const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _nutField('Carbs g', _carbCtrl,
                      const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: _nutField('Fat g', _fatCtrl,
                      const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('ADD TO LOG',
                        style: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _nutField(String label, TextEditingController ctrl, TextInputType kb) =>
    TextField(
      controller: ctrl,
      keyboardType: kb,
      style: GoogleFonts.dmSans(color: IronMindColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.dmSans(color: IronMindColors.textSecondary, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: IronMindColors.border)),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: IronMindColors.accent)),
      ),
    );
