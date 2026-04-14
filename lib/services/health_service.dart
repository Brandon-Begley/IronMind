import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unified gateway to Apple HealthKit (iOS) and Google Health Connect (Android).
///
/// Usage:
///   await HealthService.initialize();   // called once in main()
///   HealthService.instance.isConnected  // check status anywhere
///   await HealthService.instance.connect()   // trigger permission flow
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  static const String _connectedKey = 'health_connected';

  final Health _health = Health();
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // ── Types we request ─────────────────────────────────────────────────────

  static const List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.WEIGHT,
  ];

  static const List<HealthDataType> _writeTypes = [
    HealthDataType.WEIGHT,
    HealthDataType.WATER,
    HealthDataType.WORKOUT,
  ];

  static const List<HealthDataAccess> _readPermissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static const List<HealthDataAccess> _writePermissions = [
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
    HealthDataAccess.READ_WRITE,
  ];

  // All types in a single flat list for requestAuthorization
  static List<HealthDataType> get _allTypes => [..._readTypes, ..._writeTypes];
  static List<HealthDataAccess> get _allPermissions =>
      [..._readPermissions, ..._writePermissions];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once after WidgetsFlutterBinding.ensureInitialized().
  /// No-op on web — health APIs require a mobile platform.
  static Future<void> initialize() async {
    if (kIsWeb) return;
    instance._health.configure();
    final prefs = await SharedPreferences.getInstance();
    instance._isConnected = prefs.getBool(_connectedKey) ?? false;
  }

  // ── Connect / Disconnect ──────────────────────────────────────────────────

  /// Shows the platform permission sheet. Returns true if authorization was
  /// granted (or was already granted on a previous call).
  Future<bool> connect() async {
    if (kIsWeb) return false;
    try {
      final granted = await _health.requestAuthorization(
        _allTypes,
        permissions: _allPermissions,
      );
      _isConnected = granted;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, granted);
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (kIsWeb) return;
    _isConnected = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, false);
  }

  // ── READ ─────────────────────────────────────────────────────────────────

  /// Total steps for today (midnight → now).
  Future<int?> getTodaySteps() => _safeRead(() async {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        final steps = await _health.getTotalStepsInInterval(midnight, now);
        return steps;
      });

  /// Total active energy burned today in kcal.
  Future<double?> getTodayActiveCalories() => _safeRead(() async {
        final now = DateTime.now();
        final midnight = DateTime(now.year, now.month, now.day);
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: midnight,
          endTime: now,
        );
        if (points.isEmpty) return null;
        final total = points.fold<double>(
          0,
          (s, p) => s + (p.value as NumericHealthValue).numericValue.toDouble(),
        );
        return total > 0 ? total : null;
      });

  /// Hours of sleep from the window (yesterday noon → today noon).
  /// Returns null if no data is available.
  Future<double?> getLastNightSleepHours() => _safeRead(() async {
        final now = DateTime.now();
        final windowEnd = DateTime(now.year, now.month, now.day, 12);
        final windowStart = windowEnd.subtract(const Duration(hours: 24));
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.SLEEP_ASLEEP],
          startTime: windowStart,
          endTime: windowEnd,
        );
        if (points.isEmpty) return null;
        final totalMinutes = points.fold<int>(
          0,
          (s, p) => s + p.dateTo.difference(p.dateFrom).inMinutes,
        );
        final hours = totalMinutes / 60.0;
        return hours > 0 ? hours : null;
      });

  /// Most recent resting heart rate sample from the last 24 hours.
  Future<double?> getRestingHeartRate() => _safeRead(() async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(hours: 24));
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.RESTING_HEART_RATE],
          startTime: yesterday,
          endTime: now,
        );
        if (points.isEmpty) return null;
        // Most recent sample
        points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        return (points.first.value as NumericHealthValue)
            .numericValue
            .toDouble();
      });

  /// Most recent body weight from the last 24 hours, in lbs.
  /// The health package returns weight in kg; we convert here.
  Future<double?> getLatestWeight() => _safeRead(() async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(hours: 24));
        final points = await _health.getHealthDataFromTypes(
          types: [HealthDataType.WEIGHT],
          startTime: yesterday,
          endTime: now,
        );
        if (points.isEmpty) return null;
        points.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        final kg = (points.first.value as NumericHealthValue)
            .numericValue
            .toDouble();
        return kg * 2.20462; // kg → lbs
      });

  // ── WRITE ─────────────────────────────────────────────────────────────────

  /// Write a body weight entry. [lbs] is automatically converted to kg.
  Future<void> writeWeight(double lbs) async {
    if (!_isConnected) return;
    try {
      final now = DateTime.now();
      await _health.writeHealthData(
        value: lbs / 2.20462,
        type: HealthDataType.WEIGHT,
        startTime: now,
        endTime: now,
      );
    } catch (_) {}
  }

  /// Write a water intake entry. [glasses] is converted to millilitres
  /// (1 glass ≈ 240 ml).
  Future<void> writeWater(int glasses) async {
    if (!_isConnected) return;
    try {
      final now = DateTime.now();
      final ml = glasses * 240.0;
      await _health.writeHealthData(
        value: ml,
        type: HealthDataType.WATER,
        startTime: now,
        endTime: now,
      );
    } catch (_) {}
  }

  /// Write a strength training workout session.
  /// [log] should contain 'exercises' (List) and optionally 'elapsed' (int seconds).
  Future<void> writeWorkout(Map<String, dynamic> log) async {
    if (!_isConnected) return;
    try {
      final exercises = (log['exercises'] as List?)?.length ?? 0;
      final elapsedSeconds = (log['elapsed'] as int?) ??
          (exercises * 120); // estimate 2 min per exercise if no timer data
      final end = DateTime.now();
      final start = end.subtract(Duration(seconds: elapsedSeconds.clamp(60, 7200)));
      await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        start: start,
        end: end,
      );
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<T?> _safeRead<T>(Future<T?> Function() fn) async {
    if (!_isConnected) return null;
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }
}
