import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'app/auth_gate.dart';
import 'app/notification_toast_host.dart';

void main() => runTravleApp(() {
      WidgetsFlutterBinding.ensureInitialized();
      // Load the IANA time-zone database so tour event times render in their
      // destination's zone (see docs/time-and-timezones.md).
      initTravleTimeZones();
      // The mobile app is portrait-only — lock it upright so no screen rotates.
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      runApp(const TravleMobileApp());
    });

class TravleMobileApp extends StatelessWidget {
  const TravleMobileApp({super.key});

  /// The app's navigator, held here so the toast host — which is mounted *above*
  /// the navigator, and therefore has none in its own ancestry — can open a
  /// tapped notification's detail screen.
  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

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
        ChangeNotifierProvider(create: (_) => DestinationCategoryProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
        ChangeNotifierProvider(create: (_) => TourProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => DestinationReviewProvider()),
        ChangeNotifierProvider(create: (_) => TourReviewProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => CountryProvider()),
        ChangeNotifierProvider(create: (_) => RegionProvider()),
        ChangeNotifierProvider(create: (_) => CityProvider()),
        ChangeNotifierProvider(create: (_) => RoleApplicationProvider()),
      ],
      child: MaterialApp(
        title: 'Travle',
        debugShowCheckedModeBanner: false,
        theme: buildTravleTheme(),
        navigatorKey: _navigatorKey,
        // Live notification toasts are mounted here rather than in a screen or
        // the shell: `builder` wraps the navigator, so they float over every
        // route and dialog instead of being buried by the next push.
        builder: (context, child) => NotificationToastHost(
          navigatorKey: _navigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
