import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Helper class for picking files across platforms
class FilePickerHelper {
  /// Picks an image file and returns the File object (or bytes for web)
  /// Returns null if user cancels
  static Future<FilePickerResult?> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      return result;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  /// Gets file bytes from FilePickerResult (for web)
  static List<int>? getBytes(FilePickerResult? result) {
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.bytes;
  }

  /// Gets file name from FilePickerResult
  static String? getFileName(FilePickerResult? result) {
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.name;
  }

  /// Gets File object from FilePickerResult (for non-web platforms)
  static File? getFile(FilePickerResult? result) {
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  /// Checks if platform is web
  static bool get isWeb => kIsWeb;
}

