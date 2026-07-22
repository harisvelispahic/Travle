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
