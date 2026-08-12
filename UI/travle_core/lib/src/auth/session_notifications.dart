/// Notification types that reflect a server-side change to the **current user's own**
/// session or permissions — the account was suspended, or a role was added/removed
/// (which rolls their security stamp and usually drops their refresh tokens). The
/// client reacts by trying a silent token refresh (seamless if the refresh token was
/// kept, e.g. an admin changing their own non-admin role) or, if that fails, ending
/// the session with a friendly message. See docs/auth-token-invalidation.md.
const Set<String> sessionAffectingNotificationTypes = {
  'AccountSuspended',
  'RoleGranted',
  'RoleRevoked',
  'RoleApplicationApproved',
  'PasswordChanged',
};

/// A human "you need to sign in again" reason for a session-affecting notification,
/// reusing the notification's own [text] where it already reads well.
String sessionEndedReason(String type, String text) {
  final trimmed = text.trim();
  if (type == 'AccountSuspended') {
    return trimmed.isNotEmpty ? trimmed : 'Your account has been suspended.';
  }
  if (type == 'PasswordChanged') {
    // Password change/reset dropped every session — the text explains, so surface it as-is.
    return trimmed.isNotEmpty
        ? '$trimmed Please sign in again.'
        : 'Your password was changed. Please sign in again.';
  }
  // A role was granted / removed / an application approved — the text is specific;
  // append the call to action.
  return trimmed.isNotEmpty
      ? '$trimmed You need to sign in again to continue.'
      : 'Your access has changed. Please sign in again.';
}
