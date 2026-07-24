import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'app/auth_gate.dart';

void main() {
  runApp(const TravleMobileApp());
}

class TravleMobileApp extends StatelessWidget {
  const TravleMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DestinationCategoryProvider()),
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
        home: const AuthGate(),
      ),
    );
  }
}
