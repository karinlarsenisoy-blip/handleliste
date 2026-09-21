import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

/// Reads text out of a photographed receipt — on-device (Google ML Kit) on
/// Android/iOS, since that's fast, free, and needs no network; via the
/// `receiptOcr` Cloud Function (Google Cloud Vision) on web, since ML Kit is
/// a native SDK with no web implementation at all — there's nothing to fall
/// back to client-side, so this proxies to a server that can actually run
/// OCR on the image.
class OcrService {
  OcrService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://handleliste-f1659.web.app/api/receipt-ocr';

  final http.Client _client;
  final String _baseUrl;

  /// Reads text from an on-device file path — Android/iOS only. Use
  /// [recognizeTextFromBytes] on web, where [imagePath] (an `XFile.path`)
  /// is a blob URL, not a real file ML Kit could open.
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

  /// Reads text from raw image bytes via the `receiptOcr` Cloud Function —
  /// the web path. Requires a signed-in user (anonymous is fine) since the
  /// endpoint is a paid-per-call API gated behind a valid Firebase Auth
  /// token.
  Future<String> recognizeTextFromBytes(Uint8List bytes) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw StateError('recognizeTextFromBytes needs a signed-in user (even an anonymous one).');
    }

    final response = await _client
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'imageBase64': base64Encode(bytes)}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('receiptOcr returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['text'] as String? ?? '';
  }
}
