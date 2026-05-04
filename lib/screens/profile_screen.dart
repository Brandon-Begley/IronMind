import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';
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

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _goals   = {};
  List<Map<String, dynamic>> _logs = [];
  int  _bestStreakDays = 0;
  int  _totalWorkouts  = 0;
  int  _totalPRs       = 0;
  bool _loading        = true;
  bool _healthConnected = false;
  String? _avatarPath;

  double get _totalVolume => _logs.fold(0.0, (s, log) => s + _logVolume(log));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiService.getProfile(),
      ApiService.getStrengthGoals(),
      ApiService.getLogs(),
      ApiService.getWorkoutLoggedDates(),
      ApiService.getHabits(),
      ApiService.getPRList(),
    ]);
    final profile      = results[0] as Map<String, dynamic>;
    final goals        = results[1] as Map<String, dynamic>;
    final logs         = results[2] as List<Map<String, dynamic>>;
    final workoutDates = results[3] as Set<String>;
    final habits       = results[4] as List<Map<String, dynamic>>;
    final prs          = results[5] as List<Map<String, dynamic>>;

    int bestStreak = ApiService.computeStreak(workoutDates)['longest'] ?? 0;
    for (final h in habits) {
      final dates = await ApiService.getHabitCompletedDates(h['id'] as String);
      final s = ApiService.computeStreak(dates)['longest'] ?? 0;
      if (s > bestStreak) bestStreak = s;
    }

    String? resolvedAvatar;
    final rawAvatar = profile['avatarPath']?.toString();
    if (rawAvatar != null && rawAvatar.isNotEmpty) {
      if (await File(rawAvatar).exists()) resolvedAvatar = rawAvatar;
    }

    if (!mounted) return;
    setState(() {
      _profile       = profile;
      _goals         = goals;
      _logs          = logs;
      _bestStreakDays = bestStreak;
      _totalWorkouts  = logs.length;
      _totalPRs       = prs.length;
      _healthConnected = HealthService.instance.isConnected;
      _avatarPath    = resolvedAvatar;
      _loading       = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: IronMindColors.accent))
            : RefreshIndicator(
                color: IronMindColors.accent,
                backgroundColor: IronMindColors.surfaceElevated,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildHero(),
                    const SizedBox(height: 20),
                    _buildStatsStrip(),
                    const SizedBox(height: 28),
                    _buildActivity(),
                    const SizedBox(height: 28),
                    _buildAchievements(),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Profile',
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textPrimary,
              fontSize: 28, letterSpacing: 2)),
          GestureDetector(
            onTap: _showSettingsSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: IronMindColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: IronMindColors.border),
              ),
              child: const Icon(Icons.settings_outlined,
                color: IronMindColors.textSecondary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    final name  = (_profile['name'] ?? 'Athlete').toString();
    final goal  = _formatGoal((_profile['goal'] ?? _profile['trainingGoal'] ?? '').toString());
    final style = _formatStyle((_profile['style'] ?? '').toString());
    final sub   = [goal, style].where((s) => s.isNotEmpty && s != '—').join(' · ');

    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: _showPhotoSourceSheet,
          child: Stack(
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IronMindColors.surfaceElevated,
                  border: Border.all(
                    color: IronMindColors.accent.withOpacity(0.4), width: 2),
                ),
                child: ClipOval(
                  child: _avatarPath != null
                      ? Image.file(File(_avatarPath!), fit: BoxFit.cover)
                      : const Icon(Icons.person,
                          color: IronMindColors.textMuted, size: 40),
                ),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: IronMindColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: IronMindColors.background, width: 2),
                  ),
                  child: const Icon(Icons.edit,
                    color: Colors.black, size: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Name + subtitle + edit
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 28, letterSpacing: 1.5, height: 1)),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(sub,
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textSecondary, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _editProfile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: IronMindColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: IronMindColors.border),
                  ),
                  child: Text('Edit Profile',
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Stats strip ────────────────────────────────────────────────────────────

  Widget _buildStatsStrip() {
    final vol = _totalVolume;
    final volLabel = vol >= 1000000
        ? '${(vol / 1000000).toStringAsFixed(1)}M'
        : vol >= 1000
            ? '${(vol / 1000).toStringAsFixed(1)}k'
            : vol.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IronMindColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatCol(label: 'Sessions', value: '$_totalWorkouts',  color: IronMindColors.accent),
            _vDivider(),
            _StatCol(label: 'Best Streak', value: '${_bestStreakDays}d', color: IronMindColors.warning),
            _vDivider(),
            _StatCol(label: 'Volume', value: volLabel,             color: IronMindColors.success),
            _vDivider(),
            _StatCol(label: 'PRs', value: '$_totalPRs',            color: IronMindColors.textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => VerticalDivider(
    color: IronMindColors.border, width: 1, thickness: 1,
    indent: 6, endIndent: 6);

  // ── Activity feed ──────────────────────────────────────────────────────────

  Widget _buildActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(title: 'Activity'),
            if (_logs.length > 5)
              Text('${_logs.length} total',
                style: GoogleFonts.dmMono(
                  color: IronMindColors.textMuted, fontSize: 10, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 12),
        if (_logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: IronMindColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: IronMindColors.border),
            ),
            child: Center(
              child: Column(children: [
                Icon(Icons.fitness_center_outlined,
                  color: IronMindColors.textMuted, size: 36),
                const SizedBox(height: 10),
                Text('No workouts logged yet',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textSecondary, fontSize: 14)),
                Text('Head to the Workout tab to start',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textMuted, fontSize: 12)),
              ]),
            ),
          )
        else
          ..._logs.take(8).map((log) => _ActivityCard(log: log)),
      ],
    );
  }

  // ── Achievements ───────────────────────────────────────────────────────────

  Widget _buildAchievements() {
    final badges = _computeBadges();
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Achievements'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: badges.map((b) => _AchievementPill(badge: b)).toList(),
        ),
      ],
    );
  }

  List<_Badge> _computeBadges() {
    final badges = <_Badge>[];
    // Workout count milestones
    const workoutMilestones = [1, 10, 25, 50, 100, 200, 365, 500];
    for (final m in workoutMilestones) {
      if (_totalWorkouts >= m) {
        badges.add(_Badge(
          emoji: m >= 365 ? '🔱' : m >= 100 ? '🏆' : m >= 25 ? '⭐' : '🎯',
          label: '$m Sessions',
          color: m >= 100 ? const Color(0xFFFFD700) : IronMindColors.accent,
        ));
      }
    }
    // Streak milestones
    const streakMilestones = [7, 14, 30, 60, 90, 180, 365];
    for (final m in streakMilestones) {
      if (_bestStreakDays >= m) {
        badges.add(_Badge(
          emoji: m >= 90 ? '🔥' : '⚡',
          label: '${m}d Streak',
          color: IronMindColors.warning,
        ));
      }
    }
    return badges;
  }

  // ── Settings sheet ─────────────────────────────────────────────────────────

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: IronMindColors.border,
                borderRadius: BorderRadius.circular(2)),
            ),
            Text('Settings',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 24, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            _SettingsRow(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () { Navigator.pop(context); _editProfile(); },
            ),
            _SettingsRow(
              icon: Icons.flag_outlined,
              label: 'Strength Goals',
              onTap: () { Navigator.pop(context); _editGoalsSheet(); },
            ),
            _HealthConnectRow(
              connected: _healthConnected,
              onConnect: _handleHealthConnect,
              onDisconnect: _handleHealthDisconnect,
            ),
            const SizedBox(height: 8),
            const Divider(color: IronMindColors.border),
            const SizedBox(height: 8),
            _SettingsRow(
              icon: Icons.restart_alt,
              label: 'Redo Onboarding',
              onTap: () { Navigator.pop(context); _redoOnboarding(); },
              color: IronMindColors.warning,
            ),
            _SettingsRow(
              icon: Icons.logout,
              label: 'Sign Out',
              onTap: () { Navigator.pop(context); _signOut(); },
              color: IronMindColors.alert,
            ),
          ],
        ),
      ),
    );
  }


  double _logVolume(Map<String, dynamic> log) {
    final exercises = log['exercises'] as List? ?? [];
    return exercises.fold<double>(0, (sum, exercise) {
      return sum +
          ((exercise['weight'] ?? 0) as num).toDouble() *
              ((exercise['sets'] ?? 1) as num).toDouble() *
              ((exercise['reps'] ?? 1) as num).toDouble();
    });
  }

  String _monthAbbr(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(month - 1).clamp(0, 11)];
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

  Future<void> _pickAndSavePhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null || !mounted) return;
      final userId = await AuthService.getCurrentUserId() ?? 'local';
      final dir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${dir.path}/avatars');
      if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);
      final dest = '${avatarDir.path}/${userId}_profile.jpg';
      await File(picked.path).copy(dest);
      final current = await ApiService.getProfile();
      current['avatarPath'] = dest;
      await ApiService.saveProfile(current);
      if (!mounted) return;
      setState(() => _avatarPath = dest);
    } catch (_) {}
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: IronMindColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PROFILE PHOTO',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 20, letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 20),
            _PhotoSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Photo Library',
              onTap: () { Navigator.pop(context); _pickAndSavePhoto(ImageSource.gallery); },
            ),
            const SizedBox(height: 10),
            _PhotoSourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: () { Navigator.pop(context); _pickAndSavePhoto(ImageSource.camera); },
            ),
            if (_avatarPath != null) ...[
              const SizedBox(height: 10),
              _PhotoSourceTile(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                color: IronMindColors.alert,
                onTap: () async {
                  Navigator.pop(context);
                  final current = await ApiService.getProfile();
                  current.remove('avatarPath');
                  await ApiService.saveProfile(current);
                  if (mounted) setState(() => _avatarPath = null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _editProfile() {
    final nameCtrl = TextEditingController(
      text: (_profile['name'] ?? '').toString(),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: IronMindColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: IronMindColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'EDIT PROFILE',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 22, letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showPhotoSourceSheet();
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: IronMindColors.surfaceElevated,
                          backgroundImage: _avatarPath != null
                              ? FileImage(File(_avatarPath!))
                              : null,
                          child: _avatarPath == null
                              ? const Icon(
                                  Icons.person,
                                  color: IronMindColors.textMuted,
                                  size: 36,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: IronMindColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: IronMindColors.surface, width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: IronMindColors.background,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Tap to change photo',
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textMuted, fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final current = await ApiService.getProfile();
                      current['name'] = name;
                      await ApiService.saveProfile(current);
                      if (!mounted) return;
                      setState(() => _profile = {..._profile, 'name': name});
                      Navigator.pop(context);
                    },
                    child: Text(
                      'SAVE',
                      style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

  Future<void> _handleHealthConnect() async {
    final granted = await HealthService.instance.connect();
    if (!mounted) return;
    setState(() => _healthConnected = granted);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Health connected — data will sync on next load.'
              : 'Permission not granted. You can enable it in device Settings.',
          style: GoogleFonts.dmSans(),
        ),
        backgroundColor: granted
            ? IronMindColors.surfaceElevated
            : IronMindColors.alert,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _handleHealthDisconnect() async {
    await HealthService.instance.disconnect();
    if (!mounted) return;
    setState(() => _healthConnected = false);
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: IronMindColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IronMindColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: IronMindColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthConnectRow extends StatelessWidget {
  final bool connected;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _HealthConnectRow({
    required this.connected,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: connected ? IronMindColors.success : IronMindColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.health_and_safety_outlined,
            color: connected ? IronMindColors.success : IronMindColors.textPrimary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Health Connected' : 'Connect Health',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  connected
                      ? 'Syncing steps, sleep, HR & weight'
                      : 'Sync steps, sleep, calories & more',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (connected)
            GestureDetector(
              onTap: onDisconnect,
              child: Text(
                'Disconnect',
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textMuted,
                  fontSize: 12,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: IronMindColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'CONNECT',
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

// ── New profile widgets ───────────────────────────────────────────────────────

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatCol({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value,
          style: GoogleFonts.bebasNeue(
            color: color, fontSize: 22, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(label,
          style: GoogleFonts.dmMono(
            color: IronMindColors.textMuted, fontSize: 9, letterSpacing: 0.8),
          textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _ActivityCard({required this.log});

  String _fmt(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)}k'
      : v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final exercises = (log['exercises'] as List? ?? []);
    final name      = (log['day_name'] ?? log['program_name'] ?? 'Workout') as String;
    final focus     = (log['focus'] ?? '') as String;
    final rawDate   = log['date']?.toString() ?? log['timestamp']?.toString() ?? '';
    final date      = DateTime.tryParse(rawDate);
    const months    = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateLabel = date != null
        ? '${months[date.month - 1]} ${date.day}'
        : rawDate.split('T').first;
    final sets = exercises.fold<int>(0, (s, e) => s + ((e['sets'] ?? 1) as num).toInt());
    final vol  = exercises.fold<double>(0, (s, e) =>
        s + ((e['weight'] ?? 0) as num).toDouble()
          * ((e['sets']  ?? 1) as num).toDouble()
          * ((e['reps']  ?? 1) as num).toDouble());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name,
                style: GoogleFonts.bebasNeue(
                  color: IronMindColors.textPrimary,
                  fontSize: 17, letterSpacing: 1)),
            ),
            Text(dateLabel,
              style: GoogleFonts.dmMono(
                color: IronMindColors.textMuted, fontSize: 10)),
          ]),
          if (focus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(focus,
                style: GoogleFonts.dmSans(
                  color: IronMindColors.accent, fontSize: 11)),
            ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  exercises.take(3).map((e) => e['name'] ?? '').join(' · '),
                  style: GoogleFonts.dmMono(
                    color: IronMindColors.textMuted, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IronMindColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: IronMindColors.border),
                ),
                child: Text('$sets sets · ${_fmt(vol)} lbs',
                  style: GoogleFonts.dmMono(
                    color: IronMindColors.textSecondary, fontSize: 9)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Badge {
  final String emoji;
  final String label;
  final Color  color;
  const _Badge({required this.emoji, required this.label, required this.color});
}

class _AchievementPill extends StatelessWidget {
  final _Badge badge;
  const _AchievementPill({required this.badge});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: badge.color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: badge.color.withOpacity(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(badge.emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 5),
      Text(badge.label,
        style: GoogleFonts.dmSans(
          color: badge.color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}


class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _PhotoSourceTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: IronMindColors.surfaceElevated,
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
          ],
        ),
      ),
    );
  }
}
