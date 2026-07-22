import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../layouts/bottom_nav_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';

/// Root switch: shows the app shell only for an authenticated account that holds
/// a mobile role (Traveler/Curator); otherwise the login screen. An organizer/
/// admin who signs in here is treated as not-allowed — [LoginScreen] clears that
/// session and explains why, so the shell never appears for the wrong role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) return const AppSplash();
    if (!auth.isAuthenticated || !auth.hasAnyRole(AppRole.mobile)) {
      return const LoginScreen();
    }
    // Wait for the post-login profile fetch, then route a not-yet-onboarded
    // traveler to onboarding before the shell.
    if (!auth.sessionResolved) return const AppSplash();
    if (auth.onboardingActive) return const OnboardingScreen();
    return const BottomNavShell();
  }
}
