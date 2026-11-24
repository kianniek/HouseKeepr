abstract class OnDeviceLlmStorageBackend {
  Future<bool> exists(String fileName);
  Future<int> fileSizeBytes(String fileName);
  Future<bool> isBundledDeleted(String fileName) async => false;
  Future<void> setBundledDeleted(String fileName, bool deleted) async {}
  Future<void> downloadToFile({
    required String url,
    required String fileName,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  });
  Future<void> deleteFile(String fileName);
}

OnDeviceLlmStorageBackend createOnDeviceLlmStorageBackend() {
  return _StubOnDeviceLlmStorageBackend();
}

class _StubOnDeviceLlmStorageBackend implements OnDeviceLlmStorageBackend {
  @override
  Future<bool> exists(String fileName) async => false;

  @override
  Future<int> fileSizeBytes(String fileName) async => 0;

  @override
  Future<bool> isBundledDeleted(String fileName) async => false;

  @override
  Future<void> setBundledDeleted(String fileName, bool deleted) async {}

  @override
  Future<void> downloadToFile({
    required String url,
    required String fileName,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    throw UnsupportedError(
      'On-device LLM model download is only supported on native platforms.',
    );
  }

  @override
  Future<void> deleteFile(String fileName) async {}
}
