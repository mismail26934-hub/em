import 'dart:math' as math;

import 'package:excel/excel.dart';

import '../models/jack_knife_dashboard_data.dart';

const _defaultThresholdX = 19.0;
const _defaultThresholdY = 61.0;
const _defaultXMax = 120.0;
const _defaultYMax = 300.0;

String _excelSpanPlain(TextSpan span) {
  final b = StringBuffer();
  if (span.text != null) b.write(span.text!);
  final ch = span.children;
  if (ch != null) {
    for (final c in ch) {
      b.write(_excelSpanPlain(c));
    }
  }
  return b.toString();
}

String _plain(CellValue? v) {
  if (v == null) return '';
  return switch (v) {
    TextCellValue(:final value) => _excelSpanPlain(value),
    IntCellValue(:final value) => value.toString(),
    DoubleCellValue(:final value) => value.toString(),
    FormulaCellValue(:final formula) => formula,
    BoolCellValue(:final value) => value.toString(),
    DateTimeCellValue(:final year, :final month, :final day) =>
      DateTime(year, month, day).toIso8601String(),
    DateCellValue(:final year, :final month, :final day) =>
      DateTime(year, month, day).toIso8601String(),
    TimeCellValue() => '',
  };
}

String _cellStr(Data? cell) => _plain(cell?.value).replaceAll('\u00a0', ' ').trim();

double? _cellDouble(Data? cell) {
  final v = cell?.value;
  if (v == null) return null;
  return switch (v) {
    IntCellValue(:final value) => value.toDouble(),
    DoubleCellValue(:final value) => value,
    FormulaCellValue(:final formula) => double.tryParse(formula),
    TextCellValue(:final value) => double.tryParse(value.toString()),
    _ => null,
  };
}

bool _looksLikeHeader(List<Data?> row) {
  final lower = row.map(_cellStr).map((s) => s.toLowerCase()).toList();
  return lower.contains('components') &&
      lower.contains('duration') &&
      lower.contains('events');
}

(int components, int duration, int events, int percent)? _headerCols(List<Data?> row) {
  var comp = -1;
  var dur = -1;
  var ev = -1;
  var pct = -1;
  for (var c = 0; c < row.length; c++) {
    final s = _cellStr(row[c]).toLowerCase();
    if (s == 'components') comp = c;
    if (s == 'duration') dur = c;
    if (s == 'events') ev = c;
    if (s == '% imp' || s == '%imp') pct = c;
  }
  if (comp < 0 || dur < 0 || ev < 0) return null;
  return (comp, dur, ev, pct);
}

String? _findTitle(List<List<Data?>> rows, String sheetName) {
  for (final row in rows) {
    for (final cell in row) {
      final s = _cellStr(cell);
      final lower = s.toLowerCase();
      if (lower.contains('jack knife')) return s;
      if (lower.startsWith('top downtime')) {
        final rest = s.replaceFirst(RegExp(r'top downtime\s*[-–]?\s*', caseSensitive: false), '');
        if (rest.isNotEmpty) return 'Jack Knife - $rest';
      }
    }
  }
  if (sheetName.trim().isNotEmpty) {
    return 'Jack Knife - ${sheetName.trim()}';
  }
  return null;
}

bool _isSumbuLabel(String text, String axis) {
  final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final a = axis.toLowerCase();
  return t == a || t.replaceAll(' ', '') == a.replaceAll(' ', '');
}

int _cellColumnIndex(List<Data?> row, int listIndex) {
  final cell = listIndex >= 0 && listIndex < row.length ? row[listIndex] : null;
  return cell?.columnIndex ?? listIndex;
}

double? _atCol(List<Data?> row, int col) {
  if (col < 0 || col >= row.length) return null;
  return _cellDouble(row[col]);
}

bool _isAxisHeaderPair(List<Data?> row, int col) {
  final a = _cellStr(row.length > col ? row[col] : null).toLowerCase();
  final b = _cellStr(row.length > col + 1 ? row[col + 1] : null).toLowerCase();
  return a == 'x' && b == 'y';
}

bool _rowHasSumbuLabel(List<Data?> row, String exceptAxis) {
  for (final cell in row) {
    final s = _cellStr(cell);
    if (_isSumbuLabel(s, 'sumbu x') && exceptAxis != 'sumbu x') return true;
    if (_isSumbuLabel(s, 'sumbu y') && exceptAxis != 'sumbu y') return true;
  }
  return false;
}

List<({int row, int col})> _findSumbuLabels(List<List<Data?>> rows, String axis) {
  final hits = <({int row, int col})>[];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      if (!_isSumbuLabel(_cellStr(rows[r][c]), axis)) continue;
      hits.add((row: r, col: _cellColumnIndex(rows[r], c)));
    }
  }
  return hits;
}

List<(double x, double y)> _collectSumbuPairs(
  List<List<Data?>> rows,
  int labelRow,
  int labelCol,
  String axis,
) {
  final pairs = <(double x, double y)>[];
  final dataCols = [labelCol, labelCol + 1];

  for (var rr = labelRow + 1; rr < math.min(labelRow + 10, rows.length); rr++) {
    final row = rows[rr];
    if (_rowHasSumbuLabel(row, axis)) break;

    (double x, double y)? found;
    for (final dc in dataCols) {
      if (_isAxisHeaderPair(row, dc)) continue;
      final x = _atCol(row, dc);
      final y = _atCol(row, dc + 1);
      if (x != null && y != null) {
        found = (x, y);
        break;
      }
    }
    if (found == null) continue;
    pairs.add(found);
    if (pairs.length >= 2) break;
  }
  return pairs;
}

bool _isVerticalPairs(List<(double x, double y)> pairs) {
  if (pairs.length < 2) return false;
  final xs = pairs.map((p) => p.$1).toList();
  return xs.reduce(math.max) - xs.reduce(math.min) < 0.01;
}

bool _isHorizontalPairs(List<(double x, double y)> pairs) {
  if (pairs.length < 2) return false;
  final ys = pairs.map((p) => p.$2).toList();
  return ys.reduce(math.max) - ys.reduce(math.min) < 0.01;
}

({double threshold, double start, double end})? _sumbuXSegment(List<List<Data?>> rows) {
  for (final hit in _findSumbuLabels(rows, 'sumbu x')) {
    final pairs = _collectSumbuPairs(rows, hit.row, hit.col, 'sumbu x');
    if (!_isVerticalPairs(pairs)) continue;
    final xs = pairs.map((p) => p.$1).toList();
    final ys = pairs.map((p) => p.$2).toList();
    return (
      threshold: xs.first,
      start: ys.reduce(math.min),
      end: ys.reduce(math.max),
    );
  }
  return null;
}

({double threshold, double start, double end})? _sumbuYSegment(List<List<Data?>> rows) {
  for (final hit in _findSumbuLabels(rows, 'sumbu y')) {
    final pairs = _collectSumbuPairs(rows, hit.row, hit.col, 'sumbu y');
    if (!_isHorizontalPairs(pairs)) continue;
    final xs = pairs.map((p) => p.$1).toList();
    final ys = pairs.map((p) => p.$2).toList();
    return (
      threshold: ys.first,
      start: xs.reduce(math.min),
      end: xs.reduce(math.max),
    );
  }
  return null;
}

JackKnifePanel? _parseSheet(String sheetName, List<List<Data?>> rows) {
  if (rows.isEmpty) return null;

  var headerRow = -1;
  (int, int, int, int)? cols;
  for (var r = 0; r < rows.length; r++) {
    if (!_looksLikeHeader(rows[r])) continue;
    final c = _headerCols(rows[r]);
    if (c == null) continue;
    headerRow = r;
    cols = c;
    break;
  }
  if (headerRow < 0 || cols == null) return null;

  final (compCol, durCol, evCol, pctCol) = cols;
  final points = <JackKnifePoint>[];

  for (var r = headerRow + 1; r < rows.length; r++) {
    final row = rows[r];
    final name = _cellStr(row.length > compCol ? row[compCol] : null);
    if (name.isEmpty) continue;
    final lower = name.toLowerCase();
    if (lower.contains('grand total') || lower == 'total') break;
    if (_isSumbuLabel(name, 'sumbu x') || _isSumbuLabel(name, 'sumbu y')) continue;
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(name)) continue;

    final duration = _cellDouble(row.length > durCol ? row[durCol] : null);
    final events = _cellDouble(row.length > evCol ? row[evCol] : null);
    if (duration == null || events == null) continue;

    double? pct;
    if (pctCol >= 0 && row.length > pctCol) {
      pct = _cellDouble(row[pctCol]);
    }

    points.add(
      JackKnifePoint(
        component: name,
        duration: duration,
        events: events,
        percentImp: pct,
      ),
    );
  }

  if (points.isEmpty) return null;

  final sumbuX = _sumbuXSegment(rows);
  final sumbuY = _sumbuYSegment(rows);
  final thresholdX = sumbuX?.threshold ?? _defaultThresholdX;
  final thresholdY = sumbuY?.threshold ?? _defaultThresholdY;
  final title = _findTitle(rows, sheetName) ?? 'Jack Knife - $sheetName';

  return JackKnifePanel(
    title: title,
    points: points,
    thresholdX: thresholdX,
    thresholdY: thresholdY,
    xMax: _defaultXMax,
    yMax: _defaultYMax,
    xLineYMin: sumbuX?.start ?? 0,
    xLineYMax: sumbuX?.end ?? _defaultYMax,
    yLineXMin: sumbuY?.start ?? 0,
    yLineXMax: sumbuY?.end ?? _defaultXMax,
  );
}

/// Parses Jack Knife sheets (Components / Duration / Events) from workbook bytes.
JackKnifeDashboardData parseJackKnifeExcelBytes(List<int> bytes) {
  final excel = Excel.decodeBytes(bytes);
  if (excel.tables.isEmpty) {
    throw const FormatException('Workbook has no sheets.');
  }

  final panels = <JackKnifePanel>[];
  for (final name in excel.tables.keys) {
    final sheet = excel.tables[name]!;
    final panel = _parseSheet(name, sheet.rows);
    if (panel != null) panels.add(panel);
  }

  if (panels.isEmpty) {
    throw const FormatException(
      'No Jack Knife sheets found (header Components / Duration / Events).',
    );
  }

  return JackKnifeDashboardData(panels: panels);
}
