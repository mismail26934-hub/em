import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

/// Namespaced keys. **String** is the preferred store (web `localStorage`).
const String _kMinutesStr = 'fleet_em_dashboard.v1.carousel_minutes_str';
const String _kMinutesInt = 'fleet_em_dashboard.v1.carousel_minutes_int';

/// Legacy key — still read by [loadCarouselIntervalMinutes] and used as last-resort save.
const String _kLegacyCarouselPref = 'carousel_interval_minutes';

const int kCarouselStoredMaxMinutes = 24 * 60;

/// Minutes between auto-advance slides. `0` = off. When nothing stored: **0**.
Future<int> loadCarouselIntervalMinutes() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_kMinutesStr);
    if (raw != null && raw.isNotEmpty) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        return parsed.clamp(0, kCarouselStoredMaxMinutes);
      }
    }

    final primary = prefs.getInt(_kMinutesInt);
    if (primary != null) {
      return primary.clamp(0, kCarouselStoredMaxMinutes);
    }

    final legacy = prefs.getInt(_kLegacyCarouselPref);
    if (legacy != null) {
      final v = legacy.clamp(0, kCarouselStoredMaxMinutes);
      await prefs.setString(_kMinutesStr, '$v');
      await prefs.setInt(_kMinutesInt, v);
      await prefs.remove(_kLegacyCarouselPref);
      return v;
    }

    return 0;
  } catch (e, st) {
    debugPrint('loadCarouselIntervalMinutes: $e\n$st');
    return 0;
  }
}

/// Persists interval using string (web-friendly), then int fallbacks, then legacy int.
Future<bool> saveCarouselIntervalMinutes(int minutes) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final m = minutes.clamp(0, kCarouselStoredMaxMinutes);
    final str = '$m';

    Future<void> shortDelay() =>
        Future<void>.delayed(const Duration(milliseconds: 40));

    var strOk = await prefs.setString(_kMinutesStr, str);
    if (!strOk) {
      await shortDelay();
      strOk = await prefs.setString(_kMinutesStr, str);
    }

    if (strOk) {
      try {
        await prefs.setInt(_kMinutesInt, m);
      } catch (e, st) {
        debugPrint('saveCarouselIntervalMinutes: setInt mirror (non-fatal): $e\n$st');
      }
      await prefs.remove(_kLegacyCarouselPref);
      return true;
    }

    var intOk = await prefs.setInt(_kMinutesInt, m);
    if (!intOk) {
      await shortDelay();
      intOk = await prefs.setInt(_kMinutesInt, m);
    }
    if (intOk) {
      await prefs.remove(_kLegacyCarouselPref);
      return true;
    }

    var legacyOk = await prefs.setInt(_kLegacyCarouselPref, m);
    if (!legacyOk) {
      await shortDelay();
      legacyOk = await prefs.setInt(_kLegacyCarouselPref, m);
    }
    return legacyOk;
  } catch (e, st) {
    debugPrint('saveCarouselIntervalMinutes: $e\n$st');
    return false;
  }
}
