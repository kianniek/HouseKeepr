import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../contracts/health_data_store.dart';
import '../../storage/local_health_data_store.dart';
import '../food_tracker_launcher.dart';
import '../ai/nutrition_estimator.dart';
import '../ai/on_device_llm_model_manager.dart';
import '../ml/food_classifier.dart';
import '../ml/nutrition_catalog.dart';
import '../ml/nutrition_mapper.dart';
import '../models/daily_nutrition_summary.dart';
import '../models/meal_log.dart';
import '../models/meal_type.dart';
import '../models/nutrition_food.dart';
import '../storage/food_tracker_repository.dart';
import '../sync/nutrition_health_connect_gateway.dart';
import 'food_confirmation_sheet.dart';
import 'manual_food_add_sheet.dart';

/// Daily Food Snap & Calorie Tracker screen.
///
/// Stores all meals locally via [FoodTrackerRepository] (creating and closing
/// its own [LocalHealthDataStore] when [store] is omitted), supports offline
/// photo recognition with host-supplied cropping, and optionally syncs logged
/// nutrition to Android Health Connect when available and permitted.
class FoodTrackerScreen extends StatefulWidget {
  const FoodTrackerScreen({
    super.key,
    this.store,
    this.cropper,
    this.classifier,
    this.imagePicker,
    this.healthConnectGateway,
    this.catalog,
    this.estimator,
    this.llmModelManager,
  });

  final HealthDataStore? store;
  final FoodPlateCropper? cropper;
  final FoodClassifier? classifier;
  final FoodImageSourcePicker? imagePicker;
  final NutritionHealthConnectGateway? healthConnectGateway;
  final NutritionCatalog? catalog;
  final NutritionEstimator? estimator;
  final OnDeviceLlmModelManager? llmModelManager;

  @override
  State<FoodTrackerScreen> createState() => _FoodTrackerScreenState();
}

class _FoodTrackerScreenState extends State<FoodTrackerScreen> {
  late final HealthDataStore _store;
  late final bool _ownsStore;
  late final FoodTrackerRepository _repository;
  late final NutritionHealthConnectGateway _healthConnectGateway;
  late final OnDeviceLlmModelManager _llmModelManager;
  late final bool _ownsLlmModelManager;

  FoodClassifier? _ownedClassifier;
  NutritionCatalog? _catalog;
  List<String> _favoriteFoodIds = const <String>[];
  List<String> _recentFoodIds = const <String>[];

  DateTime _selectedDate = _dateOnly(DateTime.now());
  DailyNutritionSummary? _summary;
  bool _isLoading = true;
  bool _isSnapping = false;
  String? _loadError;

  NutritionHealthConnectStatus _hcStatus =
      NutritionHealthConnectStatus.unavailable;
  bool _hcHasPermission = false;
  bool _hcSyncEnabled = false;
  bool _hcPermissionDeclined = false;

  static DateTime _dateOnly(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? LocalHealthDataStore();
    _repository = FoodTrackerRepository(_store);
    _catalog = widget.catalog;
    _ownsLlmModelManager = widget.llmModelManager == null;
    _llmModelManager = widget.llmModelManager ?? OnDeviceLlmModelManager();
    _healthConnectGateway =
        widget.healthConnectGateway ??
        MethodChannelNutritionHealthConnectGateway();
    unawaited(_loadInitialData());
  }

  @override
  void dispose() {
    final ownedClassifier = _ownedClassifier;
    _ownedClassifier = null;
    if (ownedClassifier != null) {
      unawaited(ownedClassifier.dispose());
    }
    if (_ownsLlmModelManager) {
      _llmModelManager.dispose();
    }
    if (_ownsStore) {
      unawaited(_store.close());
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final catalogFuture = _ensureCatalog();
      final summaryFuture = _repository.loadDailySummary(_selectedDate);
      final syncEnabledFuture = _repository.loadHealthConnectSyncEnabled();
      final hcStatusFuture = _healthConnectGateway.getSdkStatus();
      final favoritesFuture = _repository.loadFavoriteFoodIds();
      final recentsFuture = _repository.loadRecentFoodIds();
      unawaited(_llmModelManager.refreshStatus());

      final catalog = await catalogFuture;
      final summary = await summaryFuture;
      final syncEnabled = await syncEnabledFuture;
      final hcStatus = await hcStatusFuture;
      final favoriteIds = await favoritesFuture;
      final recentIds = await recentsFuture;

      var hasPermission = false;
      if (_isAndroid && hcStatus == NutritionHealthConnectStatus.available) {
        hasPermission = await _healthConnectGateway
            .hasWriteNutritionPermission();
      }

      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _summary = summary;
        _hcSyncEnabled = syncEnabled;
        _hcStatus = hcStatus;
        _hcHasPermission = hasPermission;
        _favoriteFoodIds = favoriteIds;
        _recentFoodIds = recentIds;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load nutrition data: $error';
        _isLoading = false;
      });
    }
  }

  Future<NutritionCatalog> _ensureCatalog() async {
    final existing = _catalog;
    if (existing != null) return existing;
    final loaded = await NutritionCatalog.loadFromAsset();
    final customFoods = await _repository.loadCustomFoods();
    final merged = loaded.mergeFoods(customFoods);
    _catalog = merged;
    return merged;
  }

  Future<void> _reloadSummary() async {
    final summary = await _repository.loadDailySummary(_selectedDate);
    final recents = await _repository.loadRecentFoodIds();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _recentFoodIds = recents;
    });
  }

  Future<void> _changeDate(int deltaDays) async {
    final next = _dateOnly(_selectedDate.add(Duration(days: deltaDays)));
    setState(() {
      _selectedDate = next;
    });
    await _reloadSummary();
  }

  Future<void> _jumpToToday() async {
    final today = _dateOnly(DateTime.now());
    if (_selectedDate == today) return;
    setState(() {
      _selectedDate = today;
    });
    await _reloadSummary();
  }

  Future<void> _editDailyGoal() async {
    final currentGoal =
        _summary?.dailyKcalGoal ?? FoodTrackerRepository.defaultDailyKcalGoal;
    final controller = TextEditingController(
      text: currentGoal.round().toString(),
    );
    String? errorText;

    final updatedGoal = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Daily Calorie Goal'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Goal (kcal)',
              suffixText: 'kcal',
              border: const OutlineInputBorder(),
              errorText: errorText,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (parsed == null || !parsed.isFinite || parsed <= 0) {
                  setDialogState(() {
                    errorText = 'Enter a calorie goal greater than 0.';
                  });
                  return;
                }
                Navigator.of(dialogContext).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (updatedGoal == null) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 400),
          controller.dispose,
        ),
      );
      return;
    }
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        controller.dispose,
      ),
    );
    await _repository.saveDailyKcalGoal(updatedGoal);
    await _reloadSummary();
  }

  Future<void> _onToggleHealthConnect(bool value) async {
    if (!_isAndroid || _hcStatus != NutritionHealthConnectStatus.available) {
      return;
    }

    if (!value) {
      await _repository.saveHealthConnectSyncEnabled(false);
      if (!mounted) return;
      setState(() {
        _hcSyncEnabled = false;
      });
      return;
    }

    var granted = await _healthConnectGateway.hasWriteNutritionPermission();
    if (!granted) {
      granted = await _healthConnectGateway.requestWriteNutritionPermission();
    }

    await _repository.saveHealthConnectSyncEnabled(granted);
    if (!mounted) return;
    setState(() {
      _hcHasPermission = granted;
      _hcSyncEnabled = granted;
      _hcPermissionDeclined = !granted;
    });

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Health Connect nutrition permission was declined. '
            'Meals will still be saved locally.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () {
              unawaited(_healthConnectGateway.openHealthConnectSettings());
            },
          ),
        ),
      );
    }
  }

  Future<void> _persistAndMaybeSyncPlate(List<MealLog> logs) async {
    if (logs.isEmpty) return;
    if (logs.length == 1) {
      await _persistAndMaybeSyncMeal(logs.first);
      return;
    }

    var syncedCount = 0;
    for (final log in logs) {
      await _repository.saveMealLog(log);
      if (_isAndroid &&
          _hcStatus == NutritionHealthConnectStatus.available &&
          _hcSyncEnabled &&
          _hcHasPermission) {
        try {
          final hcId = await _healthConnectGateway.writeNutritionRecord(log);
          if (hcId != null && hcId.isNotEmpty) {
            await _repository.saveMealLog(log.copyWith(healthConnectId: hcId));
            syncedCount++;
          }
        } catch (_) {}
      }
    }

    await _reloadSummary();
    if (!mounted) return;
    final totalKcal = logs.fold<double>(0, (sum, l) => sum + l.kcal).round();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          syncedCount > 0
              ? 'Logged ${logs.length} items ($totalKcal kcal) & synced to Health Connect.'
              : 'Logged ${logs.length} items ($totalKcal kcal).',
        ),
      ),
    );
  }

  Future<void> _deleteMealLog(MealLog log) async {
    await _repository.deleteMealLog(log.id);
    await _reloadSummary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted ${log.foodName}.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(() async {
              await _repository.saveMealLog(log);
              await _reloadSummary();
            }());
          },
        ),
      ),
    );
  }

  Future<void> _editMealLog(MealLog log) async {
    final nameController = TextEditingController(text: log.foodName);
    final gramsController = TextEditingController(
      text: log.servingGrams.round().toString(),
    );
    final kcalController = TextEditingController(
      text: log.kcal.round().toString(),
    );
    var selectedMealType = log.mealType;
    String? errorText;

    final updated = await showDialog<MealLog>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Meal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Food name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: gramsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Serving (g)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kcalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Calories (kcal)',
                    border: const OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: MealType.values.map((mealType) {
                    return ChoiceChip(
                      label: Text(mealType.label),
                      selected: selectedMealType == mealType,
                      onSelected: (_) =>
                          setDialogState(() => selectedMealType = mealType),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final grams = double.tryParse(
                  gramsController.text.trim().replaceAll(',', '.'),
                );
                final kcal = double.tryParse(
                  kcalController.text.trim().replaceAll(',', '.'),
                );
                if (name.isEmpty ||
                    grams == null ||
                    !grams.isFinite ||
                    grams <= 0 ||
                    kcal == null ||
                    !kcal.isFinite ||
                    kcal < 0) {
                  setDialogState(() {
                    errorText = 'Enter valid name, grams (>0), and kcal.';
                  });
                  return;
                }
                final scale = log.servingGrams > 0
                    ? grams / log.servingGrams
                    : 1.0;
                Navigator.of(dialogContext).pop(
                  log.copyWith(
                    foodName: name,
                    mealType: selectedMealType,
                    servingGrams: grams,
                    kcal: kcal,
                    proteinGrams: log.proteinGrams * scale,
                    carbsGrams: log.carbsGrams * scale,
                    fatGrams: log.fatGrams * scale,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        nameController.dispose();
        gramsController.dispose();
        kcalController.dispose();
      }),
    );

    if (updated == null) return;
    await _repository.saveMealLog(updated);
    await _reloadSummary();
  }

  Future<void> _persistAndMaybeSyncMeal(MealLog log) async {
    await _repository.saveMealLog(log);

    var syncedToHealthConnect = false;
    if (_isAndroid &&
        _hcStatus == NutritionHealthConnectStatus.available &&
        _hcSyncEnabled &&
        _hcHasPermission) {
      try {
        final hcId = await _healthConnectGateway.writeNutritionRecord(log);
        if (hcId != null && hcId.isNotEmpty) {
          await _repository.saveMealLog(log.copyWith(healthConnectId: hcId));
          syncedToHealthConnect = true;
        }
      } catch (_) {
        // Local save already succeeded; Health Connect errors are non-fatal.
      }
    }

    await _reloadSummary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          syncedToHealthConnect
              ? 'Logged ${log.foodName} (${log.kcal.round()} kcal) & synced to Health Connect.'
              : 'Logged ${log.foodName} (${log.kcal.round()} kcal).',
        ),
      ),
    );
  }

  Future<void> _startSnapFlow() async {
    if (_isSnapping) return;

    final origin = await _pickImageOrigin();
    if (origin == null || !mounted) return;

    setState(() {
      _isSnapping = true;
    });

    var loadingDialogOpen = false;
    try {
      final picker = widget.imagePicker;
      final imagePath = picker != null
          ? await picker(context, origin)
          : await FoodTrackerLauncher.pickImageWithDefault(context, origin);

      if (imagePath == null || imagePath.isEmpty || !mounted) {
        return;
      }

      final cropper = widget.cropper ?? FoodTrackerLauncher.defaultCropper;
      final Uint8List? imageBytes;
      if (cropper != null) {
        imageBytes = await cropper(context, imagePath);
        if (imageBytes == null || !mounted) {
          return;
        }
      } else {
        imageBytes = await XFile(imagePath).readAsBytes();
      }

      if (!mounted) return;
      loadingDialogOpen = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Expanded(child: Text('Analyzing meal')),
                ],
              ),
            ),
          ),
        ).whenComplete(() {
          loadingDialogOpen = false;
        }),
      );

      final catalog = await _ensureCatalog();
      final classifier =
          widget.classifier ??
          (_ownedClassifier ??= FoodTrackerLauncher.createDefaultClassifier());
      final predictions = await classifier.classifyImageBytes(
        imageBytes,
        topK: 5,
      );
      final mapped = NutritionMapper(catalog).mapPredictions(predictions);

      if (mounted && loadingDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogOpen = false;
      }
      if (!mounted) return;

      List<MealLog>? confirmedPlate;
      final confirmedLog = await showModalBottomSheet<MealLog>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FoodConfirmationSheet(
          mappedPredictions: mapped,
          catalog: catalog,
          initialMealType: MealType.defaultForLocalTime(DateTime.now()),
          previewBytes: imageBytes,
          targetDate: _selectedDate,
          estimator:
              widget.estimator ??
              HybridNutritionEstimator(
                catalog: catalog,
                isBuiltInAiEnabled: _llmModelManager.isReady,
              ),
          isAiModelReady: _llmModelManager.isReady,
          onOpenAiModelManager: () {
            Navigator.of(context).pop();
            unawaited(_openLlmModelDialog());
          },
          onConfirmPlate: (items) {
            confirmedPlate = items;
          },
        ),
      );
      if (confirmedPlate != null && mounted) {
        await _persistAndMaybeSyncPlate(confirmedPlate!);
      } else if (confirmedLog != null && mounted) {
        await _persistAndMaybeSyncMeal(confirmedLog);
      }
    } catch (error) {
      if (mounted && loadingDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogOpen = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not analyze photo: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSnapping = false;
        });
      }
    }
  }

  Future<FoodImageOrigin?> _pickImageOrigin() {
    return showModalBottomSheet<FoodImageOrigin>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              subtitle: const Text('Snap your plate with the camera'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(FoodImageOrigin.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick an existing meal photo'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(FoodImageOrigin.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManualAdd() async {
    try {
      final catalog = await _ensureCatalog();
      if (!mounted) return;
      final log = await showModalBottomSheet<MealLog>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ManualFoodAddSheet(
          catalog: catalog,
          initialMealType: MealType.defaultForLocalTime(DateTime.now()),
          targetDate: _selectedDate,
          favoriteFoodIds: _favoriteFoodIds,
          recentFoodIds: _recentFoodIds,
          estimator:
              widget.estimator ??
              HybridNutritionEstimator(
                catalog: catalog,
                isBuiltInAiEnabled: _llmModelManager.isReady,
              ),
          isAiModelReady: _llmModelManager.isReady,
          onOpenAiModelManager: () {
            Navigator.of(context).pop();
            unawaited(_openLlmModelDialog());
          },
          onToggleFavorite: (foodId) {
            unawaited(() async {
              final updated = await _repository.toggleFavoriteFoodId(foodId);
              if (mounted) {
                setState(() => _favoriteFoodIds = updated);
              }
            }());
          },
          onSaveCustomFood: (customFood) {
            unawaited(() async {
              await _repository.saveCustomFood(customFood);
              final current = _catalog;
              if (current != null && mounted) {
                setState(() {
                  _catalog = current.mergeFoods(<NutritionFood>[customFood]);
                });
              }
            }());
          },
        ),
      );
      if (log != null && mounted) {
        await _persistAndMaybeSyncMeal(log);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Manual Add: $error')),
      );
    }
  }

  String _formatDateLabel(DateTime date) {
    final today = _dateOnly(DateTime.now());
    final yesterday = _dateOnly(today.subtract(const Duration(days: 1)));
    final tomorrow = _dateOnly(today.add(const Duration(days: 1)));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    if (date == tomorrow) return 'Tomorrow';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _openLlmModelDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ListenableBuilder(
        listenable: _llmModelManager,
        builder: (context, _) {
          final info = _llmModelManager.modelInfo;
          final state = _llmModelManager.state;
          final progress = _llmModelManager.progress;
          final error = _llmModelManager.errorMessage;
          final statusText = switch (state) {
            LlmModelState.notDownloaded =>
              'Model deleted. Auto-fill uses basic catalog lookup only.',
            LlmModelState.downloading =>
              'Downloading (${(progress * 100).round()}%)...',
            LlmModelState.ready =>
              'Built-in (${(_llmModelManager.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB). Ready offline.',
            LlmModelState.error => error ?? 'Could not manage model.',
          };

          return AlertDialog(
            title: const Text('On-Device AI Model'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${info.displayName} (~${info.approxSizeMb} MB)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(statusText),
                if (state == LlmModelState.downloading) ...<Widget>[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              if (state == LlmModelState.ready)
                TextButton(
                  onPressed: () => unawaited(_llmModelManager.deleteModel()),
                  child: const Text('Delete'),
                )
              else if (state != LlmModelState.downloading)
                FilledButton(
                  onPressed: () => unawaited(_llmModelManager.downloadModel()),
                  child: const Text('Download'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSettingsDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          return AlertDialog(
            title: const Text('Settings'),
            content: SizedBox(
              width: double.maxFinite,
              child: _buildHealthConnectContent(
                theme,
                colorScheme,
                onAfterToggle: () {
                  if (dialogContext.mounted) {
                    setDialogState(() {});
                  }
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = _dateOnly(DateTime.now());
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Snap & Tracker'),
        actions: <Widget>[
          IconButton(
            tooltip: 'On-Device AI Model',
            onPressed: _openLlmModelDialog,
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettingsDialog,
            icon: const Icon(Icons.settings_outlined),
          ),
          if (_selectedDate != today)
            TextButton(onPressed: _jumpToToday, child: const Text('Today')),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadInitialData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: <Widget>[
                _buildDateHeader(theme, colorScheme),
                const SizedBox(height: 12),
                if (summary != null)
                  _buildSummaryCard(theme, colorScheme, summary),
                const SizedBox(height: 12),
                _buildQuickActionsRow(),
                const SizedBox(height: 16),
                if (summary != null)
                  ...MealType.values.map(
                    (mealType) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildMealGroupCard(
                        theme,
                        colorScheme,
                        mealType,
                        summary,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDateHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          tooltip: 'Previous day',
          onPressed: () => _changeDate(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          _formatDateLabel(_selectedDate),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          onPressed: () => _changeDate(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    ColorScheme colorScheme,
    DailyNutritionSummary summary,
  ) {
    final consumed = summary.totalKcal.round();
    final goal = summary.dailyKcalGoal.round();
    final remaining = summary.remainingKcal.round();
    final overage = summary.overageKcal.round();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$consumed / $goal kcal',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.isOverGoal
                          ? '$overage kcal over daily goal'
                          : '$remaining kcal remaining',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: summary.isOverGoal
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                ActionChip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Edit goal'),
                  onPressed: _editDailyGoal,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.goalProgress,
                minHeight: 10,
                color: summary.isOverGoal ? colorScheme.error : null,
                backgroundColor: colorScheme.surface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MacroMetric(
                    label: 'Protein',
                    grams: summary.totalProteinGrams,
                  ),
                ),
                Expanded(
                  child: _MacroMetric(
                    label: 'Carbs',
                    grams: summary.totalCarbsGrams,
                  ),
                ),
                Expanded(
                  child: _MacroMetric(
                    label: 'Fat',
                    grams: summary.totalFatGrams,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthConnectContent(
    ThemeData theme,
    ColorScheme colorScheme, {
    VoidCallback? onAfterToggle,
  }) {
    final canEnable =
        _isAndroid && _hcStatus == NutritionHealthConnectStatus.available;
    final switchValue = canEnable && _hcSyncEnabled && _hcHasPermission;

    final String subtitle;
    final bool showSettingsAction;
    if (!_isAndroid) {
      subtitle =
          'Health Connect sync is available on Android only. Meals are saved locally.';
      showSettingsAction = false;
    } else if (_hcStatus == NutritionHealthConnectStatus.unavailable) {
      subtitle =
          'Health Connect is unavailable on this device. Meals are saved locally.';
      showSettingsAction = false;
    } else if (_hcStatus ==
        NutritionHealthConnectStatus.providerUpdateRequired) {
      subtitle =
          'Health Connect needs an update before syncing. Local logging works normally.';
      showSettingsAction = true;
    } else if (_hcPermissionDeclined && !switchValue) {
      subtitle =
          'Nutrition write permission was declined. Grant access in settings or continue logging locally.';
      showSettingsAction = true;
    } else if (switchValue) {
      subtitle =
          'New meals sync calories and macros to Android Health Connect.';
      showSettingsAction = false;
    } else {
      subtitle =
          'Optional: sync logged meals (kcal, protein, carbs, fat) to Health Connect.';
      showSettingsAction = false;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(
            Icons.sync_rounded,
            color: switchValue
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          title: const Text('Health Connect sync'),
          subtitle: Text(subtitle),
          value: switchValue,
          onChanged: canEnable
              ? (value) async {
                  await _onToggleHealthConnect(value);
                  onAfterToggle?.call();
                }
              : null,
        ),
        if (showSettingsAction)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                unawaited(
                  _healthConnectGateway.openHealthConnectSettings(),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Health Connect'),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: _isSnapping ? null : _startSnapFlow,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Snap Food'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSnapping ? null : _openManualAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Manual Add'),
          ),
        ),
      ],
    );
  }

  Widget _buildMealGroupCard(
    ThemeData theme,
    ColorScheme colorScheme,
    MealType mealType,
    DailyNutritionSummary summary,
  ) {
    final logs = summary.logsForMealType(mealType);
    final subtotal = summary.kcalForMealType(mealType).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  mealType.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$subtotal kcal',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Text(
                'No items logged',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...List<Widget>.generate(logs.length, (index) {
                final log = logs[index];
                return Column(
                  children: <Widget>[
                    if (index > 0) const Divider(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _editMealLog(log),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    log.foodName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${log.servingGrams.round()} g · '
                                    'P ${log.proteinGrams.toStringAsFixed(0)}g · '
                                    'C ${log.carbsGrams.toStringAsFixed(0)}g · '
                                    'F ${log.fatGrams.toStringAsFixed(0)}g',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (log.healthConnectId != null) ...<Widget>[
                              Icon(
                                Icons.cloud_done_outlined,
                                size: 15,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '${log.kcal.round()} kcal',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete meal',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => _deleteMealLog(log),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MacroMetric extends StatelessWidget {
  const _MacroMetric({required this.label, required this.grams});

  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${grams.toStringAsFixed(0)} g',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
