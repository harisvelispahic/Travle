/// Role names exactly as seeded in the backend (`RoleNames`). They appear in
/// the JWT role claim and drive endpoint authorization (server) plus per-app
/// login gating (client). Keep these strings in sync with the backend.
class AppRole {
  AppRole._();

  static const String admin = 'Admin';
  static const String traveler = 'Traveler';
  static const String curator = 'Curator';
  static const String organizer = 'Organizer';

  /// Roles permitted to use the mobile (traveler-facing) app.
  static const Set<String> mobile = {traveler, curator};

  /// Roles permitted to use the desktop (management-facing) app.
  static const Set<String> desktop = {organizer, admin};
}
