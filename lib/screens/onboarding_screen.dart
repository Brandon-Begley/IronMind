import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _currentWeightController = TextEditingController();
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _squatController = TextEditingController();
  final _benchController = TextEditingController();
  final _deadliftController = TextEditingController();
  final _ohpController = TextEditingController();
  final _goalSquatController = TextEditingController();
  final _goalBenchController = TextEditingController();
  final _goalDeadliftController = TextEditingController();
  final _goalOhpController = TextEditingController();

  String _experience = 'intermediate';
  String _goal = 'peak-strength';
  DateTime? _birthDate;
  String _gender = 'Male';
  String _style = 'strength';
  String _weakPoint = 'none';
  double _trainingDays = 4;
  double _sessionLength = 75;
  final Set<String> _equipment = <String>{};
  bool _fullGymAccess = false;
  bool _loading = true;
  bool _saving = false;
  int _step = 0;

  static const List<String> _equipmentOptions = [
    'Barbell',
    'Dumbbells',
    'Cable Machine',
    'Safety Squat Bar',
    'Bands / Chains',
    'Leg Press',
    'Smith Machine',
    'Kettlebells',
  ];

  static const List<_DropdownOption> _trainingStyleOptions = [
    _DropdownOption(value: 'powerlifting', label: 'Powerlifting'),
    _DropdownOption(value: 'powerbuilding', label: 'Powerbuilding'),
    _DropdownOption(value: 'strength', label: 'General Strength'),
    _DropdownOption(value: 'hypertrophy', label: 'Hypertrophy'),
    _DropdownOption(value: 'bodybuilding', label: 'Bodybuilding'),
    _DropdownOption(value: 'athletic', label: 'Athletic Performance'),
  ];

  static const List<int> _heightFeetOptions = [4, 5, 6, 7];
  static const List<int> _heightInchOptions = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  ];

  static const List<_ChoiceOption> _experienceOptions = [
    _ChoiceOption(
      value: 'beginner',
      title: 'Beginner',
      subtitle: '0-1 year in the gym and still building consistency.',
      icon: Icons.sports_gymnastics,
    ),
    _ChoiceOption(
      value: 'intermediate',
      title: 'Intermediate',
      subtitle: '1-3 years training with a base and steady habits.',
      icon: Icons.fitness_center,
    ),
    _ChoiceOption(
      value: 'advanced',
      title: 'Advanced',
      subtitle: '3-5 years of serious lifting with solid technique.',
      icon: Icons.emoji_events_outlined,
    ),
    _ChoiceOption(
      value: 'elite',
      title: 'Elite',
      subtitle: '5+ years of high-level training and performance focus.',
      icon: Icons.workspace_premium_outlined,
    ),
  ];

  static const List<_ChoiceOption> _goalOptions = [
    _ChoiceOption(
      value: 'peak-strength',
      title: 'Peak Strength',
      subtitle: 'Prioritize max load, big compounds, and lower rep work.',
      icon: Icons.fitness_center,
    ),
    _ChoiceOption(
      value: 'hypertrophy',
      title: 'Build Muscle',
      subtitle: 'Focus on volume, recovery, and adding quality size.',
      icon: Icons.accessibility_new,
    ),
    _ChoiceOption(
      value: 'lose-fat',
      title: 'Cut Body Fat',
      subtitle: 'Train hard while leaning out and keeping performance up.',
      icon: Icons.monitor_weight_outlined,
    ),
    _ChoiceOption(
      value: 'fitness',
      title: 'General Fitness',
      subtitle: 'Build strength, conditioning, and consistency together.',
      icon: Icons.directions_run,
    ),
  ];

  static const List<_OnboardingStepMeta> _steps = [
    _OnboardingStepMeta(
      title: 'Who Are You?',
      subtitle: 'Set up the basics so IronMind can speak to you like a training partner.',
      kicker: 'STEP 1',
    ),
    _OnboardingStepMeta(
      title: 'What\'s Your Experience?',
      subtitle: 'Your training level helps shape the recommendations and pacing.',
      kicker: 'STEP 2',
    ),
    _OnboardingStepMeta(
      title: 'What\'s The Main Goal?',
      subtitle: 'Choose the outcome you want this training phase to prioritize.',
      kicker: 'STEP 3',
    ),
    _OnboardingStepMeta(
      title: 'Body Snapshot',
      subtitle: 'Your weight, height, and target — the numbers that anchor everything.',
      kicker: 'STEP 4',
    ),
    _OnboardingStepMeta(
      title: 'Current Strength',
      subtitle: 'Enter your best current numbers so the app has a real baseline.',
      kicker: 'STEP 5',
    ),
    _OnboardingStepMeta(
      title: 'Strength Goals',
      subtitle: 'Now set the numbers you want to chase next.',
      kicker: 'STEP 6',
    ),
    _OnboardingStepMeta(
      title: 'Training Setup',
      subtitle: 'Tell IronMind how you like to train and what your week looks like.',
      kicker: 'STEP 7',
    ),
    _OnboardingStepMeta(
      title: 'AI Workout Context',
      subtitle: 'Only share equipment the AI generator should consider when building sessions.',
      kicker: 'STEP 8',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final current = await ApiService.getLifterProfile();
      final goals = await ApiService.getStrengthGoals();
      if (!mounted) return;
      setState(() {
        _nameController.text = current['name']?.toString() ?? '';
        _birthDate = _parseBirthDate(current['birthDate']?.toString());
        _gender = current['gender']?.toString() ?? _gender;
        _currentWeightController.text =
            current['bodyweight']?.toString() ??
            current['weight']?.toString() ??
            '';
        final totalHeightInches = _parseHeightInches(current);
        if (totalHeightInches != null && totalHeightInches > 0) {
          _heightFeetController.text = (totalHeightInches ~/ 12).toString();
          _heightInchesController.text = (totalHeightInches % 12).toString();
        }
        _targetWeightController.text = current['goalWeight']?.toString() ?? '';
        _squatController.text = current['squat']?.toString() ?? '';
        _benchController.text = current['bench']?.toString() ?? '';
        _deadliftController.text = current['deadlift']?.toString() ?? '';
        _ohpController.text = current['ohp']?.toString() ?? '';
        _goalSquatController.text = goals['squat']?.toString() ?? '315';
        _goalBenchController.text = goals['bench']?.toString() ?? '225';
        _goalDeadliftController.text = goals['deadlift']?.toString() ?? '405';
        _goalOhpController.text = goals['ohp']?.toString() ?? '135';
        _experience = _normalizeExperience(
          current['experience']?.toString() ??
              current['experienceLevel']?.toString(),
        );
        _goal = _normalizeGoal(
          current['goal']?.toString() ?? current['trainingGoal']?.toString(),
        );
        _style = _normalizeStyle(current['style']?.toString());
        _weakPoint = current['weakpoint']?.toString() ?? _weakPoint;
        _trainingDays =
            (current['trainingDays'] as num?)?.toDouble() ?? _trainingDays;
        _sessionLength =
            (current['sessionLength'] as num?)?.toDouble() ?? _sessionLength;
        _fullGymAccess = current['fullGymAccess'] == true;
        _equipment
          ..clear()
          ..addAll(List<String>.from(current['equipment'] ?? const []));
        if (_equipment.length == _equipmentOptions.length) {
          _fullGymAccess = true;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    final current = await ApiService.getLifterProfile();
    final heightTotalInches = _heightTotalInches();
    current['name'] = _nameController.text.trim();
    current['birthDate'] = _birthDate?.toIso8601String().split('T').first;
    current['age'] = _calculatedAge();
    current['gender'] = _gender;
    current['experience'] = _experience;
    current['experienceLevel'] = _experienceDisplayLabel(_experience);
    current['goal'] = _goal;
    current['trainingGoal'] = _goalDisplayLabel(_goal);
    current['bodyweight'] = _currentWeightController.text.trim();
    current['weight'] = _currentWeightController.text.trim();
    current['heightFeet'] = _heightFeetController.text.trim();
    current['heightInches'] = _heightInchesController.text.trim();
    current['height'] = heightTotalInches > 0 ? '$heightTotalInches' : '';
    current['goalWeight'] = _targetWeightController.text.trim();
    current['style'] = _style;
    current['weakpoint'] = _weakPoint;
    current['trainingDays'] = _trainingDays.round();
    current['sessionLength'] = _sessionLength.round();
    current['fullGymAccess'] = _fullGymAccess;
    current['equipment'] = _fullGymAccess
        ? List<String>.from(_equipmentOptions)
        : _equipment.toList();
    current['squat'] = _squatController.text.trim();
    current['bench'] = _benchController.text.trim();
    current['deadlift'] = _deadliftController.text.trim();
    current['ohp'] = _ohpController.text.trim();
    current['currentSquat'] = double.tryParse(_squatController.text.trim()) ?? 0;
    current['currentBench'] = double.tryParse(_benchController.text.trim()) ?? 0;
    current['currentDeadlift'] =
        double.tryParse(_deadliftController.text.trim()) ?? 0;
    current['currentOhp'] = double.tryParse(_ohpController.text.trim()) ?? 0;

    await ApiService.saveLifterProfile(current);
    await ApiService.saveStrengthGoals({
      'squat': int.tryParse(_goalSquatController.text.trim()) ?? 315,
      'bench': int.tryParse(_goalBenchController.text.trim()) ?? 225,
      'deadlift': int.tryParse(_goalDeadliftController.text.trim()) ?? 405,
      'ohp': int.tryParse(_goalOhpController.text.trim()) ?? 135,
    });
    await ApiService.completeOnboarding();
    await widget.onComplete();
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_nameController.text.trim().isEmpty) return 'Please enter your name to continue.';
      case 3:
        if (_currentWeightController.text.trim().isEmpty) return 'Please enter your current weight.';
        if (double.tryParse(_currentWeightController.text.trim()) == null) return 'Enter a valid weight (e.g. 185).';
        if (_targetWeightController.text.trim().isNotEmpty &&
            double.tryParse(_targetWeightController.text.trim()) == null) {
          return 'Enter a valid target weight (e.g. 175).';
        }
    }
    return null;
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    final error = _validateCurrentStep();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: GoogleFonts.dmSans(fontSize: 13)),
          backgroundColor: IronMindColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
      return;
    }
    if (_step == _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _step += 1);
  }

  void _previousStep() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step -= 1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentWeightController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _targetWeightController.dispose();
    _squatController.dispose();
    _benchController.dispose();
    _deadliftController.dispose();
    _ohpController.dispose();
    _goalSquatController.dispose();
    _goalBenchController.dispose();
    _goalDeadliftController.dispose();
    _goalOhpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _steps[_step];
    final progress = (_step + 1) / _steps.length;

    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: IronMindColors.accent),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WELCOME TO IRONMIND',
                      style: GoogleFonts.bebasNeue(
                        color: IronMindColors.textPrimary,
                        fontSize: 36,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: IronMindColors.surface,
                        color: IronMindColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_step + 1} / ${_steps.length}',
                      style: GoogleFonts.dmMono(
                        color: IronMindColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _OnboardingStepShell(
                          key: ValueKey(_step),
                          meta: meta,
                          child: _buildStepContent(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving ? null : _previousStep,
                              child: Text(
                                'BACK',
                                style: GoogleFonts.bebasNeue(letterSpacing: 1.4),
                              ),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _nextStep,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _step == _steps.length - 1
                                        ? 'START TRAINING'
                                        : 'CONTINUE',
                                    style: GoogleFonts.bebasNeue(
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.dmSans(color: IronMindColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'What should IronMind call you?',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Birth Date',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBirthDate,
              child: AbsorbPointer(
                child: TextField(
                  controller: TextEditingController(
                    text: _formattedBirthDate(),
                  ),
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Birth Date',
                    hintText: 'Select your birth date',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    helperText: _birthDate == null
                        ? null
                        : 'Age: ${_calculatedAge()}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Gender',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _SegmentedPicker(
              options: const ['Male', 'Female', 'Other'],
              selected: _gender,
              onChanged: (value) => setState(() => _gender = value),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose the level that feels closest to where you are right now.',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            ..._experienceOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SelectionCard(
                  title: option.title,
                  subtitle: option.subtitle,
                  icon: option.icon,
                  selected: _experience == option.value,
                  onTap: () => setState(() => _experience = option.value),
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick the result you want IronMind to bias your training toward.',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            ..._goalOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SelectionCard(
                  title: option.title,
                  subtitle: option.subtitle,
                  icon: option.icon,
                  selected: _goal == option.value,
                  onTap: () => setState(() => _goal = option.value),
                ),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LiftField(
              label: 'Current Weight',
              controller: _currentWeightController,
              suffixText: 'lbs',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _HeightDropdown(
                    label: 'Height',
                    value: int.tryParse(_heightFeetController.text),
                    items: _heightFeetOptions,
                    suffix: 'ft',
                    onChanged: (value) => setState(
                      () => _heightFeetController.text = value?.toString() ?? '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HeightDropdown(
                    label: 'Inches',
                    value: int.tryParse(_heightInchesController.text),
                    items: _heightInchOptions,
                    suffix: 'in',
                    onChanged: (value) => setState(
                      () => _heightInchesController.text = value?.toString() ?? '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LiftField(
              label: 'Target Weight',
              controller: _targetWeightController,
              suffixText: 'lbs',
            ),
            const SizedBox(height: 4),
            Text(
              'Optional — you can set or update this later.',
              style: GoogleFonts.dmSans(
                color: IronMindColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        );
      case 4:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _LiftField(
                    label: 'Squat',
                    controller: _squatController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiftField(
                    label: 'Bench',
                    controller: _benchController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LiftField(
                    label: 'Deadlift',
                    controller: _deadliftController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiftField(label: 'OHP', controller: _ohpController),
                ),
              ],
            ),
          ],
        );
      case 5:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _LiftField(
                    label: 'Squat Goal',
                    controller: _goalSquatController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiftField(
                    label: 'Bench Goal',
                    controller: _goalBenchController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LiftField(
                    label: 'Deadlift Goal',
                    controller: _goalDeadliftController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LiftField(
                    label: 'OHP Goal',
                    controller: _goalOhpController,
                  ),
                ),
              ],
            ),
          ],
        );
      case 6:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _style,
              dropdownColor: IronMindColors.surface,
              decoration: const InputDecoration(labelText: 'Training Style'),
              items: _trainingStyleOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _style = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _weakPoint,
              dropdownColor: IronMindColors.surface,
              decoration: const InputDecoration(labelText: 'Weak Point'),
              items: const [
                DropdownMenuItem(
                  value: 'none',
                  child: Text('None / Balanced'),
                ),
                DropdownMenuItem(
                  value: 'squat-depth',
                  child: Text('Squat Depth'),
                ),
                DropdownMenuItem(
                  value: 'squat-lockout',
                  child: Text('Squat Lockout'),
                ),
                DropdownMenuItem(
                  value: 'bench-bottom',
                  child: Text('Bench Off Chest'),
                ),
                DropdownMenuItem(
                  value: 'bench-lockout',
                  child: Text('Bench Lockout'),
                ),
                DropdownMenuItem(
                  value: 'deadlift-floor',
                  child: Text('Deadlift Off Floor'),
                ),
                DropdownMenuItem(
                  value: 'deadlift-lockout',
                  child: Text('Deadlift Lockout'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _weakPoint = value);
              },
            ),
            const SizedBox(height: 16),
            _SliderField(
              label: 'Training Days / Week',
              value: _trainingDays,
              min: 2,
              max: 7,
              divisions: 5,
              suffix: '${_trainingDays.round()} days',
              onChanged: (value) => setState(() => _trainingDays = value),
            ),
            const SizedBox(height: 12),
            _SliderField(
              label: 'Session Length',
              value: _sessionLength,
              min: 30,
              max: 120,
              divisions: 6,
              suffix: '${_sessionLength.round()} min',
              onChanged: (value) => setState(() => _sessionLength = value),
            ),
          ],
        );
      case 7:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterChip(
              label: const Text('Full Gym'),
              selected: _fullGymAccess,
              selectedColor: IronMindColors.accent.withValues(alpha: 0.18),
              checkmarkColor: IronMindColors.accent,
              side: const BorderSide(color: IronMindColors.border),
              labelStyle: GoogleFonts.dmSans(
                color: _fullGymAccess
                    ? IronMindColors.textPrimary
                    : IronMindColors.textSecondary,
                fontSize: 12,
              ),
              onSelected: (value) {
                setState(() {
                  _fullGymAccess = value;
                  if (value) {
                    _equipment
                      ..clear()
                      ..addAll(_equipmentOptions);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _equipmentOptions.map((item) {
                final selected = _equipment.contains(item);
                return FilterChip(
                  label: Text(item),
                  selected: selected || _fullGymAccess,
                  selectedColor: IronMindColors.accent.withValues(alpha: 0.18),
                  checkmarkColor: IronMindColors.accent,
                  side: const BorderSide(color: IronMindColors.border),
                  labelStyle: GoogleFonts.dmSans(
                    color: selected || _fullGymAccess
                        ? IronMindColors.textPrimary
                        : IronMindColors.textSecondary,
                    fontSize: 12,
                  ),
                  onSelected: (value) {
                    setState(() {
                      _fullGymAccess = false;
                      if (value) {
                        _equipment.add(item);
                      } else {
                        _equipment.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  String _formattedBirthDate() {
    if (_birthDate == null) return '';
    final month = _birthDate!.month.toString().padLeft(2, '0');
    final day = _birthDate!.day.toString().padLeft(2, '0');
    return '$month/$day/${_birthDate!.year}';
  }

  int? _calculatedAge() {
    if (_birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - _birthDate!.year;
    final hasHadBirthday =
        now.month > _birthDate!.month ||
        (now.month == _birthDate!.month && now.day >= _birthDate!.day);
    if (!hasHadBirthday) age -= 1;
    return age;
  }

  DateTime? _parseBirthDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  int? _parseHeightInches(Map<String, dynamic> current) {
    final feet = int.tryParse(current['heightFeet']?.toString() ?? '');
    final inches = int.tryParse(current['heightInches']?.toString() ?? '');
    if (feet != null) {
      return (feet * 12) + (inches ?? 0);
    }
    return int.tryParse(current['height']?.toString() ?? '');
  }

  int _heightTotalInches() {
    final feet = int.tryParse(_heightFeetController.text.trim()) ?? 0;
    final inches = int.tryParse(_heightInchesController.text.trim()) ?? 0;
    return (feet * 12) + inches;
  }

  String _normalizeExperience(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'beginner':
        return 'beginner';
      case 'advanced':
        return 'advanced';
      case 'elite':
        return 'elite';
      case 'intermediate':
      default:
        return 'intermediate';
    }
  }

  String _normalizeGoal(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'strength':
      case 'peak strength':
      case 'peak-strength':
        return 'peak-strength';
      case 'hypertrophy':
      case 'build muscle':
        return 'hypertrophy';
      case 'weight loss':
      case 'lose fat':
      case 'lose-fat':
      case 'cut body fat':
        return 'lose-fat';
      case 'endurance':
      case 'general fitness':
      case 'fitness':
      case 'athletic performance':
      case 'athletic':
        return 'fitness';
      default:
        return 'peak-strength';
    }
  }

  String _experienceDisplayLabel(String value) {
    switch (value) {
      case 'beginner':
        return 'Beginner';
      case 'advanced':
        return 'Advanced';
      case 'elite':
        return 'Elite';
      case 'intermediate':
      default:
        return 'Intermediate';
    }
  }

  String _goalDisplayLabel(String value) {
    switch (value) {
      case 'hypertrophy':
        return 'Build Muscle';
      case 'lose-fat':
        return 'Cut Body Fat';
      case 'fitness':
        return 'General Fitness';
      case 'peak-strength':
      default:
        return 'Peak Strength';
    }
  }

  String _normalizeStyle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'powerlifting':
        return 'powerlifting';
      case 'powerbuilding':
        return 'powerbuilding';
      case 'hypertrophy / bodybuilding':
      case 'hypertrophy':
        return 'hypertrophy';
      case 'bodybuilding':
        return 'bodybuilding';
      case 'athletic':
      case 'athletic performance':
        return 'athletic';
      case 'strength':
      case 'general strength':
      default:
        return 'strength';
    }
  }
}

class _OnboardingStepMeta {
  final String title;
  final String subtitle;
  final String kicker;

  const _OnboardingStepMeta({
    required this.title,
    required this.subtitle,
    required this.kicker,
  });
}

class _ChoiceOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ChoiceOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _DropdownOption {
  final String value;
  final String label;

  const _DropdownOption({required this.value, required this.label});
}

class _HeightDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<int> items;
  final String suffix;
  final ValueChanged<int?> onChanged;

  const _HeightDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: IronMindColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: value,
          dropdownColor: IronMindColors.surface,
          decoration: InputDecoration(
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item,
                  child: Text(
                    '$item',
                    style: GoogleFonts.dmMono(
                      color: IronMindColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _OnboardingStepShell extends StatelessWidget {
  final _OnboardingStepMeta meta;
  final Widget child;

  const _OnboardingStepShell({
    super.key,
    required this.meta,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meta.kicker,
            style: GoogleFonts.dmMono(
              color: IronMindColors.accent,
              fontSize: 11,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            meta.title,
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.textPrimary,
              fontSize: 30,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta.subtitle,
            style: GoogleFonts.dmSans(
              color: IronMindColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  color: IronMindColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              suffix,
              style: GoogleFonts.dmMono(
                color: IronMindColors.accent,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? IronMindColors.accent.withValues(alpha: 0.14)
              : IronMindColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? IronMindColors.accent : IronMindColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? IronMindColors.accent.withValues(alpha: 0.18)
                    : IronMindColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: selected
                    ? IronMindColors.accent
                    : IronMindColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.bebasNeue(
                      color: selected
                          ? IronMindColors.accent
                          : IronMindColors.textPrimary,
                      fontSize: 18,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      color: IronMindColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: selected
                  ? IronMindColors.accent
                  : IronMindColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedPicker extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentedPicker({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IronMindColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? IronMindColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option,
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

class _LiftField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffixText;

  const _LiftField({
    required this.label,
    required this.controller,
    this.suffixText = 'lbs',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
      style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
      decoration: InputDecoration(labelText: label, suffixText: suffixText),
    );
  }
}
