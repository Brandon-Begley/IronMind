import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';

class _MobileLocalStore implements LocalStore {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async {
    final prefs = await _prefs;
    return prefs.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    final prefs = await _prefs;
    return prefs.getBool(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
  }
}

LocalStore createLocalStore() => _MobileLocalStore();
