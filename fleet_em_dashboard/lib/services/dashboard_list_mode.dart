import 'package:shared_preferences/shared_preferences.dart';

import 'fleet_server_config.dart';

const String _kDashboardListMode = 'fleet_em_dashboard.v1.dashboard_list_mode';

/// Runtime list1/list2 selection (persisted). Overrides compile-time [FleetServerConfig.activeList].
class DashboardListMode {
  DashboardListMode._();

  static String? _runtime;

  static String get current {
    final r = _runtime?.trim();
    if (r == 'list1' || r == 'list2') return r!;
    final compiled = FleetServerConfig.activeList.trim().toLowerCase();
    return compiled == 'list2' ? 'list2' : 'list1';
  }

  static bool get isList2 => current == 'list2';

  static String get uploadUrl =>
      isList2 ? FleetServerConfig.uploadUrlList2 : FleetServerConfig.uploadUrl;

  static String get currentUrl =>
      isList2 ? FleetServerConfig.currentUrlList2 : FleetServerConfig.currentUrl;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kDashboardListMode)?.trim();
      if (saved == 'list1' || saved == 'list2') {
        _runtime = saved;
        return;
      }
      final compiled = FleetServerConfig.activeList.trim().toLowerCase();
      _runtime = compiled == 'list2' ? 'list2' : 'list1';
    } catch (_) {}
  }

  static Future<bool> setMode(String mode) async {
    final m = mode.trim().toLowerCase();
    if (m != 'list1' && m != 'list2') return false;
    _runtime = m;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_kDashboardListMode, m);
    } catch (_) {
      return false;
    }
  }
}
