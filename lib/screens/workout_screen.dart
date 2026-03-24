import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../services/api_service.dart';
import '../services/csv_service.dart';

class WorkoutScreen extends StatefulWidget {
  final bool connected;
  const WorkoutScreen({super.key, this.connected = false});
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _workoutActive = false;
  int _elapsed = 0;
  Timer? _timer;
  String _workoutName = '';
  String _workoutFocus = '';
  final List<_ExerciseEntry> _exercises = [];

  @override
  void initState() { super.initState(); _tabs = TabController(length: 5, vsync: this); }

  @override
  void dispose() { _tabs.dispose(); _timer?.cancel(); super.dispose(); }

  String get _timerLabel {
    final h = _elapsed ~/ 3600;
    final m = (_elapsed % 3600) ~/ 60;
    final s = _elapsed % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  void _startWorkout() {
    setState(() { _workoutActive = true; _elapsed = 0; _exercises.clear(); _exercises.add(_ExerciseEntry()); });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _elapsed++); });
  }

  void _showRoutineSelection() async {
    final routines = await ApiService.getRoutines();
    if (!mounted) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('SELECT ROUTINE', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
          const SizedBox(height: 16),
          ...routines.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: IronButton(
              label: r['name'] as String,
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _workoutName = r['name'];
                  _workoutFocus = (r['primary'] as List?)?.join(', ') ?? '';
                  _exercises.clear();
                  for (final ex in r['exercises'] as List) {
                    _exercises.add(_ExerciseEntry(name: ex as String));
                  }
                  if (_exercises.isNotEmpty) {
                    _workoutActive = true;
                    _elapsed = 0;
                    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _elapsed++); });
                  }
                });
              },
            ),
          )),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () { Navigator.pop(ctx); _startWorkout(); },
            style: OutlinedButton.styleFrom(foregroundColor: IronMindTheme.text2, side: BorderSide(color: IronMindTheme.border2)),
            child: Text('START EMPTY', style: GoogleFonts.dmMono(fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  void _finishWorkout() async {
    _timer?.cancel();
    final data = _exercises.where((e) => e.name.isNotEmpty).map((e) => {
      'name': e.name,
      'sets': e.sets.length,
      'reps': e.sets.isNotEmpty ? e.sets.last.reps : 0,
      'weight': e.sets.isNotEmpty ? e.sets.last.weight : 0,
    }).toList();
    if (data.isNotEmpty) {
      try {
        await ApiService.saveLog({'date': DateTime.now().toIso8601String().split('T')[0], 'program_name': _workoutName, 'day_name': _workoutName.isEmpty ? 'Workout' : _workoutName, 'focus': _workoutFocus, 'exercises': data, 'notes': ''});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout saved!'), backgroundColor: IronMindTheme.green));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server offline — workout not saved'), backgroundColor: IronMindTheme.orange));
      }
    }
    setState(() { _workoutActive = false; _elapsed = 0; _exercises.clear(); _workoutName = ''; _workoutFocus = ''; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IronMindTheme.bg,
      appBar: IronMindAppBar(
        subtitle: _workoutActive ? _timerLabel : 'Workout',
        connected: widget.connected,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _workoutActive
                ? OutlinedButton(
                    onPressed: _finishWorkout,
                    style: OutlinedButton.styleFrom(foregroundColor: IronMindTheme.red, side: BorderSide(color: IronMindTheme.red.withOpacity(0.4)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text('FINISH', style: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1)),
                  )
                : ElevatedButton(
                    onPressed: _showRoutineSelection,
                    style: ElevatedButton.styleFrom(backgroundColor: IronMindTheme.accent, foregroundColor: IronMindTheme.bg, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), minimumSize: Size.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: Text('START', style: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1)),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: IronMindTheme.accent, unselectedLabelColor: IronMindTheme.text3,
          indicatorColor: IronMindTheme.accent, indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: GoogleFonts.dmMono(fontSize: 9), unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 9),
          isScrollable: true, tabAlignment: TabAlignment.start,
          tabs: const [Tab(text: 'Log'), Tab(text: 'Routines'), Tab(text: 'Records'), Tab(text: 'Profile'), Tab(text: 'AI')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _workoutActive
              ? _ActiveWorkoutTab(exercises: _exercises, onNameChanged: (v) => setState(() => _workoutName = v), onFocusChanged: (v) => setState(() => _workoutFocus = v), onAddExercise: () => setState(() => _exercises.add(_ExerciseEntry())), onUpdate: () => setState(() {}))
              : _LogHistoryTab(),
          _RoutinesTab(),
          const _RecordsTab(),
          const _LifterProfileTab(),
          const _AITab(),
        ],
      ),
    );
  }
}

// ── Active Workout ────────────────────────────────────────────────────────────
class _ActiveWorkoutTab extends StatelessWidget {
  final List<_ExerciseEntry> exercises;
  final ValueChanged<String> onNameChanged, onFocusChanged;
  final VoidCallback onAddExercise, onUpdate;
  const _ActiveWorkoutTab({required this.exercises, required this.onNameChanged, required this.onFocusChanged, required this.onAddExercise, required this.onUpdate});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
    child: Column(children: [
      Row(children: [
        Expanded(child: TextField(onChanged: onNameChanged, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Workout Name', hintText: 'e.g. Squat Day'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(onChanged: onFocusChanged, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Focus', hintText: 'e.g. Squat'))),
      ]),
      const SizedBox(height: 12),
      ...exercises.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ExerciseCard(entry: e.value, onUpdate: onUpdate, onRemove: exercises.length > 1 ? () { exercises.removeAt(e.key); onUpdate(); } : null),
      )),
      const SizedBox(height: 8),
      IronButton(label: '+ ADD EXERCISE', onPressed: onAddExercise),
    ]),
  );
}

class _ExerciseEntry { 
  String name; 
  List<_SetEntry> sets;
  _ExerciseEntry({this.name = '', List<_SetEntry>? sets}) : sets = sets ?? [_SetEntry()];
}
class _SetEntry {
  double weight = 0; int reps = 0; bool done = false;
  final TextEditingController weightCtrl = TextEditingController();
  final TextEditingController repsCtrl = TextEditingController();
}

class _ExerciseCard extends StatefulWidget {
  final _ExerciseEntry entry;
  final VoidCallback onUpdate;
  final VoidCallback? onRemove;
  const _ExerciseCard({required this.entry, required this.onUpdate, this.onRemove});
  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _resting = false;

  void _startRest(int s) {
    _restTimer?.cancel();
    setState(() { _resting = true; _restSeconds = s; });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restSeconds <= 0) { t.cancel(); setState(() => _resting = false); HapticFeedback.heavyImpact(); }
      else {
        setState(() => _restSeconds--);
      }
    });
  }

  @override
  void dispose() { _restTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(
          onChanged: (v) => e.name = v,
          style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
          decoration: const InputDecoration(hintText: 'Exercise name', border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
        )),
        if (widget.onRemove != null)
          GestureDetector(onTap: widget.onRemove, child: const Icon(Icons.close, color: IronMindTheme.text3, size: 18)),
      ]),
      if (_resting) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: IronMindTheme.accentDim, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('REST', style: GoogleFonts.dmMono(color: IronMindTheme.accent, fontSize: 10, letterSpacing: 1)),
            Text('${_restSeconds}s', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 22, letterSpacing: 1)),
            GestureDetector(onTap: () { _restTimer?.cancel(); setState(() => _resting = false); }, child: const Icon(Icons.close, color: IronMindTheme.accent, size: 16)),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      Row(children: [
        const SizedBox(width: 28, child: Text('SET', style: TextStyle(color: IronMindTheme.text3, fontSize: 9, fontFamily: 'monospace'), textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('PREV', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9), textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('LBS', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9), textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('REPS', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9), textAlign: TextAlign.center)),
        const SizedBox(width: 36),
      ]),
      const SizedBox(height: 4),
      ...e.sets.asMap().entries.map((entry) {
        final i = entry.key; final s = entry.value;
        final prev = i > 0 ? '${e.sets[i-1].weight.toInt()}×${e.sets[i-1].reps}' : '—';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${i+1}', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 11), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(prev, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10), textAlign: TextAlign.center)),
            Expanded(flex: 2, child: TextField(
              controller: s.weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmMono(color: s.done ? IronMindTheme.green : IronMindTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(hintText: '0', hintStyle: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 14), border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
              onChanged: (v) => s.weight = double.tryParse(v) ?? 0,
            )),
            Expanded(flex: 2, child: TextField(
              controller: s.repsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmMono(color: s.done ? IronMindTheme.green : IronMindTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(hintText: '0', hintStyle: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 14), border: InputBorder.none, filled: false, contentPadding: EdgeInsets.zero),
              onChanged: (v) => s.reps = int.tryParse(v) ?? 0,
            )),
            GestureDetector(
              onTap: () {
                setState(() => s.done = !s.done);
                if (s.done) {
                  HapticFeedback.mediumImpact();
                  _startRest(90);
                  if (s.weight > 0 && s.reps > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('e1RM: ~${ApiService.calculate1RM(s.weight, s.reps).round()}lb', style: GoogleFonts.dmMono(fontSize: 12)),
                      backgroundColor: IronMindTheme.surface2, duration: const Duration(seconds: 2),
                    ));
                  }
                }
              },
              child: SizedBox(width: 36, child: Center(child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, color: s.done ? IronMindTheme.green : Colors.transparent, border: Border.all(color: s.done ? IronMindTheme.green : IronMindTheme.border2, width: 1.5)),
                child: s.done ? const Icon(Icons.check, color: Colors.black, size: 13) : null,
              ))),
            ),
          ]),
        );
      }),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => setState(() => e.sets.add(_SetEntry())),
          style: OutlinedButton.styleFrom(foregroundColor: IronMindTheme.text2, side: const BorderSide(color: IronMindTheme.border2), padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: Text('+ Set', style: GoogleFonts.dmMono(fontSize: 10)),
        )),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showRestPicker(context),
          style: OutlinedButton.styleFrom(foregroundColor: IronMindTheme.accent, side: BorderSide(color: IronMindTheme.accent.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.timer_outlined, size: 14), const SizedBox(width: 4), Text('Rest', style: GoogleFonts.dmMono(fontSize: 10, color: IronMindTheme.accent))]),
        ),
      ]),
    ]));
  }

  void _showRestPicker(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('REST TIMER', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 20, letterSpacing: 2)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [60, 90, 120, 180, 240, 300].map((s) => GestureDetector(
            onTap: () { Navigator.pop(context); _startRest(s); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(8), border: Border.all(color: IronMindTheme.border2)),
              child: Text(s >= 60 ? '${s ~/ 60}m${s % 60 > 0 ? "${s % 60}s" : ""}' : '${s}s', style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 18)),
            ),
          )).toList()),
        ]),
      ),
    );
  }
}

// ── Log History ───────────────────────────────────────────────────────────────
class _LogHistoryTab extends StatefulWidget {
  @override
  State<_LogHistoryTab> createState() => _LogHistoryTabState();
}
class _LogHistoryTabState extends State<_LogHistoryTab> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final l = await ApiService.getLogs(); setState(() { _logs = l; _loading = false; }); }
    catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    if (_logs.isEmpty) return const EmptyState(icon: '🏋️', title: 'No Workouts Yet', sub: 'Tap START to log your first workout');
    return RefreshIndicator(
      color: IronMindTheme.accent, backgroundColor: IronMindTheme.surface2, onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _logs.length,
        itemBuilder: (ctx, i) {
          final log = _logs[i];
          final exs = log['exercises'] as List? ?? [];
          return Dismissible(
            key: Key('log-${log['id']}'),
            direction: DismissDirection.endToStart,
            background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: IronMindTheme.redDim, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: IronMindTheme.red)),
            onDismissed: (_) => ApiService.deleteLog(log['id']),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(log['day_name'] ?? 'Workout', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 18, letterSpacing: 1))),
                  IronBadge(log['date'] ?? '', color: IronMindTheme.text3),
                ]),
                if ((log['focus'] ?? '').isNotEmpty) Text(log['focus'], style: GoogleFonts.dmMono(color: IronMindTheme.accent, fontSize: 10)),
                if (exs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...exs.take(3).map((ex) => Text('• ${ex['name']} — ${ex['weight']}lb × ${ex['sets']}×${ex['reps']}', style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 10))),
                  if (exs.length > 3) Text('+ ${exs.length - 3} more exercises', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                ],
              ])),
            ),
          );
        },
      ),
    );
  }
}

// ── Routines ──────────────────────────────────────────────────────────────────
class _RoutinesTab extends StatefulWidget {
  @override
  State<_RoutinesTab> createState() => _RoutinesTabState();
}
class _RoutinesTabState extends State<_RoutinesTab> {
  List<Map<String, dynamic>> _routines = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await ApiService.getRoutines();
    setState(() { _routines = r; _loading = false; });
  }

  void _showCreate() {
    final nameCtrl = TextEditingController();
    final exCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CREATE ROUTINE', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
          const SizedBox(height: 14),
          TextField(controller: nameCtrl, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Routine Name', hintText: 'e.g. Squat Day')),
          const SizedBox(height: 10),
          TextField(controller: exCtrl, maxLines: 3, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Exercises (one per line)', hintText: 'Back Squat\nLeg Press\nRDL')),
          const SizedBox(height: 14),
          IronButton(label: 'CREATE ROUTINE', onPressed: () async {
            if (nameCtrl.text.isEmpty) return;
            final exercises = exCtrl.text.split('\n').where((e) => e.trim().isNotEmpty).toList();
            await ApiService.saveRoutine({
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'name': nameCtrl.text,
              'exercises': exercises,
              'primary': [], 'secondary': [],
            });
            Navigator.pop(ctx);
            _load();
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      if (file.bytes == null) return;

      final csvContent = String.fromCharCodes(file.bytes!);
      final routines = await CSVService.parseRoutineCSV(csvContent);
      
      for (final routine in routines) {
        await ApiService.saveRoutine(routine);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${routines.length} routine(s)!'), backgroundColor: IronMindTheme.green),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: IronMindTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        Row(children: [
          Expanded(child: IronButton(label: '+ CREATE ROUTINE', onPressed: _showCreate)),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _importCSV,
            style: ElevatedButton.styleFrom(backgroundColor: IronMindTheme.accent, foregroundColor: IronMindTheme.bg, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), minimumSize: Size.zero, elevation: 0),
            child: const Icon(Icons.upload_file, size: 20),
          ),
        ]),
        const SizedBox(height: 12),
        ..._routines.asMap().entries.map((entry) {
          final r = entry.value;
          final exs = (r['exercises'] as List? ?? []);
          return Dismissible(
            key: Key('routine-${r['id']}'),
            direction: DismissDirection.endToStart,
            background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: IronMindTheme.redDim, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: IronMindTheme.red)),
            confirmDismiss: (_) async {
              return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                backgroundColor: IronMindTheme.surface2,
                title: Text('Delete Routine?', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 18)),
                content: Text('This cannot be undone.', style: GoogleFonts.dmSans(color: IronMindTheme.text2)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.dmMono(color: IronMindTheme.text2))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.dmMono(color: IronMindTheme.red))),
                ],
              ));
            },
            onDismissed: (_) async { await ApiService.deleteRoutine(r['id']); _load(); },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r['name'] ?? '', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14))),
                  IronGhostButton(label: 'START', color: IronMindTheme.accent, onPressed: () {}),
                ]),
                if (exs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(exs.take(3).join(' · '), style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (exs.length > 3) Text('+ ${exs.length - 3} more', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                ],
                if ((r['primary'] as List? ?? []).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, children: [
                    ...(r['primary'] as List).map((m) => MuscleTag(m as String, primary: true)),
                    ...(r['secondary'] as List? ?? []).map((m) => MuscleTag(m as String, primary: false)),
                  ]),
                ],
              ])),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Records ───────────────────────────────────────────────────────────────────
class _RecordsTab extends StatefulWidget {
  const _RecordsTab();
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}
class _RecordsTabState extends State<_RecordsTab> {
  List<Map<String, dynamic>> _prs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final p = await ApiService.getPRs(); setState(() { _prs = p; _loading = false; }); }
    catch (_) { setState(() => _loading = false); }
  }

  void _show1RM() {
    final wC = TextEditingController(); 
    final rC = TextEditingController();
    String result = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        void calc() {
          final w = double.tryParse(wC.text) ?? 0; 
          final r = int.tryParse(rC.text) ?? 0;
          if (w > 0 && r > 0) {
            set(() => result = '~${ApiService.calculate1RM(w, r).round()}lb');
          } else {
            set(() => result = '');
          }
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('1RM CALCULATOR', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextField(controller: wC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Weight (lbs)'), onChanged: (_) => calc())),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: rC, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Reps'), onChanged: (_) => calc())),
              ]),
              if (result.isNotEmpty) ...[
                const SizedBox(height: 24),
                Center(child: Column(children: [
                  Text('ESTIMATED 1RM', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 11, letterSpacing: 1)),
                  Text(result, style: GoogleFonts.bebasNeue(color: IronMindTheme.accent, fontSize: 52, letterSpacing: 2)),
                  Text('Epley formula', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 9)),
                ])),
              ],
              const SizedBox(height: 8),
            ]),
          ),
        );
      }),
    );
  }

  void _showAddPR() {
    final eC = TextEditingController(); 
    final wC = TextEditingController(); 
    final rC = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: IronMindTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        Map<String, dynamic>? lastPR;
        bool isNewPR = false;
        
        void checkPR() async {
          final exercise = eC.text.trim();
          final weight = double.tryParse(wC.text) ?? 0;
          
          if (exercise.isNotEmpty && weight > 0) {
            lastPR = await ApiService.getLastPRForExercise(exercise);
            isNewPR = weight > ((lastPR?['weight'] as num?) ?? 0);
            set(() {});
          }
        }
        
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LOG PR', style: GoogleFonts.bebasNeue(color: IronMindTheme.textPrimary, fontSize: 22, letterSpacing: 2)),
              const SizedBox(height: 14),
              TextField(
                controller: eC, 
                style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), 
                decoration: const InputDecoration(labelText: 'Exercise'),
                onChanged: (_) => checkPR(),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(
                  controller: wC, 
                  keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                  style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), 
                  decoration: const InputDecoration(labelText: 'Weight (lbs)'),
                  onChanged: (_) => checkPR(),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: rC, 
                  keyboardType: TextInputType.number, 
                  style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), 
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (_) => checkPR(),
                )),
              ]),
              if (lastPR != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isNewPR ? IronMindTheme.greenDim : IronMindTheme.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isNewPR ? IronMindTheme.green : IronMindTheme.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isNewPR ? '🔥 NEW PR!' : 'Previous PR',
                      style: GoogleFonts.bebasNeue(
                        color: isNewPR ? IronMindTheme.green : IronMindTheme.text2,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lastPR!['weight']}lb × ${lastPR!['reps']}',
                      style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From ${_daysSince(lastPR!['date'] as String)}',
                      style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              IronButton(label: 'SAVE PR', onPressed: () async {
                if (eC.text.isEmpty || wC.text.isEmpty || rC.text.isEmpty) return;
                try {
                  await ApiService.savePR({
                    'exercise': eC.text,
                    'weight': double.parse(wC.text),
                    'reps': int.parse(rC.text),
                    'date': DateTime.now().toIso8601String().split('T')[0],
                    'notes': ''
                  });
                  Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isNewPR ? '🔥 New PR!' : 'PR logged!'),
                        backgroundColor: isNewPR ? IronMindTheme.green : IronMindTheme.accent,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: IronMindTheme.red),
                    );
                  }
                  Navigator.pop(ctx);
                }
              }),
              const SizedBox(height: 8),
            ]),
          ),
        );
      }),
    );
  }
  
  String _daysSince(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date).inDays;
      if (diff == 0) return 'today';
      if (diff == 1) return 'yesterday';
      if (diff < 7) return '$diff days ago';
      if (diff < 30) return '${(diff / 7).ceil()} weeks ago';
      return '${(diff / 30).ceil()} months ago';
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        Row(children: [
          Expanded(child: IronButton(label: '+ LOG PR', onPressed: _showAddPR)),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton(
            onPressed: _show1RM,
            style: OutlinedButton.styleFrom(foregroundColor: IronMindTheme.accent, side: BorderSide(color: IronMindTheme.accent.withOpacity(0.3)), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7))),
            child: Text('1RM CALC', style: GoogleFonts.bebasNeue(fontSize: 16, letterSpacing: 1, color: IronMindTheme.accent)),
          )),
        ]),
        const SizedBox(height: 12),
        _prs.isEmpty
            ? const EmptyState(icon: '🏆', title: 'No Records Yet', sub: 'Log workouts or add PRs manually')
            : IronCard(padding: EdgeInsets.zero, child: Column(children: _prs.asMap().entries.map((e) {
                final pr = e.value; final isLast = e.key == _prs.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: IronMindTheme.border))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(pr['exercise'] ?? '', style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontWeight: FontWeight.w500)),
                      Text(pr['date'] ?? '', style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
                    ])),
                    Wrap(spacing: 5, children: [
                      IronBadge('${pr['weight']}lb × ${pr['reps']}', color: IronMindTheme.accent),
                      if (pr['estimated_1rm'] != null) IronBadge('~${pr['estimated_1rm']}lb e1RM', color: IronMindTheme.green),
                    ]),
                  ]),
                );
              }).toList())),
      ]),
    );
  }
}

// ── Lifter Profile (moved from Profile screen) ────────────────────────────────
class _LifterProfileTab extends StatefulWidget {
  const _LifterProfileTab();
  @override
  State<_LifterProfileTab> createState() => _LifterProfileTabState();
}
class _LifterProfileTabState extends State<_LifterProfileTab> {
  Map<String, dynamic> _p = {};
  bool _loaded = false, _saving = false;
  final _nameCtrl = TextEditingController();
  final _bwCtrl = TextEditingController();
  final _squatCtrl = TextEditingController();
  final _benchCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();
  final _ohpCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await ApiService.getLifterProfile();
    setState(() {
      _p = p; _nameCtrl.text = p['name'] ?? ''; _bwCtrl.text = p['bodyweight'] ?? '';
      _squatCtrl.text = p['squat'] ?? ''; _benchCtrl.text = p['bench'] ?? '';
      _dlCtrl.text = p['deadlift'] ?? ''; _ohpCtrl.text = p['ohp'] ?? ''; _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _p['name'] = _nameCtrl.text; _p['bodyweight'] = _bwCtrl.text;
    _p['squat'] = _squatCtrl.text; _p['bench'] = _benchCtrl.text;
    _p['deadlift'] = _dlCtrl.text; _p['ohp'] = _ohpCtrl.text;
    await ApiService.saveLifterProfile(_p);
    setState(() => _saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved! AI will now use your stats.'), backgroundColor: IronMindTheme.green));
  }

  Widget _drop(String label, String key, Map<String, String> items) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: IronDropdown(label: label, value: _p[key] ?? items.keys.first, items: items, onChanged: (v) => setState(() => _p[key] = v)),
  );

  Widget _maxField(String label, TextEditingController ctrl) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
    const SizedBox(height: 4),
    TextField(controller: ctrl, keyboardType: TextInputType.number, style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 14), decoration: const InputDecoration(suffixText: 'lb')),
  ]);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: IronMindTheme.accent));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: IronMindTheme.accentDim, borderRadius: BorderRadius.circular(10), border: Border.all(color: IronMindTheme.accent.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: IronMindTheme.accent, size: 16),
            const SizedBox(width: 10),
            Expanded(child: Text('Your profile is used by the AI generator to create personalized workouts.', style: GoogleFonts.dmSans(color: IronMindTheme.accent, fontSize: 11))),
          ]),
        ),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Personal'),
          const SizedBox(height: 10),
          TextField(controller: _nameCtrl, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(controller: _bwCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: GoogleFonts.dmMono(color: IronMindTheme.textPrimary, fontSize: 13), decoration: const InputDecoration(labelText: 'Bodyweight (lbs)', suffixText: 'lbs')),
        ])),
        const SizedBox(height: 10),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Training Style'),
          const SizedBox(height: 10),
          _drop('Training Focus', 'style', {'powerlifting': 'Powerlifting (SBD)', 'powerbuilding': 'Powerbuilding', 'strength': 'General Strength', 'hypertrophy': 'Hypertrophy / Bodybuilding', 'olympic': 'Olympic Lifting', 'crossfit': 'CrossFit / Functional', 'athletic': 'Athletic Performance'}),
          _drop('Experience Level', 'experience', {'beginner': 'Beginner (0–1 yr)', 'intermediate': 'Intermediate (1–3 yr)', 'advanced': 'Advanced (3+ yr)', 'elite': 'Elite / Competitor'}),
          IronSlider(label: 'Training Days / Week', value: (_p['trainingDays'] as num?)?.toDouble() ?? 4, min: 2, max: 7, divisions: 5, format: (v) => '${v.toInt()} days', onChanged: (v) => setState(() => _p['trainingDays'] = v)),
          IronSlider(label: 'Session Length', value: (_p['sessionLength'] as num?)?.toDouble() ?? 75, min: 30, max: 120, divisions: 6, format: (v) => '${v.toInt()} min', onChanged: (v) => setState(() => _p['sessionLength'] = v)),
        ])),
        const SizedBox(height: 10),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Current Maxes (lbs)'),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _maxField('Squat 1RM', _squatCtrl)), const SizedBox(width: 10), Expanded(child: _maxField('Bench 1RM', _benchCtrl))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _maxField('Deadlift 1RM', _dlCtrl)), const SizedBox(width: 10), Expanded(child: _maxField('OHP 1RM', _ohpCtrl))]),
        ])),
        const SizedBox(height: 10),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Goals'),
          const SizedBox(height: 10),
          _drop('Primary Goal', 'goal', {'peak-strength': 'Peak Strength / Meet Prep', 'hypertrophy': 'Add Muscle Mass', 'total': 'Increase Total', 'weak-points': 'Bring Up Weak Points', 'fitness': 'General Fitness', 'lose-fat': 'Lose Body Fat', 'athletic': 'Athletic Performance'}),
          _drop('Weak Point', 'weakpoint', {'none': 'None / Balanced', 'squat-depth': 'Squat — depth', 'squat-lockout': 'Squat — lockout', 'bench-bottom': 'Bench — off chest', 'bench-lockout': 'Bench — lockout', 'deadlift-floor': 'Deadlift — off floor', 'deadlift-lockout': 'Deadlift — lockout'}),
        ])),
        const SizedBox(height: 10),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Equipment Available'),
          const SizedBox(height: 8),
          ...['Barbell', 'Dumbbells', 'Cable Machine', 'Safety Squat Bar', 'Bands / Chains', 'Leg Press', 'Smith Machine', 'Kettlebells'].map((eq) {
            final equip = List<String>.from(_p['equipment'] ?? []);
            return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
              SizedBox(width: 20, height: 20, child: Checkbox(
                value: equip.contains(eq),
                onChanged: (v) => setState(() { if (v == true) {
                  equip.add(eq);
                } else {
                  equip.remove(eq);
                } _p['equipment'] = equip; }),
                activeColor: IronMindTheme.accent, checkColor: IronMindTheme.bg,
                side: const BorderSide(color: IronMindTheme.border2), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
              const SizedBox(width: 10),
              Text(eq, style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 13)),
            ]));
          }),
        ])),
        const SizedBox(height: 14),
        IronButton(label: 'SAVE PROFILE', onPressed: _save, loading: _saving),
      ]),
    );
  }

  @override
  void dispose() { _nameCtrl.dispose(); _bwCtrl.dispose(); _squatCtrl.dispose(); _benchCtrl.dispose(); _dlCtrl.dispose(); _ohpCtrl.dispose(); super.dispose(); }
}

// ── AI Tab ────────────────────────────────────────────────────────────────────
class _AITab extends StatefulWidget {
  const _AITab();
  @override
  State<_AITab> createState() => _AITabState();
}
class _AITabState extends State<_AITab> {
  final _ctrl = TextEditingController();
  String _output = '';
  bool _loading = false;
  Map<String, dynamic> _profile = {};

  final _chips = ['Squat Day', 'Bench Day', 'Pull Day', 'Full Body', 'Deload', 'Hypertrophy', 'Accessory Work', 'GPP'];
  final _prompts = {
    'Squat Day': 'Generate a squat-focused training day with warm-up, main work, and accessories.',
    'Bench Day': 'Generate a bench press focused day with competition-style work and upper body accessories.',
    'Pull Day': 'Generate a pull day with deadlifts or rows as main lift, plus lat and bicep work.',
    'Full Body': 'Generate a full body training day hitting all major muscle groups with compound movements.',
    'Deload': 'Generate a deload week at 50-60% intensity with reduced volume for recovery.',
    'Hypertrophy': 'Generate a hypertrophy day with 8-15 rep ranges, higher volume, and muscle isolation.',
    'Accessory Work': 'Generate a light accessory session targeting weak points and muscle balance.',
    'GPP': 'Generate a general physical preparedness session for conditioning and movement quality.',
  };

  @override
  void initState() { super.initState(); _loadProfile(); }

  Future<void> _loadProfile() async {
    final p = await ApiService.getLifterProfile();
    setState(() => _profile = p);
  }

  String _buildPrompt(String base) {
    final parts = <String>[];
    if ((_profile['name'] ?? '').isNotEmpty) parts.add('Name: ${_profile['name']}');
    if ((_profile['bodyweight'] ?? '').isNotEmpty) parts.add('Bodyweight: ${_profile['bodyweight']}lb');
    if ((_profile['squat'] ?? '').isNotEmpty) parts.add('Squat 1RM: ${_profile['squat']}lb');
    if ((_profile['bench'] ?? '').isNotEmpty) parts.add('Bench 1RM: ${_profile['bench']}lb');
    if ((_profile['deadlift'] ?? '').isNotEmpty) parts.add('Deadlift 1RM: ${_profile['deadlift']}lb');
    if ((_profile['ohp'] ?? '').isNotEmpty) parts.add('OHP 1RM: ${_profile['ohp']}lb');
    parts.add('Experience: ${_profile['experience'] ?? 'intermediate'}');
    parts.add('Style: ${_profile['style'] ?? 'general strength'}');
    parts.add('Goal: ${_profile['goal'] ?? 'general fitness'}');
    if ((_profile['weakpoint'] ?? 'none') != 'none') parts.add('Weak point: ${_profile['weakpoint']}');
    final equip = List<String>.from(_profile['equipment'] ?? []);
    if (equip.isNotEmpty) parts.add('Equipment: ${equip.join(', ')}');
    return '$base\n\nAthlete profile: ${parts.join(' | ')}';
  }

  bool get _profileComplete => (_profile['squat'] ?? '').isNotEmpty || (_profile['bench'] ?? '').isNotEmpty;

  Future<void> _generate() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _output = ''; });
    try {
      final result = await ApiService.generateWorkout(_buildPrompt(_ctrl.text.trim()));
      setState(() => _output = result);
    } catch (_) {
      setState(() => _output = 'Cannot connect to server. Start your backend and update the URL in Profile → Settings.');
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_profileComplete)
          Container(
            padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: IronMindTheme.blueDim, borderRadius: BorderRadius.circular(10), border: Border.all(color: IronMindTheme.blue.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: IronMindTheme.blue, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text('Fill out your Lifter Profile tab to get personalized AI workouts.', style: GoogleFonts.dmSans(color: IronMindTheme.blue, fontSize: 11))),
            ]),
          ),
        if (_profileComplete)
          IronCard2(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IronLabel('Using Your Profile'),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if ((_profile['squat'] ?? '').isNotEmpty) IronBadge('Squat: ${_profile['squat']}lb', color: IronMindTheme.accent),
              if ((_profile['bench'] ?? '').isNotEmpty) IronBadge('Bench: ${_profile['bench']}lb', color: IronMindTheme.green),
              if ((_profile['deadlift'] ?? '').isNotEmpty) IronBadge('DL: ${_profile['deadlift']}lb', color: IronMindTheme.blue),
              IronBadge(_profile['style'] ?? 'strength', color: IronMindTheme.purple),
              IronBadge(_profile['experience'] ?? 'intermediate', color: IronMindTheme.orange),
            ]),
          ])),
        const SizedBox(height: 10),
        IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IronLabel('Quick Prompts'),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: _chips.map((c) => GestureDetector(
            onTap: () => setState(() => _ctrl.text = _prompts[c] ?? c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(6), border: Border.all(color: IronMindTheme.border2)),
              child: Text(c, style: GoogleFonts.dmMono(color: IronMindTheme.text2, fontSize: 10)),
            ),
          )).toList()),
          const SizedBox(height: 12),
          TextField(controller: _ctrl, maxLines: 4, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13), decoration: InputDecoration(hintText: 'Describe the workout you want...', hintStyle: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 13), border: InputBorder.none, filled: false)),
          IronButton(label: 'GENERATE', onPressed: _generate, loading: _loading),
        ])),
        if (_output.isNotEmpty) ...[
          const SizedBox(height: 12),
          IronCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IronLabel('Generated Workout'),
            const SizedBox(height: 10),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: IronMindTheme.surface2, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(_output, style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13, height: 1.6))),
          ])),
        ],
      ]),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}
