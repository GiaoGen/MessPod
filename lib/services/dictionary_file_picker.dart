import 'package:flutter/services.dart';

class PickedDictionaryFile {
  const PickedDictionaryFile({
    required this.name,
    required this.path,
  });

  final String name;
  final String path;
}

class DictionaryFilePicker {
  static const _channel = MethodChannel('ytpodcast/file_picker');

  Future<PickedDictionaryFile?> pickDictionaryFile() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'pickDictionaryFile',
    );
    if (result == null) {
      return null;
    }

    final name = result['name'] as String?;
    final path = result['path'] as String?;
    if (name == null || path == null) {
      return null;
    }

    return PickedDictionaryFile(name: name, path: path);
  }
}
