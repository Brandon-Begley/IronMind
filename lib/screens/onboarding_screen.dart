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
  final _startWeightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _squatController = TextEditingController();
  final _benchController = TextEditingController();
  final _deadliftController = TextEditingController();
  final _ohpController = TextEditingController();
  String _experience = 'intermediate';
  String _goal = 'peak-strength';
  String _style = 'strength';
  String _weakPoint = 'none';
  double _trainingDays = 4;
  double _sessionLength = 75;
  final Set<String> _equipment = <String>{};
  bool _saving = false;

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

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final current = await ApiService.getLifterProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = current['name']?.toString() ?? '';
      _currentWeightController.text =
          current['bodyweight']?.toString() ??
          current['weight']?.toString() ??
          '';
      _startWeightController.text = current['startWeight']?.toString() ?? '';
      _targetWeightController.text = current['goalWeight']?.toString() ?? '';
      _squatController.text = current['squat']?.toString() ?? '';
      _benchController.text = current['bench']?.toString() ?? '';
      _deadliftController.text = current['deadlift']?.toString() ?? '';
      _ohpController.text = current['ohp']?.toString() ?? '';
      _experience = current['experience']?.toString() ?? _experience;
      _goal = current['goal']?.toString() ?? _goal;
      _style = current['style']?.toString() ?? _style;
      _weakPoint = current['weakpoint']?.toString() ?? _weakPoint;
      _trainingDays =
          (current['trainingDays'] as num?)?.toDouble() ?? _trainingDays;
      _sessionLength =
          (current['sessionLength'] as num?)?.toDouble() ?? _sessionLength;
      _equipment
        ..clear()
        ..addAll(List<String>.from(current['equipment'] ?? const []));
    });
  }

  Future<void> _finish() async {
    setState(() => _saving = true);

    final current = await ApiService.getLifterProfile();
    current['name'] = _nameController.text.trim();
    current['experience'] = _experience;
    current['goal'] = _goal;
    current['bodyweight'] = _currentWeightController.text.trim();
    current['weight'] = _currentWeightController.text.trim();
    current['startWeight'] = _startWeightController.text.trim();
    current['goalWeight'] = _targetWeightController.text.trim();
    current['style'] = _style;
    current['weakpoint'] = _weakPoint;
    current['trainingDays'] = _trainingDays.round();
    current['sessionLength'] = _sessionLength.round();
    current['equipment'] = _equipment.toList();
    current['squat'] = _squatController.text.trim();
    current['bench'] = _benchController.text.trim();
    current['deadlift'] = _deadliftController.text.trim();
    current['ohp'] = _ohpController.text.trim();
    current['currentSquat'] =
        double.tryParse(_squatController.text.trim()) ?? 0;
    current['currentBench'] =
        double.tryParse(_benchController.text.trim()) ?? 0;
    current['currentDeadlift'] =
        double.tryParse(_deadliftController.text.trim()) ?? 0;
    current['currentOhp'] = double.tryParse(_ohpController.text.trim()) ?? 0;

    await ApiService.saveLifterProfile(current);
    await ApiService.completeOnboarding();
    await widget.onComplete();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentWeightController.dispose();
    _startWeightController.dispose();
    _targetWeightController.dispose();
    _squatController.dispose();
    _benchController.dispose();
    _deadliftController.dispose();
    _ohpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'WELCOME TO IRONMIND',
                  style: GoogleFonts.bebasNeue(
                    color: IronMindColors.textPrimary,
                    fontSize: 36,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Set your goal, current numbers, and target weight so your training starts in the right place.',
                  style: GoogleFonts.dmSans(
                    color: IronMindColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Athlete',
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        style: GoogleFonts.dmSans(
                          color: IronMindColors.textPrimary,
                        ),
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _experience,
                        dropdownColor: IronMindColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Experience',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'beginner',
                            child: Text('Beginner'),
                          ),
                          DropdownMenuItem(
                            value: 'intermediate',
                            child: Text('Intermediate'),
                          ),
                          DropdownMenuItem(
                            value: 'advanced',
                            child: Text('Advanced'),
                          ),
                          DropdownMenuItem(
                            value: 'elite',
                            child: Text('Elite'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setState(() => _experience = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Training Setup',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _style,
                        dropdownColor: IronMindColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Training Style',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'powerlifting',
                            child: Text('Powerlifting'),
                          ),
                          DropdownMenuItem(
                            value: 'powerbuilding',
                            child: Text('Powerbuilding'),
                          ),
                          DropdownMenuItem(
                            value: 'strength',
                            child: Text('General Strength'),
                          ),
                          DropdownMenuItem(
                            value: 'hypertrophy',
                            child: Text('Hypertrophy / Bodybuilding'),
                          ),
                          DropdownMenuItem(
                            value: 'athletic',
                            child: Text('Athletic Performance'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _style = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _weakPoint,
                        dropdownColor: IronMindColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Weak Point',
                        ),
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
                        onChanged: (value) =>
                            setState(() => _trainingDays = value),
                      ),
                      const SizedBox(height: 12),
                      _SliderField(
                        label: 'Session Length',
                        value: _sessionLength,
                        min: 30,
                        max: 120,
                        divisions: 6,
                        suffix: '${_sessionLength.round()} min',
                        onChanged: (value) =>
                            setState(() => _sessionLength = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Goals',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _goal,
                        dropdownColor: IronMindColors.surface,
                        decoration: const InputDecoration(
                          labelText: 'Primary Goal',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'peak-strength',
                            child: Text('Peak Strength'),
                          ),
                          DropdownMenuItem(
                            value: 'hypertrophy',
                            child: Text('Build Muscle'),
                          ),
                          DropdownMenuItem(
                            value: 'lose-fat',
                            child: Text('Cut Body Fat'),
                          ),
                          DropdownMenuItem(
                            value: 'fitness',
                            child: Text('General Fitness'),
                          ),
                          DropdownMenuItem(
                            value: 'athletic',
                            child: Text('Athletic Performance'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _goal = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startWeightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GoogleFonts.dmMono(
                                color: IronMindColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Starting Weight',
                                suffixText: 'lbs',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _targetWeightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: GoogleFonts.dmMono(
                                color: IronMindColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Target Weight',
                                suffixText: 'lbs',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _currentWeightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GoogleFonts.dmMono(
                          color: IronMindColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Current Weight',
                          suffixText: 'lbs',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Equipment',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _equipmentOptions.map((item) {
                      final selected = _equipment.contains(item);
                      return FilterChip(
                        label: Text(item),
                        selected: selected,
                        selectedColor: IronMindColors.accent.withValues(
                          alpha: 0.18,
                        ),
                        checkmarkColor: IronMindColors.accent,
                        side: const BorderSide(color: IronMindColors.border),
                        labelStyle: GoogleFonts.dmSans(
                          color: selected
                              ? IronMindColors.textPrimary
                              : IronMindColors.textSecondary,
                          fontSize: 12,
                        ),
                        onSelected: (value) {
                          setState(() {
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
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Current Strength',
                  child: Column(
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
                            child: _LiftField(
                              label: 'OHP',
                              controller: _ohpController,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _finish,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'START TRAINING',
                            style: GoogleFonts.bebasNeue(letterSpacing: 1.5),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: IronMindColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IronMindColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.bebasNeue(
              color: IronMindColors.accent,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LiftField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _LiftField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.dmMono(color: IronMindColors.textPrimary),
      decoration: InputDecoration(labelText: '$label 1RM', suffixText: 'lbs'),
    );
  }
}
