import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'profile/become_curator_screen.dart';
import 'profile/become_organizer_screen.dart';
import 'profile/change_password_screen.dart';
import 'profile/edit_profile_screen.dart';

/// The signed-in user's profile: an identity header (avatar, name, email, home
/// city) over a menu (edit profile, change password, log out). Reads the live
/// profile from [AuthProvider.currentUser], so it refreshes after an edit.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _initials(UserResponse? user, String? username) {
    final first = (user?.firstName ?? '').trim();
    final last = (user?.lastName ?? '').trim();
    if (first.isNotEmpty || last.isNotEmpty) {
      final a = first.isNotEmpty ? first[0] : '';
      final b = last.isNotEmpty ? last[0] : '';
      return (a + b).toUpperCase();
    }
    final name = (username ?? '').trim();
    return name.isNotEmpty ? name[0].toUpperCase() : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final displayName = user != null && user.fullName.trim().isNotEmpty
        ? user.fullName
        : (auth.username ?? 'Signed in');
    final roles = user?.roles ?? auth.roles;
    final isCurator = roles.contains(AppRole.curator);
    final isOrganizer = roles.contains(AppRole.organizer);

    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(TravleTokens.space16),
            child: Row(
              children: [
                ProfileAvatar(
                  base64Image: user?.profileImage,
                  radius: 32,
                  initials: _initials(user, auth.username),
                ),
                const SizedBox(width: TravleTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: theme.textTheme.titleLarge),
                      if (user?.email != null) ...[
                        const SizedBox(height: TravleTokens.space4),
                        Text(
                          user!.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (user?.cityName != null) ...[
                        const SizedBox(height: TravleTokens.space4),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: TravleTokens.space4),
                            Text(
                              user!.cityName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space12),
          Wrap(
            spacing: TravleTokens.space8,
            runSpacing: TravleTokens.space8,
            children: [
              for (final role in roles) Chip(label: Text(role)),
            ],
          ),
        ],
        const SizedBox(height: TravleTokens.space24),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EditProfileScreen(),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              ),
              if (!isCurator) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Become a curator'),
                  subtitle: const Text('Apply to submit destinations'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BecomeCuratorScreen(),
                    ),
                  ),
                ),
              ],
              if (!isOrganizer) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tour_outlined),
                  title: const Text('Become an organizer'),
                  subtitle: const Text('Apply to create & run tours'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BecomeOrganizerScreen(),
                    ),
                  ),
                ),
              ],
            ],
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
