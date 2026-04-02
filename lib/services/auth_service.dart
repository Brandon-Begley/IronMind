import 'dart:convert';

import 'local_store.dart';
import 'supabase_service.dart';

class AuthService {
  static const String _legacyMigratedKey = 'legacy_data_migrated';
  static const String _onboardingKey = 'needs_onboarding';
  static const String _legacyUsersKey = 'auth_users';
  static const String _legacyCurrentUserIdKey = 'auth_current_user_id';

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final user = SupabaseService().getCurrentUser();
    if (user != null) {
      final needsOnboarding = await _readOnboardingFlag(user.id);
      return {
        'id': user.id,
        'email': user.email ?? '',
        'createdAt': user.createdAt,
        'needsOnboarding': needsOnboarding,
      };
    }

    return _getLegacyCurrentUser();
  }

  static Future<bool> isSignedIn() async => (await getCurrentUser()) != null;

  static Future<bool> needsOnboarding() async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;
    return _readOnboardingFlag(userId);
  }

  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw Exception('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final response = await SupabaseService().signUp(normalizedEmail, password);
    final user = response.user;
    if (user == null) {
      throw Exception('Unable to create account right now.');
    }

    await _setOnboardingFlag(user.id, true);
    await _migrateLegacyDataIfNeeded(user.id);
    await _clearLegacySession();

    return {
      'id': user.id,
      'email': user.email ?? normalizedEmail,
      'createdAt': user.createdAt,
      'needsOnboarding': true,
    };
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await SupabaseService().signIn(normalizedEmail, password);
      final user = response.user;
      if (user == null) {
        throw Exception('Incorrect email or password.');
      }

      await _migrateLegacyDataIfNeeded(user.id);
      final needsOnboarding = await _readOnboardingFlag(user.id);

      return {
        'id': user.id,
        'email': user.email ?? normalizedEmail,
        'createdAt': user.createdAt,
        'needsOnboarding': needsOnboarding,
      };
    } catch (_) {
      final legacyUser = await _findLegacyUser(normalizedEmail, password);
      if (legacyUser == null) {
        throw Exception('Incorrect email or password.');
      }

      final legacyId = (legacyUser['id'] ?? '').toString();
      if (legacyId.isEmpty) {
        throw Exception('Legacy account is missing an id.');
      }
      await localStore.setString(_legacyCurrentUserIdKey, legacyId);
      return Map<String, dynamic>.from(legacyUser);
    }
  }

  static Future<void> signOut() async {
    await SupabaseService().signOut();
    await _clearLegacySession();
  }

  static Future<Map<String, dynamic>> continueOfflinePreview() async {
    const previewEmail = 'preview@local.ironmind';
    final users = await _getLegacyUsers();
    Map<String, dynamic>? previewUser;

    for (final user in users) {
      if ((user['email'] ?? '').toString().toLowerCase() == previewEmail) {
        previewUser = user;
        break;
      }
    }

    if (previewUser == null) {
      previewUser = {
        'id': 'preview_user',
        'email': previewEmail,
        'password': '',
        'createdAt': DateTime.now().toIso8601String(),
        'needsOnboarding': true,
      };
      users.add(previewUser);
      await _saveLegacyUsers(users);
    }

    await localStore.setString(
      _legacyCurrentUserIdKey,
      previewUser['id'].toString(),
    );
    return Map<String, dynamic>.from(previewUser);
  }

  static Future<void> completeOnboarding() async {
    final userId = await getCurrentUserId();
    if (userId == null) return;
    await _setOnboardingFlag(userId, false);
  }

  static Future<void> requireOnboarding() async {
    final userId = await getCurrentUserId();
    if (userId == null) return;
    await _setOnboardingFlag(userId, true);
  }

  static Future<String?> getCurrentUserId() async {
    final user = SupabaseService().getCurrentUser();
    if (user != null) return user.id;

    final legacy = await _getLegacyCurrentUser();
    return legacy?['id']?.toString();
  }

  static Future<String> _scopedKey(String userId, String key) async {
    return 'user_${userId}_$key';
  }

  static Future<bool> _readOnboardingFlag(String userId) async {
    final explicit = await localStore.getBool(await _scopedKey(userId, _onboardingKey));
    if (explicit != null) return explicit;

    final profileRaw = await localStore.getString(await _scopedKey(userId, 'user_profile'));
    return profileRaw == null || profileRaw.isEmpty;
  }

  static Future<void> _setOnboardingFlag(String userId, bool value) async {
    await localStore.setBool(await _scopedKey(userId, _onboardingKey), value);
  }

  static Future<void> _migrateLegacyDataIfNeeded(String userId) async {
    final migrated = await localStore.getBool(_legacyMigratedKey) ?? false;
    if (migrated) return;

    const legacyKeys = <String>[
      'workout_logs',
      'personal_records',
      'wellness_data',
      'routines',
      'user_profile',
      'strength_goals',
      'bodyweight_logs',
      'measurements_logs',
      'nutrition_targets',
      'nutrition_plans',
    ];

    var copiedAny = false;
    for (final key in legacyKeys) {
      final value = await localStore.getString(key);
      if (value == null || value.isEmpty) continue;
      await localStore.setString(await _scopedKey(userId, key), value);
      copiedAny = true;
    }

    if (copiedAny) {
      await localStore.setBool(_legacyMigratedKey, true);
    }
  }

  static Future<Map<String, dynamic>?> _findLegacyUser(
    String email,
    String password,
  ) async {
    final raw = await localStore.getString(_legacyUsersKey);
    if (raw == null || raw.isEmpty) return null;

    final users = List<Map<String, dynamic>>.from(jsonDecode(raw));
    final encodedPassword = base64Encode(utf8.encode(password));

    for (final user in users) {
      if ((user['email'] ?? '').toString().toLowerCase() == email &&
          (user['password'] ?? '').toString() == encodedPassword) {
        return user;
      }
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> _getLegacyUsers() async {
    final raw = await localStore.getString(_legacyUsersKey);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> _saveLegacyUsers(List<Map<String, dynamic>> users) async {
    await localStore.setString(_legacyUsersKey, jsonEncode(users));
  }

  static Future<Map<String, dynamic>?> _getLegacyCurrentUser() async {
    final currentUserId = await localStore.getString(_legacyCurrentUserIdKey);
    if (currentUserId == null || currentUserId.isEmpty) return null;

    final raw = await localStore.getString(_legacyUsersKey);
    if (raw == null || raw.isEmpty) return null;

    final users = List<Map<String, dynamic>>.from(jsonDecode(raw));
    for (final user in users) {
      if ((user['id'] ?? '').toString() == currentUserId) {
        return user;
      }
    }
    return null;
  }

  static Future<void> _clearLegacySession() async {
    await localStore.setString(_legacyCurrentUserIdKey, '');
  }
}
