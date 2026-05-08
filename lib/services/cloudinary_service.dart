// lib/services/cloudinary_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // ── Config ─────────────────────────────────────────────────────────────────
  // Replace with your own values from cloudinary.com → Settings → Upload
  static const String cloudName    = 'dhagylhdk';
  static const String uploadPreset = 'FoodGuru';

  // ── Upload ─────────────────────────────────────────────────────────────────

  /// Uploads [file] to Cloudinary under [folder] and returns the secure URL.
  ///
  /// [publicId] should be unique per upload (include a timestamp) so that
  /// unsigned presets don't need "overwrite" enabled.
  ///
  /// [onProgress] is called with values from 0.0 → 1.0 as the request proceeds.
  static Future<String> upload({
    required File file,
    required String folder,
    required String publicId,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await file.readAsBytes();

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder']        = folder
      ..fields['public_id']     = publicId
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: '${publicId.split('/').last}.jpg',
      ));

    onProgress?.call(0.1);

    final streamedResponse = await request.send();

    onProgress?.call(0.8);

    final body = await streamedResponse.stream.bytesToString();

    onProgress?.call(1.0);

    if (streamedResponse.statusCode != 200) {
      throw Exception(
          'Cloudinary upload failed (${streamedResponse.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }
}