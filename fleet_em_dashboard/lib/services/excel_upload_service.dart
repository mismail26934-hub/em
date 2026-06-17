import 'dart:convert';

import 'package:http/http.dart' as http;

import 'fleet_server_config.dart';

class ExcelUploadResult {
  const ExcelUploadResult({
    required this.ok,
    this.url,
    this.filename,
    this.error,
  });

  final bool ok;
  final String? url;
  final String? filename;
  final String? error;
}

/// Upload `.xlsx` to PHP backend; file disimpan di `/em/data/` di server.
class ExcelUploadService {
  ExcelUploadService._();

  static Future<ExcelUploadResult> uploadBytes(
    List<int> bytes,
    String filename,
  ) async {
    final endpoint = FleetServerConfig.uploadUrl.trim();
    if (endpoint.isEmpty) {
      return const ExcelUploadResult(
        ok: false,
        error: 'Endpoint upload belum dikonfigurasi.',
      );
    }

    try {
      final req = http.MultipartRequest('POST', Uri.parse(endpoint));
      req.headers['X-Upload-Token'] = FleetServerConfig.uploadToken;
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename.endsWith('.xlsx') ? filename : '$filename.xlsx',
        ),
      );

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      Map<String, dynamic>? json;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final msg = json?['error']?.toString();
        return ExcelUploadResult(
          ok: false,
          error: msg ?? 'Upload gagal (HTTP ${streamed.statusCode}).',
        );
      }

      if (json?['ok'] == true) {
        final url = json?['url']?.toString().trim();
        final filename = json?['filename']?.toString().trim();
        return ExcelUploadResult(
          ok: true,
          url: url,
          filename: filename,
        );
      }

      return ExcelUploadResult(
        ok: false,
        error: json?['error']?.toString() ?? 'Upload gagal.',
      );
    } catch (e) {
      return ExcelUploadResult(ok: false, error: '$e');
    }
  }
}
