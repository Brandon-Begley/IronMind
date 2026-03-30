import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';

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

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _goals = {};
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
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _goals = goals;
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
                  ? const Center(child: CircularProgressIndicator(color: IronMindColors.accent))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(),
                        _buildSettingsTab(),
                      ],
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
            text: TextSpan(children: [
              TextSpan(
                  text: 'IRON',
                  style: GoogleFonts.bebasNeue(color: IronMindColors.accent, fontSize: 24, letterSpacing: 2)),
              TextSpan(
                  text: 'MIND',
                  style: GoogleFonts.bebasNeue(color: IronMindColors.textPrimary, fontSize: 24, letterSpacing: 2)),
              TextSpan(
                  text: '  •  PROFILE',
                  style: GoogleFonts.bebasNeue(color: IronMindColors.textSecondary, fontSize: 20, letterSpacing: 2)),
            ]),
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
          tabs: const [
            Tab(text: 'INFO'),
            Tab(text: 'SETTINGS'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    final name = _profile['name'] ?? '—';
    final age = _profile['age'] ?? '—';
    final gender = _profile['gender'] ?? '—';
    final level = _profile['experienceLevel'] ?? '—';
    final goal = _profile['trainingGoal'] ?? '—';
    final weight = _profile['weight'] ?? '—';
    final height = _profile['height'] ?? '—';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'ATHLETE',
          items: [
            _InfoItem('Name', '$name'),
            _InfoItem('Age', '$age'),
            _InfoItem('Gender', '$gender'),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'TRAINING',
          items: [
            _InfoItem('Experience', '$level'),
            _InfoItem('Goal', '$goal'),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'BODY STATS',
          items: [
            _InfoItem('Weight', '${weight == '—' ? '—' : '$weight lbs'}'),
            _InfoItem('Height', '${height == '—' ? '—' : '$height in'}'),
          ],
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'CURRENT LIFTS',
          items: [
            _InfoItem('Squat', _liftStr(_profile['currentSquat'])),
            _InfoItem('Bench', _liftStr(_profile['currentBench'])),
            _InfoItem('Deadlift', _liftStr(_profile['currentDeadlift'])),
            _InfoItem('OHP', _liftStr(_profile['currentOhp'])),
          ],
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

  String _liftStr(dynamic value) {
    if (value == null || value == 0) return '—';
    return '${value.toStringAsFixed(0)} lbs';
  }

  void _editGoalsSheet() {
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
          'Use Redo Onboarding to update your full profile details.',
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

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;

  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title,
            style: GoogleFonts.bebasNeue(color: IronMindColors.accent, fontSize: 14, letterSpacing: 1.5),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        item.label,
                        style: GoogleFonts.dmSans(color: IronMindColors.textSecondary, fontSize: 13),
                      ),
                    ),
                    Text(
                      item.value,
                      style: GoogleFonts.dmSans(
                        color: IronMindColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
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
              style: GoogleFonts.dmSans(color: color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: IronMindColors.textMuted, size: 18),
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STRENGTH GOALS',
              style: GoogleFonts.bebasNeue(color: IronMindColors.textPrimary, fontSize: 22, letterSpacing: 2),
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
        _GoalFieldInline(label: 'SQUAT', ctrl: _squatC, color: IronMindColors.accent),
        const SizedBox(height: 12),
        _GoalFieldInline(label: 'BENCH', ctrl: _benchC, color: IronMindColors.success),
        const SizedBox(height: 12),
        _GoalFieldInline(label: 'DEADLIFT', ctrl: _deadC, color: IronMindColors.accent),
        const SizedBox(height: 12),
        _GoalFieldInline(label: 'OHP', ctrl: _ohpC, color: IronMindColors.warning),
        const SizedBox(height: 16),
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
            style: GoogleFonts.bebasNeue(color: color, fontSize: 14, letterSpacing: 1.5),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.dmMono(color: IronMindColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(
              suffixText: 'lbs',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
