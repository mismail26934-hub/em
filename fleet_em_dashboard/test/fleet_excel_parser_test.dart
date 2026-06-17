import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_em_dashboard/services/fleet_excel_parser.dart';

Uint8List _minimalWorkbookBytes() {
  final excel = Excel.createExcel();
  final sheet = excel['Sheet1'];
  sheet.appendRow([
    TextCellValue('Fleet'),
    TextCellValue('01-Jan'),
    TextCellValue('02-Jan'),
    TextCellValue('03-Jan'),
    TextCellValue('04-Jan'),
    TextCellValue('05-Jan'),
    TextCellValue('06-Jan'),
    TextCellValue('07-Jan'),
    TextCellValue('08-Jan'),
  ]);
  sheet.appendRow([
    TextCellValue('777 Xpro MTD'),
    DoubleCellValue(0.81),
    DoubleCellValue(0.82),
    DoubleCellValue(0.83),
    DoubleCellValue(0.84),
    DoubleCellValue(0.85),
    DoubleCellValue(0.86),
    DoubleCellValue(0.87),
    DoubleCellValue(0.88),
  ]);
  sheet.appendRow([
    TextCellValue('320 MTD'),
    DoubleCellValue(0.71),
    DoubleCellValue(0.72),
    DoubleCellValue(0.73),
    DoubleCellValue(0.74),
    DoubleCellValue(0.75),
    DoubleCellValue(0.76),
    DoubleCellValue(0.77),
    DoubleCellValue(0.78),
  ]);
  sheet.appendRow([
    TextCellValue('Target'),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
    DoubleCellValue(0.88),
  ]);
  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Failed to encode test workbook.');
  }
  return Uint8List.fromList(bytes);
}

void main() {
  test('panel titles follow Fleet column order and labels', () {
    final data = parseFleetExcelBytes(_minimalWorkbookBytes());

    expect(data.panels.length, 2);
    expect(data.panels[0].title, '777 Xpro MTD');
    expect(data.panels[1].title, '320 MTD');
    expect(data.periodLabels.first, '01-Jan');
    expect(data.targetFraction, closeTo(0.88, 1e-9));
  });
}
