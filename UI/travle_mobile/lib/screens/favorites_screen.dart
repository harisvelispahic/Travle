import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ComingSoon(title: 'Favorites', icon: Icons.favorite_outline);
}
