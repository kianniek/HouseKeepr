import 'package:equatable/equatable.dart';
import '../models/ping_request.dart';

class PingState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<PingRequest> activePings;
  final List<PingRequest> recentLogs;
  final Map<String, DateTime> cooldowns;

  const PingState({
    this.isLoading = false,
    this.error,
    this.activePings = const [],
    this.recentLogs = const [],
    this.cooldowns = const {},
  });

  PingState copyWith({
    bool? isLoading,
    String? error,
    List<PingRequest>? activePings,
    List<PingRequest>? recentLogs,
    Map<String, DateTime>? cooldowns,
  }) {
    return PingState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activePings: activePings ?? this.activePings,
      recentLogs: recentLogs ?? this.recentLogs,
      cooldowns: cooldowns ?? this.cooldowns,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    error,
    activePings,
    recentLogs,
    cooldowns,
  ];
}
