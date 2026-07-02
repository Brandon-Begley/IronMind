import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/program_import_service.dart';
import '../core/theme/ironmind_theme.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

Future<void> showImportProgramSheet(
  BuildContext context, {
  void Function()? onRoutinesSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImportProgramSheet(onRoutinesSaved: onRoutinesSaved),
  );
}

// ── Bottom sheet ──────────────────────────────────────────────────────────────

enum _Step   { source, parsing, preview, saving }
enum _Source { file, googleSheets }

class _ImportProgramSheet extends StatefulWidget {
  final void Function()? onRoutinesSaved;
  const _ImportProgramSheet({this.onRoutinesSaved});

  @override
  State<_ImportProgramSheet> createState() => _ImportProgramSheetState();
}

class _ImportProgramSheetState extends State<_ImportProgramSheet> {
  _Step   _step   = _Step.source;
  _Source _source = _Source.file;

  final _urlCtrl  = TextEditingController();
  final _nameCtrl = TextEditingController();

  String?        _error;
  ParsedProgram? _parsed;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _parse(() => ProgramImportService.fromFile(File(path)));
  }

  Future<void> _fetchSheets() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste a Google Sheets share link first.');
      return;
    }
    await _parse(() => ProgramImportService.fromGoogleSheetsUrl(url));
  }

  Future<void> _parse(Future<ParsedProgram> Function() loader) async {
    setState(() { _step = _Step.parsing; _error = null; });
    try {
      final result = await loader();
      _nameCtrl.text = result.name;
      setState(() { _parsed = result; _step = _Step.preview; });
    } on FormatException catch (e) {
      setState(() { _error = e.message; _step = _Step.source; });
    } catch (e) {
      setState(() {
        _error = 'Could not read file: ${e.toString().split('\n').first}';
        _step  = _Step.source;
      });
    }
  }

  Future<void> _saveAsRoutines() async {
    if (_parsed == null) return;
    setState(() => _step = _Step.saving);
    try {
      final base = _nameCtrl.text.trim().ifEmpty(_parsed!.name);
      for (final day in _parsed!.days) {
        await ApiService.saveRoutine({
          'name':      '$base – ${day.label}',
          'exercises': day.exercises
              .map((e) => e.toRoutineExerciseName())
              .toList(),
        });
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onRoutinesSaved?.call();
        _showSnack(
          '${_parsed!.days.length} routine${_parsed!.days.length == 1 ? "" : "s"} '
          'imported to Workout tab.',
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _step = _Step.preview; });
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(fontSize: 13)),
      backgroundColor: IronMindTheme.surface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == _Step.preview ? 0.88 : 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: IronMindTheme.surface2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: IronMindTheme.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(child: _buildStep(ctrl)),
        ]),
      ),
    );
  }

  Widget _buildStep(ScrollController ctrl) {
    switch (_step) {
      case _Step.parsing:
      case _Step.saving:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: IronMindTheme.accent),
            const SizedBox(height: 16),
            Text(
              _step == _Step.parsing ? 'Reading file…' : 'Saving…',
              style: GoogleFonts.dmSans(color: IronMindTheme.text2)),
          ]),
        );
      case _Step.preview:
        return _buildPreview(ctrl);
      case _Step.source:
        return _buildSourcePicker(ctrl);
    }
  }

  // ── Source picker ──────────────────────────────────────────────────────────

  Widget _buildSourcePicker(ScrollController ctrl) {
    return ListView(
      controller: ctrl,
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      children: [
        Text('Import Program',
          style: GoogleFonts.bebasNeue(
            color: IronMindTheme.textPrimary, fontSize: 26, letterSpacing: 1.5)),
        Text(
          'Import a powerlifting or strength program from your coach\'s spreadsheet.',
          style: GoogleFonts.dmSans(
            color: IronMindTheme.text2, fontSize: 13, height: 1.4)),
        const SizedBox(height: 20),

        // Source toggle
        Row(children: [
          _SourceTab(
            label: 'File (.xlsx / .csv)',
            icon:  Icons.upload_file_outlined,
            selected: _source == _Source.file,
            onTap: () => setState(() => _source = _Source.file),
          ),
          const SizedBox(width: 8),
          _SourceTab(
            label: 'Google Sheets',
            icon:  Icons.link,
            selected: _source == _Source.googleSheets,
            onTap: () => setState(() => _source = _Source.googleSheets),
          ),
        ]),
        const SizedBox(height: 20),

        if (_source == _Source.file) ...[
          _InfoBox(
            icon: Icons.info_outline,
            text: 'Supports .xlsx (Excel) and .csv files.\n'
                'Columns are detected automatically — works with most standard '
                'powerlifting program templates.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text('Choose File',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
              onPressed: _pickFile,
            ),
          ),
        ] else ...[
          _InfoBox(
            icon: Icons.lock_open_outlined,
            text: 'All tabs (Day 1, Day 2…) are imported automatically — '
                'just paste any link from the spreadsheet.\n\n'
                'The sheet must be public:\n'
                '1. Open the sheet → Share (top-right).\n'
                '2. Change to "Anyone with the link" → Viewer → Done.\n'
                '3. Copy the URL from the address bar and paste below.\n\n'
                'Tabs named "Overview", "PR Tracker", "Training Maxes" etc. '
                'are skipped automatically.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            style: GoogleFonts.dmSans(color: IronMindTheme.textPrimary, fontSize: 13),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Google Sheets URL',
              hintText: 'https://docs.google.com/spreadsheets/d/…',
              hintStyle: GoogleFonts.dmSans(color: IronMindTheme.text3, fontSize: 12),
              prefixIcon: const Icon(Icons.link, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_outlined, size: 18),
                color: IronMindTheme.text2,
                tooltip: 'Paste',
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) _urlCtrl.text = data!.text!;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text('Fetch Sheet',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
              onPressed: _fetchSheets,
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(message: _error!),
        ],

        const SizedBox(height: 28),
        _SupportedFormatsSection(),
      ],
    );
  }

  // ── Preview ────────────────────────────────────────────────────────────────

  Widget _buildPreview(ScrollController ctrl) {
    final p = _parsed!;
    final total = p.days.fold(0, (s, d) => s + d.exercises.length);

    return ListView(
      controller: ctrl,
      padding: EdgeInsets.fromLTRB(
        20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            color: IronMindTheme.text2,
            onPressed: () => setState(() { _step = _Step.source; _error = null; }),
          ),
          const SizedBox(width: 2),
          Text('Preview & Save',
            style: GoogleFonts.bebasNeue(
              color: IronMindTheme.textPrimary, fontSize: 24, letterSpacing: 1.5)),
        ]),
        Text(
          '$total exercise${total == 1 ? "" : "s"} across '
          '${p.days.length} day${p.days.length == 1 ? "" : "s"} detected.',
          style: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12)),
        const SizedBox(height: 16),

        TextField(
          controller: _nameCtrl,
          style: GoogleFonts.dmSans(
            color: IronMindTheme.textPrimary,
            fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Program Name',
            labelStyle: GoogleFonts.dmSans(color: IronMindTheme.text2, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),

        ...p.days.map((d) => _DayPreviewTile(day: d)),
        const SizedBox(height: 24),

        if (_error != null) ...[
          _ErrorBox(message: _error!),
          const SizedBox(height: 14),
        ],

        Text('SAVE AS',
          style: GoogleFonts.dmMono(
            color: IronMindTheme.text3, fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 10),

        _SaveOptionCard(
          icon:     Icons.fitness_center,
          title:    'Workout Routines',
          subtitle: 'Each day becomes a quick-start routine in the Workout tab.',
          color:    IronMindTheme.blue,
          onTap:    _saveAsRoutines,
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SourceTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SourceTab({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? IronMindTheme.accent.withOpacity(0.12)
                : IronMindTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? IronMindTheme.accent.withOpacity(0.5)
                  : IronMindTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15,
                color: selected ? IronMindTheme.accent : IronMindTheme.text2),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                  style: GoogleFonts.dmSans(
                    color: selected ? IronMindTheme.accent : IronMindTheme.text2,
                    fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IronMindTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IronMindTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: IronMindTheme.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
              style: GoogleFonts.dmSans(
                color: IronMindTheme.text2, fontSize: 12, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
              style: GoogleFonts.dmSans(
                color: Colors.redAccent, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _DayPreviewTile extends StatefulWidget {
  final ParsedDay day;
  const _DayPreviewTile({required this.day});

  @override
  State<_DayPreviewTile> createState() => _DayPreviewTileState();
}

class _DayPreviewTileState extends State<_DayPreviewTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.day;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: IronMindTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: IronMindTheme.border),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Expanded(
                    child: Text(d.label,
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Text(
                    '${d.exercises.length} exercise${d.exercises.length == 1 ? "" : "s"}',
                    style: GoogleFonts.dmMono(color: IronMindTheme.text3, fontSize: 10)),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: IronMindTheme.text3),
                ]),
              ),
            ),
            if (_expanded)
              ...d.exercises.map((ex) => Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: IronMindTheme.border))),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(children: [
                  Expanded(
                    child: Text(ex.name,
                      style: GoogleFonts.dmSans(
                        color: IronMindTheme.textPrimary, fontSize: 12)),
                  ),
                  Text(
                    '${ex.sets} × ${ex.reps}',
                    style: GoogleFonts.dmMono(color: IronMindTheme.accent, fontSize: 11)),
                  if (ex.load.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: IronMindTheme.border.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(ex.load,
                        style: GoogleFonts.dmMono(
                          color: IronMindTheme.text2, fontSize: 10)),
                    ),
                  ],
                ]),
              )),
          ],
        ),
      ),
    );
  }
}

class _SaveOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SaveOptionCard({
    required this.icon, required this.title,
    required this.subtitle, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 13)),
                Text(subtitle,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.text2, fontSize: 11, height: 1.35)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14, color: color),
        ]),
      ),
    );
  }
}

class _SupportedFormatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SUPPORTED FORMATS',
          style: GoogleFonts.dmMono(
            color: IronMindTheme.text3, fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        _FormatRow(
          label: 'Column layout (most common)',
          detail: 'Day | Exercise | Sets | Reps | Weight | Notes',
        ),
        _FormatRow(
          label: 'Sheet-per-day (Excel)',
          detail: 'Each Excel sheet tab becomes one training day',
        ),
        _FormatRow(
          label: 'Google Sheets (public link)',
          detail: 'Paste any share link — fetched as CSV automatically',
        ),
        _FormatRow(
          label: 'Auto-detect (no headers)',
          detail: 'Text col → sets number → reps → load',
        ),
      ],
    );
  }
}

class _FormatRow extends StatelessWidget {
  final String label;
  final String detail;
  const _FormatRow({required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5, height: 5,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(
              color: IronMindTheme.accent, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: GoogleFonts.dmSans(
                    color: IronMindTheme.textPrimary,
                    fontSize: 12, fontWeight: FontWeight.w500)),
                Text(detail,
                  style: GoogleFonts.dmMono(
                    color: IronMindTheme.text3, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ── Extension ─────────────────────────────────────────────────────────────────

extension _StrExt on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
