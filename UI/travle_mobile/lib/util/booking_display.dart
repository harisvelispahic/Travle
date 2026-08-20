import 'package:travle_ui/travle_ui.dart';

/// Maps a booking status name to a semantic [StatusTone] for its pill.
StatusTone bookingStatusTone(String status) => switch (status) {
      'Confirmed' => StatusTone.success,
      'Pending' => StatusTone.info,
      'PaymentInProgress' => StatusTone.warning,
      'Cancelled' => StatusTone.danger,
      'Expired' => StatusTone.neutral,
      'Completed' => StatusTone.completed,
      _ => StatusTone.neutral,
    };

/// A short, human-friendly label for a booking status (the API's enum names are
/// concatenated words the traveler shouldn't see raw).
String bookingStatusLabel(String status) => switch (status) {
      'PaymentInProgress' => 'Awaiting payment',
      'Pending' => 'Awaiting confirmation',
      _ => status,
    };
