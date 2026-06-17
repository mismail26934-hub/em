import 'dart:io';

import 'workbook_read_result.dart';

String _resolvedConfiguredPath() {
  const fromDefine = String.fromEnvironment('FLEET_EXCEL_PATH', defaultValue: '');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Platform.environment['FLEET_EXCEL_PATH'] ?? '';
}

Future<WorkbookReadResult> readConfiguredLocalPath() async {
  final path = _resolvedConfiguredPath();
  if (path.isEmpty) return const WorkbookReadResult();
  return readPathIfSupported(path);
}

Future<WorkbookReadResult> readPathIfSupported(String absolutePath) async {
  if (absolutePath.isEmpty) {
    return const WorkbookReadResult(error: 'Path berkas kosong.');
  }
  try {
    final f = File(absolutePath);
    if (!await f.exists()) {
      return WorkbookReadResult(
        label: absolutePath,
        error: 'Berkas tidak ditemukan:\n$absolutePath',
      );
    }
    final bytes = await f.readAsBytes();
    return WorkbookReadResult(bytes: bytes, label: absolutePath);
  } catch (e) {
    return WorkbookReadResult(label: absolutePath, error: '$e');
  }
}
