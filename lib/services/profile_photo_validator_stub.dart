import 'dart:typed_data';

import 'photo_validation_result.dart';

/// Fallback used only if the target platform is neither dart:io nor
/// dart:html (shouldn't happen for Flutter mobile/web/desktop). Fails
/// open rather than blocking users on an unsupported platform.
Future<PhotoValidationResult> validateImpl({
  required String imagePath,
  required Uint8List bytes,
}) async {
  return PhotoValidationResult.valid();
}

void disposeImpl() {}
