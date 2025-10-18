import 'package:shared_preferences/shared_preferences.dart';

class InMemoryPrefs implements SharedPreferences {
  final Map<String, Object> _map = {};

  @override
  Future<bool> setString(String key, String value) async {
    _map[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _map[key] as String?;

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _map[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) =>
      (_map[key] as List?)?.cast<String>();

  @override
  Future<bool> remove(String key) async {
    _map.remove(key);
    return true;
  }

  // Not used in tests
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
