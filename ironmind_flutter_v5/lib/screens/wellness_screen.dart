import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

class WellnessScreen extends StatefulWidget {
  final bool connected;
  const WellnessScreen({super.key, this.connected = false});
  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() { super.initState(); _tabs = TabController(length: 3, vsync: this); }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: 'Wellness',
        connected: widget.connected,
        bottom: TabBar(
          controller: _tabs,
          labelColor: IronMindTheme.accent, unselectedLabelColor: IronMindTheme.text3,
          indicatorColor: IronMindTheme.accent, indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.dmMono(fontSize: 10), unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 10),
          tabs: const [Tab(text: 'Check-In'), Tab(text: 'Bodyweight'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [
        _CheckInTab(),
        _BodyweightTab(),
        _HistoryTab(),
      ]),
    );
  }
}

// ── Check-In Tab ──────────────────────────────────────────────────────────────
class _CheckInTab extends StatefulWidget {
  const _CheckInTab();
  @override
  State<_CheckInTab> createState() => _CheckInTabState();
}
class _CheckInTabState extends State<_CheckInTab> {
  double _mood = 7, _energy = 7, _stress = 3, _recovery = 7, _sleep = 7;
  final _notesCtrl = TextEditingController();
  bool _saving = false, _todayDone = false;

  @override
  void initState() { super.initState(); _loadToday(); }

  Future<void> _loadToday() async {
    final today = await ApiService.getWellnessToday();
    if (today != null) {
      setState(() {
        _todayDone = true;
        _mood = (today['mood'] as num).toDouble();
        _energy = (today['energy'] as num).toDouble();
        _stress = (today['stress'] as num).toDouble();
        _recovery = (today['recovery'] as num).toDouble();
        _sleep = (today['sleep'] as num?)?.toDouble() ?? 7;
        _notesCtrl.text = today['notes'] ?? '';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.saveWellness({
        'date': DateTime.now().toIso8601String().split('T')[0],
        'mood': _mood.round(), 'energy': _energy.round(),
        'stress': _stress.round(), 'recovery': _recovery.round(),
        'sleep': _sleep.round(), 'notes': _notesCtrl.text,
      });
      setState(() => _todayDone = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in saved!'), backgroundColor: IronMindTheme.green));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server offline — could not save'), backgroundColor: IronMindTheme.orange));
    } finally { setState(() => _saving = false); }
  }

  Color _color(double v, {bool inv = false}) {
    if (!inv) return v >= 8 ? IronMindTheme.green : v <= 4 ? IronMindTheme.red : IronMindTheme.accent;
    return v >= 8 ? IronMindTheme.red : v <= 4 ? IronMindTheme.green : IronMindTheme.accent;
  }

  Widget _slide(String emoji, String label, double val, bool inv, ValueChanged<double> cb) {
    final c = _color(val, inv: inv);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: 10), Text(label, style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13, fontWeight: FontWeight.w500))]),
          Text('${val.round()}/10', style: GoogleFonts.bebasNeue(color: c, fontSize: 22, letterSpacing: 1)),
        ]),
        SliderTheme(
          data: SliderThemeData(activeTrackColor: c, inactiveTrackColor: IronMindTheme.border2, thumbColor: c, overlayColor: c.withOpacity(0.15), trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
          child: Slider(value: val, min: 1, max: 10, divisions: 9, onChanged: cb),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const IronLabel('Daily Check-In'),
            if (_todayDone) IronBadge('✓ Logged today', color: IronMindTheme.green),
          ]),
          const SizedBox(height: 16),
          _slide('😊', 'Mood', _mood, false, (v) => setState(() => _mood = v)),
          _slide('⚡', 'Energy', _energy, false, (v) => setState(() => _energy = v)),
          _slide('😤', 'Stress', _stress, true, (v) => setState(() => _stress = v)),
          _slide('💪', 'Recovery', _recovery, false, (v) => setState(() => _recovery = v)),
          _slide('😴', 'Sleep Quality', _sleep, false, (v) => setState(() => _sleep = v)),
          TextField(
            controller: _notesCtrl, maxLines: 2,
            style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'How are you feeling today?'),
          ),
          const SizedBox(height: 14),
          IronButton(label: _todayDone ? 'UPDATE CHECK-IN' : 'SAVE CHECK-IN', onPressed: _save, loading: _saving),
        ])),
      ]),
    );
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }
}

// ── Bodyweight Tab ────────────────────────────────────────────────────────────
class _BodyweightTab extends StatefulWidget {
  const _BodyweightTab();
  @override
  State<_BodyweightTab> createState() => _BodyweightTabState();
}
class _BodyweightTabState extends State<_BodyweightTab> {
  List<Map<String, dynamic>> _log = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final l = await ApiService.getBodyweightLog();
    setState(() { _log = l; _loading = false; });
  }

  void _showLog() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LOG BODYWEIGHT', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 32, letterSpacing: 1),
            decoration: const InputDecoration(labelText: 'Weight', suffixText: 'lbs', hintText: '0.0'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          IronButton(label: 'LOG WEIGHT', onPressed: () async {
            final w = double.tryParse(ctrl.text);
            if (w == null || w <= 0) return;
            await ApiService.logBodyweight(w, DateTime.now().toIso8601String().split('T')[0]);
            Navigator.pop(ctx); _load();
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_log.isNotEmpty) ...[
          IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const IronLabel('Current'),
                Text('${_log.last['weight']}', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 40, letterSpacing: 1)),
                Text('lbs · ${_log.last['date']}', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
              ])),
              if (_log.length >= 2) ...[
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const IronLabel('Change'),
                  Builder(builder: (_) {
                    final diff = (_log.last['weight'] as num).toDouble() - (_log.first['weight'] as num).toDouble();
                    final color = diff < 0 ? IronMindTheme.green : diff > 0 ? IronMindTheme.red : IronMindTheme.text3;
                    return Text('${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}', style: GoogleFonts.bebasNeue(color: color, fontSize: 28, letterSpacing: 1));
                  }),
                  Text('lbs total', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                ]),
              ],
            ]),
          ])),
          const SizedBox(height: 10),
          if (_log.length >= 2)
            IronCard(child: SizedBox(height: 150, child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: IronMindTheme.border, strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(
                spots: _log.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble())).toList(),
                isCurved: true, color: IronMindTheme.orange, barWidth: 2,
                dotData: FlDotData(getDotPainter: (a, b, c, d) => FlDotCirclePainter(radius: 3, color: IronMindTheme.orange, strokeColor: IronMindTheme.bg, strokeWidth: 1)),
                belowBarData: BarAreaData(show: true, color: IronMindTheme.orange.withOpacity(0.08)),
              )],
            )))),
          const SizedBox(height: 14),
        ],
        IronButton(label: '+ LOG BODYWEIGHT', onPressed: _showLog),
        const SizedBox(height: 16),
        if (_log.isEmpty)
          const EmptyState(icon: '⚖️', title: 'No Weigh-ins Yet', sub: 'Log your first bodyweight above')
        else ...[
          const SectionHeader(title: 'Weigh-in Log'),
          const SizedBox(height: 10),
          IronCard(padding: EdgeInsets.zero, child: Column(
            children: _log.reversed.take(20).toList().asMap().entries.map((e) {
              final entry = e.value;
              final isLast = e.key == (_log.reversed.take(20).length - 1);
              return Dismissible(
                key: Key('bw-${entry['date']}'),
                direction: DismissDirection.endToStart,
                background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: IronMindTheme.redDim, child: const Icon(Icons.delete_outline, color: IronMindTheme.red)),
                onDismissed: (_) async { await ApiService.deleteBodyweightEntry(entry['date']); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border))),
                  child: Row(children: [
                    Text(entry['date'] ?? '', style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 11)),
                    const Spacer(),
                    Text('${entry['weight']}', style: GoogleFonts.bebasNeue(color: IronMindTheme.orange, fontSize: 20, letterSpacing: 1)),
                    Text(' lbs', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
                  ]),
                ),
              );
            }).toList(),
          )),
        ],
      ]),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────
class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}
class _HistoryTabState extends State<_HistoryTab> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final l = await ApiService.getWellness(); setState(() { _logs = l; _loading = false; }); }
    catch (_) { setState(() => _loading = false); }
  }

  Color _c(double v, {bool inv = false}) {
    if (!inv) return v >= 8 ? IronMindTheme.green : v <= 4 ? IronMindTheme.red : IronMindTheme.accent;
    return v >= 8 ? IronMindTheme.red : v <= 4 ? IronMindTheme.green : IronMindTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    if (_logs.isEmpty) return const EmptyState(icon: '📊', title: 'No History Yet', sub: 'Complete daily check-ins to see your trends');

    // 7-day averages
    final last7 = _logs.take(7).toList();
    double avg(String k) => last7.fold<double>(0, (s, l) => s + (l[k] as num).toDouble()) / last7.length;

    return RefreshIndicator(
      color: IronMindTheme.accent, backgroundColor: IronMindTheme.surface2, onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: '7-Day Average'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _AvgCard('Mood', avg('mood'), false)),
            const SizedBox(width: 8),
            Expanded(child: _AvgCard('Energy', avg('energy'), false)),
            const SizedBox(width: 8),
            Expanded(child: _AvgCard('Stress', avg('stress'), true)),
            const SizedBox(width: 8),
            Expanded(child: _AvgCard('Recovery', avg('recovery'), false)),
          ]),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Log'),
          const SizedBox(height: 10),
          IronCard(padding: EdgeInsets.zero, child: Column(
            children: _logs.take(30).toList().asMap().entries.map((e) {
              final log = e.value;
              final isLast = e.key == (_logs.take(30).length - 1);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border))),
                child: Row(children: [
                  Expanded(child: Text(log['date'] ?? '', style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 11))),
                  Wrap(spacing: 4, children: [
                    IronBadge('M:${log['mood']}', color: _c((log['mood'] as num).toDouble())),
                    IronBadge('E:${log['energy']}', color: _c((log['energy'] as num).toDouble())),
                    IronBadge('S:${log['stress']}', color: _c((log['stress'] as num).toDouble(), inv: true)),
                    IronBadge('R:${log['recovery']}', color: _c((log['recovery'] as num).toDouble())),
                  ]),
                ]),
              );
            }).toList(),
          )),
        ]),
      ),
    );
  }
}

class _AvgCard extends StatelessWidget {
  final String label;
  final double value;
  final bool inverted;
  const _AvgCard(this.label, this.value, this.inverted);

  Color get _color {
    if (!inverted) return value >= 8 ? IronMindTheme.green : value <= 4 ? IronMindTheme.red : IronMindTheme.accent;
    return value >= 8 ? IronMindTheme.red : value <= 4 ? IronMindTheme.green : IronMindTheme.accent;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(label.toUpperCase(), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value.toStringAsFixed(1), style: GoogleFonts.bebasNeue(color: _color, fontSize: 20, letterSpacing: 1)),
    ]),
  );
}
