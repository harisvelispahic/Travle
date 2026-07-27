import 'package:travle_ui/travle_ui.dart';

/// Maps a booking status name to a semantic [StatusTone] for its pill.
StatusTone bookingStatusTone(String status) => switch (status) {
      'Confirmed' => StatusTone.success,
      'Pending' => StatusTone.info,
      'PaymentInProgress' => StatusTone.warning,
      'Cancelled' => StatusTone.danger,
      'Expired' => StatusTone.neutral,
      'Completed' => StatusTone.neutral,
      _ => StatusTone.neutral,
    };

/// A short, human-friendly label for a booking status (the API's enum names are
/// concatenated words that shouldn't be shown raw).
String bookingStatusLabel(String status) => switch (status) {
      'PaymentInProgress' => 'Awaiting payment',
      'Pending' => 'Awaiting confirmation',
      _ => status,
    };

/// (label, statusId) options for the status filter; a null id means "all".
const List<(String, int?)> bookingStatusFilters = [
  ('All statuses', null),
  ('Awaiting payment', 1),
  ('Awaiting confirmation', 2),
  ('Confirmed', 3),
  ('Completed', 4),
  ('Cancelled', 5),
  ('Expired', 6),
];
