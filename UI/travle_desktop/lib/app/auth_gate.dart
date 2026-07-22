import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';

import '../layouts/side_nav_shell.dart';
import '../screens/auth/login_screen.dart';

/// Root switch: shows the management shell only for an authenticated account
/// that holds a desktop role (Organizer/Admin); otherwise the login screen. A
/// traveler/curator who signs in here is treated as not-allowed — [LoginScreen]
/// clears that session and explains why.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allowed = auth.isAuthenticated && auth.hasAnyRole(AppRole.desktop);
    return allowed ? const SideNavShell() : const LoginScreen();
  }
}
