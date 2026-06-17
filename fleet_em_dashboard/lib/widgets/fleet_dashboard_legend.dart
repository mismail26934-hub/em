import 'package:flutter/material.dart';

const _barLegendColor = Color(0xFF1F4788);
const _barBelowLegendColor = Color(0xFFC62828);
const _targetLegendColor = Color(0xFFC62828);

/// Bar + target line descriptions (strip under each panel chart).
class FleetLegendContent extends StatelessWidget {
  const FleetLegendContent({
    super.key,
    required this.targetFraction,
    this.textScale = 1.0,
  });

  final double targetFraction;

  /// Scales legend typography and swatches with chart layout (carousel vs grid).
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final pct = (targetFraction * 100).toStringAsFixed(0);
    final sc = textScale.clamp(0.75, 3.0);
    final fs = (8.5 * sc).clamp(7.5, 16.0);
    final box = (10.0 * sc).clamp(8.0, 18.0);
    final spacing = (12.0 * sc).clamp(8.0, 22.0);
    final targetLineW = (12.5 * sc).clamp(11.0, 20.0);
    final targetSwatchH = (7.0 * sc).clamp(6.5, 12.5);
    final targetLineH = (1.15 * sc).clamp(1.0, 2.05);

    return Wrap(
      spacing: spacing,
      runSpacing: (4 * sc).clamp(3.0, 10.0),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendEntry(
          leading: Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              color: _barLegendColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          label: '≥ Target',
          fontSize: fs,
        ),
        _LegendEntry(
          leading: Container(
            width: box,
            height: box,
            decoration: BoxDecoration(
              color: _barBelowLegendColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          label: '< Target',
          fontSize: fs,
        ),
        _LegendEntry(
          leading: SizedBox(
            width: targetLineW,
            height: targetSwatchH,
            child: Align(
              alignment: Alignment.center,
              child: Container(
                height: targetLineH,
                color: _targetLegendColor,
              ),
            ),
          ),
          label: 'Target ($pct%)',
          fontSize: fs,
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.leading,
    required this.label,
    required this.fontSize,
  });

  final Widget leading;
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        SizedBox(width: fontSize >= 12 ? 8 : 6),
        Text(
          label,
          style: TextStyle(fontSize: fontSize, color: Colors.grey.shade900),
        ),
      ],
    );
  }
}
