enum SyncMode { localOnly, sync, remoteOnly }

extension SyncModeExtension on SyncMode {
  String toKey() {
    return toString().split('.').last;
  }

  static SyncMode fromKey(String? key) {
    switch (key) {
      case 'localOnly':
        return SyncMode.localOnly;
      case 'remoteOnly':
        return SyncMode.remoteOnly;
      case 'sync':
      default:
        return SyncMode.sync;
    }
  }
}
