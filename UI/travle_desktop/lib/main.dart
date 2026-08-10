import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'app/auth_gate.dart';

void main() => runTravleApp(() {
      runApp(const TravleDesktopApp());
    });

class TravleDesktopApp extends StatelessWidget {
  const TravleDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Notifications react to auth: connect the SignalR feed + prime the badge
        // on sign-in, tear it all down on sign-out (syncAuth is idempotent).
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) =>
              notifications!..syncAuth(auth.isAuthenticated),
        ),
        ChangeNotifierProvider(create: (_) => RoleApplicationProvider()),
        // User management + self-service account (Phase 10).
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => TourProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => DestinationReviewProvider()),
        ChangeNotifierProvider(create: (_) => TourReviewProvider()),
        // Lookups the destination submit/edit + tour forms populate their dropdowns from.
        ChangeNotifierProvider(create: (_) => DestinationCategoryProvider()),
        // Country → Region → City cascade (destination location picker + the
        // self-account home-city field).
        ChangeNotifierProvider(create: (_) => CountryProvider()),
        ChangeNotifierProvider(create: (_) => RegionProvider()),
        ChangeNotifierProvider(create: (_) => CityProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => TourTypeProvider()),
      ],
      child: MaterialApp(
        title: 'Travle — Management',
        debugShowCheckedModeBanner: false,
        theme: buildTravleTheme(compact: true),
        home: const AuthGate(),
      ),
    );
  }
}
