import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'app/auth_gate.dart';

void main() {
  runApp(const TravleDesktopApp());
}

class TravleDesktopApp extends StatelessWidget {
  const TravleDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoleApplicationProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => TourProvider()),
        // Lookups the destination submit/edit + tour forms populate their dropdowns from.
        ChangeNotifierProvider(create: (_) => DestinationCategoryProvider()),
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
