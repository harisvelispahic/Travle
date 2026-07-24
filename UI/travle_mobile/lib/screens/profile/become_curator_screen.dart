import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';

import 'role_application_screen.dart';

/// The curator preset of [RoleApplicationScreen]: a curator picks the region
/// they'd curate, so the region dropdown is shown and required.
class BecomeCuratorScreen extends StatelessWidget {
  const BecomeCuratorScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoleApplicationScreen(
        roleName: AppRole.curator,
        title: 'Become a curator',
        intro:
            'Curators submit destinations to the platform. Tell us where you\'d like to curate and why.',
        motivationHint: 'Why do you want to become a curator?',
        showRegion: true,
        regionLabel: 'Region to curate',
        regionRequired: true,
      );
}
