import 'package:health_keepr/health_keepr.dart';

/// Optional self-hosted openGym server connection configuration.
///
/// OpenGym runs 100% offline by default; this config is only populated when
/// the user explicitly pairs or logs into a self-hosted server in Settings.
class ServerConnectionConfig with HealthRecordMetadata {
  const ServerConnectionConfig({
    this.id = 'default_server_connection',
    required this.serverUrl,
    this.authToken,
    this.cfAccessClientId,
    this.cfAccessClientSecret,
    this.lastSyncedAt,
    this.autoSync = false,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ServerConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ServerConnectionConfig(
      id: (json['id'] as String?) ?? 'default_server_connection',
      serverUrl: (json['serverUrl'] as String?) ?? '',
      authToken: json['authToken'] as String?,
      cfAccessClientId: json['cfAccessClientId'] as String?,
      cfAccessClientSecret: json['cfAccessClientSecret'] as String?,
      lastSyncedAt: json['lastSyncedAt'] as String?,
      autoSync: (json['autoSync'] as bool?) ?? false,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final String serverUrl;
  final String? authToken;
  final String? cfAccessClientId;
  final String? cfAccessClientSecret;
  final String? lastSyncedAt;
  final bool autoSync;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  bool get isConnected => serverUrl.isNotEmpty && (authToken?.isNotEmpty ?? false);

  ServerConnectionConfig copyWith({
    String? serverUrl,
    String? authToken,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
    String? lastSyncedAt,
    bool? autoSync,
  }) {
    return ServerConnectionConfig(
      id: id,
      serverUrl: serverUrl ?? this.serverUrl,
      authToken: authToken ?? this.authToken,
      cfAccessClientId: cfAccessClientId ?? this.cfAccessClientId,
      cfAccessClientSecret: cfAccessClientSecret ?? this.cfAccessClientSecret,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      autoSync: autoSync ?? this.autoSync,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'serverUrl': serverUrl,
        if (authToken != null) 'authToken': authToken,
        if (cfAccessClientId != null) 'cfAccessClientId': cfAccessClientId,
        if (cfAccessClientSecret != null)
          'cfAccessClientSecret': cfAccessClientSecret,
        if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt,
        'autoSync': autoSync,
      };
}

/// Local user preferences for OpenGym.
class OpenGymPreferences with HealthRecordMetadata {
  const OpenGymPreferences({
    this.id = 'default_preferences',
    this.usePounds = false,
    this.oneRmFormula = 'epley',
    this.defaultRestSeconds = 90,
    this.barWeightKg = 20.0,
    this.goalWeightKg,
    this.trainingMode = 'rotation',
    this.rotationIndex = 0,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.prSoundEnabled = true,
    this.restSound = 'chime',
    this.flashScreen = false,
    this.keepScreenAwake = true,
    this.workoutLayout = 'cards',
    this.effortMode = 'off',
    this.swipeActionsEnabled = true,
    this.exerciseAnimationSize = 'small',
    this.rotationSequence = const <String>[],
    this.rotationCompletedIndices = const <int>[],
    this.weeklySchedule = const <int, List<String>>{},
    this.weeklyTrainSeparately = const <int, bool>{},
    this.dayOverrides = const <String, String>{},
    this.folderOpenState = const <String, bool>{},
    this.favoriteExerciseIds = const <String>[],
    required this.updatedAt,
    this.isSynced = false,
  });

  factory OpenGymPreferences.fromJson(Map<String, dynamic> json) {
    final rawSeq = json['rotationSequence'] as List<dynamic>? ?? const <dynamic>[];
    final rawCompleted =
        json['rotationCompletedIndices'] as List<dynamic>? ?? const <dynamic>[];
    final rawWeekly = json['weeklySchedule'] as Map? ?? const <String, dynamic>{};
    final parsedWeekly = <int, List<String>>{};
    for (final entry in rawWeekly.entries) {
      final day = int.tryParse(entry.key.toString());
      if (day != null && entry.value is List) {
        parsedWeekly[day] = (entry.value as List<dynamic>)
            .whereType<String>()
            .toList();
      }
    }
    final rawApart =
        json['weeklyTrainSeparately'] as Map? ?? const <String, dynamic>{};
    final parsedApart = <int, bool>{};
    for (final entry in rawApart.entries) {
      final day = int.tryParse(entry.key.toString());
      if (day != null && entry.value is bool) {
        parsedApart[day] = entry.value as bool;
      }
    }
    final rawOverrides =
        json['dayOverrides'] as Map? ?? const <String, dynamic>{};
    final parsedOverrides = <String, String>{
      for (final e in rawOverrides.entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };
    final rawFolders =
        json['folderOpenState'] as Map? ?? const <String, dynamic>{};
    final parsedFolders = <String, bool>{
      for (final e in rawFolders.entries)
        if (e.value is bool) e.key.toString(): e.value as bool,
    };
    final rawFavEx =
        json['favoriteExerciseIds'] as List<dynamic>? ?? const <dynamic>[];

    return OpenGymPreferences(
      id: (json['id'] as String?) ?? 'default_preferences',
      usePounds: (json['usePounds'] as bool?) ?? false,
      oneRmFormula: (json['oneRmFormula'] as String?) ?? 'epley',
      defaultRestSeconds: (json['defaultRestSeconds'] as num?)?.toInt() ?? 90,
      barWeightKg: (json['barWeightKg'] as num?)?.toDouble() ?? 20.0,
      goalWeightKg: (json['goalWeightKg'] as num?)?.toDouble(),
      trainingMode: (json['trainingMode'] as String?) ?? 'rotation',
      rotationIndex: (json['rotationIndex'] as num?)?.toInt() ?? 0,
      soundEnabled: (json['soundEnabled'] as bool?) ?? true,
      hapticsEnabled: (json['hapticsEnabled'] as bool?) ?? true,
      prSoundEnabled: (json['prSoundEnabled'] as bool?) ?? true,
      restSound: (json['restSound'] as String?) ?? 'chime',
      flashScreen: (json['flashScreen'] as bool?) ?? false,
      keepScreenAwake: (json['keepScreenAwake'] as bool?) ?? true,
      workoutLayout: (json['workoutLayout'] as String?) ?? 'cards',
      effortMode: (json['effortMode'] as String?) ?? 'off',
      swipeActionsEnabled: (json['swipeActionsEnabled'] as bool?) ?? true,
      exerciseAnimationSize:
          (json['exerciseAnimationSize'] as String?) ?? 'small',
      rotationSequence: rawSeq.whereType<String>().toList(),
      rotationCompletedIndices:
          rawCompleted.whereType<num>().map((e) => e.toInt()).toList(),
      weeklySchedule: parsedWeekly,
      weeklyTrainSeparately: parsedApart,
      dayOverrides: parsedOverrides,
      folderOpenState: parsedFolders,
      favoriteExerciseIds: rawFavEx.whereType<String>().toList(),
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final bool usePounds;
  final String oneRmFormula;
  final int defaultRestSeconds;
  final double barWeightKg;
  final double? goalWeightKg;
  final String trainingMode;
  final int rotationIndex;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool prSoundEnabled;
  final String restSound;
  final bool flashScreen;
  final bool keepScreenAwake;
  final String workoutLayout;
  final String effortMode;
  final bool swipeActionsEnabled;
  final String exerciseAnimationSize;
  final List<String> rotationSequence;
  final List<int> rotationCompletedIndices;
  final Map<int, List<String>> weeklySchedule;
  final Map<int, bool> weeklyTrainSeparately;
  final Map<String, String> dayOverrides;
  final Map<String, bool> folderOpenState;
  final List<String> favoriteExerciseIds;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  String get weightUnit => usePounds ? 'lb' : 'kg';

  OpenGymPreferences copyWith({
    bool? usePounds,
    String? oneRmFormula,
    int? defaultRestSeconds,
    double? barWeightKg,
    double? goalWeightKg,
    String? trainingMode,
    int? rotationIndex,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? prSoundEnabled,
    String? restSound,
    bool? flashScreen,
    bool? keepScreenAwake,
    String? workoutLayout,
    String? effortMode,
    bool? swipeActionsEnabled,
    String? exerciseAnimationSize,
    List<String>? rotationSequence,
    List<int>? rotationCompletedIndices,
    Map<int, List<String>>? weeklySchedule,
    Map<int, bool>? weeklyTrainSeparately,
    Map<String, String>? dayOverrides,
    Map<String, bool>? folderOpenState,
    List<String>? favoriteExerciseIds,
  }) {
    return OpenGymPreferences(
      id: id,
      usePounds: usePounds ?? this.usePounds,
      oneRmFormula: oneRmFormula ?? this.oneRmFormula,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      barWeightKg: barWeightKg ?? this.barWeightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      trainingMode: trainingMode ?? this.trainingMode,
      rotationIndex: rotationIndex ?? this.rotationIndex,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      prSoundEnabled: prSoundEnabled ?? this.prSoundEnabled,
      restSound: restSound ?? this.restSound,
      flashScreen: flashScreen ?? this.flashScreen,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      workoutLayout: workoutLayout ?? this.workoutLayout,
      effortMode: effortMode ?? this.effortMode,
      swipeActionsEnabled: swipeActionsEnabled ?? this.swipeActionsEnabled,
      exerciseAnimationSize:
          exerciseAnimationSize ?? this.exerciseAnimationSize,
      rotationSequence: rotationSequence ?? this.rotationSequence,
      rotationCompletedIndices:
          rotationCompletedIndices ?? this.rotationCompletedIndices,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      weeklyTrainSeparately:
          weeklyTrainSeparately ?? this.weeklyTrainSeparately,
      dayOverrides: dayOverrides ?? this.dayOverrides,
      folderOpenState: folderOpenState ?? this.folderOpenState,
      favoriteExerciseIds: favoriteExerciseIds ?? this.favoriteExerciseIds,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'usePounds': usePounds,
        'oneRmFormula': oneRmFormula,
        'defaultRestSeconds': defaultRestSeconds,
        'barWeightKg': barWeightKg,
        if (goalWeightKg != null) 'goalWeightKg': goalWeightKg,
        'trainingMode': trainingMode,
        'rotationIndex': rotationIndex,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
        'prSoundEnabled': prSoundEnabled,
        'restSound': restSound,
        'flashScreen': flashScreen,
        'keepScreenAwake': keepScreenAwake,
        'workoutLayout': workoutLayout,
        'effortMode': effortMode,
        'swipeActionsEnabled': swipeActionsEnabled,
        'exerciseAnimationSize': exerciseAnimationSize,
        if (rotationSequence.isNotEmpty) 'rotationSequence': rotationSequence,
        if (rotationCompletedIndices.isNotEmpty)
          'rotationCompletedIndices': rotationCompletedIndices,
        if (weeklySchedule.isNotEmpty)
          'weeklySchedule': weeklySchedule.map(
            (k, v) => MapEntry<String, List<String>>(k.toString(), v),
          ),
        if (weeklyTrainSeparately.isNotEmpty)
          'weeklyTrainSeparately': weeklyTrainSeparately.map(
            (k, v) => MapEntry<String, bool>(k.toString(), v),
          ),
        if (dayOverrides.isNotEmpty) 'dayOverrides': dayOverrides,
        if (folderOpenState.isNotEmpty) 'folderOpenState': folderOpenState,
        if (favoriteExerciseIds.isNotEmpty)
          'favoriteExerciseIds': favoriteExerciseIds,
      };
}
