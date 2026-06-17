import 'workbook_read_result.dart';

Future<WorkbookReadResult> readConfiguredLocalPath() async =>
    const WorkbookReadResult();

Future<WorkbookReadResult> readPathIfSupported(String absolutePath) async =>
    const WorkbookReadResult(
      error: 'Reading a local file path is not supported on this platform. '
          'Use Windows/macOS/Linux build with FLEET_EXCEL_PATH, or set FLEET_EXCEL_URL for web.',
    );
