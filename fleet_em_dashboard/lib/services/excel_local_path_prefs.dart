import 'package:shared_preferences/shared_preferences.dart';

const String _kExcelLocalPath = 'fleet_em_dashboard.v1.excel_local_path';

/// Path absolut berkas `.xlsx` terakhir yang berhasil dimuat (desktop/native saja).
Future<String> loadExcelLocalPath() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kExcelLocalPath)?.trim() ?? '';
  } catch (_) {
    return '';
  }
}

Future<bool> saveExcelLocalPath(String absolutePath) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final p = absolutePath.trim();
    if (p.isEmpty) {
      await prefs.remove(_kExcelLocalPath);
      return true;
    }
    return await prefs.setString(_kExcelLocalPath, p);
  } catch (_) {
    return false;
  }
}
