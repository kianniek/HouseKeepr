import 'dart:convert';
import 'dart:typed_data';

Uint8List avatarBytes() {
  // base64 string embedded for tests (1x1 PNG)
  final b64 =
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMBAQEAiQ0AAAAASUVORK5CYII=";
  return base64Decode(b64);
}
