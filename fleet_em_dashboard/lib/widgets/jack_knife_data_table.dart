import 'package:flutter/material.dart';

import '../models/jack_knife_dashboard_data.dart';
import '../theme/app_orange.dart';

const _headerBg = Color(0xFF1F4788);
const _rowHi = Color(0xFFE8EEF7);
const _border = Color(0xFFD0D7E2);

String _fmtDuration(double v) => v.toStringAsFixed(2);

String _fmtEvents(double v) {
  final r = v.round();
  if ((v - r).abs() < 0.001) return r.toString();
  return v.toStringAsFixed(0);
}

String _fmtPct(double? v) {
  if (v == null) return '';
  return '${v.toStringAsFixed(2)}%';
}

/// Downtime table (Rank / Components / Duration / Events / % Imp) beside Jack Knife chart.
class JackKnifeDataTable extends StatelessWidget {
  const JackKnifeDataTable({
    super.key,
    required this.panel,
    this.highlightedIndex,
    this.onRowHover,
    this.compact = false,
  });

  final JackKnifePanel panel;
  final int? highlightedIndex;
  final ValueChanged<int?>? onRowHover;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fs = compact ? 8.5 : 10.0;
    final headerFs = compact ? 9.0 : 10.5;
    final padH = compact ? 4.0 : 6.0;
    final padV = compact ? 3.0 : 5.0;
    final rows = jackKnifeRankedRows(panel.points);

    final totalDuration = panel.points.fold<double>(0, (s, p) => s + p.duration);
    final totalEvents = panel.points.fold<double>(0, (s, p) => s + p.events);
    final totalPct = panel.points.fold<double>(
      0,
      (s, p) => s + (p.percentImp ?? 0),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _headerRow(headerFs, padH, padV),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final row in rows)
                      _dataRow(
                        row,
                        fs,
                        padH,
                        padV,
                        hi: row.originalIndex == highlightedIndex,
                        inChart: row.rank <= jackKnifeChartTopN,
                      ),
                    _totalRow(
                      totalDuration,
                      totalEvents,
                      totalPct,
                      fs,
                      padH,
                      padV,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(double fs, double padH, double padV) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _headerBg),
      child: Row(
        children: [
          _cell('Rank', fs, padH, padV, flex: 1, header: true, align: TextAlign.center),
          _cell('Components', fs, padH, padV, flex: 5, header: true),
          _cell('Duration', fs, padH, padV, flex: 3, header: true, align: TextAlign.right),
          _cell('Events', fs, padH, padV, flex: 2, header: true, align: TextAlign.right),
          _cell('% Imp', fs, padH, padV, flex: 2, header: true, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _dataRow(
    JackKnifeRankedRow row,
    double fs,
    double padH,
    double padV, {
    required bool hi,
    required bool inChart,
  }) {
    return MouseRegion(
      onEnter: (_) => onRowHover?.call(row.originalIndex),
      onExit: (_) => onRowHover?.call(null),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hi
              ? _rowHi
              : (row.rank.isEven ? Colors.white : const Color(0xFFFAFBFC)),
          border: const Border(bottom: BorderSide(color: _border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cell(
              '${row.rank}',
              fs,
              padH,
              padV,
              flex: 1,
              align: TextAlign.center,
              bold: hi || inChart,
              color: inChart ? _headerBg : const Color(0xFF5C6B7A),
            ),
            _cell(row.point.component, fs, padH, padV, flex: 5, bold: hi),
            _cell(_fmtDuration(row.point.duration), fs, padH, padV, flex: 3, align: TextAlign.right, bold: hi),
            _cell(_fmtEvents(row.point.events), fs, padH, padV, flex: 2, align: TextAlign.right, bold: hi),
            _cell(_fmtPct(row.point.percentImp), fs, padH, padV, flex: 2, align: TextAlign.right, bold: hi),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    double totalDuration,
    double totalEvents,
    double totalPct,
    double fs,
    double padH,
    double padV,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppOrange.legendStripe,
        border: Border(top: BorderSide(color: AppOrange.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _cell('', fs, padH, padV, flex: 1),
          _cell('Grand Total', fs, padH, padV, flex: 5, bold: true),
          _cell(_fmtDuration(totalDuration), fs, padH, padV, flex: 3, align: TextAlign.right, bold: true),
          _cell(_fmtEvents(totalEvents), fs, padH, padV, flex: 2, align: TextAlign.right, bold: true),
          _cell(_fmtPct(totalPct), fs, padH, padV, flex: 2, align: TextAlign.right, bold: true),
        ],
      ),
    );
  }

  Widget _cell(
    String text,
    double fs,
    double padH,
    double padV, {
    required int flex,
    bool header = false,
    bool bold = false,
    TextAlign align = TextAlign.left,
    Color? color,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Text(
          text,
          textAlign: align,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fs,
            fontWeight: header || bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? (header ? Colors.white : const Color(0xFF1A1A1A)),
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
