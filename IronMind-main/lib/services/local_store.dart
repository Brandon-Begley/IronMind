import 'local_store_stub.dart'
    if (dart.library.html) 'local_store_web.dart'
    if (dart.library.io) 'local_store_mobile.dart';

abstract class LocalStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
}

final LocalStore localStore = createLocalStore();
