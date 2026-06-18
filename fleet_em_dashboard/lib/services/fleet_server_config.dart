/// Shared server endpoints for https://strakin.tech/em/
///
/// Override at build time:
/// `--dart-define=FLEET_EXCEL_URL=...`
/// `--dart-define=FLEET_UPLOAD_URL=...`
/// `--dart-define=FLEET_CURRENT_URL=...`
/// `--dart-define=FLEET_UPLOAD_URL_LIST2=...`
/// `--dart-define=FLEET_CURRENT_URL_LIST2=...`
/// `--dart-define=FLEET_ACTIVE_LIST=list1|list2`
/// `--dart-define=FLEET_UPLOAD_TOKEN=...`
class FleetServerConfig {
  FleetServerConfig._();

  static const String _hostBase = String.fromEnvironment(
    'FLEET_HOST_BASE',
    defaultValue: 'https://strakin.tech/em',
  );

  static const String _excelFileName = String.fromEnvironment(
    'FLEET_EXCEL_FILENAME',
    defaultValue: 'Dashboard_EM.xlsx',
  );

  static const String excelUrlOverride = String.fromEnvironment(
    'FLEET_EXCEL_URL',
    defaultValue: '',
  );

  static const String uploadUrl = String.fromEnvironment(
    'FLEET_UPLOAD_URL',
    defaultValue: 'https://strakin.tech/em/api/upload.php',
  );

  static const String currentUrl = String.fromEnvironment(
    'FLEET_CURRENT_URL',
    defaultValue: 'https://strakin.tech/em/api/current.php',
  );

  static const String uploadUrlList2 = String.fromEnvironment(
    'FLEET_UPLOAD_URL_LIST2',
    defaultValue: 'https://strakin.tech/em/api/upload_list2.php',
  );

  static const String currentUrlList2 = String.fromEnvironment(
    'FLEET_CURRENT_URL_LIST2',
    defaultValue: 'https://strakin.tech/em/api/current_list2.php',
  );

  static const String activeList = String.fromEnvironment(
    'FLEET_ACTIVE_LIST',
    defaultValue: 'list1',
  );

  static const String uploadToken = String.fromEnvironment(
    'FLEET_UPLOAD_TOKEN',
    defaultValue: 'fleet-em-change-me',
  );

  /// Fallback jika `current.php` belum punya file (migrasi dari deploy lama).
  static String get legacyDefaultExcelUrl {
    final override = excelUrlOverride.trim();
    if (override.isNotEmpty) return override;
    final base = _hostBase.replaceAll(RegExp(r'/+$'), '');
    final sub = activeList.trim().toLowerCase() == 'list2' ? 'list2' : 'list1';
    return '$base/data/$sub/$_excelFileName';
  }

  @Deprecated('Use ExcelCurrentService.resolveServerExcelUrl()')
  static String get defaultExcelUrl => legacyDefaultExcelUrl;

  static bool get hasUploadEndpoint =>
      uploadUrl.trim().isNotEmpty || uploadUrlList2.trim().isNotEmpty;

  static bool get hasCurrentEndpoint =>
      currentUrl.trim().isNotEmpty || currentUrlList2.trim().isNotEmpty;
}
