import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../models/fleet_dashboard_data.dart';
import '../theme/app_orange.dart';
import 'fleet_dashboard_legend.dart';

const _barColor = Color(0xFF1F4788);
const _barBelowTargetColor = Color(0xFFC62828);
const _targetColor = Color(0xFFC62828);

const _barWFrac = 0.55;

/// Scale typography & padding from chart canvas [Size] (carousel vs grid).
/// Uses the true shorter side (no high floor) so dense grid cells can shrink text.
double fleetChartLayoutScale(Size size) {
  final short = math.min(size.width, size.height);
  final m = short.clamp(44.0, 520.0);
  return (m / 158).clamp(0.50, 2.85);
}

/// Plot scale geometry shared with [CustomPainter].
class _PanelLayout {
  _PanelLayout._({
    required this.plot,
    required this.ymin,
    required this.ymax,
    required this.values,
    required this.scale,
  });

  final Rect plot;
  final double ymin;
  final double ymax;
  final List<double> values;
  final double scale;

  double yToDy(double y) {
    final t = (y - ymin) / (ymax - ymin);
    return plot.bottom - t * plot.height;
  }

  double get yFloor => yToDy(ymin);

  int get n => values.length;

  double get slot => plot.width / n;

  double get barW => slot * _barWFrac;

  static _PanelLayout? tryCompute(Size size, List<double> values, double target) {
    if (values.isEmpty) return null;
    final sc = fleetChartLayoutScale(size);
    final padL = (36 * sc).clamp(32.0, 108.0);
    final padR = (6 * sc).clamp(5.0, 18.0);
    final padT = (4 * sc).clamp(3.0, 14.0);
    final padB = (50 * sc).clamp(46.0, 128.0);

    final plot = Rect.fromLTWH(
      padL,
      padT,
      math.max(1.0, size.width - padL - padR),
      math.max(1.0, size.height - padT - padB),
    );

    final vmin = values.reduce(math.min);
    final vmax = math.max(values.reduce(math.max), target);
    var ymin = 0.85;
    if (vmin < ymin) {
      ymin = (vmin - 0.015).clamp(0.5, 0.849);
    }
    var ymax = math.max(0.93, vmax * 1.02);
    if (ymax <= ymin) {
      ymax = ymin + 0.08;
    }

    return _PanelLayout._(
      plot: plot,
      ymin: ymin,
      ymax: ymax,
      values: values,
      scale: sc,
    );
  }
}

/// Kolom batang di bawah pointer (untuk hover), memakai geometri sama dengan [_FleetPanelPainter].
int? _fleetPanelBarHitTest(
  Offset local,
  Size size,
  List<double> values,
  double target,
) {
  final layout = _PanelLayout.tryCompute(size, values, target);
  if (layout == null) return null;
  final plot = layout.plot;
  if (!plot.contains(local)) return null;
  final n = layout.n;
  final slot = layout.slot;
  final halfSlot = slot * 0.46;
  for (var i = 0; i < n; i++) {
    final cx = plot.left + slot * (i + 0.5);
    if ((local.dx - cx).abs() <= halfSlot) return i;
  }
  return null;
}

/// Area chart + hover pointer: animasi batang saat hover.
class _FleetPanelPlotBody extends StatefulWidget {
  const _FleetPanelPlotBody({
    required this.values,
    required this.xLabels,
    required this.target,
    this.onBarHovered,
  });

  final List<double> values;
  final List<String> xLabels;
  final double target;
  /// `true` saat pointer di atas salah satu batang (bukan hanya area chart).
  final ValueChanged<bool>? onBarHovered;

  @override
  State<_FleetPanelPlotBody> createState() => _FleetPanelPlotBodyState();
}

class _FleetPanelPlotBodyState extends State<_FleetPanelPlotBody> with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl;
  int? _hovered;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    if (_hovered != null) {
      widget.onBarHovered?.call(false);
    }
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FleetPanelPlotBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length || !listEquals(oldWidget.values, widget.values)) {
      final wasBar = _hovered != null;
      setState(() {
        _hovered = null;
        _hoverCtrl.value = 0;
      });
      if (wasBar) widget.onBarHovered?.call(false);
    }
  }

  void _applyHover(int? idx) {
    if (idx == _hovered) return;
    final prev = _hovered;
    final wasBar = prev != null;
    final nowBar = idx != null;
    setState(() => _hovered = idx);
    if (wasBar != nowBar) {
      widget.onBarHovered?.call(nowBar);
    }
    if (idx == null) {
      _hoverCtrl.reverse();
    } else if (prev == null) {
      _hoverCtrl.forward(from: 0);
    } else {
      _hoverCtrl.value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, lc) {
        final size = Size(lc.maxWidth, lc.maxHeight);
        return ColoredBox(
          color: AppOrange.chartWell,
          child: MouseRegion(
            cursor: _hovered != null ? SystemMouseCursors.click : MouseCursor.defer,
            onExit: (_) => _applyHover(null),
            onHover: (e) {
              final idx = _fleetPanelBarHitTest(e.localPosition, size, widget.values, widget.target);
              _applyHover(idx);
            },
            child: AnimatedBuilder(
              animation: _hoverCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FleetPanelPainter(
                    values: widget.values,
                    xLabels: widget.xLabels,
                    target: widget.target,
                    layoutSize: size,
                    hoveredBarIndex: _hovered,
                    hoverT: _hoverCtrl.value,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Single panel: title, bar chart, target line, compact legend strip.
class FleetPanelChart extends StatelessWidget {
  const FleetPanelChart({
    super.key,
    required this.panel,
    required this.periodLabels,
    required this.targetFraction,
    this.onBarHovered,
  });

  final FleetPanel panel;
  final List<String> periodLabels;
  final double targetFraction;
  /// Dipanggil saat hover memasuki/meninggalkan batang (untuk menjeda carousel, dll.).
  final ValueChanged<bool>? onBarHovered;

  @override
  Widget build(BuildContext context) {
    final xLabels = periodLabels.length == panel.values.length
        ? periodLabels
        : List.generate(
            panel.values.length,
            (i) => i < periodLabels.length ? periodLabels[i] : '$i',
          );

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
          final sc = fleetChartLayoutScale(
            Size(constraints.maxWidth, constraints.maxHeight),
          );
          final titleFs = (13 * sc).clamp(11.0, 19.0);
          final titlePadH = (11 * sc).clamp(8.0, 16.0);
          final titlePadV = (4.5 * sc).clamp(3.0, 9.0);

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
                  padding: EdgeInsets.fromLTRB(
                    titlePadH,
                    titlePadV,
                    titlePadH,
                    titlePadV,
                  ),
                  child: Text(
                    panel.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: titleFs,
                      fontWeight: FontWeight.w700,
                      color: AppOrange.deepText,
                      letterSpacing: 0.15,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, belowTitle) {
                    // Legend used full-card [sc] before; grid cells stay wide while the
                    // chart band is short — scale the strip from approximate chart height.
                    const legendStripeReserve = 42.0;
                    final effChartH = math.max(
                      48.0,
                      belowTitle.maxHeight - legendStripeReserve,
                    );
                    final legendSc = fleetChartLayoutScale(
                      Size(belowTitle.maxWidth, effChartH),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              8 * legendSc,
                              8 * legendSc,
                              8 * legendSc,
                              6 * legendSc,
                            ),
                            child: _FleetPanelPlotBody(
                              values: panel.values,
                              xLabels: xLabels,
                              target: targetFraction,
                              onBarHovered: onBarHovered,
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppOrange.legendStripe,
                            border: Border(
                              top: BorderSide(
                                color: AppOrange.border.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              10 * legendSc,
                              6 * legendSc,
                              10 * legendSc,
                              8 * legendSc,
                            ),
                            child: FleetLegendContent(
                              targetFraction: targetFraction,
                              textScale: legendSc,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FleetPanelPainter extends CustomPainter {
  _FleetPanelPainter({
    required this.values,
    required this.xLabels,
    required this.target,
    required this.layoutSize,
    this.hoveredBarIndex,
    this.hoverT = 0,
  });

  final List<double> values;
  final List<String> xLabels;
  final double target;
  final Size layoutSize;
  final int? hoveredBarIndex;
  final double hoverT;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final layout = _PanelLayout.tryCompute(size, values, target);
    if (layout == null) return;

    final sc = layout.scale;
    final plot = layout.plot;
    final ymin = layout.ymin;
    final ymax = layout.ymax;
    double yToDy(double y) => layout.yToDy(y);

    final yAxisFs = (8.5 * sc).clamp(7.5, 20.0);
    final xAxisFs = (7.5 * sc).clamp(7.0, 18.0);
    final valueFs = (7.0 * sc).clamp(6.5, 18.0);
    final gapAboveBar = (4.0 * sc).clamp(3.0, 12.0);
    final xLabelDy = (6.0 * sc).clamp(4.0, 14.0);

    final gridPaint = Paint()
      ..color = const Color(0x52000000)
      ..strokeWidth = (0.75 * sc).clamp(0.6, 2.0);

    // Grid di nilai persen nyata; tick & label dipilih agar tidak bertumpuk (tinggi plot pendek).
    final pMin = (ymin * 100).ceil();
    final pMax = (ymax * 100).floor();
    final span = pMax - pMin;
    final minLabelDy = (yAxisFs * 1.32).clamp(yAxisFs + 2.0, 28.0);
    final maxTicks = (plot.height / minLabelDy).floor().clamp(4, 14);
    final minStep = span / math.max(1, maxTicks - 1);
    const niceSteps = [1, 2, 5, 10, 20, 25, 50, 100];
    var step = niceSteps.last;
    for (final s in niceSteps) {
      if (s.toDouble() >= minStep - 1e-9) {
        step = s;
        break;
      }
    }

    final tickPcts = <int>{};
    for (var p = pMin; p <= pMax; p += step) {
      tickPcts.add(p);
    }
    // Garis target digambar terpisah; jangan sisipkan label/grid di % target jika sudah rapat tick utama.
    final targetPct = (target * 100).round();
    if (targetPct >= pMin && targetPct <= pMax) {
      final minGap = math.max(2, (step / 2).ceil());
      final crowded = tickPcts.any((e) => (e - targetPct).abs() < minGap);
      if (!crowded) tickPcts.add(targetPct);
    }
    var ticks = tickPcts.toList()..sort();

    // Buang tick yang masih overlap vertikal (carousel / sel grid sangat pendek).
    final thinned = <int>[];
    for (final p in ticks) {
      final dy = yToDy(p / 100.0);
      if (thinned.isEmpty) {
        thinned.add(p);
        continue;
      }
      final prevDy = yToDy(thinned.last / 100.0);
      if ((dy - prevDy).abs() >= minLabelDy) {
        thinned.add(p);
      }
    }
    ticks = thinned;

    for (final p in ticks) {
      final yv = p / 100.0;
      if (yv < ymin - 1e-9 || yv > ymax + 1e-9) continue;
      final dy = yToDy(yv);
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$p%',
          style: TextStyle(
            fontSize: yAxisFs,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF455A64),
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: plot.left - 4);
      tp.paint(canvas, Offset((2 * sc).clamp(1.0, 6.0), dy - tp.height / 2));
    }

    final borderPaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = (0.9 * sc).clamp(0.7, 2.2);
    canvas.drawRect(plot, borderPaint..style = PaintingStyle.stroke);

    final axisPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = (1.0 * sc).clamp(0.8, 2.5);
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axisPaint,
    );

    final n = layout.n;
    final slot = layout.slot;
    final barW = layout.barW;
    final yFloor = layout.yFloor;
    final barRadius = Radius.circular((1.5 * sc).clamp(1.0, 5.0));

    final hoverIdx = hoveredBarIndex;
    final tHover = hoverT.clamp(0.0, 1.0);

    for (var i = 0; i < n; i++) {
      final isHover = hoverIdx != null && i == hoverIdx;
      final t = isHover ? tHover : 0.0;
      if (t > 0.008) {
        final cx0 = plot.left + slot * (i + 0.5);
        final yVal0 = yToDy(values[i]);
        final top0 = math.min(yVal0, yFloor);
        final bottom0 = math.max(yVal0, yFloor);
        final w0 = barW * (1.0 + 0.11 * t);
        final lift = (5.0 * sc) * t;
        final topLifted = math.max(plot.top + sc, top0 - lift);
        final rShadow = RRect.fromRectAndRadius(
          Rect.fromLTRB(cx0 - w0 / 2, topLifted, cx0 + w0 / 2, bottom0),
          barRadius,
        );
        canvas.drawRRect(
          rShadow.shift(Offset(0, (2.2 * sc) * t)),
          Paint()..color = Color.fromRGBO(0, 0, 0, (0.12 * t).clamp(0.0, 0.35)),
        );
      }
    }

    for (var i = 0; i < n; i++) {
      final cx = plot.left + slot * (i + 0.5);
      final isHover = hoverIdx != null && i == hoverIdx;
      final t = isHover ? tHover : 0.0;
      final effW = barW * (1.0 + 0.11 * t);
      final left = cx - effW / 2;
      final yVal = yToDy(values[i]);
      final lift = isHover ? (5.0 * sc) * t : 0.0;
      var top = math.min(yVal, yFloor) - lift;
      top = math.max(plot.top + sc * 0.5, top);
      final bottom = math.max(yVal, yFloor);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, left + effW, bottom),
        barRadius,
      );
      final belowTarget = values[i] < target;
      final base = belowTarget ? _barBelowTargetColor : _barColor;
      final barColor = Color.lerp(base, Colors.white, 0.14 * t)!;
      final barPaint = Paint()..color = barColor;
      canvas.drawRRect(r, barPaint);
    }

    final ty = yToDy(target);
    final targetPaint = Paint()
      ..color = _targetColor
      // Slightly above grid stroke, well below axis — avoids dominating small charts.
      ..strokeWidth = (1.05 * sc).clamp(0.95, 2.0);
    canvas.drawLine(
      Offset(plot.left, ty),
      Offset(plot.right, ty),
      targetPaint,
    );

    for (var i = 0; i < n; i++) {
      final cx = plot.left + slot * (i + 0.5);
      final label = i < xLabels.length ? xLabels[i] : '$i';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: xAxisFs,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF455A64),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slot * 1.4);

      canvas.save();
      canvas.translate(cx, plot.bottom + xLabelDy);
      canvas.rotate(-math.pi / 4);
      tp.paint(canvas, Offset(-tp.width / 2, 0));
      canvas.restore();
    }

    for (var i = 0; i < n; i++) {
      final cx = plot.left + slot * (i + 0.5);
      final yVal = yToDy(values[i]);
      final isHover = hoverIdx != null && i == hoverIdx;
      final t = isHover ? tHover : 0.0;
      final lift = isHover ? (5.0 * sc) * t : 0.0;
      var top = math.min(yVal, yFloor) - lift;
      top = math.max(plot.top + sc * 0.5, top);
      final effW = barW * (1.0 + 0.11 * t);
      final pct = values[i] * 100;
      final text = pct >= 10 ? '${pct.toStringAsFixed(1)}%' : '${pct.toStringAsFixed(2)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: valueFs,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF202020),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: effW + (8 * sc));
      final dx = cx - tp.width / 2;
      final dy = math.max(plot.top + sc, top - tp.height - gapAboveBar);
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _FleetPanelPainter oldDelegate) {
    return !listEquals(oldDelegate.values, values) ||
        oldDelegate.target != target ||
        !listEquals(oldDelegate.xLabels, xLabels) ||
        oldDelegate.layoutSize != layoutSize ||
        oldDelegate.hoveredBarIndex != hoveredBarIndex ||
        oldDelegate.hoverT != hoverT;
  }
}
