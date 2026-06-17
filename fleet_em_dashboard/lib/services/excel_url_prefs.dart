import 'package:shared_preferences/shared_preferences.dart';

const String _kExcelDataUrl = 'fleet_em_dashboard.v1.excel_data_url';

/// User-saved HTTPS/HTTP URL for the `.xlsx` workbook (no file upload).
Future<String> loadExcelDataUrl() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kExcelDataUrl)?.trim() ?? '';
  } catch (_) {
    return '';
  }
}

Future<bool> saveExcelDataUrl(String url) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final u = url.trim();
    if (u.isEmpty) {
      await prefs.remove(_kExcelDataUrl);
      return true;
    }
    return await prefs.setString(_kExcelDataUrl, u);
  } catch (_) {
    return false;
  }
}
