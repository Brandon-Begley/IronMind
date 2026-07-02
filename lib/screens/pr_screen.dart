import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../core/theme/ironmind_theme.dart';
import '../shared/widgets/common.dart';
import '../widgets/powerlifting_total_card.dart';
import '../models/bar_type.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class PRScreen extends StatefulWidget {
  const PRScreen({super.key});

  @override
  State<PRScreen> createState() => _PRScreenState();
}

class _PRScreenState extends State<PRScreen> {
  List<Map<String, dynamic>> _prs        = [];
  Map<String, dynamic>       _rawPRs     = {};   // keyed by exercise.toLowerCase()
  Map<String, dynamic>       _profile    = {};
  List<Map<String, dynamic>> _logs       = [];
  Map<String, dynamic>?      _wellness;
  bool                       _loading    = true;
  late _Readiness             _readiness;

  /// Returns the best recorded weight for a lift, checking PRs first then profile.
  double _liftWeight(List<String> prKeys, List<String> profileKeys) {
    // Check all matching PR keys
    double best = 0;
    for (final k in prKeys) {
      final pr = _rawPRs[k];
      if (pr is Map) {
        final w = (pr['weight'] as num?)?.toDouble() ?? 0;
        if (w > best) best = w;
      }
    }
    // Fallback: profile fields
    if (best == 0) {
      for (final k in profileKeys) {
        final v = (_profile[k] as num?)?.toDouble() ??
            double.tryParse(_profile[k]?.toString() ?? '') ?? 0;
        if (v > best) best = v;
      }
    }
    return best;
  }

  double get _squat    => _liftWeight(['squat', 'back squat', 'low bar squat', 'high bar squat'],
                                      ['squat', 'currentSquat']);
  double get _bench    => _liftWeight(['bench press', 'bench', 'flat bench'],
                                      ['bench', 'currentBench']);
  double get _deadlift => _liftWeight(['deadlift', 'conventional deadlift', 'sumo deadlift'],
                                      ['deadlift', 'currentDeadlift']);
  double get _ohp      => _liftWeight(['overhead press', 'ohp', 'military press', 'shoulder press'],
                                      ['ohp', 'currentOhp']);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPRList(),
        ApiService.getPRs(),
        ApiService.getLogs(),
        ApiService.getWellnessToday(),
        ApiService.getProfile(),
      ]);
      final prs      = results[0] as List<Map<String, dynamic>>;
      final rawPRs   = results[1] as Map<String, dynamic>;
      final logs     = results[2] as List<Map<String, dynamic>>;
      final wellness = results[3] as Map<String, dynamic>?;
      final profile  = results[4] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _prs      = prs;
        _rawPRs   = rawPRs;
        _profile  = profile;
        _logs     = logs;
        _wellness = wellness;
        _readiness = _computeReadiness(logs, wellness);
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: 'PR Tracker',
        connected: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: IronMindTheme.text2,
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            color: IronMindTheme.accent,
            onPressed: _showAddPRSheet,
            tooltip: 'Log a PR',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: IronMindTheme.accent))
          : RefreshIndicator(
              color: IronMindTheme.accent,
              backgroundColor: IronMindTheme.surface2,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  // ── Readiness card ───────────────────────────────────────
                  _ReadinessCard(readiness: _readiness),
                  const SizedBox(height: 16),

                  // ── Powerlifting total ───────────────────────────────────
                  PowerliftingTotalCard(
                    squat:    _squat,
                    bench:    _bench,
                    deadlift: _deadlift,
                  ),
                  const SizedBox(height: 20),

                  // ── Lift achievements ────────────────────────────────────
                  _LiftAchievementsCard(
                    squat:    _squat,
                    bench:    _bench,
                    deadlift: _deadlift,
                    ohp:      _ohp,
                  ),
                  const SizedBox(height: 24),

                  // ── PR list ──────────────────────────────────────────────
                  if (_prs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          children: [
                            Icon(Icons.emoji_events_outlined,
                              size: 44, color: IronMindTheme.text3),
                            const SizedBox(height: 12),
                            Text('No PRs yet.',
                              style: GoogleFonts.dmSans(
                                color: IronMindTheme.text2, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text('PRs are detected automatically when you\ncomplete a set during a workout.',
                              style: GoogleFonts.dmSans(
                                color: IronMindTheme.text3, fontSize: 12),
                              textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    const SectionHeader(title: 'Your Records'),
                    const SizedBox(height: 10),
                    ..._prs.map((pr) => _PRCard(
                      pr:           pr,
                      readiness:    _readiness,
                      onPowerMatrix: () => _showPowerMatrix(pr),
                      onDelete:     () => _confirmDelete(pr),
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _showPowerMatrix(Map<String, dynamic> pr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PowerMatrixSheet(pr: pr, readiness: _readiness),
    );
  }

  void _showAddPRSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: IronMindTheme.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AddPRSheet(onSaved: _load),
    );
  }

  void _confirmDelete(Map<String, dynamic> pr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IronMindTheme.surface2,
        title: Text('Delete PR?',
          style: GoogleFonts.bebasNeue(
            color: IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 1.2)),
        content: Text(
          'Remove the PR for "${pr['exercise']}"? This cannot be undone.',
          style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
              style: GoogleFonts.dmSans(color: IronMindTheme.text2))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.deletePR(pr['exercise'] as String);
              _load();
            },
            child: Text('Delete',
              style: GoogleFonts.dmSans(color: Colors.redAccent,
                fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ── Lift achievements card ────────────────────────────────────────────────────

class _LiftMilestone {
  final String lift;
  final double weight;
  final String badge;
  final Color  color;
  const _LiftMilestone(this.lift, this.weight, this.badge, this.color);
}

const _liftMilestones = <_LiftMilestone>[
  // Squat
  _LiftMilestone('Squat',    135, '🔰', Color(0xFF6BCB77)),
  _LiftMilestone('Squat',    225, '🟢', Color(0xFF47FF8A)),
  _LiftMilestone('Squat',    315, '🔵', Color(0xFF47B4FF)),
  _LiftMilestone('Squat',    405, '🟡', Color(0xFFFFD700)),
  _LiftMilestone('Squat',    495, '🟠', Color(0xFFFFB347)),
  _LiftMilestone('Squat',    585, '🔴', Color(0xFFFF6B6B)),
  _LiftMilestone('Squat',    675, '🟣', Color(0xFF9B8AFB)),
  // Bench
  _LiftMilestone('Bench',     95, '🔰', Color(0xFF6BCB77)),
  _LiftMilestone('Bench',    135, '🟢', Color(0xFF47FF8A)),
  _LiftMilestone('Bench',    185, '🔵', Color(0xFF47B4FF)),
  _LiftMilestone('Bench',    225, '🟡', Color(0xFFFFD700)),
  _LiftMilestone('Bench',    275, '🟠', Color(0xFFFFB347)),
  _LiftMilestone('Bench',    315, '🔴', Color(0xFFFF6B6B)),
  _LiftMilestone('Bench',    365, '🟣', Color(0xFF9B8AFB)),
  _LiftMilestone('Bench',    405, '👑', Color(0xFFFF8EC8)),
  // Deadlift
  _LiftMilestone('Deadlift', 225, '🔰', Color(0xFF6BCB77)),
  _LiftMilestone('Deadlift', 315, '🟢', Color(0xFF47FF8A)),
  _LiftMilestone('Deadlift', 405, '🔵', Color(0xFF47B4FF)),
  _LiftMilestone('Deadlift', 495, '🟡', Color(0xFFFFD700)),
  _LiftMilestone('Deadlift', 585, '🟠', Color(0xFFFFB347)),
  _LiftMilestone('Deadlift', 675, '🔴', Color(0xFFFF6B6B)),
  _LiftMilestone('Deadlift', 750, '🟣', Color(0xFF9B8AFB)),
  _LiftMilestone('Deadlift', 900, '🔱', Color(0xFFFF8EC8)),
  // OHP
  _LiftMilestone('OHP',       95, '🔰', Color(0xFF6BCB77)),
  _LiftMilestone('OHP',      115, '🟢', Color(0xFF47FF8A)),
  _LiftMilestone('OHP',      135, '🔵', Color(0xFF47B4FF)),
  _LiftMilestone('OHP',      185, '🟡', Color(0xFFFFD700)),
  _LiftMilestone('OHP',      225, '🔴', Color(0xFFFF6B6B)),
];

class _LiftAchievementsCard extends StatefulWidget {
  final double squat;
  final double bench;
  final double deadlift;
  final double ohp;

  const _LiftAchievementsCard({
    required this.squat,
    required this.bench,
    required this.deadlift,
    required this.ohp,
  });

  @override
  State<_LiftAchievementsCard> createState() => _LiftAchievementsCardState();
}

class _LiftAchievementsCardState extends State<_LiftAchievementsCard> {
  bool _expanded = false;

  double _valueFor(String lift) {
    switch (lift) {
      case 'Squat':    return widget.squat;
      case 'Bench':    return widget.bench;
      case 'Deadlift': return widget.deadlift;
      case 'OHP':      return widget.ohp;
      default:         return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final achieved = _liftMilestones
        .where((m) => _valueFor(m.lift) >= m.weight)
        .toList();
    final locked = _liftMilestones
        .where((m) => _valueFor(m.lift) < m.weight)
        .toList();

    // Show the next 4 unlockable (one per lift)
    final nextUnlocks = <String, _LiftMilestone>{};
    for (final m in locked) {
      if (!nextUnlocks.containsKey(m.lift)) nextUnlocks[m.lift] = m;
    }

    final display = _expanded ? achieved : achieved.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Text('LIFT ACHIEVEMENTS',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
              const Spacer(),
              Text('${achieved.length} / ${_liftMilestones.length}',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.accent, fontSize: 10,
                  fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 12),

          // Achieved badges
          if (achieved.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'No milestones yet. Log your first PR to start unlocking badges.',
                style: GoogleFonts.dmSans(
                  color: IronMindTheme.text3, fontSize: 12)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: display.map((m) => _AchievementBadge(m)).toList(),
              ),
            ),
            if (achieved.length > 6)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded
                      ? 'Show less'
                      : 'Show all ${achieved.length} badges',
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.accent, fontSize: 12)),
              ),
          ],

          // Next unlocks
          if (nextUnlocks.isNotEmpty) ...[
            const Divider(height: 1, color: IronMindTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text('NEXT UP',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
            ),
            ...nextUnlocks.values.map((m) {
              final current = _valueFor(m.lift);
              final needed  = m.weight - current;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(children: [
                  Text(m.badge, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${m.lift} ${m.weight.toInt()} lb',
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.text2, fontSize: 12,
                        fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    current > 0
                        ? '${needed.toInt()} lbs away'
                        : 'Log a ${m.lift} PR',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 10)),
                ]),
              );
            }),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final _LiftMilestone milestone;
  const _AchievementBadge(this.milestone);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: milestone.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: milestone.color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(milestone.badge, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        Text(
          '${milestone.lift} ${milestone.weight.toInt()}',
          style: GoogleFonts.dmSans(
            color: milestone.color,
            fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

// ── Readiness model ───────────────────────────────────────────────────────────

class _Readiness {
  final double score;        // 0.0 – 1.0
  final int    daysSinceWorkout;
  final double recentVolume;
  final double baselineVolume;
  final bool   hasWellnessData;

  const _Readiness({
    required this.score,
    required this.daysSinceWorkout,
    required this.recentVolume,
    required this.baselineVolume,
    required this.hasWellnessData,
  });

  String get label {
    if (score >= 0.85) return 'Peak Readiness';
    if (score >= 0.65) return 'Building';
    if (score >= 0.40) return 'Moderate Fatigue';
    return 'High Fatigue';
  }

  String get recommendation {
    if (score >= 0.85) return 'Optimal day for a max attempt.';
    if (score >= 0.65) return 'Good training day — hold off on maxing out.';
    if (score >= 0.40) return 'Focus on technique work, not heavy singles.';
    return 'Recovery day recommended. Prioritise sleep and nutrition.';
  }

  String get attemptIn {
    if (score >= 0.85) return 'Today';
    if (score >= 0.65) return '1–2 days';
    if (score >= 0.40) return '2–3 days';
    return '3–5 days';
  }

  Color get color {
    if (score >= 0.85) return IronMindTheme.green;
    if (score >= 0.65) return IronMindTheme.accent;
    if (score >= 0.40) return IronMindTheme.orange;
    return Colors.redAccent;
  }
}

_Readiness _computeReadiness(
  List<Map<String, dynamic>> logs,
  Map<String, dynamic>? wellness,
) {
  final now = DateTime.now();

  double _logVolume(Map<String, dynamic> log) {
    final exs = log['exercises'] as List? ?? [];
    return exs.fold(0.0, (s, e) =>
        s + ((e['weight'] ?? 0) as num).toDouble() *
            ((e['sets']   ?? 1) as num).toDouble() *
            ((e['reps']   ?? 1) as num).toDouble());
  }

  DateTime? _logDate(Map<String, dynamic> log) {
    final raw = log['date'] ?? log['timestamp'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  // Days since last workout
  final sortedDates = logs
      .map(_logDate)
      .whereType<DateTime>()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  final daysSince = sortedDates.isEmpty
      ? 7
      : now.difference(sortedDates.first).inDays.clamp(0, 10);

  // Recent 3-day volume
  final recentVol = logs.fold(0.0, (s, l) {
    final d = _logDate(l);
    if (d == null || now.difference(d).inDays > 3) return s;
    return s + _logVolume(l);
  });

  // 7-day baseline volume (daily avg × 3)
  final weekVol = logs.fold(0.0, (s, l) {
    final d = _logDate(l);
    if (d == null || now.difference(d).inDays > 7) return s;
    return s + _logVolume(l);
  });
  final baseline3d = (weekVol / 7.0) * 3.0;

  // Fatigue ratio (0 = no fatigue, 1 = fully fatigued)
  final fatigue = baseline3d > 0
      ? (recentVol / baseline3d).clamp(0.0, 2.0) / 2.0
      : 0.0;

  // Rest bonus
  final restBonus = (daysSince.clamp(0, 5) / 5.0) * 0.45;

  // Wellness modifier (-0.15 to +0.15)
  double wellnessBonus = 0.0;
  if (wellness != null) {
    final sleep = (wellness['sleep'] as num?)?.toDouble() ?? 5.0;
    final mood  = (wellness['mood']  as num?)?.toDouble() ?? 5.0;
    wellnessBonus = ((sleep + mood) / 2.0 - 5.0) / 33.0;
  }

  // Cap if trained very recently and hard
  double score = (0.45 + restBonus - fatigue * 0.65 + wellnessBonus).clamp(0.0, 1.0);
  if (daysSince == 0 && recentVol > 0) score = score.clamp(0.0, 0.60);

  return _Readiness(
    score:             score,
    daysSinceWorkout:  daysSince,
    recentVolume:      recentVol,
    baselineVolume:    baseline3d,
    hasWellnessData:   wellness != null,
  );
}

// ── Readiness card ────────────────────────────────────────────────────────────

class _ReadinessCard extends StatelessWidget {
  final _Readiness readiness;
  const _ReadinessCard({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final r = readiness;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: r.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r.color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('PR READINESS',
              style: GoogleFonts.dmMono(
                color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: r.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: r.color.withOpacity(0.4)),
              ),
              child: Text(r.label,
                style: GoogleFonts.dmSans(
                  color: r.color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 14),

          // Score gauge
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _CircleGauge(score: r.score, color: r.color),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.recommendation,
                    style: GoogleFonts.dmSans(
                      color: IronMindTheme.textPrimary,
                      fontSize: 12, height: 1.45)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined,
                      size: 12, color: IronMindTheme.text3),
                    const SizedBox(width: 4),
                    Text('Attempt window: ',
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text3, fontSize: 10)),
                    Text(r.attemptIn,
                      style: GoogleFonts.dmMono(
                        color: r.color, fontSize: 10,
                        fontWeight: FontWeight.w700)),
                  ]),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Factor chips
          Row(children: [
            _FactorChip(
              label: 'Days rest',
              value: '${r.daysSinceWorkout}d',
              color: r.daysSinceWorkout >= 2
                  ? IronMindTheme.green : IronMindTheme.orange,
            ),
            const SizedBox(width: 8),
            _FactorChip(
              label: 'Recent vol',
              value: r.recentVolume >= 1000
                  ? '${(r.recentVolume / 1000).toStringAsFixed(1)}k'
                  : '${r.recentVolume.toInt()}',
              color: IronMindTheme.blue,
            ),
            const SizedBox(width: 8),
            _FactorChip(
              label: 'Wellness',
              value: r.hasWellnessData ? 'Logged' : 'No data',
              color: r.hasWellnessData
                  ? IronMindTheme.accent : IronMindTheme.text3,
            ),
          ]),
        ],
      ),
    );
  }
}

class _CircleGauge extends StatelessWidget {
  final double score;
  final Color color;
  const _CircleGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70, height: 70,
      child: CustomPaint(
        painter: _GaugePainter(score: score, color: color),
        child: Center(
          child: Text(
            '${(score * 100).round()}%',
            style: GoogleFonts.bebasNeue(
              color: color, fontSize: 20, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;
  const _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.width - 8) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(rect, -math.pi * 0.8, math.pi * 1.6, false,
      Paint()
        ..color = IronMindTheme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round);

    // Fill
    canvas.drawArc(rect, -math.pi * 0.8, math.pi * 1.6 * score.clamp(0, 1), false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score || old.color != color;
}

class _FactorChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FactorChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Column(
          children: [
            Text(value,
              style: GoogleFonts.bebasNeue(
                color: color, fontSize: 15, letterSpacing: 0.5)),
            Text(label,
              style: GoogleFonts.dmMono(
                color: IronMindTheme.text3, fontSize: 8, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ── PR card ───────────────────────────────────────────────────────────────────

class _PRCard extends StatelessWidget {
  final Map<String, dynamic>  pr;
  final _Readiness             readiness;
  final VoidCallback           onPowerMatrix;
  final VoidCallback           onDelete;

  const _PRCard({
    required this.pr,
    required this.readiness,
    required this.onPowerMatrix,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final exercise   = pr['exercise'] as String? ?? '';
    final weight     = (pr['weight']  as num?)?.toDouble() ?? 0;
    final reps       = (pr['reps']    as num?)?.toInt()    ?? 0;
    final est1rm     = (pr['estimated_1rm'] as num?)?.toInt()
                    ?? (pr['estimated1rm']  as num?)?.toInt();
    final dateStr    = pr['date']?.toString().split('T').first ?? '';

    return GestureDetector(
      onTap: onPowerMatrix,
      child: IronCard(
        child: Row(children: [
          // Lift icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: IronMindTheme.accent.withOpacity(0.12),
              shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_outlined,
              color: IronMindTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Row(children: [
                  IronBadge(
                    '${_fmt(weight)} lbs × $reps',
                    color: IronMindTheme.accent),
                  if (est1rm != null) ...[
                    const SizedBox(width: 6),
                    IronBadge('~$est1rm lb 1RM', color: IronMindTheme.green),
                  ],
                ]),
                if (dateStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(dateStr,
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text3, fontSize: 9)),
                  ),
              ],
            ),
          ),

          // Actions
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Matrix',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.blue, fontSize: 9, letterSpacing: 0.5)),
              const Icon(Icons.chevron_right,
                color: IronMindTheme.text3, size: 18),
            ],
          ),

          // Delete
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.delete_outline,
                color: IronMindTheme.text3, size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Power Matrix sheet ────────────────────────────────────────────────────────

class _PowerMatrixSheet extends StatefulWidget {
  final Map<String, dynamic> pr;
  final _Readiness readiness;

  const _PowerMatrixSheet({required this.pr, required this.readiness});

  @override
  State<_PowerMatrixSheet> createState() => _PowerMatrixSheetState();
}

class _PowerMatrixSheetState extends State<_PowerMatrixSheet> {
  BarType? _selectedBar;

  double get _barWeight => _selectedBar != null ? barSpecFor(_selectedBar!).weightLb : 45.0;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.pr['exercise'] as String? ?? '';
    final weight   = (widget.pr['weight'] as num?)?.toDouble() ?? 0;
    final reps     = (widget.pr['reps']   as num?)?.toInt()    ?? 0;
    final est1rm   = (widget.pr['estimated_1rm'] as num?)?.toDouble()
                  ?? (widget.pr['estimated1rm']  as num?)?.toDouble()
                  ?? ApiService.calculate1RM(weight, reps);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: IronMindTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: IronMindTheme.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Header
                Text('POWER MATRIX',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                Text(exercise,
                  style: GoogleFonts.bebasNeue(
                    color: IronMindTheme.textPrimary,
                    fontSize: 26, letterSpacing: 2)),
                const SizedBox(height: 4),
                Row(children: [
                  IronBadge('PR: ${_fmt(weight)} lbs × $reps', color: IronMindTheme.accent),
                  const SizedBox(width: 8),
                  IronBadge('~${est1rm.round()} lb 1RM', color: IronMindTheme.green),
                ]),
                const SizedBox(height: 16),

                // Bar selector
                _BarSelector(
                  selected: _selectedBar,
                  onChanged: (t) => setState(() => _selectedBar = t),
                ),
                const SizedBox(height: 16),

                // Readiness context
                _MatrixReadinessRow(readiness: widget.readiness),
                const SizedBox(height: 20),

                // Column headers
                _MatrixHeader(showPlates: _selectedBar != null),
                const SizedBox(height: 4),
                const Divider(height: 1, color: IronMindTheme.border),
                const SizedBox(height: 4),

                // Matrix rows
                ..._matrixRows.map((row) => _MatrixRow(
                  pct:        row.pct,
                  weight:     _roundToPlate(est1rm * row.pct),
                  barWeight:  _barWeight,
                  reps:       row.reps,
                  zone:       row.zone,
                  isPR:       row.isPRZone,
                  isReady:    widget.readiness.score >= 0.85,
                  showPlates: _selectedBar != null,
                )),

                const SizedBox(height: 20),
                _ZoneLegend(),
                const SizedBox(height: 20),

                // RPE reference table
                _RpeChart(est1rm: est1rm),
                const SizedBox(height: 16),

                _PercentageExplainer(),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Matrix data ───────────────────────────────────────────────────────────────

class _MatrixRowData {
  final double pct;
  final String reps;
  final String zone;
  final bool   isPRZone;
  const _MatrixRowData(this.pct, this.reps, this.zone, {this.isPRZone = false});
}

const _matrixRows = [
  _MatrixRowData(0.50,  '10+',  'Warm-up / Speed'),
  _MatrixRowData(0.575, '10',   'Warm-up / Speed'),
  _MatrixRowData(0.60,  '8-10', 'Hypertrophy'),
  _MatrixRowData(0.65,  '8',    'Hypertrophy'),
  _MatrixRowData(0.70,  '6-8',  'Hypertrophy'),
  _MatrixRowData(0.75,  '5-6',  'Strength-Size'),
  _MatrixRowData(0.80,  '4-5',  'Strength-Size'),
  _MatrixRowData(0.85,  '3-4',  'Strength'),
  _MatrixRowData(0.875, '2-3',  'Strength'),
  _MatrixRowData(0.90,  '2-3',  'Strength'),
  _MatrixRowData(0.925, '1-2',  'Near Max'),
  _MatrixRowData(0.95,  '1-2',  'Near Max'),
  _MatrixRowData(0.975, '1',    'PR Prep',    isPRZone: true),
  _MatrixRowData(1.00,  '—',    'Current PR', isPRZone: true),
  _MatrixRowData(1.025, '1',    'PR Target',  isPRZone: true),
  _MatrixRowData(1.05,  '1',    'Stretch',    isPRZone: true),
];

// ── Matrix sub-widgets ────────────────────────────────────────────────────────

class _MatrixReadinessRow extends StatelessWidget {
  final _Readiness readiness;
  const _MatrixReadinessRow({required this.readiness});

  @override
  Widget build(BuildContext context) {
    final r = readiness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: r.color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(
          r.score >= 0.85 ? Icons.check_circle_outline
              : r.score >= 0.65 ? Icons.access_time
              : Icons.warning_amber_rounded,
          color: r.color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.dmSans(
                color: IronMindTheme.text2, fontSize: 12),
              children: [
                TextSpan(text: '${r.label} — '),
                TextSpan(
                  text: r.score >= 0.85
                      ? 'PR rows highlighted. Go get it.'
                      : 'PR attempt suggested in ${r.attemptIn}.',
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  final bool showPlates;
  const _MatrixHeader({this.showPlates = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _col('% 1RM', flex: 2, align: TextAlign.left),
      _col(showPlates ? 'TOTAL / PLATES' : 'WEIGHT', flex: 3, align: TextAlign.center),
      _col('Reps', flex: 2, align: TextAlign.center),
      _col('Zone', flex: 4, align: TextAlign.right),
    ]);
  }

  Widget _col(String t, {int flex = 1, TextAlign align = TextAlign.left}) =>
      Expanded(
        flex: flex,
        child: Text(t,
          textAlign: align,
          style: GoogleFonts.dmMono(
            color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
      );
}

class _MatrixRow extends StatelessWidget {
  final double pct;
  final double weight;
  final double barWeight;
  final String reps;
  final String zone;
  final bool   isPR;
  final bool   isReady;
  final bool   showPlates;

  const _MatrixRow({
    required this.pct,       required this.weight,
    required this.barWeight, required this.reps,
    required this.zone,      required this.isPR,
    required this.isReady,   this.showPlates = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color zoneColor;
    if (isPR && pct > 1.0) {
      zoneColor = isReady ? IronMindTheme.green : IronMindTheme.text3;
    } else if (isPR) {
      zoneColor = IronMindTheme.accent;
    } else {
      zoneColor = IronMindTheme.text3;
    }

    final isHighlighted = isPR && isReady;
    final bg = isHighlighted
        ? IronMindTheme.green.withValues(alpha: 0.08)
        : isPR ? IronMindTheme.accent.withValues(alpha: 0.05) : Colors.transparent;

    final platesWeight = (weight - barWeight).clamp(0.0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: isHighlighted
            ? Border.all(color: IronMindTheme.green.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text('${_pctLabel(pct)}%',
            style: GoogleFonts.dmMono(
              color: isPR ? IronMindTheme.accent : IronMindTheme.text2,
              fontSize: 12,
              fontWeight: isPR ? FontWeight.w700 : FontWeight.normal)),
        ),
        Expanded(
          flex: 3,
          child: pct == 1.0
              ? Text('Your PR',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.textPrimary, fontSize: 12,
                    fontWeight: FontWeight.w600))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_fmt(weight)} lb',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.textPrimary, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                    if (showPlates)
                      Text('${_fmt(platesWeight)} plates',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.text3, fontSize: 9)),
                  ],
                ),
        ),
        Expanded(
          flex: 2,
          child: Text(reps,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text2, fontSize: 11)),
        ),
        Expanded(
          flex: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isHighlighted)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: const Icon(Icons.bolt,
                    color: IronMindTheme.green, size: 12)),
              Flexible(
                child: Text(zone,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmMono(
                    color: zoneColor, fontSize: 9, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Bar Selector ──────────────────────────────────────────────────────────────

class _BarSelector extends StatelessWidget {
  final BarType? selected;
  final ValueChanged<BarType?> onChanged;
  const _BarSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BAR TYPE',
          style: GoogleFonts.dmMono(
            color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _BarChip(
                label: 'Stiff Bar',
                sublabel: '45 lb',
                isSelected: selected == null,
                onTap: () => onChanged(null),
              ),
              ...BarType.values.map((t) {
                final spec = barSpecFor(t);
                return _BarChip(
                  label: spec.shortName,
                  sublabel: '${spec.weightLb.toInt()} lb',
                  isSelected: selected == t,
                  onTap: () => onChanged(t),
                );
              }),
            ],
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: IronMindTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: IronMindTheme.border2),
            ),
            child: Text(
              barSpecFor(selected!).benefit,
              style: GoogleFonts.dmSans(
                color: IronMindTheme.text2, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}

class _BarChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;
  const _BarChip({
    required this.label, required this.sublabel,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? IronMindTheme.accent.withValues(alpha: 0.12)
              : IronMindTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? IronMindTheme.accent
                : IronMindTheme.border2,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(label,
              style: GoogleFonts.dmSans(
                color: isSelected
                    ? IronMindTheme.accent
                    : IronMindTheme.text2,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
            Text(sublabel,
              style: GoogleFonts.dmMono(
                color: IronMindTheme.text3, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── RPE Reference Chart ───────────────────────────────────────────────────────

class _RpeChart extends StatelessWidget {
  final double est1rm;
  const _RpeChart({required this.est1rm});

  // Tuchscherer RPE chart: [reps][rpe index 6..10] → % of 1RM
  static const _rpeData = <int, List<double>>{
    1:  [0.893, 0.917, 0.940, 0.960, 1.000],
    2:  [0.863, 0.887, 0.910, 0.930, 0.970],
    3:  [0.833, 0.857, 0.880, 0.900, 0.940],
    4:  [0.803, 0.827, 0.850, 0.870, 0.910],
    5:  [0.773, 0.797, 0.820, 0.840, 0.880],
    6:  [0.743, 0.767, 0.790, 0.810, 0.850],
    8:  [0.693, 0.717, 0.740, 0.760, 0.800],
    10: [0.643, 0.667, 0.690, 0.710, 0.750],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RPE → LOAD REFERENCE',
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(
            'Find your target reps × RPE to get the corresponding % and load.',
            style: GoogleFonts.dmSans(
              color: IronMindTheme.text3, fontSize: 10, height: 1.4)),
          const SizedBox(height: 12),
          // Header row
          Row(children: [
            SizedBox(width: 36,
              child: Text('REPS', style: GoogleFonts.dmMono(
                color: IronMindTheme.text3, fontSize: 8, letterSpacing: 0.8))),
            ...['RPE 6','RPE 7','RPE 8','RPE 9','RPE 10'].map((h) =>
              Expanded(child: Text(h, textAlign: TextAlign.center,
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.text3, fontSize: 7, letterSpacing: 0.5)))),
          ]),
          const SizedBox(height: 4),
          const Divider(height: 1, color: IronMindTheme.border),
          const SizedBox(height: 4),
          ..._rpeData.entries.map((e) => _RpeRow(
            reps: e.key,
            pcts: e.value,
            est1rm: est1rm,
          )),
        ],
      ),
    );
  }
}

class _RpeRow extends StatelessWidget {
  final int reps;
  final List<double> pcts;
  final double est1rm;
  const _RpeRow({required this.reps, required this.pcts, required this.est1rm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text('$reps',
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text2, fontSize: 11,
              fontWeight: FontWeight.w600)),
        ),
        ...pcts.map((pct) {
          final load = _roundToPlate(est1rm * pct);
          return Expanded(
            child: Column(
              children: [
                Text('${(pct * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.accent, fontSize: 9)),
                Text('${load.toInt()}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.textPrimary, fontSize: 10,
                    fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }),
      ]),
    );
  }
}

class _ZoneLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TRAINING ZONES',
          style: GoogleFonts.dmMono(
            color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _legend('50–65%',   'Speed / Technique — bar speed focus',     IronMindTheme.blue),
        _legend('65–80%',   'Hypertrophy — higher reps, build mass',    IronMindTheme.green),
        _legend('80–92%',   'Strength — heavy triples and doubles',     IronMindTheme.accent),
        _legend('92–100%',  'Near Max — singles and heavy prep',        IronMindTheme.orange),
        _legend('100%+',    'PR Zone — max attempts only when ready',   IronMindTheme.green),
      ],
    );
  }

  Widget _legend(String range, String desc, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          child: Text(range,
            style: GoogleFonts.dmMono(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Text(desc,
            style: GoogleFonts.dmSans(
              color: IronMindTheme.text2, fontSize: 11)),
        ),
      ],
    ),
  );
}

class _PercentageExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOW READINESS IS CALCULATED',
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            'Score is based on three factors: '
            '(1) Days of rest since your last session — more rest = higher readiness. '
            '(2) Recent training volume vs. your 7-day average — high recent volume = more fatigue. '
            '(3) Today\'s wellness check-in (sleep and mood) if logged.',
            style: GoogleFonts.dmSans(
              color: IronMindTheme.text2, fontSize: 11, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Add PR sheet ──────────────────────────────────────────────────────────────

class _AddPRSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddPRSheet({required this.onSaved});

  @override
  State<_AddPRSheet> createState() => _AddPRSheetState();
}

class _AddPRSheetState extends State<_AddPRSheet> {
  final _exCtrl  = TextEditingController();
  final _wtCtrl  = TextEditingController();
  final _repCtrl = TextEditingController();
  bool _saving   = false;
  String? _error;

  @override
  void dispose() {
    _exCtrl.dispose(); _wtCtrl.dispose(); _repCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ex  = _exCtrl.text.trim();
    final wt  = double.tryParse(_wtCtrl.text.trim());
    final rep = int.tryParse(_repCtrl.text.trim());
    if (ex.isEmpty || wt == null || rep == null || wt <= 0 || rep <= 0) {
      setState(() => _error = 'Fill in all fields with valid numbers.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.savePR({
        'exercise': ex, 'weight': wt, 'reps': rep,
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log a PR',
            style: GoogleFonts.bebasNeue(
              color: IronMindTheme.textPrimary, fontSize: 24, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _field(_exCtrl,  'Exercise', TextInputType.text),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_wtCtrl,  'Weight (lbs)', TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _field(_repCtrl, 'Reps', TextInputType.number)),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: GoogleFonts.dmSans(
              color: Colors.redAccent, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2))
                  : Text('Save PR',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, TextInputType kb) =>
      TextField(
        controller: ctrl,
        keyboardType: kb,
        style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: IronMindTheme.border2)),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: IronMindTheme.accent)),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Round to nearest 2.5 lb (standard plate increment).
double _roundToPlate(double w) => (w / 2.5).round() * 2.5;

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Clean percentage label — e.g. 87.5%, 100%, 102.5%.
String _pctLabel(double pct) {
  final v = pct * 100;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
