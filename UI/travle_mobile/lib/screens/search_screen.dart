import 'package:flutter/material.dart';

import '../widgets/coming_soon.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ComingSoon(title: 'Search', icon: Icons.search_outlined);
}
