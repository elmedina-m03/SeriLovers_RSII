// Web-specific implementation for file picking
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

/// Picks an image file (web only)
Future<Map<String, dynamic>?> pickImageFile() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  final completer = Completer<Map<String, dynamic>?>();
  
  input.onChange.listen((e) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((e) {
      if (reader.result != null) {
        completer.complete({
          'bytes': reader.result as Uint8List,
          'fileName': file.name,
        });
      } else {
        completer.complete(null);
      }
    });

    reader.readAsArrayBuffer(file);
  });

  return completer.future;
}

