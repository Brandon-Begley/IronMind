import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool connected;
  const ProfileScreen({super.key, this.connected = false});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
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
        subtitle: 'Profile',
        connected: widget.connected,
        bottom: TabBar(
          controller: _tabs,
          labelColor: IronMindTheme.accent, unselectedLabelColor: IronMindTheme.text3,
          indicatorColor: IronMindTheme.accent, indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.dmMono(fontSize: 10), unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 10),
          tabs: const [Tab(text: 'Info'), Tab(text: 'Progress'), Tab(text: 'Settings')],
        ),
      ),
      body: TabBarView(controller: _tabs, children: const [_InfoTab(), _ProgressTab(), _SettingsTab()]),
    );
  }
}

// ── Info Tab ──────────────────────────────────────────────────────────────────
class _InfoTab extends StatefulWidget {
  const _InfoTab();
  @override
  State<_InfoTab> createState() => _InfoTabState();
}
class _InfoTabState extends State<_InfoTab> {
  Map<String, dynamic> _p = {};
  int _workouts = 0, _prs = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await ApiService.getLifterProfile();
    int wc = 0, pc = 0;
    try {
      final logs = await ApiService.getLogs(); wc = logs.length;
      final prs = await ApiService.getPRs(); pc = prs.length;
    } catch (_) {}
    setState(() { _p = p; _workouts = wc; _prs = pc; });
  }

  String get _initials {
    final name = (_p['name'] ?? '').trim();
    if (name.isEmpty) return 'AT';
    final parts = name.split(' ');
    return parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final styleMap = {'powerlifting': 'Powerlifter', 'powerbuilding': 'Powerbuilder', 'hypertrophy': 'Bodybuilder', 'strength': 'Strength Athlete', 'olympic': 'Olympic Lifter', 'crossfit': 'CrossFitter', 'athletic': 'Athlete'};
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        IronCard(child: Column(children: [
          Row(children: [
            Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: IronMindTheme.accentDim, border: Border.all(color: IronMindTheme.accent, width: 2)),
              child: Center(child: Text(_initials, style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 22, letterSpacing: 1)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((_p['name'] ?? '').isEmpty ? 'Athlete' : _p['name'], style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 1)),
              Text(styleMap[_p['style'] ?? ''] ?? 'Fitness Enthusiast', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
              const SizedBox(height: 4),
              Row(children: [
                IronBadge(_p['experience'] ?? 'intermediate', color: IronMindTheme.accent),
                if ((_p['bodyweight'] ?? '').isNotEmpty) ...[const SizedBox(width: 6), IronBadge('${_p['bodyweight']}lb', color: IronMindTheme.orange)],
              ]),
            ])),
          ]),
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.only(top: 14), decoration: const BoxDecoration(border: Border(top: BorderSide(color: IronMindTheme.border))),
            child: Row(children: [
              _stat('Workouts', '$_workouts', IronMindTheme.accent),
              _div(), _stat('Records', '$_prs', IronMindTheme.green),
              _div(), _stat('Training', '${(_p['trainingDays'] ?? 4).toInt()}x/wk', IronMindTheme.blue),
              _div(), _stat('Goal', _shortGoal(_p['goal'] ?? ''), IronMindTheme.purple),
            ]),
          ),
        ])),
        const SizedBox(height: 10),
        if ((_p['squat'] ?? '').isNotEmpty || (_p['bench'] ?? '').isNotEmpty || (_p['deadlift'] ?? '').isNotEmpty)
          IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IronLabel('Current Maxes'),
            const SizedBox(height: 10),
            Row(children: [
              if ((_p['squat'] ?? '').isNotEmpty) Expanded(child: _maxTile('Squat', _p['squat']!)),
              if ((_p['bench'] ?? '').isNotEmpty) Expanded(child: _maxTile('Bench', _p['bench']!)),
              if ((_p['deadlift'] ?? '').isNotEmpty) Expanded(child: _maxTile('Deadlift', _p['deadlift']!)),
              if ((_p['ohp'] ?? '').isNotEmpty) Expanded(child: _maxTile('OHP', _p['ohp']!)),
            ]),
          ])),
        const SizedBox(height: 10),
        IronCard2(child: Row(children: [
          const Icon(Icons.fitness_center, color: IronMindTheme.text2, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text('Update your lifter profile and 1RMs in Workout → Profile tab', style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12))),
          const Icon(Icons.arrow_forward_ios, color: IronMindTheme.text3, size: 12),
        ])),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(child: Column(children: [
    Text(label.toUpperCase(), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1)),
    const SizedBox(height: 3),
    Text(value, style: GoogleFonts.bebasNeue(color: color, fontSize: 16, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
  ]));
  Widget _div() => Container(width: 1, height: 28, color: IronMindTheme.border, margin: const EdgeInsets.symmetric(horizontal: 8));
  Widget _maxTile(String label, String value) => Column(children: [
    Text(label.toUpperCase(), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1)),
    const SizedBox(height: 3),
    Text('${value}lb', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 16, letterSpacing: 1)),
  ]);
  String _shortGoal(String g) => {'peak-strength': 'Strength', 'hypertrophy': 'Muscle', 'total': 'Total', 'weak-points': 'Weak Pts', 'fitness': 'Fitness', 'lose-fat': 'Fat Loss', 'athletic': 'Athletic'}[g] ?? g;
}

// ── Progress Tab ──────────────────────────────────────────────────────────────
class _ProgressTab extends StatefulWidget {
  const _ProgressTab();
  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}
class _ProgressTabState extends State<_ProgressTab> {
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _bodyweight = [];
  List<Map<String, dynamic>> _measurements = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await ApiService.getLifterProfile();
    final bw = await ApiService.getBodyweightLog();
    final meas = await ApiService.getMeasurements();
    setState(() { _profile = p; _bodyweight = bw; _measurements = meas; _loading = false; });
  }

  void _showAddMeasurement() {
    final waistC = TextEditingController();
    final armsC = TextEditingController();
    final chestC = TextEditingController();
    final thighsC = TextEditingController();
    final neckC = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('LOG MEASUREMENTS', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: TextField(controller: waistC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12), decoration: const InputDecoration(labelText: 'Waist (in)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: chestC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12), decoration: const InputDecoration(labelText: 'Chest (in)'))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: armsC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12), decoration: const InputDecoration(labelText: 'Arms (in)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: thighsC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12), decoration: const InputDecoration(labelText: 'Thighs (in)'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: neckC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12), decoration: const InputDecoration(labelText: 'Neck (in)'))),
          ]),
          const SizedBox(height: 14),
          IronButton(label: 'SAVE MEASUREMENTS', onPressed: () async {
            await ApiService.saveMeasurement({
              'date': DateTime.now().toIso8601String().split('T')[0],
              if (waistC.text.isNotEmpty) 'waist': double.tryParse(waistC.text),
              if (chestC.text.isNotEmpty) 'chest': double.tryParse(chestC.text),
              if (armsC.text.isNotEmpty) 'arms': double.tryParse(armsC.text),
              if (thighsC.text.isNotEmpty) 'thighs': double.tryParse(thighsC.text),
              if (neckC.text.isNotEmpty) 'neck': double.tryParse(neckC.text),
            });
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
        // Strength progress
        if ((_profile['squat'] ?? '').isNotEmpty || (_profile['bench'] ?? '').isNotEmpty) ...[
          const SectionHeader(title: 'Strength Goals'),
          const SizedBox(height: 10),
          IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((_profile['squat'] ?? '').isNotEmpty) MacroBar(label: 'Squat', value: double.tryParse(_profile['squat'] ?? '') ?? 0, target: 500, color: IronMindTheme.accent),
            if ((_profile['bench'] ?? '').isNotEmpty) MacroBar(label: 'Bench', value: double.tryParse(_profile['bench'] ?? '') ?? 0, target: 365, color: IronMindTheme.green),
            if ((_profile['deadlift'] ?? '').isNotEmpty) MacroBar(label: 'Deadlift', value: double.tryParse(_profile['deadlift'] ?? '') ?? 0, target: 600, color: IronMindTheme.blue),
            if ((_profile['ohp'] ?? '').isNotEmpty) MacroBar(label: 'OHP', value: double.tryParse(_profile['ohp'] ?? '') ?? 0, target: 225, color: IronMindTheme.orange),
            const SizedBox(height: 4),
            Text('Progress bars show current vs goal lifts', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
          ])),
          const SizedBox(height: 20),
        ],

        // Bodyweight chart
        SectionHeader(title: 'Bodyweight', trailing: IronGhostButton(label: '+ LOG', color: IronMindTheme.accent, onPressed: () {})),
        const SizedBox(height: 10),
        if (_bodyweight.length >= 2)
          IronCard(child: SizedBox(height: 140, child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: IronMindTheme.border, strokeWidth: 1)),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [LineChartBarData(
              spots: _bodyweight.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['weight'] as num).toDouble())).toList(),
              isCurved: true, color: IronMindTheme.orange, barWidth: 2,
              dotData: FlDotData(getDotPainter: (a, b, c, d) => FlDotCirclePainter(radius: 3, color: IronMindTheme.orange, strokeColor: IronMindTheme.bg, strokeWidth: 1)),
              belowBarData: BarAreaData(show: true, color: IronMindTheme.orange.withOpacity(0.08)),
            )],
          ))))
        else
          IronCard2(child: Column(children: [
            const EmptyState(icon: '⚖️', title: 'No Weigh-ins Yet', sub: 'Log bodyweight in Wellness → Bodyweight'),
          ])),

        const SizedBox(height: 20),

        // Measurements
        SectionHeader(title: 'Measurements', trailing: IronGhostButton(label: '+ LOG', color: IronMindTheme.accent, onPressed: _showAddMeasurement)),
        const SizedBox(height: 10),
        if (_measurements.isEmpty)
          IronCard2(child: const EmptyState(icon: '📏', title: 'No Measurements Yet', sub: 'Track waist, arms, chest and more'))
        else
          IronCard(padding: EdgeInsets.zero, child: Column(
            children: _measurements.reversed.take(5).toList().asMap().entries.map((e) {
              final m = e.value;
              final isLast = e.key == (_measurements.reversed.take(5).length - 1);
              final parts = <String>[];
              if (m['waist'] != null) parts.add('W: ${m['waist']}"');
              if (m['chest'] != null) parts.add('C: ${m['chest']}"');
              if (m['arms'] != null) parts.add('A: ${m['arms']}"');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border))),
                child: Row(children: [
                  Text(m['date'] ?? '', style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 11)),
                  const Spacer(),
                  Text(parts.join(' · '), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
                ]),
              );
            }).toList(),
          )),
      ]),
    );
  }
}

// ── Settings Tab ──────────────────────────────────────────────────────────────
class _SettingsTab extends StatefulWidget {
  const _SettingsTab();
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}
class _SettingsTabState extends State<_SettingsTab> {
  final _urlCtrl = TextEditingController();
  bool _testing = false;
  String _connStatus = '';
  bool _appleHealthEnabled = false;

  @override
  void initState() { super.initState(); _urlCtrl.text = ApiService.baseUrl; }

  Future<void> _testAndSave() async {
    setState(() { _testing = true; _connStatus = ''; });
    await ApiService.setBaseUrl(_urlCtrl.text.trim());
    final ok = await ApiService.testConnection();
    setState(() {
      _testing = false;
      _connStatus = ok ? 'Connected! All features are now available.' : 'Could not connect. Check the URL and make sure your server is running.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Server URL
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Backend Server'),
          const SizedBox(height: 8),
          Text('Enter your IronMind server address. This connects the app to your workout logs, AI generator, and more.', style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12, height: 1.5)),
          const SizedBox(height: 12),
          TextField(controller: _urlCtrl, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12), decoration: const InputDecoration(labelText: 'Server URL', hintText: 'http://192.168.1.x:3000 or https://your-app.railway.app')),
          const SizedBox(height: 12),
          IronButton(label: 'SAVE & TEST CONNECTION', onPressed: _testAndSave, loading: _testing),
          if (_connStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _connStatus.startsWith('Connected') ? IronMindTheme.greenDim : IronMindTheme.redDim, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                Icon(_connStatus.startsWith('Connected') ? Icons.check_circle_outline : Icons.error_outline,
                    color: _connStatus.startsWith('Connected') ? IronMindTheme.green : IronMindTheme.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_connStatus, style: GoogleFonts.dmSans(color: _connStatus.startsWith('Connected') ? IronMindTheme.green : IronMindTheme.red, fontSize: 12))),
              ]),
            ),
          ],
        ])),
        const SizedBox(height: 14),

        // Apple Health
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Apple Health'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sync with Apple Health', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
              Text('Read steps, sleep, heart rate. Write workouts to Health app.', style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 11, height: 1.4)),
            ])),
            Switch(value: _appleHealthEnabled, onChanged: (v) => setState(() => _appleHealthEnabled = v), activeThumbColor: IronMindTheme.accent),
          ]),
          if (_appleHealthEnabled) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: IronMindTheme.greenDim, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.favorite, color: IronMindTheme.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Apple Health connected. Workouts will be written automatically.', style: GoogleFonts.dmSans(color: IronMindTheme.green, fontSize: 11))),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          IronCard2(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IronLabel('Synced Data'),
            const SizedBox(height: 8),
            _healthItem(Icons.directions_walk, 'Steps', 'Read from Health'),
            _healthItem(Icons.bedtime_outlined, 'Sleep', 'Read from Health'),
            _healthItem(Icons.monitor_heart_outlined, 'Heart Rate', 'Read from Health'),
            _healthItem(Icons.fitness_center, 'Workouts', 'Written to Health'),
            _healthItem(Icons.scale_outlined, 'Bodyweight', 'Read & written'),
          ])),
        ])),
        const SizedBox(height: 14),

        // Other settings
        IronCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: [
          _menuItem(Icons.notifications_outlined, 'Notifications', () {}),
          _menuItem(Icons.lock_outline, 'Privacy', () {}),
          _menuItem(Icons.info_outline, 'About IronMind', () {}),
          _menuItem(Icons.logout, 'Sign Out', () {}, color: IronMindTheme.red, isLast: true),
        ])),
      ]),
    );
  }

  Widget _healthItem(IconData icon, String label, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: IronMindTheme.text2, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12))),
      Text(desc, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
    ]),
  );

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, {Color? color, bool isLast = false}) {
    final c = color ?? IronMindTheme.textPrimary;
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border))),
        child: Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(7)), child: Icon(icon, size: 15, color: color ?? IronMindTheme.text2)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.dmSans(color: c, fontSize: 13, fontWeight: FontWeight.w500))),
          Icon(Icons.chevron_right, size: 16, color: color ?? IronMindTheme.text3),
        ]),
      ),
    );
  }

  @override
  void dispose() { _urlCtrl.dispose(); super.dispose(); }
}
