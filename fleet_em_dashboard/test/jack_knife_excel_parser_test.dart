import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleet_em_dashboard/services/jack_knife_excel_parser.dart';

Uint8List _jackKnifeWorkbookBytes() {
  final excel = Excel.createExcel();
  final sheet = excel['CAT 320'];
  sheet.appendRow([TextCellValue('Top Downtime - CAT 320 May 2026')]);
  sheet.appendRow([
    TextCellValue('Components'),
    TextCellValue('Duration'),
    TextCellValue('Events'),
    TextCellValue('% Imp'),
  ]);
  sheet.appendRow([
    TextCellValue('IMPLEMENTS'),
    DoubleCellValue(229.86),
    DoubleCellValue(99),
    DoubleCellValue(7.72),
  ]);
  sheet.appendRow([
    TextCellValue('FRAME'),
    DoubleCellValue(156.03),
    DoubleCellValue(8),
    DoubleCellValue(5.24),
  ]);
  sheet.appendRow([TextCellValue('Sumbu X')]);
  sheet.appendRow([DoubleCellValue(19), DoubleCellValue(0)]);
  sheet.appendRow([DoubleCellValue(19), DoubleCellValue(242)]);
  sheet.appendRow([TextCellValue('Sumbu Y')]);
  sheet.appendRow([DoubleCellValue(0), DoubleCellValue(61)]);
  sheet.appendRow([DoubleCellValue(104), DoubleCellValue(61)]);

  final bytes = excel.encode();
  if (bytes == null) throw StateError('encode failed');
  return Uint8List.fromList(bytes);
}

/// Mirrors Excel layout: data cols A-E, Sumbu X in G-H, Sumbu Y in J-K (same rows).
Uint8List _sideBySideWorkbookBytes() {
  final excel = Excel.createExcel();
  final sheet = excel['CAT 320'];

  void setCell(int row, int col, CellValue value) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value = value;
  }

  setCell(2, 0, TextCellValue('Top Downtime - CAT 320 May 2026'));

  setCell(3, 0, TextCellValue('Components'));
  setCell(3, 1, TextCellValue('Duration'));
  setCell(3, 2, TextCellValue('Events'));
  setCell(3, 3, TextCellValue('% Imp'));
  setCell(3, 6, TextCellValue('Sumbu X'));
  setCell(3, 9, TextCellValue('Sumbu Y'));

  setCell(4, 0, TextCellValue('IMPLEMENTS'));
  setCell(4, 1, DoubleCellValue(229.86));
  setCell(4, 2, DoubleCellValue(99));
  setCell(4, 3, DoubleCellValue(7.72));
  setCell(4, 6, DoubleCellValue(19));
  setCell(4, 7, DoubleCellValue(0));
  setCell(4, 9, DoubleCellValue(0));
  setCell(4, 10, DoubleCellValue(61));

  setCell(5, 0, TextCellValue('FRAME'));
  setCell(5, 1, DoubleCellValue(156.03));
  setCell(5, 2, DoubleCellValue(8));
  setCell(5, 3, DoubleCellValue(5.24));
  setCell(5, 6, DoubleCellValue(19));
  setCell(5, 7, DoubleCellValue(242));
  setCell(5, 9, DoubleCellValue(104));
  setCell(5, 10, DoubleCellValue(61));

  setCell(6, 0, TextCellValue('DIFFERENTIAL'));
  setCell(6, 1, DoubleCellValue(103.93));
  setCell(6, 2, DoubleCellValue(6));
  setCell(6, 3, DoubleCellValue(3.49));

  final bytes = excel.encode();
  if (bytes == null) throw StateError('encode failed');
  return Uint8List.fromList(bytes);
}

void main() {
  test('parses Jack Knife sheet with thresholds', () {
    final data = parseJackKnifeExcelBytes(_jackKnifeWorkbookBytes());
    expect(data.panels.length, 1);
    expect(data.panels.first.points.length, 2);
    expect(data.panels.first.points.first.component, 'IMPLEMENTS');
    expect(data.panels.first.thresholdX, 19);
    expect(data.panels.first.thresholdY, 61);
    expect(data.panels.first.xLineYMin, 0);
    expect(data.panels.first.xLineYMax, 242);
    expect(data.panels.first.yLineXMin, 0);
    expect(data.panels.first.yLineXMax, 104);
    expect(data.panels.first.title.toLowerCase(), contains('jack knife'));
  });

  test('parses Sumbu tables side-by-side like Excel (cols G-K)', () {
    final data = parseJackKnifeExcelBytes(_sideBySideWorkbookBytes());
    final panel = data.panels.first;
    expect(panel.thresholdX, 19);
    expect(panel.thresholdY, 61);
    expect(panel.xLineYMax, 242);
    expect(panel.yLineXMax, 104);
    expect(panel.points.length, greaterThan(2));
  });
}
