import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.person, color: theme.colorScheme.onPrimary),
            ),
            title: Text(auth.username ?? 'Signed in'),
            subtitle: Text(
              auth.roles.isEmpty ? 'No roles' : auth.roles.join(' · '),
            ),
          ),
        ),
        const SizedBox(height: TravleTokens.space24),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: 'Log out',
              message: 'Are you sure you want to log out?',
              confirmLabel: 'Log out',
              destructive: true,
            );
            if (confirmed) {
              await auth.logout();
            }
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
