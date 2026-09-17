import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps on-device text recognition (Google ML Kit) for reading a
/// photographed receipt. Android/iOS only — there is no web implementation
/// of ML Kit, so callers must check [isSupported] first and fall back to
/// the paste-text flow on web/desktop.
class OcrService {
  static bool get isSupported => !kIsWeb;

  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      await recognizer.close();
    }
  }
}
