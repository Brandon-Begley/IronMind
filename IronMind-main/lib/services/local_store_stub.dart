import 'local_store.dart';

class _MemoryLocalStore implements LocalStore {
  final Map<String, String> _strings = <String, String>{};
  final Map<String, bool> _bools = <String, bool>{};

  @override
  Future<String?> getString(String key) async => _strings[key];

  @override
  Future<void> setString(String key, String value) async {
    _strings[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async => _bools[key];

  @override
  Future<void> setBool(String key, bool value) async {
    _bools[key] = value;
  }
}

LocalStore createLocalStore() => _MemoryLocalStore();
