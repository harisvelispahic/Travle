import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'destination_details_screen.dart';

/// Home landing screen (mockup Slika 6). A tap-through search bar hands off to the
/// Search tab, then two horizontal sections of the approved catalogue: Featured
/// destinations and "Popular right now" (most-viewed). The recommender-driven
/// "Recommended for you" section and popular tours arrive in Phases 8 and 4;
/// until the recommender exists every user is cold-start, so the popularity list
/// stands in per the documented cold-start rule.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenSearch});

  /// Invoked when the search bar is tapped — the shell switches to the Search tab
  /// and focuses its field.
  final VoidCallback? onOpenSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DestinationResponse> _featured = [];
  List<DestinationResponse> _popular = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<DestinationProvider>();
    try {
      final featured = await provider.get(filter: {
        'isFeatured': true,
        'pageSize': 10,
        'includeTotalCount': false,
        'sortBy': 'AverageRating desc',
      });
      final popular = await provider.get(filter: {
        'pageSize': 10,
        'includeTotalCount': false,
        'sortBy': 'ViewCount desc',
      });
      if (!mounted) return;
      setState(() {
        _featured = featured.items;
        _popular = popular.items;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _openDetails(DestinationResponse destination) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailsScreen(
          destinationId: destination.id,
          initialName: destination.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final hasContent = _featured.isNotEmpty || _popular.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: TravleTokens.space16),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
            child: _SearchBarButton(onTap: widget.onOpenSearch),
          ),
          const SizedBox(height: TravleTokens.space24),
          if (!hasContent)
            const Padding(
              padding: EdgeInsets.only(top: TravleTokens.space32),
              child: EmptyState(
                icon: Icons.travel_explore_outlined,
                message: 'No destinations yet',
                hint: 'Check back soon — new places are on the way.',
              ),
            )
          else ...[
            if (_featured.isNotEmpty)
              _CarouselSection(
                title: 'Featured destinations',
                destinations: _featured,
                onTap: _openDetails,
              ),
            if (_popular.isNotEmpty)
              _CarouselSection(
                title: 'Popular right now',
                destinations: _popular,
                onTap: _openDetails,
              ),
          ],
        ],
      ),
    );
  }
}

/// The read-only search field on Home that routes to the Search tab.
class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(TravleTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(TravleTokens.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: TravleTokens.space16, vertical: TravleTokens.space12),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: TravleTokens.space12),
              Text(
                'Search destinations',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A titled horizontal carousel of destination cards.
class _CarouselSection extends StatelessWidget {
  const _CarouselSection({
    required this.title,
    required this.destinations,
    required this.onTap,
  });

  final String title;
  final List<DestinationResponse> destinations;
  final void Function(DestinationResponse) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: TravleTokens.space12),
        SizedBox(
          height: 216,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
            itemCount: destinations.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: TravleTokens.space12),
            itemBuilder: (_, i) => _HomeDestinationCard(
              destination: destinations[i],
              onTap: () => onTap(destinations[i]),
            ),
          ),
        ),
        const SizedBox(height: TravleTokens.space24),
      ],
    );
  }
}

/// Compact destination card for the Home carousels: cover thumbnail on top, then
/// name, location, and rating.
class _HomeDestinationCard extends StatelessWidget {
  const _HomeDestinationCard({required this.destination, required this.onTap});

  final DestinationResponse destination;
  final VoidCallback onTap;

  String get _location => [destination.cityName, destination.regionName]
      .where((p) => p != null && p.isNotEmpty)
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThumbnailImage(
                base64: destination.primaryThumbnail,
                width: 180,
                height: 110,
                radius: 0,
                placeholderIcon: Icons.photo_outlined,
              ),
              Padding(
                padding: const EdgeInsets.all(TravleTokens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_location.isNotEmpty) ...[
                      const SizedBox(height: TravleTokens.space4),
                      Text(
                        _location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: TravleTokens.space8),
                    RatingStars(value: destination.averageRating, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
