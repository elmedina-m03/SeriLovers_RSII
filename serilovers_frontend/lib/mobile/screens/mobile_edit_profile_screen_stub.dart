// Stub implementation for non-web platforms (desktop/mobile)
import 'dart:typed_data';

/// Picks an image file (stub for non-web platforms)
/// Returns null as file picking requires platform-specific implementation
Future<Map<String, dynamic>?> pickImageFile() async {
  // Stub implementation - returns null
  // For desktop/mobile, you would use file_picker package or platform channels
  return null;
}

