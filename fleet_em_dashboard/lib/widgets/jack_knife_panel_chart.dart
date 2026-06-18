import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/jack_knife_dashboard_data.dart';
import '../theme/app_orange.dart';
import 'jack_knife_data_table.dart';

const _pointColor = Color(0xFF1F4788);
const _pointHighlightColor = Color(0xFF0D47A1);
const _thresholdXColor = Color(0xFFE65100);
const _thresholdYColor = Color(0xFF2E7D32);
const _border = Color(0xFFD0D7E2);

double _jkScale(Size size) {
  final short = math.min(size.width, size.height);
  return (short / 180).clamp(0.55, 2.4);
}

class _JackKnifeLayout {
  _JackKnifeLayout._({
    required this.plot,
    required this.scale,
  });

  final Rect plot;
  final double scale;

  static _JackKnifeLayout? compute(Size size) {
    final sc = _jkScale(size);
    final padL = (48 * sc).clamp(42.0, 88.0);
    final padR = (12 * sc).clamp(8.0, 24.0);
    final padT = (8 * sc).clamp(6.0, 18.0);
    final padB = (42 * sc).clamp(36.0, 72.0);
    final plot = Rect.fromLTWH(
      padL,
      padT,
      math.max(1.0, size.width - padL - padR),
      math.max(1.0, size.height - padT - padB),
    );
    return _JackKnifeLayout._(plot: plot, scale: sc);
  }

  Offset pointToOffset(double x, double y, double xMax, double yMax) {
    final tx = (x / xMax).clamp(0.0, 1.2);
    final ty = (y / yMax).clamp(0.0, 1.2);
    return Offset(
      plot.left + tx * plot.width,
      plot.bottom - ty * plot.height,
    );
  }
}

class _LabelPlacement {
  const _LabelPlacement({
    required this.pointIndex,
    required this.center,
    required this.box,
    required this.paragraph,
    required this.showLeader,
    required this.showLabel,
  });

  final int pointIndex;
  final Offset center;
  final Rect box;
  final ui.Paragraph paragraph;
  final bool showLeader;
  /// False when label would overlap another visible label.
  final bool showLabel;
}

ui.Paragraph _buildParagraph(String text, TextStyle style, {double maxWidth = 220}) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(fontSize: style.fontSize, maxLines: 2),
  )
    ..pushStyle(style.getTextStyle())
    ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));
}

List<_LabelPlacement> _placePointLabels({
  required JackKnifePanel panel,
  required Set<int> chartIndices,
  required _JackKnifeLayout layout,
  required TextStyle nameStyle,
  required double scale,
}) {
  final plot = layout.plot;
  final gap = (6 * scale).clamp(4.0, 12.0);
  final labelPad = (2 * scale).clamp(1.5, 4.0);
  final markerPad = (5 * scale).clamp(4.0, 10.0);
  final bounds = plot.inflate((6 * scale).clamp(4.0, 14.0));

  final entries = <({int index, Offset center, ui.Paragraph paragraph})>[];
  for (final i in chartIndices) {
    final pt = panel.points[i];
    final center = layout.pointToOffset(pt.events, pt.duration, panel.xMax, panel.yMax);
    if (!plot.inflate(24).contains(center)) continue;
    entries.add((
      index: i,
      center: center,
      paragraph: _buildParagraph(pt.component, nameStyle),
    ));
  }

  entries.sort((a, b) {
    final da = panel.points[a.index].events + panel.points[a.index].duration;
    final db = panel.points[b.index].events + panel.points[b.index].duration;
    return db.compareTo(da);
  });

  final placedBoxes = <Rect>[];
  final markerBoxes = <Rect>[];
  final results = <_LabelPlacement>[];

  Rect markerRect(Offset c) => Rect.fromCenter(
        center: c,
        width: markerPad * 2,
        height: markerPad * 2,
      );

  int overlapScore(Rect box, {bool countMarkers = true}) {
    var score = 0;
    for (final other in placedBoxes) {
      if (box.overlaps(other.inflate(labelPad))) score += 100;
    }
    if (countMarkers) {
      for (final other in markerBoxes) {
        if (box.overlaps(other)) score += 40;
      }
    }
    if (!bounds.contains(box.topLeft) || !bounds.contains(box.bottomRight)) {
      score += 30;
    }
    return score;
  }

  List<Rect> labelCandidates(Offset c, double w, double h) {
    final g = gap;
    return [
      Rect.fromLTWH(c.dx + g, c.dy - g - h, w, h),
      Rect.fromLTWH(c.dx + g, c.dy - h / 2, w, h),
      Rect.fromLTWH(c.dx + g, c.dy + g, w, h),
      Rect.fromLTWH(c.dx - g - w, c.dy - g - h, w, h),
      Rect.fromLTWH(c.dx - g - w, c.dy - h / 2, w, h),
      Rect.fromLTWH(c.dx - g - w, c.dy + g, w, h),
      Rect.fromLTWH(c.dx - w / 2, c.dy - g - h, w, h),
      Rect.fromLTWH(c.dx - w / 2, c.dy + g, w, h),
      Rect.fromLTWH(c.dx + g * 1.8, c.dy - g - h * 1.5, w, h),
      Rect.fromLTWH(c.dx - g * 1.8 - w, c.dy - g - h * 1.5, w, h),
      Rect.fromLTWH(c.dx + g * 2.5, c.dy - h / 2, w, h),
      Rect.fromLTWH(c.dx - g * 2.5 - w, c.dy - h / 2, w, h),
      Rect.fromLTWH(c.dx + g, c.dy - g * 2.8 - h, w, h),
      Rect.fromLTWH(c.dx - g - w, c.dy - g * 2.8 - h, w, h),
      Rect.fromLTWH(c.dx + g * 3.2, c.dy - h / 2, w, h),
      Rect.fromLTWH(c.dx - g * 3.2 - w, c.dy - h / 2, w, h),
    ];
  }

  Rect pickBestBox(List<Rect> candidates) {
    var best = candidates.first;
    var bestScore = overlapScore(best);
    for (final box in candidates.skip(1)) {
      final s = overlapScore(box);
      if (s < bestScore) {
        bestScore = s;
        best = box;
      }
    }
    return best;
  }

  for (final entry in entries) {
    final w = entry.paragraph.maxIntrinsicWidth;
    final h = entry.paragraph.height;
    final c = entry.center;
    markerBoxes.add(markerRect(c));

    final candidates = labelCandidates(c, w, h);
    final best = pickBestBox(candidates);
    final labelOverlap = overlapScore(best, countMarkers: false) >= 100;
    final showLabel = !labelOverlap;

    final defaultBox = candidates.first;
    final showLeader = showLabel &&
        (best.center - defaultBox.center).distance > (4 * scale);

    if (showLabel) {
      placedBoxes.add(best);
    }

    results.add(_LabelPlacement(
      pointIndex: entry.index,
      center: c,
      box: best,
      paragraph: entry.paragraph,
      showLeader: showLeader,
      showLabel: showLabel,
    ));
  }

  return results;
}

class _JackKnifePainter extends CustomPainter {
  _JackKnifePainter({
    required this.panel,
    required this.chartIndices,
    this.highlightedIndex,
  });

  final JackKnifePanel panel;
  final Set<int> chartIndices;
  final int? highlightedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _JackKnifeLayout.compute(size);
    if (layout == null) return;
    final plot = layout.plot;
    final sc = layout.scale;

    canvas.drawRect(plot, Paint()..color = Colors.white);

    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const xTicks = [0, 20, 40, 60, 80, 100, 120];
    for (final xt in xTicks) {
      if (xt > panel.xMax) continue;
      final p = layout.pointToOffset(xt.toDouble(), 0, panel.xMax, panel.yMax);
      canvas.drawLine(Offset(p.dx, plot.top), Offset(p.dx, plot.bottom), gridPaint);
    }
    for (var yi = 0; yi <= 300; yi += 50) {
      final p = layout.pointToOffset(0, yi.toDouble(), panel.xMax, panel.yMax);
      canvas.drawLine(Offset(plot.left, p.dy), Offset(plot.right, p.dy), gridPaint);
    }

    canvas.drawRect(plot, axisPaint);

    final xLineY0 = layout.pointToOffset(
      panel.thresholdX,
      panel.xLineYMin,
      panel.xMax,
      panel.yMax,
    );
    final xLineY1 = layout.pointToOffset(
      panel.thresholdX,
      panel.xLineYMax,
      panel.xMax,
      panel.yMax,
    );
    final yLineX0 = layout.pointToOffset(
      panel.yLineXMin,
      panel.thresholdY,
      panel.xMax,
      panel.yMax,
    );
    final yLineX1 = layout.pointToOffset(
      panel.yLineXMax,
      panel.thresholdY,
      panel.xMax,
      panel.yMax,
    );

    canvas.drawLine(
      Offset(xLineY0.dx, xLineY0.dy),
      Offset(xLineY1.dx, xLineY1.dy),
      Paint()
        ..color = _thresholdXColor
        ..strokeWidth = 2.2,
    );
    canvas.drawLine(
      Offset(yLineX0.dx, yLineX0.dy),
      Offset(yLineX1.dx, yLineX1.dy),
      Paint()
        ..color = _thresholdYColor
        ..strokeWidth = 2.2,
    );

    final labelStyle = TextStyle(
      color: Colors.grey.shade800,
      fontSize: (9 * sc).clamp(8.0, 12.0),
    );
    for (final xt in xTicks) {
      if (xt > panel.xMax) continue;
      final p = layout.pointToOffset(xt.toDouble(), 0, panel.xMax, panel.yMax);
      _drawAxisText(canvas, '$xt', Offset(p.dx, plot.bottom + 4), labelStyle, align: TextAlign.center);
    }
    for (var yi = 0; yi <= 300; yi += 50) {
      final p = layout.pointToOffset(0, yi.toDouble(), panel.xMax, panel.yMax);
      _drawAxisText(
        canvas,
        yi.toStringAsFixed(2),
        Offset(plot.left - 6, p.dy),
        labelStyle,
        align: TextAlign.right,
      );
    }

    final nameStyle = TextStyle(
      color: _pointColor,
      fontSize: (8.5 * sc).clamp(7.0, 11.0),
      fontWeight: FontWeight.w500,
    );

    final placements = _placePointLabels(
      panel: panel,
      chartIndices: chartIndices,
      layout: layout,
      nameStyle: nameStyle,
      scale: sc,
    );

    final leaderPaint = Paint()
      ..color = _pointColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    final pointPaint = Paint()
      ..color = _pointColor
      ..style = PaintingStyle.fill;

    for (final placement in placements) {
      final isHi = placement.pointIndex == highlightedIndex;
      final center = placement.center;
      final r = (4 * sc) * (isHi ? 1.35 : 1.0);
      final path = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + r, center.dy)
        ..lineTo(center.dx, center.dy + r)
        ..lineTo(center.dx - r, center.dy)
        ..close();
      canvas.drawPath(
        path,
        pointPaint..color = isHi ? _pointHighlightColor : _pointColor,
      );
    }

    for (final placement in placements) {
      final isHi = placement.pointIndex == highlightedIndex;
      final center = placement.center;
      final drawLabel = placement.showLabel || isHi;

      if (!drawLabel) continue;

      if (placement.showLeader || isHi) {
        final anchor = _nearestBoxPoint(placement.box, center);
        canvas.drawLine(center, anchor, leaderPaint);
      }

      if (isHi) {
        final hi = panel.points[placement.pointIndex];
        final hiStyle = nameStyle.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (nameStyle.fontSize ?? 10) + 1,
          color: _pointHighlightColor,
        );
        final hiPara = _buildParagraph(hi.component, hiStyle, maxWidth: 260);
        _drawLabelBadge(
          canvas,
          placement.box,
          hiPara,
          sc,
          borderColor: _pointHighlightColor.withValues(alpha: 0.55),
        );
      } else {
        _drawLabelBadge(
          canvas,
          placement.box,
          placement.paragraph,
          sc,
          borderColor: _pointColor.withValues(alpha: 0.18),
        );
      }
    }
  }

  void _drawLabelBadge(
    Canvas canvas,
    Rect box,
    ui.Paragraph paragraph,
    double scale, {
    required Color borderColor,
  }) {
    final pad = (3 * scale).clamp(2.0, 6.0);
    final bg = box.inflate(pad);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(3 * scale)),
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, Radius.circular(3 * scale)),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawParagraph(paragraph, Offset(box.left, box.top));
  }

  Offset _nearestBoxPoint(Rect box, Offset from) {
    final clampedX = from.dx.clamp(box.left, box.right);
    final clampedY = from.dy.clamp(box.top, box.bottom);
    if (from.dx < box.left) {
      return Offset(box.left, clampedY);
    }
    if (from.dx > box.right) {
      return Offset(box.right, clampedY);
    }
    if (from.dy < box.top) {
      return Offset(clampedX, box.top);
    }
    if (from.dy > box.bottom) {
      return Offset(clampedX, box.bottom);
    }
    return box.center;
  }

  void _drawAxisText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    final paragraph = _buildParagraph(text, style, maxWidth: 200);
    var dx = offset.dx;
    if (align == TextAlign.center) dx -= paragraph.maxIntrinsicWidth / 2;
    if (align == TextAlign.right) dx -= paragraph.maxIntrinsicWidth;
    canvas.drawParagraph(paragraph, Offset(dx, offset.dy - paragraph.height / 2));
  }

  @override
  bool shouldRepaint(covariant _JackKnifePainter oldDelegate) =>
      oldDelegate.panel != panel ||
      oldDelegate.chartIndices != chartIndices ||
      oldDelegate.highlightedIndex != highlightedIndex;
}

int? _hitTestPoint(
  Offset local,
  Size size,
  JackKnifePanel panel,
  Set<int> chartIndices,
) {
  final layout = _JackKnifeLayout.compute(size);
  if (layout == null) return null;
  final sc = layout.scale;
  final hitR = (18 * sc).clamp(12.0, 28.0);

  int? best;
  var bestD = double.infinity;
  for (final i in chartIndices) {
    final pt = panel.points[i];
    final c = layout.pointToOffset(pt.events, pt.duration, panel.xMax, panel.yMax);
    final d = (local - c).distance;
    if (d <= hitR && d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// Scatter Jack Knife chart (Events vs Duration) with quadrant reference lines.
class JackKnifePanelChart extends StatefulWidget {
  const JackKnifePanelChart({
    super.key,
    required this.panel,
    this.showTable = true,
  });

  final JackKnifePanel panel;
  final bool showTable;

  @override
  State<JackKnifePanelChart> createState() => _JackKnifePanelChartState();
}

class _JackKnifePanelChartState extends State<JackKnifePanelChart> {
  int? _hoveredIndex;

  void _setHovered(int? index) {
    if (index != _hoveredIndex) {
      setState(() => _hoveredIndex = index);
    }
  }

  void _onHover(Offset? position, Size chartSize, Set<int> chartIndices) {
    _setHovered(
      position == null ? null : _hitTestPoint(position, chartSize, widget.panel, chartIndices),
    );
  }

  Widget _buildChartStack(JackKnifePanel panel, Size paintSize, double sc, Set<int> chartIndices) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
          onHover: (e) => _onHover(e.localPosition, paintSize, chartIndices),
          onExit: (_) => _onHover(null, paintSize, chartIndices),
          cursor: _hoveredIndex != null ? SystemMouseCursors.help : MouseCursor.defer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _onHover(d.localPosition, paintSize, chartIndices),
            child: CustomPaint(
              painter: _JackKnifePainter(
                panel: panel,
                chartIndices: chartIndices,
                highlightedIndex: _hoveredIndex,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (_hoveredIndex != null)
          _JackKnifeHoverChip(
            point: panel.points[_hoveredIndex!],
            scale: sc,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.panel;
    final chartIndices = jackKnifeChartPointIndices(panel.points).toSet();
    return Card(
      elevation: 4,
      shadowColor: AppOrange.primary.withValues(alpha: 0.32),
      surfaceTintColor: Colors.transparent,
      color: AppOrange.surface,
      margin: EdgeInsets.zero,
      shape: AppOrange.panelCardShape(radius: 16),
      clipBehavior: Clip.none,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartSize = Size(constraints.maxWidth, constraints.maxHeight);
          final sc = _jkScale(chartSize);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppOrange.light, AppOrange.wash],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (11 * sc).clamp(8.0, 16.0),
                    vertical: (4.5 * sc).clamp(3.0, 9.0),
                  ),
                  child: Text(
                    panel.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (13 * sc).clamp(11.0, 19.0),
                      fontWeight: FontWeight.w700,
                      color: AppOrange.deepText,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all((8 * sc).clamp(6.0, 14.0)),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        final chartSize = Size(inner.maxWidth, inner.maxHeight);
                        if (!widget.showTable) {
                          return _buildChartStack(panel, chartSize, sc, chartIndices);
                        }

                        final sideBySide = inner.maxWidth >= 640;
                        final gap = (8 * sc).clamp(6.0, 12.0);
                        final table = JackKnifeDataTable(
                          panel: panel,
                          highlightedIndex: _hoveredIndex,
                          onRowHover: _setHovered,
                          compact: inner.maxWidth < 900,
                        );

                        if (sideBySide) {
                          final splitChartSize = Size(inner.maxWidth * 0.58, inner.maxHeight);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 58,
                                child: _buildChartStack(panel, splitChartSize, sc, chartIndices),
                              ),
                              SizedBox(width: gap),
                              Container(width: 1, color: _border),
                              SizedBox(width: gap),
                              Expanded(flex: 42, child: table),
                            ],
                          );
                        }

                        final stackedChartSize = Size(inner.maxWidth, inner.maxHeight * 0.58);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 58,
                              child: _buildChartStack(panel, stackedChartSize, sc, chartIndices),
                            ),
                            SizedBox(height: gap),
                            Expanded(flex: 42, child: table),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JackKnifeHoverChip extends StatelessWidget {
  const _JackKnifeHoverChip({required this.point, required this.scale});

  final JackKnifePoint point;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: (2 * scale).clamp(1.0, 6.0)),
        child: Material(
          elevation: 3,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (10 * scale).clamp(8.0, 14.0),
              vertical: (5 * scale).clamp(4.0, 8.0),
            ),
            child: Text(
              '${point.component}  ·  Events ${point.events.round()}  ·  Duration ${point.duration.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: (10 * scale).clamp(9.0, 12.0),
                fontWeight: FontWeight.w600,
                color: _pointHighlightColor,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
