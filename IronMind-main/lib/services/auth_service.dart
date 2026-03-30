import 'dart:convert';

import 'local_store.dart';

class AuthService {
  static const String _usersKey = 'auth_users';
  static const String _currentUserIdKey = 'auth_current_user_id';
  static const String _legacyMigratedKey = 'legacy_data_migrated';

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final currentUserId = await localStore.getString(_currentUserIdKey);
    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }

    final users = await _getUsers();
    for (final user in users) {
      if (user['id'] == currentUserId) {
        return user;
      }
    }
    return null;
  }

  static Future<bool> isSignedIn() async => (await getCurrentUser()) != null;

  static Future<bool> needsOnboarding() async {
    final user = await getCurrentUser();
    return (user?['needsOnboarding'] as bool?) ?? false;
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

    final users = await _getUsers();
    final exists = users.any((user) => user['email'] == normalizedEmail);
    if (exists) {
      throw Exception('An account with that email already exists.');
    }

    final user = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'email': normalizedEmail,
      'password': _encodePassword(password),
      'createdAt': DateTime.now().toIso8601String(),
      'needsOnboarding': true,
    };

    users.add(user);
    await _saveUsers(users);
    await localStore.setString(_currentUserIdKey, user['id'] as String);
    await _migrateLegacyDataIfNeeded(user['id'] as String, existingUsers: users.length - 1);
    return user;
  }

  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final encodedPassword = _encodePassword(password);
    final users = await _getUsers();

    for (final user in users) {
      if (user['email'] == normalizedEmail && user['password'] == encodedPassword) {
        await localStore.setString(_currentUserIdKey, user['id'] as String);
        return user;
      }
    }

    throw Exception('Incorrect email or password.');
  }

  static Future<void> signOut() async {
    await localStore.setString(_currentUserIdKey, '');
  }

  static Future<void> completeOnboarding() async {
    await _updateCurrentUser((user) {
      user['needsOnboarding'] = false;
      return user;
    });
  }

  static Future<void> requireOnboarding() async {
    await _updateCurrentUser((user) {
      user['needsOnboarding'] = true;
      return user;
    });
  }

  static Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?['id']?.toString();
  }

  static Future<List<Map<String, dynamic>>> _getUsers() async {
    final raw = await localStore.getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> _saveUsers(List<Map<String, dynamic>> users) async {
    await localStore.setString(_usersKey, jsonEncode(users));
  }

  static String _encodePassword(String password) {
    return base64Encode(utf8.encode(password));
  }

  static Future<void> _updateCurrentUser(
    Map<String, dynamic> Function(Map<String, dynamic> user) update,
  ) async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) return;

    final users = await _getUsers();
    for (var i = 0; i < users.length; i++) {
      if (users[i]['id'] == currentUser['id']) {
        users[i] = update(Map<String, dynamic>.from(users[i]));
        await _saveUsers(users);
        return;
      }
    }
  }

  static Future<void> _migrateLegacyDataIfNeeded(
    String userId, {
    required int existingUsers,
  }) async {
    if (existingUsers > 0) return;

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
      await localStore.setString('user_${userId}_$key', value);
      copiedAny = true;
    }

    final onboardingComplete = await localStore.getBool('onboarding_complete');
    if (onboardingComplete != null) {
      final users = await _getUsers();
      for (var i = 0; i < users.length; i++) {
        if (users[i]['id'] == userId) {
          users[i]['needsOnboarding'] = !onboardingComplete;
          break;
        }
      }
      await _saveUsers(users);
      copiedAny = true;
    }

    if (copiedAny) {
      await localStore.setBool(_legacyMigratedKey, true);
    }
  }
}
