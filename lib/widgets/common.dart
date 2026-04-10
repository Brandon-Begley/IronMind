import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

// ── IronMind Top Bar (shown on every screen) ──────────────────────────────────
class IronMindAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? subtitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool connected;

  const IronMindAppBar({
    super.key,
    this.subtitle,
    this.actions,
    this.bottom,
    this.connected = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? 48 + bottom!.preferredSize.height : 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: IronMindTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      toolbarHeight: 48,
      title: Row(children: [
        Text('IRON', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 18, letterSpacing: 3)),
        Text('MIND', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 18, letterSpacing: 3)),
        const SizedBox(width: 6),
        Container(width: 5, height: 5, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: connected ? IronMindTheme.green : IronMindTheme.text3,
        )),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: IronMindTheme.border2),
          const SizedBox(width: 8),
          Text(subtitle!.toUpperCase(), style: GoogleFonts.bebasNeue(color: IronMindTheme.text3, fontSize: 14, letterSpacing: 2)),
        ],
      ]),
      actions: actions,
      bottom: bottom,
    );
  }
}

// ── Cards ─────────────────────────────────────────────────────────────────────
class IronCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const IronCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: IronMindTheme.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: IronMindTheme.border),
    ),
    child: child,
  );
}

class IronCard2 extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  const IronCard2({super.key, required this.child, this.padding, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: IronMindTheme.surface2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: borderColor ?? IronMindTheme.border),
    ),
    child: child,
  );
}

// ── Typography ────────────────────────────────────────────────────────────────
class IronLabel extends StatelessWidget {
  final String text;
  const IronLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5));
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 16, letterSpacing: 2)),
      if (trailing != null) trailing!,
    ],
  );
}

// ── Buttons ───────────────────────────────────────────────────────────────────
class IronButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final Color? textColor;
  const IronButton({super.key, required this.label, this.onPressed, this.loading = false, this.color, this.textColor});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 40,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? IronMindTheme.accent,
        foregroundColor: textColor ?? IronMindTheme.bg,
        disabledBackgroundColor: (color ?? IronMindTheme.accent).withOpacity(0.4),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: loading
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: textColor ?? IronMindTheme.bg))
          : Text(label, style: GoogleFonts.bebasNeue(fontSize: 15, letterSpacing: 1.5)),
    ),
  );
}

class IronGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  const IronGhostButton({super.key, required this.label, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? IronMindTheme.text2;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c, side: BorderSide(color: c.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: GoogleFonts.dmMono(fontSize: 10, letterSpacing: 0.5, color: c)),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────
class IronBadge extends StatelessWidget {
  final String text;
  final Color color;
  const IronBadge(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(text, style: GoogleFonts.dmMono(color: color, fontSize: 10)),
  );
}

// ── Progress ──────────────────────────────────────────────────────────────────
class MacroBar extends StatelessWidget {
  final String label;
  final double value, target;
  final Color color;
  const MacroBar({super.key, required this.label, required this.value, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
          Text('${value.toInt()} / ${target.toInt()}g', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
          value: pct, backgroundColor: IronMindTheme.border2,
          valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 4,
        )),
      ]),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final String? sub;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.label, required this.value, this.valueColor, this.sub, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: IronMindTheme.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (valueColor != null)
              Container(height: 2, color: valueColor!.withOpacity(0.7)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 8, letterSpacing: 1)),
                const SizedBox(height: 3),
                Text(value, style: GoogleFonts.bebasNeue(color: valueColor ?? IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 1)),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  Text(sub!, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 8)),
                ],
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Empty State ───────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String icon, title, sub;
  const EmptyState({super.key, required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: IronMindTheme.accentDim,
            shape: BoxShape.circle,
            border: Border.all(color: IronMindTheme.accent.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
        ),
        const SizedBox(height: 12),
        Text(title.toUpperCase(), style: GoogleFonts.bebasNeue(color: IronMindTheme.text2, fontSize: 15, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(sub, style: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 11, height: 1.4), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Muscle Tag ────────────────────────────────────────────────────────────────
class MuscleTag extends StatelessWidget {
  final String label;
  final bool primary;
  const MuscleTag(this.label, {super.key, this.primary = true});

  @override
  Widget build(BuildContext context) {
    final c = primary ? IronMindTheme.accent : IronMindTheme.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(3), border: Border.all(color: c.withOpacity(0.25))),
      child: Text(label, style: GoogleFonts.dmMono(color: c, fontSize: 9)),
    );
  }
}

// ── Dropdown Field ────────────────────────────────────────────────────────────
class IronDropdown extends StatelessWidget {
  final String label, value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  const IronDropdown({super.key, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12, fontWeight: FontWeight.w500)),
    const SizedBox(height: 4),
    DropdownButtonFormField<String>(
      value: items.containsKey(value) ? value : items.keys.first,
      dropdownColor: IronMindTheme.surface2,
      style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true, fillColor: IronMindTheme.surface2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: IronMindTheme.border2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: IronMindTheme.border2)),
      ),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: onChanged,
    ),
  ]);
}

// ── Slider Field ──────────────────────────────────────────────────────────────
class IronSlider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;
  const IronSlider({super.key, required this.label, required this.value, required this.min, required this.max, required this.divisions, required this.format, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12, fontWeight: FontWeight.w500)),
      Text(format(value), style: GoogleFonts.dmMono(color: IronMindTheme.accent, fontSize: 12)),
    ]),
    SliderTheme(
      data: SliderThemeData(
        activeTrackColor: IronMindTheme.accent, inactiveTrackColor: IronMindTheme.border2,
        thumbColor: IronMindTheme.accent, overlayColor: IronMindTheme.accent.withOpacity(0.15),
        trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
      child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
    ),
  ]);
}
