import 'package:shared_preferences/shared_preferences.dart';

const String _kShowJackKnifeTable = 'fleet_em_dashboard.v1.jk_show_table';

/// Jack Knife UI preferences (persisted in browser).
class JackKnifeViewPrefs {
  JackKnifeViewPrefs._();

  static bool _showTable = true;

  static bool get showTable => _showTable;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showTable = prefs.getBool(_kShowJackKnifeTable) ?? true;
    } catch (_) {}
  }

  static Future<bool> setShowTable(bool value) async {
    _showTable = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_kShowJackKnifeTable, value);
    } catch (_) {
      return false;
    }
  }
}
