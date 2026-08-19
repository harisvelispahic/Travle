/// Small display formatters for the tour screens. The API sends every time as a
/// UTC instant; **event** times (tour schedule start/end) are shown in the tour
/// destination's zone via `formatEvent*` (labelled "(local time)"), while audit
/// timestamps use the device zone. The zone conversion lives in `travle_core`
/// ([eventLocalTime]/[deviceLocalTime]). See docs/time-and-timezones.md.
library;

import 'package:travle_core/travle_core.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "15 Aug 2026" — a date without the time.
String formatDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

/// "15 Aug 2026, 10:00" — a date and time of day.
String formatDateTime(DateTime dt) =>
    '${formatDate(dt)}, ${_two(dt.hour)}:${_two(dt.minute)}';

/// "10:00 – 12:00" when start and end fall on the same day, otherwise the full
/// start and end date-times.
String formatScheduleRange(DateTime start, DateTime end) {
  final sameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) {
    return '${formatDate(start)}, ${_two(start.hour)}:${_two(start.minute)} – '
        '${_two(end.hour)}:${_two(end.minute)}';
  }
  return '${formatDateTime(start)} → ${formatDateTime(end)}';
}

/// "2h", "2h 30m", or "45m" from a whole-minute duration.
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// "25.00 KM" — a price in the displayed currency.
String formatPrice(double amount) => '${amount.toStringAsFixed(2)} KM';

// ── Event times (shown in the destination's zone, labelled "(local time)") ──────

/// A tour event date-time in its destination's zone, e.g. "15 Aug 2026, 10:00 (local time)".
String formatEventDateTime(DateTime utc, String? zone) =>
    '${formatDateTime(eventLocalTime(utc, zone))} (local time)';

/// A tour event date only, in its destination's zone (no time-of-day → no zone label).
String formatEventDate(DateTime utc, String? zone) =>
    formatDate(eventLocalTime(utc, zone));

/// A tour schedule's start–end range in its destination's zone, labelled "(local time)".
String formatEventScheduleRange(DateTime startUtc, DateTime endUtc, String? zone) =>
    '${formatScheduleRange(eventLocalTime(startUtc, zone), eventLocalTime(endUtc, zone))} (local time)';
