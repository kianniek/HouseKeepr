/// Contract for scheduling and cancelling OS-level rest-timer notifications
/// so chimes and alerts fire even when the app is backgrounded or closed.
abstract class WorkoutNotificationScheduler {
  /// Schedules a rest-timer completion notification for [endsAt].
  Future<void> scheduleRestEnd({
    required DateTime endsAt,
    required String soundProfileId,
    required bool soundEnabled,
    required bool hapticsEnabled,
    required String workoutTitle,
  });

  /// Cancels any pending rest-timer completion notification.
  Future<void> cancelRestEnd();
}
