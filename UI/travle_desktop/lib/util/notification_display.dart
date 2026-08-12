import 'package:flutter/material.dart';

import 'formatting.dart';

/// Shared presentation helpers for notifications, used by the desktop list
/// ([NotificationsScreen]) and detail ([NotificationDetailScreen]). Keys are the
/// backend `NotificationType` enum **name** (e.g. `"BookingPlaced"`), exactly what
/// the API sends in `NotificationResponse.type`. (Mirrors the mobile helper — the
/// two apps keep their own display utils, as with `formatting.dart`.)

/// Attention/negative events render with the error color; everything else primary.
bool notificationIsNegative(String type) => const {
      'BookingRejected',
      'BookingCancelled',
      'BookingExpired',
      'ScheduleCancelled',
      'DestinationRejected',
      'RoleApplicationRejected',
      'AccountSuspended',
      'ReviewRemoved',
    }.contains(type);

/// A type-specific icon for the notification's avatar.
IconData notificationIcon(String type) {
  switch (type) {
    case 'BookingConfirmed':
      return Icons.check_circle_outline;
    case 'BookingRejected':
    case 'BookingCancelled':
      return Icons.cancel_outlined;
    case 'BookingExpired':
      return Icons.timer_off_outlined;
    case 'BookingReminder':
      return Icons.alarm;
    case 'BookingCompleted':
      return Icons.task_alt;
    case 'BookingPlaced':
      return Icons.event_available_outlined;
    case 'PaymentSucceeded':
      return Icons.payments_outlined;
    case 'RefundIssued':
      return Icons.currency_exchange;
    case 'DestinationApproved':
      return Icons.verified_outlined;
    case 'DestinationRejected':
      return Icons.block;
    case 'DestinationSubmitted':
      return Icons.rate_review_outlined;
    case 'RoleApplicationApproved':
      return Icons.verified_user_outlined;
    case 'RoleApplicationRejected':
      return Icons.block;
    case 'RoleApplicationSubmitted':
      return Icons.assignment_ind_outlined;
    case 'ReviewReceived':
      return Icons.star_outline;
    case 'ReviewRemoved':
      return Icons.delete_outline;
    case 'ScheduleCancelled':
      return Icons.event_busy_outlined;
    case 'AccountSuspended':
      return Icons.gpp_bad_outlined;
    case 'PasswordChanged':
      return Icons.lock_reset;
    default:
      return Icons.notifications_outlined;
  }
}

/// Human label for the type: the enum name split on word boundaries, e.g.
/// `"BookingPlaced"` → `"Booking Placed"`.
String notificationTypeLabel(String type) {
  final buffer = StringBuffer();
  for (var i = 0; i < type.length; i++) {
    final ch = type[i];
    final isUpper = ch.toUpperCase() == ch && ch.toLowerCase() != ch;
    if (i > 0 && isUpper) buffer.write(' ');
    buffer.write(ch);
  }
  return buffer.toString();
}

/// "Just now" / "5m ago" / "3h ago" / "2d ago", else a date. [createdAt] is a UTC
/// wall-clock value (see [asUtc]); reinterpret it as UTC before measuring elapsed.
String notificationRelativeTime(DateTime createdAt) {
  final created = asUtc(createdAt);
  final diff = DateTime.now().toUtc().difference(created);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(created.toLocal());
}

/// The full local date-time for the detail screen, e.g. "15 Aug 2026, 10:00".
String notificationFullTime(DateTime createdAt) =>
    formatDateTime(asUtc(createdAt).toLocal());
