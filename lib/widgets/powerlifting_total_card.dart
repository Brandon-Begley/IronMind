import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/ironmind_theme.dart';

// ── Milestones ────────────────────────────────────────────────────────────────

class _Milestone {
  final double total;
  final String name;
  final String badge;
  final Color  color;

  const _Milestone({
    required this.total,
    required this.name,
    required this.badge,
    required this.color,
  });
}

const _milestones = [
  _Milestone(total: 300,  name: '300 lb Club',  badge: '🌱', color: Color(0xFF6BCB77)),
  _Milestone(total: 400,  name: '400 lb Club',  badge: '💧', color: Color(0xFF4FC3F7)),
  _Milestone(total: 500,  name: '500 lb Club',  badge: '🥉', color: Color(0xFFCD7F32)),
  _Milestone(total: 600,  name: '600 lb Club',  badge: '⚙️', color: Color(0xFF78909C)),
  _Milestone(total: 700,  name: '700 lb Club',  badge: '🥈', color: Color(0xFF9E9E9E)),
  _Milestone(total: 800,  name: '800 lb Club',  badge: '🔩', color: Color(0xFFB0BEC5)),
  _Milestone(total: 900,  name: '900 lb Club',  badge: '🎯', color: Color(0xFFFFB347)),
  _Milestone(total: 1000, name: '1000 lb Club', badge: '🏆', color: Color(0xFFFFD700)),
  _Milestone(total: 1100, name: '1100 lb Club', badge: '⭐', color: Color(0xFFFFA726)),
  _Milestone(total: 1200, name: '1200 lb Club', badge: '🔥', color: Color(0xFFFF7043)),
  _Milestone(total: 1300, name: '1300 lb Club', badge: '💥', color: Color(0xFFEF5350)),
  _Milestone(total: 1400, name: '1400 lb Club', badge: '🦾', color: Color(0xFFFF6B6B)),
  _Milestone(total: 1500, name: '1500 lb Club', badge: '💪', color: Color(0xFF47B4FF)),
  _Milestone(total: 1600, name: '1600 lb Club', badge: '🌊', color: Color(0xFF29B6F6)),
  _Milestone(total: 1700, name: '1700 lb Club', badge: '⚡', color: Color(0xFF9B8AFB)),
  _Milestone(total: 1800, name: '1800 lb Club', badge: '🌟', color: Color(0xFFCE93D8)),
  _Milestone(total: 2000, name: '2000 lb Club', badge: '👑', color: Color(0xFF47FF8A)),
  _Milestone(total: 2200, name: '2200 lb Club', badge: '🐉', color: Color(0xFF26C6DA)),
  _Milestone(total: 2500, name: '2500 lb Club', badge: '🔱', color: Color(0xFFFF8EC8)),
];

// ── Public card ───────────────────────────────────────────────────────────────

/// Full powerlifting total card.
/// Pass `squat`, `bench`, `deadlift` in lbs (0 if not yet set).
class PowerliftingTotalCard extends StatelessWidget {
  final double squat;
  final double bench;
  final double deadlift;

  const PowerliftingTotalCard({
    super.key,
    required this.squat,
    required this.bench,
    required this.deadlift,
  });

  @override
  Widget build(BuildContext context) {
    final total = squat + bench + deadlift;

    // Find current milestone (last one below or equal to total)
    final achieved = _milestones.where((m) => total >= m.total).toList();
    final next     = _milestones.firstWhere(
      (m) => total < m.total,
      orElse: () => _milestones.last,
    );

    // Progress fraction toward next milestone
    final prevTotal = achieved.isEmpty ? 0.0 : achieved.last.total;
    final frac = next.total > prevTotal
        ? ((total - prevTotal) / (next.total - prevTotal)).clamp(0.0, 1.0)
        : 1.0;
    final lbsAway = (next.total - total).clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Column(
        children: [

          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Text('POWERLIFTING TOTAL',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
              const Spacer(),
              if (achieved.isNotEmpty)
                _ClubBadge(milestone: achieved.last),
            ]),
          ),

          // ── Big total ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  total > 0 ? _fmt(total) : '—',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindTheme.textPrimary,
                    fontSize: 52,
                    letterSpacing: 1,
                    height: 1,
                  ),
                ),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 6),
                    child: Text('lbs',
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text2, fontSize: 14)),
                  ),
              ],
            ),
          ),

          // ── Three lift breakdown ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              _LiftColumn(label: 'SQ', value: squat,    color: IronMindTheme.accent),
              _vDivider(),
              _LiftColumn(label: 'BP', value: bench,    color: IronMindTheme.blue),
              _vDivider(),
              _LiftColumn(label: 'DL', value: deadlift, color: IronMindTheme.orange),
              _vDivider(),
              _LiftColumn(label: 'TOTAL', value: total, color: IronMindTheme.green, large: true),
            ]),
          ),

          const Divider(height: 1, color: IronMindTheme.border),

          // ── Progress to next milestone ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('NEXT: ',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1)),
                  Text(next.name,
                    style: GoogleFonts.dmMono(
                      color: next.color, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const Spacer(),
                  Text(
                    total >= _milestones.last.total
                        ? 'All clubs achieved!'
                        : '${_fmt(lbsAway)} lbs away',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.text2, fontSize: 10)),
                ]),
                const SizedBox(height: 8),

                // Segmented milestone track
                _MilestoneTrack(total: total),
                const SizedBox(height: 8),

                // Simple progress bar (prev milestone → next milestone)
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    backgroundColor: IronMindTheme.surface2,
                    valueColor: AlwaysStoppedAnimation(next.color),
                  ),
                ),
              ],
            ),
          ),

          // ── Achieved clubs ───────────────────────────────────────────────────
          if (achieved.isNotEmpty) ...[
            const Divider(height: 1, color: IronMindTheme.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACHIEVED',
                    style: GoogleFonts.dmMono(
                      color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: achieved.map((m) => _AchievedChip(m)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 36,
    color: IronMindTheme.border,
    margin: const EdgeInsets.symmetric(horizontal: 10),
  );
}

// ── Compact version for dashboard ─────────────────────────────────────────────

/// Smaller single-row version for the Progress/Dashboard screen.
class PowerliftingTotalCompact extends StatelessWidget {
  final double squat;
  final double bench;
  final double deadlift;
  final VoidCallback? onTap;

  const PowerliftingTotalCompact({
    super.key,
    required this.squat,
    required this.bench,
    required this.deadlift,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total    = squat + bench + deadlift;
    final achieved = _milestones.where((m) => total >= m.total).toList();
    final next     = _milestones.firstWhere(
      (m) => total < m.total,
      orElse: () => _milestones.last,
    );
    final lbsAway  = (next.total - total).clamp(0.0, double.infinity);
    final prevTotal = achieved.isEmpty ? 0.0 : achieved.last.total;
    final frac = next.total > prevTotal
        ? ((total - prevTotal) / (next.total - prevTotal)).clamp(0.0, 1.0)
        : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('POWERLIFTING TOTAL',
                style: GoogleFonts.dmMono(
                  color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
              const Spacer(),
              if (achieved.isNotEmpty)
                Text('${achieved.last.badge} ${achieved.last.name}',
                  style: GoogleFonts.dmSans(
                    color: achieved.last.color,
                    fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(total > 0 ? _fmt(total) : '—',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindTheme.textPrimary,
                    fontSize: 30, letterSpacing: 1)),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('lbs',
                      style: GoogleFonts.dmMono(
                        color: IronMindTheme.text2, fontSize: 11))),
                const Spacer(),
                Text(
                  'SQ ${_fmt(squat)}  BP ${_fmt(bench)}  DL ${_fmt(deadlift)}',
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text2, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 5,
                backgroundColor: IronMindTheme.surface2,
                valueColor: AlwaysStoppedAnimation(next.color),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              total >= _milestones.last.total
                  ? 'All clubs achieved! 👑'
                  : '${_fmt(lbsAway)} lbs from ${next.name}',
              style: GoogleFonts.dmSans(
                color: IronMindTheme.text2, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _LiftColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  final bool   large;

  const _LiftColumn({
    required this.label,
    required this.value,
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: large ? 2 : 1,
      child: Column(
        children: [
          Text(
            value > 0 ? _fmt(value) : '—',
            style: GoogleFonts.bebasNeue(
              color: value > 0 ? color : IronMindTheme.text3,
              fontSize: large ? 22 : 18,
              letterSpacing: 0.5),
          ),
          Text(label,
            style: GoogleFonts.dmMono(
              color: IronMindTheme.text3,
              fontSize: 9, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _ClubBadge extends StatelessWidget {
  final _Milestone milestone;
  const _ClubBadge({required this.milestone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: milestone.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: milestone.color.withOpacity(0.4)),
      ),
      child: Text(
        '${milestone.badge}  ${milestone.name}',
        style: GoogleFonts.dmSans(
          color: milestone.color,
          fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AchievedChip extends StatelessWidget {
  final _Milestone milestone;
  const _AchievedChip(this.milestone);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: milestone.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: milestone.color.withOpacity(0.35)),
      ),
      child: Text(
        '${milestone.badge} ${milestone.name}',
        style: GoogleFonts.dmSans(
          color: milestone.color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Dot track showing milestone positions relative to total.
class _MilestoneTrack extends StatelessWidget {
  final double total;
  const _MilestoneTrack({required this.total});

  @override
  Widget build(BuildContext context) {
    // Show milestones from current bracket (prev milestone) to a few ahead
    final visibleStart = _milestones.indexWhere((m) => total < m.total);
    final startIdx = (visibleStart - 1).clamp(0, _milestones.length - 1);
    final endIdx   = (startIdx + 4).clamp(0, _milestones.length - 1);
    final visible  = _milestones.sublist(startIdx, endIdx + 1);

    if (visible.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: visible.map((m) {
        final done = total >= m.total;
        return Column(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: done ? m.color : IronMindTheme.surface2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? m.color : IronMindTheme.border, width: 1.5),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              m.total >= 1000
                  ? '${(m.total / 1000).toStringAsFixed(m.total % 1000 == 0 ? 0 : 1)}k'
                  : '${m.total.toInt()}',
              style: GoogleFonts.dmMono(
                color: done ? m.color : IronMindTheme.text3,
                fontSize: 8),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
