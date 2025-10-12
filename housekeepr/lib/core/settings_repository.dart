import 'package:shared_preferences/shared_preferences.dart';
import 'sync_mode.dart';

class SettingsRepository {
  static const _kSyncMode = 'sync_mode_v1';
  final SharedPreferences prefs;

  SettingsRepository(this.prefs);

  SyncMode getSyncMode() {
    final raw = prefs.getString(_kSyncMode);
    return SyncModeExtension.fromKey(raw);
  }

  Future<void> setSyncMode(SyncMode mode) async {
    await prefs.setString(_kSyncMode, mode.toKey());
  }
}
