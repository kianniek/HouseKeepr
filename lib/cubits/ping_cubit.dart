import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../firestore/firestore_ping_repository.dart';
import '../models/ping_request.dart';
import 'ping_state.dart';

class PingCubit extends Cubit<PingState> {
  FirestorePingRepository? _repository;
  StreamSubscription? _pingsSubscription;
  Timer? _cooldownTimer;

  PingCubit() : super(const PingState()) {
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.cooldowns.isNotEmpty) {
        final now = DateTime.now();
        final newCooldowns = Map<String, DateTime>.from(state.cooldowns);
        bool changed = false;

        newCooldowns.removeWhere((key, value) {
          if (now.isAfter(value)) {
            changed = true;
            return true;
          }
          return false;
        });

        if (changed) {
          emit(state.copyWith(cooldowns: newCooldowns));
        }
      }
    });
  }

  void setRepository(FirestorePingRepository repository, String currentUserId) {
    _repository = repository;
    _pingsSubscription?.cancel();
    _pingsSubscription = _repository!.streamPingsForUser(currentUserId).listen((
      pings,
    ) {
      emit(state.copyWith(activePings: pings));
    });
    _loadRecentLogs(currentUserId);
  }

  Future<void> sendPing(
    String senderId,
    String recipientId,
    String reason, {
    bool reciprocity = false,
  }) async {
    if (_repository == null) return;

    // Check cooldown
    if (state.cooldowns.containsKey(recipientId)) {
      if (DateTime.now().isBefore(state.cooldowns[recipientId]!)) {
        emit(
          state.copyWith(
            error: 'Wait before sending another ping to this user.',
          ),
        );
        return;
      }
    }

    final request = PingRequest(
      id: const Uuid().v4(),
      senderId: senderId,
      recipientId: recipientId,
      reason: reason,
      status: PingStatus.pending,
      timestamp: DateTime.now(),
      reciprocity: reciprocity,
    );

    try {
      await _repository!.sendPing(request);

      // Update cooldown for 5 minutes
      final newCooldowns = Map<String, DateTime>.from(state.cooldowns);
      newCooldowns[recipientId] = DateTime.now().add(
        const Duration(minutes: 5),
      );
      emit(state.copyWith(cooldowns: newCooldowns));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> updateStatus(
    String pingId,
    PingStatus status, {
    PingLocation? location,
  }) async {
    if (_repository == null) return;
    try {
      await _repository!.updatePingStatus(pingId, status, location: location);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _loadRecentLogs(String userId) async {
    if (_repository == null) return;
    final logs = await _repository!.getRecentLogs(userId);
    emit(state.copyWith(recentLogs: logs));
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    _pingsSubscription?.cancel();
    return super.close();
  }
}
