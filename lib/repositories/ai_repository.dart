import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import '../constants/firebase_config.dart';
import '../models/listing_estimate.dart';

class AiRepository {
  final FirebaseFunctions _functions;

  AiRepository({FirebaseFunctions? functions})
      : _functions = functions ?? appFunctions();

  static String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  /// Sends every photo (already shrunk to <=1600px by the image picker) to
  /// the `estimateListing` Cloud Function, which asks Gemini. The API key
  /// stays server-side; the app never sees it.
  Future<ListingEstimate> estimateListing(List<File> images,
      {String hint = ''}) async {
    final payload = <Map<String, String>>[];
    for (final file in images) {
      payload.add({
        'data': base64Encode(await file.readAsBytes()),
        'mimeType': _mimeType(file.path),
      });
    }
    try {
      final callable = _functions.httpsCallable(
        'estimateListing',
        // Matches the function's own 120 s timeout (free-tier Gemini keys
        // can queue for a while at busy times).
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call({'images': payload, 'hint': hint});
      return ListingEstimate.fromJson(
          Map<String, dynamic>.from(result.data as Map));
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'ผู้ช่วย AI ประเมินไม่สำเร็จ กรุณาลองใหม่');
    }
  }
}
