import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';

import 'role_application_screen.dart';

/// The organizer preset of [RoleApplicationScreen]: organizers run tours across
/// destinations rather than curating one region, so no region is collected.
class BecomeOrganizerScreen extends StatelessWidget {
  const BecomeOrganizerScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoleApplicationScreen(
        roleName: AppRole.organizer,
        title: 'Become an organizer',
        intro:
            'Organizers create and run guided tours. Tell us why you\'d like to organize tours on Travle.',
        motivationHint: 'Why do you want to become an organizer?',
      );
}
