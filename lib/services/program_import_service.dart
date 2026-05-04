import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;

// ── Parsed data models ────────────────────────────────────────────────────────

class ParsedProgram {
  final String name;
  final List<ParsedDay> days;

  const ParsedProgram({required this.name, required this.days});
}

class ParsedDay {
  final String label;
  final List<ParsedExercise> exercises;

  const ParsedDay({required this.label, required this.exercises});
}

class ParsedExercise {
  final String name;
  final int sets;
  final String reps;
  final String load;
  final String notes;

  const ParsedExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.load,
    required this.notes,
  });

  Map<String, dynamic> toTrainerExercise() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'rest': '',
    'note': [if (load.isNotEmpty) load, if (notes.isNotEmpty) notes]
        .join(' · '),
  };

  String toRoutineExerciseName() {
    final parts = <String>[name];
    if (load.isNotEmpty) parts.add(load);
    return parts.join(' — ');
  }
}

// ── Public API ────────────────────────────────────────────────────────────────

class ProgramImportService {
  /// Parse a local Excel (.xlsx) or CSV (.csv) file.
  static Future<ParsedProgram> fromFile(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (ext == 'csv') {
      final raw = await file.readAsString();
      return _parseCsvText(raw, name: _stemName(file.path));
    }
    // treat everything else as xlsx
    final bytes = await file.readAsBytes();
    return _parseExcelBytes(bytes, name: _stemName(file.path));
  }

  /// Parse from a Google Sheets share/edit URL.
  /// Downloads the entire workbook as xlsx so ALL tab/sheet days are captured.
  /// Requires the sheet to be set to "Anyone with the link can view".
  static Future<ParsedProgram> fromGoogleSheetsUrl(String url) async {
    final trimmed = url.trim();
    final idMatch = _sheetsIdPattern.firstMatch(trimmed);
    if (idMatch == null) {
      throw const FormatException(
        'Not a valid Google Sheets link.\n\n'
        'Copy the link directly from the browser address bar while '
        'the sheet is open, or use Share → Copy link.',
      );
    }

    final id      = idMatch.group(1)!;
    // Download the entire workbook — captures ALL tab/day sheets at once
    final xlsxUrl = 'https://docs.google.com/spreadsheets/d/$id/export?format=xlsx';

    http.Response response;
    try {
      response = await http.get(Uri.parse(xlsxUrl))
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw FormatException(
        'Could not reach Google Sheets. Check your internet connection.\n($e)',
      );
    }

    if (response.statusCode != 200) {
      throw FormatException(
        'Google returned an error (${response.statusCode}).\n\n'
        'The sheet must be set to "Anyone with the link can view".\n'
        'Fix: open the sheet → Share (top-right) → '
        '"Change to Anyone with the link" → Viewer → Done. '
        'Then paste the link again.',
      );
    }

    // A 200 that returns HTML means the sheet redirected to a login page
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/html')) {
      throw const FormatException(
        'Google returned a login page instead of the workbook.\n\n'
        'Fix: Share → Change to Anyone with the link → Viewer → Done.',
      );
    }

    return _parseExcelBytes(response.bodyBytes, name: 'Imported Program');
  }

  /// Parse raw CSV text directly (useful for paste-from-clipboard).
  static ParsedProgram fromCsvText(String csv, {String name = 'Imported Program'}) =>
      _parseCsvText(csv, name: name);
}

// ── Metadata sheet names to skip ─────────────────────────────────────────────
// These sheet tab names are common in coach spreadsheets but contain no exercises.

const _metaSheetKeywords = [
  'overview', 'index', 'template', 'instructions', 'readme', 'read me',
  'notes', 'about', 'guide', 'info', 'introduction',
  'pr tracker', 'pr log', 'maxes', 'training max', 'percentages',
  'calculator', 'schedule', 'legend', 'key', 'glossary',
];

bool _isMetaSheet(String name) {
  final lower = name.toLowerCase().trim();
  return _metaSheetKeywords.any((kw) => lower.contains(kw));
}

// ── Excel parser ──────────────────────────────────────────────────────────────

ParsedProgram _parseExcelBytes(List<int> bytes, {required String name}) {
  final excel = Excel.decodeBytes(bytes);
  final days  = <ParsedDay>[];

  for (final sheetName in excel.tables.keys) {
    // Skip obvious metadata sheets
    if (_isMetaSheet(sheetName)) continue;

    final sheet = excel.tables[sheetName]!;
    final rows  = sheet.rows;
    if (rows.isEmpty) continue;

    final parsedRows = rows.map(_cellRowToStrings).toList();
    final parsed     = _parseRows(parsedRows, dayLabel: sheetName);

    // Only include sheets that actually yielded exercises
    days.addAll(parsed.where((d) => d.exercises.isNotEmpty));
  }

  if (days.isEmpty) {
    throw const FormatException(
      'No exercise data found.\n\n'
      'Make sure the sheet has columns like: Exercise, Sets, Reps, Weight.\n'
      'Sheets named "Overview", "PR Tracker", etc. are skipped automatically.',
    );
  }
  return ParsedProgram(name: name, days: days);
}

List<String> _cellRowToStrings(List<Data?> row) =>
    row.map<String>((c) {
      if (c == null) return '';
      final v = c.value;
      if (v == null) return '';
      if (v is TextCellValue) {
        // In excel v4 TextCellValue.value is a TextSpan (rich text) — stringify it
        return v.value.toString().trim();
      }
      if (v is IntCellValue)    return v.value.toString();
      if (v is DoubleCellValue) {
        final d = v.value;
        return d == d.roundToDouble()
            ? d.toInt().toString()
            : d.toStringAsFixed(2);
      }
      // BoolCellValue, DateTimeCellValue, etc.
      return v.toString().trim();
    }).toList();

// ── CSV parser ────────────────────────────────────────────────────────────────

ParsedProgram _parseCsvText(String csv, {required String name}) {
  final rows = _splitCsv(csv);
  if (rows.isEmpty) throw const FormatException('File appears to be empty.');
  final days = _parseRows(rows);
  if (days.isEmpty) throw const FormatException('No exercise data found.');
  return ParsedProgram(name: name, days: days);
}

List<List<String>> _splitCsv(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  return lines
      .map((line) => _parseCsvLine(line))
      .where((row) => row.any((c) => c.trim().isNotEmpty))
      .toList();
}

List<String> _parseCsvLine(String line) {
  final cells = <String>[];
  var inQuote = false;
  final buf = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuote = !inQuote;
      }
    } else if (ch == ',' && !inQuote) {
      cells.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  cells.add(buf.toString().trim());
  return cells;
}

// ── Core row parser (used by both Excel and CSV paths) ────────────────────────

// Column intent categories
enum _Col { day, exercise, sets, reps, load, notes, skip }

/// Maps a header cell to its column intent.
_Col _classifyHeader(String h) {
  final s = h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (_matches(s, ['day', 'session', 'trainingday', 'block', 'phase']))      return _Col.day;
  if (_matches(s, ['exercise', 'movement', 'lift', 'exercisename', 'name',
                   'exname', 'ex']))                                           return _Col.exercise;
  if (_matches(s, ['sets', 'set', 'worksets']))                               return _Col.sets;
  if (_matches(s, ['reps', 'rep', 'repetitions', 'reprange', 'repscheme',
                   'targetreps']))                                             return _Col.reps;
  if (_matches(s, ['weight', 'load', 'intensity', 'kg', 'lbs', 'percent',
                   'pct', '1rm', 'percentage', 'targetweight',
                   'prescribedweight', 'rpe', 'effort']))                     return _Col.load;
  if (_matches(s, ['notes', 'note', 'cues', 'coachnote', 'instruction',
                   'comment', 'comments', 'details']))                        return _Col.notes;
  return _Col.skip;
}

bool _matches(String s, List<String> candidates) => candidates.contains(s);

/// Given a 2D array of strings (rows × cols), parse into days/exercises.
List<ParsedDay> _parseRows(List<List<String>> rows, {String? dayLabel}) {
  if (rows.isEmpty) return [];

  // Find header row: first row where at least 2 cells classify to known columns
  int headerIdx = -1;
  Map<_Col, int> colMap = {};

  for (var r = 0; r < rows.length && r < 5; r++) {
    final candidate = <_Col, int>{};
    for (var c = 0; c < rows[r].length; c++) {
      final cls = _classifyHeader(rows[r][c]);
      if (cls != _Col.skip) candidate[cls] = c;
    }
    if (candidate.length >= 2) {
      headerIdx = r;
      colMap = candidate;
      break;
    }
  }

  // No recognized headers → try to auto-detect by position heuristic
  if (headerIdx == -1) {
    return _autoDetectRows(rows, dayLabel: dayLabel);
  }

  // Parse data rows below header
  final dataRows = rows.skip(headerIdx + 1).toList();
  final hasDay = colMap.containsKey(_Col.day);

  // Group by day
  final dayBuckets = <String, List<ParsedExercise>>{};
  String currentDay = dayLabel ?? 'Day 1';

  for (final row in dataRows) {
    if (_isBlankRow(row)) continue;

    if (hasDay) {
      final d = _cell(row, colMap[_Col.day]);
      if (d.isNotEmpty) currentDay = _normalizeDay(d);
    }

    final exName = _cell(row, colMap[_Col.exercise]);
    if (exName.isEmpty) continue;

    final ex = ParsedExercise(
      name:  exName,
      sets:  int.tryParse(_cell(row, colMap[_Col.sets])) ?? 1,
      reps:  _cell(row, colMap[_Col.reps]).ifEmpty('—'),
      load:  _cell(row, colMap[_Col.load]),
      notes: _cell(row, colMap[_Col.notes]),
    );

    dayBuckets.putIfAbsent(currentDay, () => []).add(ex);
  }

  return dayBuckets.entries
      .map((e) => ParsedDay(label: e.key, exercises: e.value))
      .toList();
}

/// Heuristic parser when no recognizable headers are present.
/// Assumes: col 0 = exercise name or day label, col 1 = sets (number),
/// col 2 = reps, col 3 = load/weight.
List<ParsedDay> _autoDetectRows(List<List<String>> rows, {String? dayLabel}) {
  final days = <String, List<ParsedExercise>>{};
  String currentDay = dayLabel ?? 'Day 1';

  for (final row in rows) {
    if (_isBlankRow(row)) continue;
    final c0 = _cell(row, 0);
    final c1 = _cell(row, 1);
    final c2 = _cell(row, 2);
    final c3 = _cell(row, 3);

    // If col 0 has text and col 1 is empty/non-numeric → treat as day header
    if (c0.isNotEmpty && (c1.isEmpty || int.tryParse(c1) == null)
        && _looksLikeDayLabel(c0)) {
      currentDay = _normalizeDay(c0);
      continue;
    }

    // If col 0 has text and col 1 looks like a number → exercise row
    if (c0.isNotEmpty && int.tryParse(c1) != null) {
      final ex = ParsedExercise(
        name:  c0,
        sets:  int.tryParse(c1) ?? 1,
        reps:  c2.ifEmpty('—'),
        load:  c3,
        notes: _cell(row, 4),
      );
      days.putIfAbsent(currentDay, () => []).add(ex);
    }
  }

  return days.entries
      .map((e) => ParsedDay(label: e.key, exercises: e.value))
      .toList();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _cell(List<String> row, int? idx) {
  if (idx == null || idx >= row.length) return '';
  return row[idx].trim();
}

bool _isBlankRow(List<String> row) => row.every((c) => c.trim().isEmpty);

bool _looksLikeDayLabel(String s) {
  final l = s.toLowerCase();
  return l.startsWith('day') ||
      l.startsWith('week') ||
      l.startsWith('session') ||
      l.startsWith('block') ||
      RegExp(r'^[a-z]+day$').hasMatch(l);
}

String _normalizeDay(String raw) {
  final s = raw.trim();
  final l = s.toLowerCase();
  if (l.startsWith('day ') || l.startsWith('day\t')) return s;
  if (RegExp(r'^\d+$').hasMatch(s)) return 'Day $s';
  return s;
}

String _stemName(String path) {
  final file = path.split(RegExp(r'[/\\]')).last;
  final dot = file.lastIndexOf('.');
  return dot == -1 ? file : file.substring(0, dot);
}

// ── Google Sheets URL handling ────────────────────────────────────────────────

final _sheetsIdPattern = RegExp(
  r'docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_\-]+)',
);
final _gidPattern = RegExp(r'[#&?]gid=(\d+)');

String? _toGoogleSheetsCsvUrl(String url) {
  final idMatch = _sheetsIdPattern.firstMatch(url);
  if (idMatch == null) return null;
  final id  = idMatch.group(1)!;
  final gid = _gidPattern.firstMatch(url)?.group(1) ?? '0';
  return 'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=$gid';
}

String? _extractSheetName(String url) {
  // Try to pull a human-readable name from the URL path — not always available
  return null;
}

extension _StringExt on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
