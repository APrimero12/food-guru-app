// lib/services/cloudinary_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  // ── Config ─────────────────────────────────────────────────────────────────
  static const String cloudName    = 'dhagylhdk';
  static const String uploadPreset = 'FoodGuru';
  // ── URL transformation ─────────────────────────────────────────────────────

  /// Inserts Cloudinary transformation parameters into an existing URL so the
  /// CDN resizes and re-encodes the image before delivery.
  ///
  /// Returns [url] unchanged when it is empty or not a Cloudinary URL, so
  /// non-Cloudinary images (e.g. Google avatar URLs) still render correctly.
  ///
  /// Common [crop] values:
  ///   • 'fill'  — crops to exact w×h, keeps subject centred (default)
  ///   • 'fit'   — fits within w×h without cropping
  ///   • 'thumb' — tight crop around the detected subject
  ///
  /// [gravity] 'auto' uses Cloudinary's AI to find the focal point.
  static String transform(
      String url, {
        int?   width,
        int?   height,
        String crop    = 'fill',
        String gravity = 'auto',
        String quality = 'auto',
        String format  = 'auto',
      }) {
    if (url.isEmpty || !url.contains('cloudinary.com')) return url;

    final segments = url.split('/upload/');
    if (segments.length != 2) return url;

    final params = <String>[
      if (width  != null) 'w_$width',
      if (height != null) 'h_$height',
      'c_$crop',
      'g_$gravity',
      'f_$format',
      'q_$quality',
    ];

    return '${segments[0]}/upload/${params.join(',')}/${segments[1]}';
  }

  // ── Preset sizes ───────────────────────────────────────────────────────────
  // Call these instead of [transform] directly for consistent sizing.

  /// 4:3 thumbnail for recipe grid cards (600 × 450 px).
  static String cardThumbnail(String url) =>
      transform(url, width: 600, height: 450);

  /// Wide hero image for the recipe detail page (1 080 × 640 px).
  static String detailHero(String url) =>
      transform(url, width: 1080, height: 640);

  /// Small square avatar (200 × 200 px).
  static String avatar(String url) =>
      transform(url, width: 200, height: 200, crop: 'thumb');

  // ── Upload ─────────────────────────────────────────────────────────────────

  static Future<String> upload({
    required File   file,
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