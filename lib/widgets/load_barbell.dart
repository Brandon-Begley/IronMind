import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/ironmind_theme.dart';

class LoadBarbell extends StatelessWidget {
  final double totalWeight;
  final double barWeight;
  final Color color;

  const LoadBarbell({
    super.key,
    required this.totalWeight,
    required this.barWeight,
    this.color = IronMindTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    final plates = platesPerSide(totalWeight, barWeight);
    final left = plates.reversed.toList();

    return SizedBox(
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: IronMindTheme.text3,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Container(
            width: 72,
            height: 14,
            decoration: BoxDecoration(
              color: IronMindTheme.text2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: IronMindTheme.textPrimary.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: _PlateStack(plates: left, color: color, alignRight: true),
          ),
          Positioned(
            right: 0,
            child: _PlateStack(plates: plates, color: color, alignRight: false),
          ),
        ],
      ),
    );
  }

  static List<double> platesPerSide(double totalWeight, double barWeight) {
    var remaining = ((totalWeight - barWeight).clamp(0, 1000)) / 2.0;
    const available = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5];
    final plates = <double>[];
    for (final plate in available) {
      while (remaining + 0.01 >= plate) {
        plates.add(plate);
        remaining -= plate;
      }
    }
    return plates.take(8).toList();
  }

  static String plateBreakdown(double totalWeight, double barWeight) {
    final plates = platesPerSide(totalWeight, barWeight);
    if (totalWeight < barWeight) return 'Under bar weight';
    if (plates.isEmpty) return 'Bar only';

    final counts = <double, int>{};
    for (final plate in plates) {
      counts[plate] = (counts[plate] ?? 0) + 1;
    }

    return counts.entries
        .map((entry) => '${entry.value} x ${_formatPlate(entry.key)}')
        .join('  +  ');
  }

  static String _formatPlate(double plate) {
    return plate == plate.truncateToDouble()
        ? plate.toInt().toString()
        : plate.toStringAsFixed(1);
  }
}

class LoadPlateAdjuster extends StatelessWidget {
  final ValueChanged<double> onChanged;

  const LoadPlateAdjuster({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const jumps = [-45.0, -25.0, -10.0, -5.0, 5.0, 10.0, 25.0, 45.0];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: jumps.map((jump) {
        final label =
            '${jump > 0 ? '+' : ''}${jump == jump.truncateToDouble() ? jump.toInt() : jump}';
        return OutlinedButton(
          onPressed: () => onChanged(jump),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(54, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.dmMono(
              color: IronMindTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PlateStack extends StatelessWidget {
  final List<double> plates;
  final Color color;
  final bool alignRight;

  const _PlateStack({
    required this.plates,
    required this.color,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    if (plates.isEmpty) {
      return Container(
        width: 38,
        height: 28,
        alignment: Alignment.center,
        child: Container(
          width: 8,
          height: 28,
          decoration: BoxDecoration(
            color: IronMindTheme.text3,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    final children = plates.map((plate) {
      final height = 38.0 + plate;
      final width = plate >= 25 ? 14.0 : 10.0;
      return Container(
        width: width,
        height: height.clamp(44.0, 86.0),
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: _plateColor(plate),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            plate == 2.5 ? '2.5' : plate.toInt().toString(),
            style: GoogleFonts.dmMono(
              color: Colors.black.withValues(alpha: 0.68),
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }).toList();

    return SizedBox(
      width: 118,
      child: Row(
        mainAxisAlignment: alignRight
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Color _plateColor(double plate) {
    if (plate >= 45) return color;
    if (plate >= 35) return IronMindTheme.orange;
    if (plate >= 25) return IronMindTheme.green;
    if (plate >= 10) return IronMindTheme.accent;
    return IronMindTheme.text2;
  }
}
