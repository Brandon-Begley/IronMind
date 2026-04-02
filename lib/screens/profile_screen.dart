import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function() onSignOut;
  final Future<void> Function() onRedoOnboarding;

  const ProfileScreen({
    super.key,
    required this.onSignOut,
    required this.onRedoOnboarding,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _goals = {};
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final profile = await ApiService.getProfile();
    final goals = await ApiService.getStrengthGoals();
    final logs = await ApiService.getLogs();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _goals = goals;
      _logs = logs;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: IronMindColors.accent,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildInfoTab(), _buildSettingsTab()],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'IRON',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.accent,
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
                TextSpan(
                  text: 'MIND',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
                TextSpan(
                  text: '  PROFILE',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textSecondary,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1.5),
          labelColor: IronMindColors.background,
          unselectedLabelColor: IronMindColors.textSecondary,
          padding: const EdgeInsets.all(4),
          tabs: const [Tab(text: 'INFO'), Tab(text: 'SETTINGS')],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    final name = (_profile['name'] ?? '—').toString();
    final goal = _formatGoal(
      (_profile['goal'] ?? _profile['trainingGoal'] ?? '—').toString(),
    );
    final style = _formatStyle((_profile['style'] ?? '—').toString());
    final level = _formatExperience(
      (_profile['experience'] ?? _profile['experienceLevel'] ?? '—')
          .toString(),
    );
    final gender = (_profile['gender'] ?? '—').toString();
    final weakPoint = _formatWeakPoint(
      (_profile['weakpoint'] ?? 'balanced').toString(),
    );
    final age = _profileAgeLabel();
    final height = _profileHeightLabel();
    final bodyweight = _displayWeight(_profile['bodyweight'] ?? _profile['weight']);
    final targetWeight = _displayWeight(_profile['goalWeight']);
    final trainingDays = _profile['trainingDays'];
    final sessionLength = _profile['sessionLength'];

    final monthSessions = _logs.where((log) {
      final date = DateTime.tryParse(log['date']?.toString() ?? '');
      if (date == null) return false;
      return date.isAfter(DateTime.now().subtract(const Duration(days: 30)));
    }).length;
    final totalSets = _logs.fold<int>(0, (sum, log) {
      final exercises = log['exercises'] as List? ?? [];
      return sum +
          exercises.fold<int>(0, (exerciseSum, exercise) {
            return exerciseSum + ((exercise['sets'] ?? 0) as num).toInt();
          });
    });
    final totalExercises = _logs.fold<int>(0, (sum, log) {
      final exercises = log['exercises'] as List? ?? [];
      return sum + exercises.length;
    });
    final totalVolume = _logs.fold<double>(0, (sum, log) {
      final exercises = log['exercises'] as List? ?? [];
      return sum +
          exercises.fold<double>(0, (exerciseSum, exercise) {
            return exerciseSum +
                ((exercise['weight'] ?? 0) as num).toDouble() *
                    ((exercise['sets'] ?? 1) as num).toDouble() *
                    ((exercise['reps'] ?? 1) as num).toDouble();
          });
    });
    final avgVolume = _logs.isEmpty ? 0.0 : totalVolume / _logs.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroCard(
          name: name,
          goal: goal,
          style: style,
          currentWeight: bodyweight,
          targetWeight: targetWeight,
          sessionLength: sessionLength == null
              ? '—'
              : '${(sessionLength as num).round()} min',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Experience',
                value: level,
                valueColor: IronMindColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Days / Week',
                value: trainingDays == null
                    ? '—'
                    : '${(trainingDays as num).round()}',
                sub: weakPoint,
                valueColor: IronMindColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Age',
                value: age,
                sub: gender,
                valueColor: IronMindColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Height',
                value: height,
                sub: 'body stats',
                valueColor: IronMindColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: 'Avg Volume',
                value: _formatVolume(avgVolume),
                sub: 'per session',
                valueColor: IronMindColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                label: '30 Days',
                value: '$monthSessions',
                sub: 'sessions',
                valueColor: IronMindColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _LiftSummaryCard(
          squat: _liftStr(_profile['squat'] ?? _profile['currentSquat']),
          bench: _liftStr(_profile['bench'] ?? _profile['currentBench']),
          deadlift: _liftStr(_profile['deadlift'] ?? _profile['currentDeadlift']),
          ohp: _liftStr(_profile['ohp'] ?? _profile['currentOhp']),
        ),
        const SizedBox(height: 12),
        IronCard(
          child: Row(
            children: [
              Expanded(
                child: _FooterMetric(
                  label: 'Lifetime Sessions',
                  value: '${_logs.length}',
                  sub: _logs.isEmpty ? 'No workouts logged yet' : 'all sessions',
                  color: IronMindColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FooterMetric(
                  label: 'Total Sets',
                  value: '$totalSets',
                  sub: '$totalExercises exercises',
                  color: IronMindColors.accent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsRow(
          icon: Icons.person_outline,
          label: 'Edit Profile',
          onTap: _editProfile,
        ),
        _SettingsRow(
          icon: Icons.flag_outlined,
          label: 'Edit Strength Goals',
          onTap: _editGoalsSheet,
        ),
        _SettingsRow(
          icon: Icons.favorite_outline,
          label: 'Body Metrics Live In Wellness',
          onTap: _goToWellnessMessage,
        ),
        _SettingsRow(
          icon: Icons.health_and_safety_outlined,
          label: 'Connect Apple Health',
          onTap: _connectAppleHealth,
        ),
        const SizedBox(height: 20),
        const Divider(color: IronMindColors.border),
        const SizedBox(height: 12),
        _SettingsRow(
          icon: Icons.restart_alt,
          label: 'Redo Onboarding',
          onTap: _redoOnboarding,
          color: IronMindColors.warning,
        ),
        _SettingsRow(
          icon: Icons.logout,
          label: 'Sign Out',
          onTap: _signOut,
          color: IronMindColors.alert,
        ),
      ],
    );
  }

  String _displayWeight(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return '—';
    return '${parsed.toStringAsFixed(0)} lbs';
  }

  String _liftStr(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return '—';
    return '${parsed.toStringAsFixed(0)} lbs';
  }

  String _formatVolume(double value) {
    if (value <= 0) return '0 lbs';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k lbs';
    return '${value.toStringAsFixed(0)} lbs';
  }

  String _profileAgeLabel() {
    final birthDate = DateTime.tryParse(_profile['birthDate']?.toString() ?? '');
    if (birthDate != null) {
      final now = DateTime.now();
      var age = now.year - birthDate.year;
      final hadBirthday =
          now.month > birthDate.month ||
          (now.month == birthDate.month && now.day >= birthDate.day);
      if (!hadBirthday) age -= 1;
      return '$age';
    }
    final age = _profile['age'];
    if (age == null || '$age'.isEmpty) return '—';
    return '$age';
  }

  String _profileHeightLabel() {
    final feet = int.tryParse(_profile['heightFeet']?.toString() ?? '');
    final inches = int.tryParse(_profile['heightInches']?.toString() ?? '');
    if (feet != null) return "$feet'${inches ?? 0}\"";
    final total = int.tryParse(_profile['height']?.toString() ?? '');
    if (total == null || total <= 0) return '—';
    return "${total ~/ 12}'${total % 12}\"";
  }

  String _formatExperience(String value) {
    switch (value.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      case 'elite':
        return 'Elite';
      default:
        return value == '—' ? '—' : _titleize(value);
    }
  }

  String _formatGoal(String value) {
    switch (value.toLowerCase()) {
      case 'peak-strength':
      case 'peak strength':
        return 'Peak Strength';
      case 'hypertrophy':
      case 'build muscle':
        return 'Build Muscle';
      case 'lose-fat':
      case 'lose fat':
      case 'cut body fat':
        return 'Cut Body Fat';
      case 'fitness':
      case 'general fitness':
        return 'General Fitness';
      default:
        return value == '—' ? '—' : _titleize(value);
    }
  }

  String _formatStyle(String value) {
    switch (value.toLowerCase()) {
      case 'powerlifting':
        return 'Powerlifting';
      case 'powerbuilding':
        return 'Powerbuilding';
      case 'strength':
      case 'general strength':
        return 'General Strength';
      case 'hypertrophy':
        return 'Hypertrophy';
      case 'bodybuilding':
        return 'Bodybuilding';
      default:
        return value == '—' ? '—' : _titleize(value);
    }
  }

  String _formatWeakPoint(String value) {
    switch (value.toLowerCase()) {
      case 'none':
      case 'balanced':
      case 'none / balanced':
        return 'Balanced';
      case 'squat-depth':
        return 'Squat Depth';
      case 'squat-lockout':
        return 'Squat Lockout';
      case 'bench-bottom':
        return 'Bench Off Chest';
      case 'bench-lockout':
        return 'Bench Lockout';
      case 'deadlift-floor':
        return 'Deadlift Off Floor';
      case 'deadlift-lockout':
        return 'Deadlift Lockout';
      default:
        return value == '—' ? '—' : _titleize(value);
    }
  }

  String _titleize(String value) {
    return value
        .replaceAll('-', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  void _editGoalsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: IronMindColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _EditGoalsInline(
            goals: _goals,
            onSaved: (updated) async {
              await ApiService.saveStrengthGoals(updated);
              await _load();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _editProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Use Redo Onboarding to update your profile setup.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: IronMindColors.surfaceElevated,
      ),
    );
  }

  void _goToWellnessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Bodyweight and measurements now live in Wellness.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: IronMindColors.surfaceElevated,
      ),
    );
  }

  void _redoOnboarding() async {
    await widget.onRedoOnboarding();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Onboarding is ready for this account.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: IronMindColors.surfaceElevated,
      ),
    );
  }

  void _connectAppleHealth() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Apple Health integration is a planned next step.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: IronMindColors.surfaceElevated,
      ),
    );
  }

  void _signOut() async {
    await widget.onSignOut();
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = IronMindColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: IronMindColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: IronMindColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditGoalsInline extends StatefulWidget {
  final Map<String, dynamic> goals;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _EditGoalsInline({required this.goals, required this.onSaved});

  @override
  State<_EditGoalsInline> createState() => _EditGoalsInlineState();
}

class _EditGoalsInlineState extends State<_EditGoalsInline> {
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
  void dispose() {
    _squatC.dispose();
    _benchC.dispose();
    _deadC.dispose();
    _ohpC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STRENGTH GOALS',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => widget.onSaved({
                'squat': int.tryParse(_squatC.text) ?? 315,
                'bench': int.tryParse(_benchC.text) ?? 225,
                'deadlift': int.tryParse(_deadC.text) ?? 405,
                'ohp': int.tryParse(_ohpC.text) ?? 135,
              }),
              child: Text('SAVE', style: GoogleFonts.bebasNeue(fontSize: 16)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _GoalFieldInline(
          label: 'SQUAT',
          ctrl: _squatC,
          color: IronMindColors.accent,
        ),
        const SizedBox(height: 12),
        _GoalFieldInline(
          label: 'BENCH',
          ctrl: _benchC,
          color: IronMindColors.success,
        ),
        const SizedBox(height: 12),
        _GoalFieldInline(
          label: 'DEADLIFT',
          ctrl: _deadC,
          color: IronMindColors.accent,
        ),
        const SizedBox(height: 12),
        _GoalFieldInline(
          label: 'OHP',
          ctrl: _ohpC,
          color: IronMindColors.warning,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String name;
  final String goal;
  final String style;
  final String currentWeight;
  final String targetWeight;
  final String sessionLength;

  const _HeroCard({
    required this.name,
    required this.goal,
    required this.style,
    required this.currentWeight,
    required this.targetWeight,
    required this.sessionLength,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101924), Color(0xFF17354D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: IronMindColors.accent.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == '—' ? 'IRONMIND ATHLETE' : name.toUpperCase(),
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textPrimary,
              fontSize: 30,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$goal • $style',
            style: GoogleFonts.dmSans(
              color: IronMindColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _HeroMetric(label: 'Current', value: currentWeight)),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Target', value: targetWeight)),
              const SizedBox(width: 10),
              Expanded(child: _HeroMetric(label: 'Session', value: sessionLength)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmMono(
              color: IronMindColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textPrimary,
              fontSize: 20,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiftSummaryCard extends StatelessWidget {
  final String squat;
  final String bench;
  final String deadlift;
  final String ohp;

  const _LiftSummaryCard({
    required this.squat,
    required this.bench,
    required this.deadlift,
    required this.ohp,
  });

  @override
  Widget build(BuildContext context) {
    return IronCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT LIFTS',
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.accent,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _LiftRow(label: 'Squat', value: squat),
          _LiftRow(label: 'Bench', value: bench),
          _LiftRow(label: 'Deadlift', value: deadlift),
          _LiftRow(label: 'OHP', value: ohp),
        ],
      ),
    );
  }
}

class _LiftRow extends StatelessWidget {
  final String label;
  final String value;

  const _LiftRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: IronMindColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: IronMindColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterMetric extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _FooterMetric({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmMono(
            color: IronMindColors.textMuted,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.bebasNeue(
            color: color,
            fontSize: 28,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: GoogleFonts.dmSans(
            color: IronMindColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _GoalFieldInline extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;

  const _GoalFieldInline({
    required this.label,
    required this.ctrl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.bebasNeue(
              color: color,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.dmMono(
              color: IronMindColors.textPrimary,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              suffixText: 'lbs',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
