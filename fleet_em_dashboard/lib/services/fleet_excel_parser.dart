import 'dart:math' as math;

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/fleet_dashboard_data.dart';

/// Default Fleet column if header cell "Fleet" is not found (column B, index 1).
const _defaultFleetCol = 1;
const _nBlock = 8;

final _dateFmt = DateFormat('dd-MMM', 'en');

String _excelSpanPlain(TextSpan span) {
  final b = StringBuffer();
  if (span.text != null) {
    b.write(span.text!);
  }
  final ch = span.children;
  if (ch != null) {
    for (final c in ch) {
      b.write(_excelSpanPlain(c));
    }
  }
  return b.toString();
}

String _plainText(CellValue v) {
  return switch (v) {
    TextCellValue(:final value) => _excelSpanPlain(value),
    FormulaCellValue(:final formula) => formula,
    IntCellValue(:final value) => value.toString(),
    DoubleCellValue(:final value) => value.toString(),
    BoolCellValue(:final value) => value.toString(),
    DateCellValue(:final year, :final month, :final day) =>
      DateTime(year, month, day).toIso8601String(),
    final DateTimeCellValue d => d.asDateTimeLocal().toIso8601String(),
    final TimeCellValue t => t.toString(),
  };
}

String? _cellString(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  return _normalizeFleetLabel(_plainText(v));
}

/// Collapses Excel whitespace (incl. NBSP) so Fleet labels stay readable.
String _normalizeFleetLabel(String raw) {
  return raw
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double? _cellDouble(CellValue? v) {
  if (v == null) return null;
  return switch (v) {
    IntCellValue(:final value) => value.toDouble(),
    DoubleCellValue(:final value) => value,
    FormulaCellValue(:final formula) => double.tryParse(formula),
    _ => null,
  };
}

/// Excel serial day with pandas-style origin `1899-12-30` (see `em_dashboard.py`).
DateTime? _fromExcelSerial(double serial) {
  if (serial.isNaN || serial.isInfinite) return null;
  final days = serial.round();
  if (days < 0 || days > 1 << 20) return null;
  try {
    return DateTime(1899, 12, 30).add(Duration(days: days));
  } catch (_) {
    return null;
  }
}

String _headerLabel(CellValue? v) {
  if (v == null) return '?';
  if (v is TextCellValue) {
    final s = _excelSpanPlain(v.value).trim();
    return s.isEmpty ? '?' : s;
  }
  if (v is DateTimeCellValue) {
    return _dateFmt.format(v.asDateTimeLocal());
  }
  if (v is DateCellValue) {
    return _dateFmt.format(DateTime(v.year, v.month, v.day));
  }
  if (v is IntCellValue) {
    final dt = _fromExcelSerial(v.value.toDouble());
    if (dt != null) return _dateFmt.format(dt);
  }
  if (v is DoubleCellValue) {
    final dt = _fromExcelSerial(v.value);
    if (dt != null) return _dateFmt.format(dt);
  }
  return _plainText(v).trim().isEmpty ? '?' : _plainText(v).trim();
}

int _findHeaderRow(List<List<Data?>> rows) {
  final limit = math.min(5, rows.length);
  for (var i = 0; i < limit; i++) {
    final row = rows[i];
    for (final cell in row) {
      final s = _cellString(cell)?.toLowerCase();
      if (s == 'fleet') return i;
    }
  }
  return 0;
}

/// Column index of the cell whose text is `Fleet` in the header row.
int _findFleetColumn(List<Data?> headerRow) {
  for (var c = 0; c < headerRow.length; c++) {
    final s = _cellString(headerRow[c])?.toLowerCase();
    if (s == 'fleet') return c;
  }
  return _defaultFleetCol;
}

double _median(List<double> xs) {
  if (xs.isEmpty) return 0.88;
  final s = List<double>.from(xs)..sort();
  final mid = s.length ~/ 2;
  if (s.length.isOdd) return s[mid];
  return (s[mid - 1] + s[mid]) / 2;
}

/// Parses the first worksheet of [bytes] (same rules as `em_dashboard.py`).
FleetDashboardData parseFleetExcelBytes(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    throw const FormatException('Workbook has no sheets.');
  }
  final sheet = excel.tables[excel.tables.keys.first]!;
  final rows = sheet.rows;
  if (rows.length < 3) {
    throw const FormatException('Sheet has too few rows.');
  }

  final h = _findHeaderRow(rows);
  final headerRow = rows[h];
  final fleetCol = _findFleetColumn(headerRow);
  final valueStartCol = fleetCol + 1;
  final xLabels = <String>[];
  for (var j = 0; j < _nBlock; j++) {
    final col = valueStartCol + j;
    final cell = col < headerRow.length ? headerRow[col] : null;
    xLabels.add(_headerLabel(cell?.value));
  }

  final panels = <FleetPanel>[];
  double targetPct = 0.88;
  var foundTarget = false;

  for (var r = h + 1; r < rows.length; r++) {
    final row = rows[r];
    final label = _cellString(
          row.length > fleetCol ? row[fleetCol] : null,
        )?.trim() ??
        '';
    if (label.isEmpty) continue;

    final vals = <double>[];
    for (var j = 0; j < _nBlock; j++) {
      final c = valueStartCol + j;
      final raw = c < row.length ? row[c]?.value : null;
      final d = _cellDouble(raw);
      if (d == null || d.isNaN) {
        vals.add(double.nan);
      } else {
        vals.add(d);
      }
    }

    if (label.toLowerCase() == 'target') {
      foundTarget = true;
      final finite = vals.where((e) => !e.isNaN).toList();
      if (finite.isNotEmpty) targetPct = _median(finite);
    } else {
      final clean = vals.map((e) => e.isNaN ? 0.0 : e).toList();
      panels.add(
        FleetPanel(
          title: label,
          seriesKey: label,
          values: clean,
        ),
      );
    }
  }

  if (panels.isEmpty) {
    throw const FormatException('No data series found in the Fleet column.');
  }

  if (!foundTarget) targetPct = 0.88;

  return FleetDashboardData(
    periodLabels: xLabels,
    panels: panels,
    targetFraction: targetPct,
  );
}
