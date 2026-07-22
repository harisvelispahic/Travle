import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Launch splash shown while a persisted session is being restored.
class AppSplash extends StatelessWidget {
  const AppSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: TravleTokens.space16),
            Text('Travle', style: theme.textTheme.headlineSmall),
            const SizedBox(height: TravleTokens.space24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
