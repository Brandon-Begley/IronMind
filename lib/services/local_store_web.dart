import 'dart:html' as html;

import 'local_store.dart';

class _WebLocalStore implements LocalStore {
  @override
  Future<String?> getString(String key) async => html.window.localStorage[key];

  @override
  Future<void> setString(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async {
    final value = html.window.localStorage[key];
    if (value == null) {
      return null;
    }
    return value.toLowerCase() == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    html.window.localStorage[key] = value.toString();
  }
}

LocalStore createLocalStore() => _WebLocalStore();
