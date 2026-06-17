import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'local_workbook.dart' as local;
import 'workbook_read_result.dart';

/// Loads workbook bytes from URL or compile-time / env configuration.
///
/// **Priority in app UI** (see dashboard): saved URL → saved local path (prefs) →
/// then [loadFromEnvironment].
///
/// [loadFromEnvironment] order:
/// 1. `FLEET_EXCEL_URL` — compile-time `dart-define` (same as [loadFromHttpUrl]).
/// 2. `FLEET_EXCEL_PATH` — local file, **VM only** (not web).
class WorkbookLoader {
  WorkbookLoader._();

  static const String excelUrl = String.fromEnvironment('FLEET_EXCEL_URL', defaultValue: '');

  /// HTTP GET of an `.xlsx` at [url] (`http` / `https` only).
  static Future<WorkbookReadResult> loadFromHttpUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const WorkbookReadResult();
    }
    try {
      final uri = Uri.parse(trimmed);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return WorkbookReadResult(
          label: trimmed,
          error: 'URL harus diawali http:// atau https://',
        );
      }
      final r = await http.get(uri);
      if (r.statusCode < 200 || r.statusCode >= 300) {
        return WorkbookReadResult(
          label: trimmed,
          error: 'Unduhan gagal (HTTP ${r.statusCode}).',
        );
      }
      return WorkbookReadResult(bytes: r.bodyBytes, label: trimmed);
    } catch (e) {
      return WorkbookReadResult(label: trimmed, error: '$e');
    }
  }

  /// `FLEET_EXCEL_URL` then local path (desktop VM only).
  static Future<WorkbookReadResult> loadFromEnvironment() async {
    if (excelUrl.isNotEmpty) {
      return loadFromHttpUrl(excelUrl);
    }
    if (kIsWeb) {
      return const WorkbookReadResult();
    }
    return local.readConfiguredLocalPath();
  }

  /// Re-read a known absolute path (optional desktop tooling).
  static Future<WorkbookReadResult> readPath(String absolutePath) =>
      local.readPathIfSupported(absolutePath);
}
