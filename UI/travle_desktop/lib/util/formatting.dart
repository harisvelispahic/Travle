/// Small display formatters shared by the tour screens. Times from the API are
/// UTC wall-clock stored without a zone marker; Phase 4 shows them as-is (a proper
/// local-time conversion arrives with the booking screens), so the value the
/// organizer picks is exactly the value shown back.
library;

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

/// "10:00 – 12:00" when the slot starts and ends on the same day, otherwise the
/// full start and end date-times.
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

/// Reinterprets a server timestamp (a UTC wall-clock value parsed without a zone
/// marker, so Dart tags it local) as the real UTC instant it represents. Use this
/// before computing a duration against [DateTime.now] or converting `toLocal`, so
/// the result is correct regardless of the device's time zone.
DateTime asUtc(DateTime serverTime) => DateTime.utc(
      serverTime.year,
      serverTime.month,
      serverTime.day,
      serverTime.hour,
      serverTime.minute,
      serverTime.second,
      serverTime.millisecond,
    );
