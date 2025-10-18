import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

typedef AsyncOp = Future<void> Function();

enum QueueOpType { saveTask, deleteTask, saveShopping, deleteShopping }

class QueueOp {
  final QueueOpType type;
  final String id; // document id
  final Map<String, dynamic>? payload; // serialized model data
  int attempts;

  QueueOp({
    required this.type,
    required this.id,
    this.payload,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'id': id,
    'payload': payload,
    'attempts': attempts,
  };

  static QueueOp fromJson(Map<String, dynamic> j) => QueueOp(
    type: QueueOpType.values[j['type'] as int],
    id: j['id'] as String,
    payload: (j['payload'] as Map?)?.cast<String, dynamic>(),
    attempts: (j['attempts'] as int?) ?? 0,
  );
}

class WriteQueue {
  static const _kKey = 'write_queue_v1';
  final SharedPreferences prefs;
  final _queue = <QueueOp>[];
  bool _running = false;
  String? _userId;

  // optional attached repositories (set when user signs in)
  AsyncOp Function(QueueOp op)? _opBuilder;

  WriteQueue(this.prefs) {
    _loadFromPrefs();
  }

  // Attach a builder that converts QueueOp -> AsyncOp using concrete repos.
  // Passing null detaches the builder (pauses processing).
  void attachOpBuilder(AsyncOp Function(QueueOp op)? builder) {
    _opBuilder = builder;
    // try to resume running if there are ops
    _run();
  }

  // Set the active user id for queue scoping. When a user signs in, call
  // setUserId(uid) to load the user's persisted queue. When signing out,
  // call setUserId(null) to clear the in-memory queue.
  // This also attempts to migrate any existing global queue (old key)
  // into the user's queue on first sign-in.
  void setUserId(String? uid) {
    // if unchanged, do nothing
    if (_userId == uid) return;
    // If switching to null (sign out), clear in-memory queue and pause
    if (uid == null) {
      _userId = null;
      _queue.clear();
      _running = false;
      return;
    }

    // Switching to a concrete user id. Migrate global queue if present.
    final perKey = '${_kKey}_$uid';
    final globalRaw = prefs.getString(_kKey);
    final perRaw = prefs.getString(perKey);
    if (globalRaw != null && perRaw == null) {
      // migrate global -> per-user
      prefs.setString(perKey, globalRaw);
      prefs.remove(_kKey);
    }
    _userId = uid;
    _loadFromPrefs();
    // try to resume processing with any attached builder
    _run();
  }

  void enqueueOp(QueueOp op) {
    _queue.add(op);
    _saveToPrefs();
    _run();
  }

  // Backwards-compatible: allow enqueueing raw AsyncOp (non-persistent)
  void enqueue(AsyncOp op) {
    // wrap into a QueueOp-less execution
    _runRaw(op);
  }

  Future<void> _runRaw(AsyncOp op) async {
    var attempt = 0;
    var success = false;
    while (!success && attempt < 5) {
      try {
        await op();
        success = true;
      } catch (_) {
        attempt++;
        final delay = Duration(milliseconds: 200 * (1 << attempt));
        await Future.delayed(delay);
      }
    }
  }

  Future<void> _run() async {
    if (_running) return;
    if (_queue.isEmpty) return;
    if (_opBuilder == null) return; // cannot process until builder attached
    _running = true;
    while (_queue.isNotEmpty) {
      final op = _queue.removeAt(0);
      var success = false;
      while (!success && op.attempts < 5) {
        try {
          final realOp = _opBuilder!(op);
          await realOp();
          success = true;
        } catch (_) {
          op.attempts++;
          final delay = Duration(milliseconds: 200 * (1 << op.attempts));
          await Future.delayed(delay);
        }
      }
      // if still not success after attempts, drop it (could escalate/log)
      _saveToPrefs();
    }
    _running = false;
  }

  void _saveToPrefs() {
    final list = _queue.map((e) => e.toJson()).toList();
    final key = _userId == null ? _kKey : '${_kKey}_$_userId';
    prefs.setString(key, jsonEncode(list));
  }

  void _loadFromPrefs() {
    final key = _userId == null ? _kKey : '${_kKey}_$_userId';
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _queue.clear();
      for (final j in list) {
        _queue.add(QueueOp.fromJson(j));
      }
    } catch (_) {}
  }
}
