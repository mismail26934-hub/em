import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dashboard_list_mode.dart';
import 'fleet_server_config.dart';

class ExcelCurrentInfo {
  const ExcelCurrentInfo({
    required this.url,
    required this.filename,
    this.size,
    this.updatedAt,
  });

  final String url;
  final String filename;
  final int? size;
  final String? updatedAt;

  factory ExcelCurrentInfo.fromJson(Map<String, dynamic> json) {
    return ExcelCurrentInfo(
      url: json['url']?.toString().trim() ?? '',
      filename: json['filename']?.toString().trim() ?? '',
      size: json['size'] is int ? json['size'] as int : int.tryParse('${json['size']}'),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

/// Membaca file Excel aktif dari `current.php` di server.
class ExcelCurrentService {
  ExcelCurrentService._();

  static Future<ExcelCurrentInfo?> fetchCurrent() async {
    final endpoint = DashboardListMode.currentUrl.trim();
    if (endpoint.isEmpty) return null;

    try {
      final r = await http.get(Uri.parse(endpoint));
      if (r.statusCode < 200 || r.statusCode >= 300) return null;

      final decoded = jsonDecode(r.body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['ok'] != true) return null;

      final info = ExcelCurrentInfo.fromJson(decoded);
      if (info.url.isEmpty) return null;
      return info;
    } catch (_) {
      return null;
    }
  }

  /// URL file aktif di server: override build → current.php → fallback statis.
  static Future<String?> resolveServerExcelUrl() async {
    final override = FleetServerConfig.excelUrlOverride.trim();
    if (override.isNotEmpty) return override;

    final current = await fetchCurrent();
    if (current != null && current.url.isNotEmpty) return current.url;

    final legacy = FleetServerConfig.legacyDefaultExcelUrl.trim();
    return legacy.isEmpty ? null : legacy;
  }
}
