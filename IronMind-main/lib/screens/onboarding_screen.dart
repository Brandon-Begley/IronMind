import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Profile fields
  final _nameController = TextEditingController();
  int _age = 25;
  String _gender = 'Male';
  String _experienceLevel = 'Intermediate';
  String _trainingGoal = 'Strength';

  // Body stats
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Current lifts
  final _squatController = TextEditingController();
  final _benchController = TextEditingController();
  final _deadliftController = TextEditingController();
  final _ohpController = TextEditingController();

  // Goals
  final _goalSquatController = TextEditingController();
  final _goalBenchController = TextEditingController();
  final _goalDeadliftController = TextEditingController();
  final _goalOhpController = TextEditingController();

  bool _saving = false;

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final profile = {
      'name': _nameController.text.trim(),
      'age': _age,
      'gender': _gender,
      'experienceLevel': _experienceLevel,
      'trainingGoal': _trainingGoal,
      'weight': double.tryParse(_weightController.text) ?? 0,
      'height': double.tryParse(_heightController.text) ?? 0,
      'currentSquat': double.tryParse(_squatController.text) ?? 0,
      'currentBench': double.tryParse(_benchController.text) ?? 0,
      'currentDeadlift': double.tryParse(_deadliftController.text) ?? 0,
      'currentOhp': double.tryParse(_ohpController.text) ?? 0,
    };
    await ApiService.saveProfile(profile);

    final goals = {
      'squat': int.tryParse(_goalSquatController.text) ?? 315,
      'bench': int.tryParse(_goalBenchController.text) ?? 225,
      'deadlift': int.tryParse(_goalDeadliftController.text) ?? 405,
      'ohp': int.tryParse(_goalOhpController.text) ?? 135,
    };
    await ApiService.saveStrengthGoals(goals);

    // Log initial bodyweight
    if (profile['weight'] != 0) {
      await ApiService.logBodyweight((profile['weight'] as num).toDouble());
    }

    await ApiService.completeOnboarding();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildProfilePage(),
                  _buildBodyStatsPage(),
                  _buildCurrentLiftsPage(),
                  _buildGoalsPage(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'IRON',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.accent,
                    fontSize: 26,
                    letterSpacing: 2,
                  ),
                ),
                TextSpan(
                  text: 'MIND',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 26,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '${_currentPage + 1} / 5',
            style: GoogleFonts.dmMono(
              color: IronMindColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_currentPage + 1) / 5,
          backgroundColor: IronMindColors.border,
          valueColor: const AlwaysStoppedAnimation(IronMindColors.accent),
          minHeight: 4,
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text('WELCOME TO\nIRONMIND',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 48,
                height: 1.0,
                letterSpacing: 2,
              )),
          const SizedBox(height: 12),
          Text(
            "Let's set up your profile so we can tailor your experience.",
            style: GoogleFonts.dmSans(
              color: IronMindColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          _label('YOUR NAME'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
            decoration: const InputDecoration(hintText: 'e.g. Brandon'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          _label('AGE'),
          const SizedBox(height: 8),
          _NumberStepper(
            value: _age,
            min: 13,
            max: 80,
            onChanged: (v) => setState(() => _age = v),
          ),
          const SizedBox(height: 24),
          _label('GENDER'),
          const SizedBox(height: 8),
          _SegmentedPicker(
            options: const ['Male', 'Female', 'Other'],
            selected: _gender,
            onChanged: (v) => setState(() => _gender = v),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('TRAINING\nPROFILE',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 48,
                height: 1.0,
                letterSpacing: 2,
              )),
          const SizedBox(height: 8),
          Text('Tell us about your training background.',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 36),
          _label('EXPERIENCE LEVEL'),
          const SizedBox(height: 8),
          _SegmentedPicker(
            options: const ['Beginner', 'Intermediate', 'Advanced'],
            selected: _experienceLevel,
            onChanged: (v) => setState(() => _experienceLevel = v),
          ),
          const SizedBox(height: 24),
          _label('PRIMARY GOAL'),
          const SizedBox(height: 12),
          ...['Strength', 'Hypertrophy', 'Endurance', 'Weight Loss'].map(
            (goal) => _GoalCard(
              title: goal,
              subtitle: _goalSubtitle(goal),
              icon: _goalIcon(goal),
              selected: _trainingGoal == goal,
              onTap: () => setState(() => _trainingGoal = goal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyStatsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('BODY\nSTATS',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 48,
                height: 1.0,
                letterSpacing: 2,
              )),
          const SizedBox(height: 8),
          Text('Your starting point. You can update this anytime.',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 36),
          _label('BODYWEIGHT (lbs)'),
          const SizedBox(height: 8),
          TextField(
            controller: _weightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            style: GoogleFonts.dmMono(
                color: IronMindColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(hintText: '185'),
          ),
          const SizedBox(height: 24),
          _label('HEIGHT (inches)'),
          const SizedBox(height: 8),
          TextField(
            controller: _heightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            style: GoogleFonts.dmMono(
                color: IronMindColors.textPrimary, fontSize: 16),
            decoration: const InputDecoration(hintText: '70'),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IronMindColors.accentDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IronMindColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: IronMindColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your bodyweight will be tracked over time on your Progress chart.',
                    style: GoogleFonts.dmSans(
                        color: IronMindColors.accent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLiftsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('CURRENT\nLIFTS',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 48,
                height: 1.0,
                letterSpacing: 2,
              )),
          const SizedBox(height: 8),
          Text(
              "Enter your current best (1RM or estimated). Skip any you haven't done.",
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 36),
          _LiftInput(
              label: 'SQUAT', controller: _squatController, hint: 'e.g. 315'),
          const SizedBox(height: 16),
          _LiftInput(
              label: 'BENCH PRESS',
              controller: _benchController,
              hint: 'e.g. 225'),
          const SizedBox(height: 16),
          _LiftInput(
              label: 'DEADLIFT',
              controller: _deadliftController,
              hint: 'e.g. 405'),
          const SizedBox(height: 16),
          _LiftInput(
              label: 'OVERHEAD PRESS',
              controller: _ohpController,
              hint: 'e.g. 135'),
        ],
      ),
    );
  }

  Widget _buildGoalsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('STRENGTH\nGOALS',
              style: GoogleFonts.bebasNeue(
                color: IronMindColors.textPrimary,
                fontSize: 48,
                height: 1.0,
                letterSpacing: 2,
              )),
          const SizedBox(height: 8),
          Text('Set a target for each lift. These power your progress bars.',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 36),
          _LiftInput(
              label: 'SQUAT GOAL',
              controller: _goalSquatController,
              hint: 'e.g. 500',
              color: IronMindColors.accent),
          const SizedBox(height: 16),
          _LiftInput(
              label: 'BENCH GOAL',
              controller: _goalBenchController,
              hint: 'e.g. 365',
              color: IronMindColors.success),
          const SizedBox(height: 16),
          _LiftInput(
              label: 'DEADLIFT GOAL',
              controller: _goalDeadliftController,
              hint: 'e.g. 600',
              color: IronMindColors.accent),
          const SizedBox(height: 16),
          _LiftInput(
              label: 'OHP GOAL',
              controller: _goalOhpController,
              hint: 'e.g. 225',
              color: IronMindColors.warning),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: IronMindColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IronMindColors.border),
            ),
            child: Text(
              '🎯  Goals can be edited anytime in your Profile → Settings.',
              style: GoogleFonts.dmSans(
                  color: IronMindColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: Text('BACK',
                    style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textSecondary,
                        fontSize: 18,
                        letterSpacing: 1.5)),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _saving ? null : _nextPage,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : Text(
                      _currentPage == 4 ? "LET'S GO" : 'CONTINUE',
                      style: GoogleFonts.bebasNeue(
                          fontSize: 20, letterSpacing: 2),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.bebasNeue(
          color: IronMindColors.textSecondary,
          fontSize: 13,
          letterSpacing: 1.5,
        ),
      );

  String _goalSubtitle(String goal) {
    switch (goal) {
      case 'Strength':
        return 'Max load, low reps (1–5)';
      case 'Hypertrophy':
        return 'Muscle size, moderate reps (6–12)';
      case 'Endurance':
        return 'High reps, cardiovascular focus';
      case 'Weight Loss':
        return 'Calorie deficit, high activity';
      default:
        return '';
    }
  }

  IconData _goalIcon(String goal) {
    switch (goal) {
      case 'Strength':
        return Icons.fitness_center;
      case 'Hypertrophy':
        return Icons.accessibility_new;
      case 'Endurance':
        return Icons.directions_run;
      case 'Weight Loss':
        return Icons.monitor_weight_outlined;
      default:
        return Icons.star;
    }
  }
}

// ─── Sub-widgets ───────────────────────────────────

class _NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _NumberStepper(
      {required this.value,
      required this.min,
      required this.max,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, color: IronMindColors.textSecondary),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmMono(
                  color: IronMindColors.textPrimary, fontSize: 20),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: IronMindColors.accent),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SegmentedPicker(
      {required this.options,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? IronMindColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    color: isSelected
                        ? IronMindColors.background
                        : IronMindColors.textSecondary,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GoalCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? IronMindColors.accentDim
              : IronMindColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? IronMindColors.accent : IronMindColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    selected ? IronMindColors.accent : IronMindColors.textMuted,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.bebasNeue(
                        color: selected
                            ? IronMindColors.accent
                            : IronMindColors.textPrimary,
                        fontSize: 16,
                        letterSpacing: 1,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.dmSans(
                          color: IronMindColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: IronMindColors.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LiftInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final Color color;
  const _LiftInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.color = IronMindColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.bebasNeue(
              color: color, fontSize: 13, letterSpacing: 1.5),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          ],
          style: GoogleFonts.dmMono(
              color: IronMindColors.textPrimary, fontSize: 18),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: 'lbs',
            suffixStyle: GoogleFonts.dmMono(
                color: IronMindColors.textMuted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}