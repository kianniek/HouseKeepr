import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'on_device_llm_storage_stub.dart';

OnDeviceLlmStorageBackend createOnDeviceLlmStorageBackend() {
  return _IoOnDeviceLlmStorageBackend();
}

class _IoOnDeviceLlmStorageBackend implements OnDeviceLlmStorageBackend {
  Future<Directory> _modelDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}food_llm');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _resolveFile(String fileName) async {
    final dir = await _modelDir();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<bool> exists(String fileName) async {
    final file = await _resolveFile(fileName);
    return file.exists();
  }

  @override
  Future<int> fileSizeBytes(String fileName) async {
    final file = await _resolveFile(fileName);
    if (!await file.exists()) return 0;
    return file.length();
  }

  @override
  Future<bool> isBundledDeleted(String fileName) async {
    final marker = await _resolveFile('$fileName.deleted');
    return marker.exists();
  }

  @override
  Future<void> setBundledDeleted(String fileName, bool deleted) async {
    final marker = await _resolveFile('$fileName.deleted');
    if (deleted) {
      await marker.writeAsString('1');
    } else if (await marker.exists()) {
      await marker.delete();
    }
  }

  @override
  Future<void> downloadToFile({
    required String url,
    required String fileName,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    final target = await _resolveFile(fileName);
    final partFile = File('${target.path}.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Model download failed with HTTP ${response.statusCode}.',
          uri: Uri.parse(url),
        );
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final sink = partFile.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          onProgress(receivedBytes, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (await target.exists()) {
        await target.delete();
      }
      await partFile.rename(target.path);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> deleteFile(String fileName) async {
    final file = await _resolveFile(fileName);
    if (await file.exists()) {
      await file.delete();
    }
    final partFile = File('${file.path}.part');
    if (await partFile.exists()) {
      await partFile.delete();
    }
  }
}
