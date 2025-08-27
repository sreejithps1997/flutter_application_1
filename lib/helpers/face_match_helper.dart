import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class FaceMatchHelper {
  // TODO: move these to secure config for production
  static const String _apiKey = 'eZkHmbMcd4qQx1k7g80WcEmpqLUcl61D';
  static const String _apiSecret = 'sIuuag0dw6uWrzO0KF9f2cE2k1bMyMpE';
  static const String _apiUrl =
      'https://api-us.faceplusplus.com/facepp/v3/compare';

  /// Main entry: compare faces using either [selfieBytes] or [selfieFile] + a [profileImageUrl].
  /// Returns confidence (0..100) or null on failure/timeout.
  static Future<double?> compareFaces({
    Uint8List? selfieBytes,
    File? selfieFile,
    required String profileImageUrl,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    try {
      if (profileImageUrl.isEmpty) return null;
      if (selfieBytes == null && selfieFile == null) return null;

      final uri = Uri.parse(_apiUrl);
      final req = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = _apiKey
        ..fields['api_secret'] = _apiSecret
        ..fields['image_url2'] = profileImageUrl;

      // Prefer bytes to avoid extra disk I/O when called from an isolate
      if (selfieBytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'image_file1',
            selfieBytes,
            filename: 'selfie.jpg',
            // contentType isn't required for Face++, but you can set it if needed:
            // contentType: MediaType('image', 'jpeg'),
          ),
        );
      } else {
        req.files.add(
          await http.MultipartFile.fromPath('image_file1', selfieFile!.path),
        );
      }

      final streamed = await req.send().timeout(timeout);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        // Face++ sometimes returns HTML on errors; don't crash on decode
        _log("❌ Face++ ${streamed.statusCode}: $body");
        return null;
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        _log("❌ Face++ non-JSON response: $body");
        return null;
      }

      // Typical response has top-level 'confidence'
      final conf = data['confidence'];
      if (conf is num) return conf.toDouble();

      // Fallback if provider nests it
      final result = data['result'];
      if (result is Map && result['confidence'] is num) {
        return (result['confidence'] as num).toDouble();
      }

      // No usable confidence
      _log("⚠️ Face++ no confidence in response: $data");
      return null;
    } on TimeoutException {
      _log("⚠️ Face++ request timed out");
      return null;
    } catch (e, st) {
      _log("⚠️ Face match failed: $e\n$st");
      return null;
    }
  }

  static void _log(Object msg) {
    // Centralize logging, easy to silence in release if you want
    // ignore: avoid_print
    print(msg);
  }
}
