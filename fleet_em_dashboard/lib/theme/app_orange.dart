import 'package:flutter/material.dart';

/// Shared orange accent for dashboard cards and chrome.
abstract final class AppOrange {
  static const Color primary = Color(0xFFF57C00);
  static const Color dark = Color(0xFFE65100);
  static const Color deepText = Color(0xFFBF360C);
  static const Color light = Color(0xFFFFE0B2);
  static const Color wash = Color(0xFFFFF3E0);
  static const Color border = Color(0xFFFFB74D);
  static const Color surface = Color(0xFFFFFBF7);
  static const Color legendStripe = Color(0xFFFFF5EB);
  static const Color chartWell = Colors.white;

  static RoundedRectangleBorder cardShape({double radius = 16}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: border, width: 1),
      );

  /// Panel chart card: rounded corners only (no stroke) so Y-axis labels are not clipped.
  static RoundedRectangleBorder panelCardShape({double radius = 16}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      );
}
