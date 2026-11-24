import 'package:flutter/foundation.dart';

import 'on_device_llm_storage_stub.dart'
    if (dart.library.io) 'on_device_llm_storage_io.dart'
    as storage_impl;
import 'on_device_llm_storage_stub.dart';

/// Lifecycle state of the optional downloadable on-device nutrition LLM.
enum LlmModelState { notDownloaded, downloading, ready, error }

/// Descriptor for the optional small quantized on-device nutrition LLM.
@immutable
class LlmModelInfo {
  const LlmModelInfo({
    required this.id,
    required this.displayName,
    required this.approxSizeMb,
    required this.fileName,
    required this.downloadUrl,
  });

  final String id;
  final String displayName;
  final int approxSizeMb;
  final String fileName;
  final String downloadUrl;

  static const LlmModelInfo defaultCompactModel = LlmModelInfo(
    id: 'builtin_nutrition_ai_v1',
    displayName: 'Built-in Nutrition AI',
    approxSizeMb: 20,
    fileName: 'builtin_nutrition_ai_v1.bin',
    downloadUrl: '',
  );
}

/// Manages status, deletion, and re-download/restore of the on-device
/// nutrition AI model, starting ready out of the box.
class OnDeviceLlmModelManager extends ChangeNotifier {
  OnDeviceLlmModelManager({
    this.modelInfo = LlmModelInfo.defaultCompactModel,
    OnDeviceLlmStorageBackend? backend,
  }) : _backend = backend ?? storage_impl.createOnDeviceLlmStorageBackend();

  final LlmModelInfo modelInfo;
  final OnDeviceLlmStorageBackend _backend;

  LlmModelState _state = LlmModelState.ready;
  double _progress = 1.0;
  int _downloadedBytes = 20 * 1024 * 1024;
  String? _errorMessage;

  LlmModelState get state => _state;
  double get progress => _progress;
  int get downloadedBytes => _downloadedBytes;
  String? get errorMessage => _errorMessage;
  bool get isReady => _state == LlmModelState.ready;

  Future<void> refreshStatus() async {
    if (kIsWeb) {
      _state = LlmModelState.notDownloaded;
      notifyListeners();
      return;
    }
    try {
      final deleted = await _backend.isBundledDeleted(modelInfo.fileName);
      if (deleted) {
        _downloadedBytes = 0;
        _state = LlmModelState.notDownloaded;
        _progress = 0.0;
      } else {
        final fileSize = await _backend.fileSizeBytes(modelInfo.fileName);
        _downloadedBytes = fileSize > 0
            ? fileSize
            : modelInfo.approxSizeMb * 1024 * 1024;
        _state = LlmModelState.ready;
        _progress = 1.0;
      }
      _errorMessage = null;
    } catch (error) {
      _state = LlmModelState.error;
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> downloadModel() async {
    if (_state == LlmModelState.downloading) return;
    _state = LlmModelState.downloading;
    _progress = 0.0;
    _downloadedBytes = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      if (modelInfo.downloadUrl.isNotEmpty) {
        await _backend.downloadToFile(
          url: modelInfo.downloadUrl,
          fileName: modelInfo.fileName,
          onProgress: (received, total) {
            _downloadedBytes = received;
            if (total > 0) {
              _progress = (received / total).clamp(0.0, 1.0);
            }
            notifyListeners();
          },
        );
        final fileSize = await _backend.fileSizeBytes(modelInfo.fileName);
        _downloadedBytes = fileSize > 0
            ? fileSize
            : modelInfo.approxSizeMb * 1024 * 1024;
      } else {
        _downloadedBytes = modelInfo.approxSizeMb * 1024 * 1024;
      }
      await _backend.setBundledDeleted(modelInfo.fileName, false);
      _progress = 1.0;
      _state = LlmModelState.ready;
    } catch (error) {
      _state = LlmModelState.error;
      _errorMessage = 'Download failed: $error';
    }
    notifyListeners();
  }

  Future<void> deleteModel() async {
    try {
      await _backend.deleteFile(modelInfo.fileName);
      await _backend.setBundledDeleted(modelInfo.fileName, true);
      _downloadedBytes = 0;
      _progress = 0.0;
      _state = LlmModelState.notDownloaded;
      _errorMessage = null;
    } catch (error) {
      _state = LlmModelState.error;
      _errorMessage = 'Could not delete model: $error';
    }
    notifyListeners();
  }
}
