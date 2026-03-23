import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final bool connected;
  const DashboardScreen({super.key, this.connected = false});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _prs = [];
  Map<String, dynamic>? _wellness;
  bool _loading = true;
  int _weekSessions = 0;
  double _weekVolume = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (widget.connected) {
      try {
        final results = await Future.wait([
          ApiService.getLogs(),
          ApiService.getPRs(),
          ApiService.getWellnessToday(),
        ]);
        _logs = results[0] as List<Map<String, dynamic>>;
        _prs = results[1] as List<Map<String, dynamic>>;
        _wellness = results[2] as Map<String, dynamic>?;
        _calcWeek();
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  void _calcWeek() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekLogs = _logs.where((l) {
      try {
        final d = DateTime.parse(l['date'] ?? '');
        return d.isAfter(weekStart.subtract(const Duration(days: 1)));
      } catch (_) { return false; }
    }).toList();
    _weekSessions = weekLogs.length;
    _weekVolume = weekLogs.fold(0, (s, l) {
      final exs = l['exercises'] as List? ?? [];
      return s + exs.fold<double>(0, (ss, e) => ss + ((e['weight'] ?? 0) as num).toDouble() * ((e['sets'] ?? 1) as num).toDouble() * ((e['reps'] ?? 1) as num).toDouble());
    });
  }

  String _formatVol(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!widget.connected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: IronMindTheme.orangeDim, borderRadius: BorderRadius.circular(10), border: Border.all(color: IronMindTheme.orange.withOpacity(0.3))),
                      child: Row(children: [
                        const Icon(Icons.wifi_off, color: IronMindTheme.orange, size: 16),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Backend offline. Go to Profile → Settings to set your server URL.',
                            style: GoogleFonts.dmSans(color: IronMindTheme.orange, fontSize: 11))),
                      ]),
                    ),

                  // This week
                  const SectionHeader(title: 'This Week'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: StatCard(label: 'Sessions', value: '$_weekSessions', valueColor: IronMindTheme.accent)),
                    const SizedBox(width: 8),
                    Expanded(child: StatCard(label: 'Volume', value: _formatVol(_weekVolume), sub: 'lbs lifted', valueColor: IronMindTheme.green)),
                    const SizedBox(width: 8),
                    Expanded(child: StatCard(
                      label: 'Mood',
                      value: _wellness != null ? '${_wellness!['mood']}/10' : '—',
                      valueColor: IronMindTheme.blue,
                      sub: _wellness != null ? 'today' : 'not logged',
                    )),
                  ]),
                  const SizedBox(height: 20),

                  // PR Highlights
                  if (_prs.isNotEmpty) ...[
                    SectionHeader(title: 'Top Records', trailing: IronGhostButton(label: 'View All', color: IronMindTheme.text2, onPressed: () {})),
                    const SizedBox(height: 10),
                    IronCard(padding: EdgeInsets.zero, child: Column(
                      children: _prs.take(4).toList().asMap().entries.map((e) {
                        final pr = e.value;
                        final isLast = e.key == (_prs.take(4).length - 1);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border))),
                          child: Row(children: [
                            Expanded(child: Text(pr['exercise'] ?? '', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 13))),
                            IronBadge('${pr['weight']}lb × ${pr['reps']}', color: IronMindTheme.accent),
                            const SizedBox(width: 6),
                            if (pr['estimated_1rm'] != null) IronBadge('~${pr['estimated_1rm']}lb', color: IronMindTheme.green),
                          ]),
                        );
                      }).toList(),
                    )),
                    const SizedBox(height: 20),
                  ],

                  // Recent workouts
                  SectionHeader(title: 'Recent Workouts', trailing: IronGhostButton(label: 'View All', color: IronMindTheme.text2, onPressed: () {})),
                  const SizedBox(height: 10),
                  if (_logs.isEmpty)
                    const EmptyState(icon: '🏋️', title: 'No Workouts Yet', sub: 'Start logging in the Workout tab')
                  else
                    ..._logs.take(3).map((log) {
                      final exercises = log['exercises'] as List? ?? [];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(log['day_name'] ?? 'Workout',
                                style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 18, letterSpacing: 1))),
                            IronBadge(log['date'] ?? '', color: IronMindTheme.text3),
                          ]),
                          if ((log['focus'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(log['focus'], style: GoogleFonts.dmMono(color: IronMindTheme.accent, fontSize: 10)),
                            ),
                          if (exercises.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(exercises.take(3).map((e) => e['name']).join(' · '),
                                style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ])),
                      );
                    }),
                ]),
              ),
            ),
    );
  }
}
