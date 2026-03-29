import 'package:csv/csv.dart';

class CSVService {
  // Parse CSV string into routines
  static Future<List<Map<String, dynamic>>> parseRoutineCSV(String csvContent) async {
    try {
      final rows = const CsvToListConverter().convert(csvContent);
      if (rows.isEmpty) throw Exception('Empty CSV file');

      // First row should be headers
      final headers = rows[0].cast<String>();
      if (!headers.contains('Exercise') && !headers.contains('Exercise Name')) {
        throw Exception('CSV must contain "Exercise" or "Exercise Name" column');
      }

      final exercises = <String>[];
      final primaryMuscles = <String>{};
      final secondaryMuscles = <String>{};

      // Parse data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final exerciseName = row[0]?.toString().trim() ?? '';
        if (exerciseName.isEmpty) continue;

        exercises.add(exerciseName);

        if (row.length > 1 && row[1] != null) {
          final primary = row[1].toString().trim();
          if (primary.isNotEmpty) primaryMuscles.add(primary);
        }

        if (row.length > 2 && row[2] != null) {
          final secondary = row[2].toString().trim();
          if (secondary.isNotEmpty) secondaryMuscles.add(secondary);
        }
      }

      if (exercises.isEmpty) throw Exception('No exercises found in CSV');

      return [
        {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': 'Imported Routine ${DateTime.now().month}/${DateTime.now().day}',
          'exercises': exercises,
          'primary': primaryMuscles.toList(),
          'secondary': secondaryMuscles.toList(),
        }
      ];
    } catch (e) {
      throw Exception('Failed to parse CSV: $e');
    }
  }

  // Export routines to CSV format
  static String exportRoutines(List<Map<String, dynamic>> routines) {
    final rows = <List<dynamic>>[
      ['Routine Name', 'Exercise', 'Primary Muscle Group', 'Secondary Muscle Group'],
    ];

    for (final routine in routines) {
      final name = routine['name'] ?? 'Unnamed';
      final exercises = routine['exercises'] as List? ?? [];
      final primary = routine['primary'] as List? ?? [];
      final secondary = routine['secondary'] as List? ?? [];

      for (int i = 0; i < exercises.length; i++) {
        rows.add([
          i == 0 ? name : '', // Routine name only on first exercise
          exercises[i],
          i < primary.length ? primary[i] : '',
          i < secondary.length ? secondary[i] : '',
        ]);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }
}
