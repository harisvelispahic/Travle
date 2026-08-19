/// Time-display helpers shared by both Travle apps. The API sends every
/// [DateTime] as a UTC instant (with a `Z` marker); this file is the single place
/// that turns those instants into the wall-clock values the UI shows, and it
/// draws the one distinction that matters:
///
/// * **Event times** (a tour schedule's start/end) are shown in the zone of the
///   tour's destination via [eventLocalTime] — a traveler plans around the
///   destination's clock, not their device's. Labelled "(local time)" in the UI.
/// * **Audit / lifecycle instants** (created, hold-expiry, "2 min ago") are shown
///   in the viewer's own device zone via [deviceLocalTime] — those are about the
///   viewer's "now".
///
/// See docs/time-and-timezones.md.
library;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

/// Loads the IANA time-zone database once so [eventLocalTime] can convert to any
/// zone. Call once at app startup (before `runApp`). Safe to call more than once.
void initTravleTimeZones() {
  if (_initialized) return;
  tzdata.initializeTimeZones();
  _initialized = true;
}

/// Every IANA time-zone identifier in the bundled database, sorted (e.g.
/// "Africa/Abidjan" … "Pacific/Wallis") — for a picker that lets an admin choose a
/// city's zone. Loads the database first, so it is safe to call before
/// [initTravleTimeZones].
List<String> allTimeZoneIds() {
  initTravleTimeZones();
  return tz.timeZoneDatabase.locations.keys.toList()..sort();
}

/// The true UTC instant a server [DateTime] represents. When the value carries a
/// zone (`isUtc`, i.e. it was parsed from the hardened `…Z` wire format) it is used
/// as-is; otherwise its fields are reinterpreted as UTC (the API always emits UTC
/// digits, so a value that lost its marker must not be shifted by the device
/// offset). Use this for durations against [DateTime.now] (e.g. a hold countdown).
DateTime asUtcInstant(DateTime serverTime) => serverTime.isUtc
    ? serverTime
    : DateTime.utc(
        serverTime.year,
        serverTime.month,
        serverTime.day,
        serverTime.hour,
        serverTime.minute,
        serverTime.second,
        serverTime.millisecond,
      );

/// A server instant converted to the viewer's device-local zone — for audit /
/// lifecycle timestamps ("created", "expires", relative "ago").
DateTime deviceLocalTime(DateTime serverTime) => asUtcInstant(serverTime).toLocal();

/// A server instant converted to the wall-clock in [ianaZone] (e.g.
/// "Europe/Sarajevo"), returned as a plain [DateTime] carrying that zone's fields,
/// ready for the app's date/time formatters. Used for **event** times so they read
/// the same for everyone, in the destination's zone. Falls back to the device zone
/// when [ianaZone] is null/empty/unknown or the tz database isn't initialised.
DateTime eventLocalTime(DateTime serverTime, String? ianaZone) {
  final utc = asUtcInstant(serverTime);
  if (ianaZone == null || ianaZone.isEmpty) return utc.toLocal();
  try {
    final zoned = tz.TZDateTime.from(utc, tz.getLocation(ianaZone));
    return DateTime(zoned.year, zoned.month, zoned.day, zoned.hour, zoned.minute,
        zoned.second, zoned.millisecond);
  } catch (_) {
    return utc.toLocal();
  }
}
