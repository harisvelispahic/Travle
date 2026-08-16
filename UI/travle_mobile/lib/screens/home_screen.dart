import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/recommendation_card.dart';
import 'destination_details_screen.dart';

/// Vertical breathing room reserved above and below the cards in the home
/// carousels. A horizontal [ListView] clips to its box, so its cards' elevation
/// shadows (and the soft rounded corners they imply) get sheared flat at the top
/// and bottom edge. Padding the list by this much — and growing the enclosing
/// [SizedBox] by twice it — keeps the shadow inside the viewport so the cards read
/// as lifted, not cut off.
const double _carouselShadowGutter = TravleTokens.space8;

/// Home landing screen. A gradient header with a tap-through search bar, then the
/// recommender-driven "Recommended for you" carousel (with per-card reasons),
/// followed by the Featured and "Popular right now" catalogue sections.
///
/// The recommendations come from `GET /Recommendations`: a warm user gets an
/// explained, personalized list; a cold-start user gets a popularity list the UI
/// labels honestly (and we drop the redundant separate "Popular" row for them).
/// Recommendations are best-effort — if that call fails the catalogue sections
/// still render, so the home screen is never blank because of the recommender.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenSearch});

  /// Invoked when the search bar is tapped — the shell switches to the Search tab
  /// and focuses its field.
  final VoidCallback? onOpenSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  RecommendationResponse? _recommendations;
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

    final destinations = context.read<DestinationProvider>();
    final recommender = context.read<RecommendationProvider>();

    // Recommendations are best-effort: a recommender hiccup must not blank the
    // whole home screen, so we swallow its error and simply hide the section.
    RecommendationResponse? recommendations;
    try {
      recommendations = await recommender.getForCurrentUser();
    } on ApiClientException {
      recommendations = null;
    }

    try {
      final featured = await destinations.get(filter: {
        'isFeatured': true,
        'pageSize': 10,
        'includeTotalCount': false,
        'sortBy': 'AverageRating desc',
      });
      final popular = await destinations.get(filter: {
        'pageSize': 10,
        'includeTotalCount': false,
        'sortBy': 'ViewCount desc',
      });
      if (!mounted) return;
      setState(() {
        _recommendations = recommendations;
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

    final recommendations = _recommendations;
    final recItems = recommendations?.items ?? const <RecommendationItem>[];
    final isColdStart = recommendations?.isColdStart ?? false;

    // Cold-start recommendations are themselves a popularity ranking, so the
    // separate "Popular" row would just duplicate them — show it only for warm
    // users (or if recommendations are missing entirely).
    final showPopular = _popular.isNotEmpty && (!isColdStart || recItems.isEmpty);

    final hasContent =
        recItems.isNotEmpty || _featured.isNotEmpty || _popular.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: TravleTokens.space16),
        children: [
          _HomeHeader(onOpenSearch: widget.onOpenSearch),
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
            if (recItems.isNotEmpty)
              _RecommendationSection(
                items: recItems,
                isColdStart: isColdStart,
                onTap: _openDetails,
              ),
            if (_featured.isNotEmpty)
              _CarouselSection(
                title: 'Featured destinations',
                destinations: _featured,
                onTap: _openDetails,
              ),
            if (showPopular)
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

/// The gradient welcome header with the tap-through search bar.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({this.onOpenSearch});

  final VoidCallback? onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TravleTokens.space16,
        TravleTokens.space32,
        TravleTokens.space16,
        TravleTokens.space24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TravleTokens.forest, TravleTokens.forestMid],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(TravleTokens.radius * 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LET’S EXPLORE',
            style: theme.textTheme.labelMedium?.copyWith(
              color: TravleTokens.sage,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: TravleTokens.space4),
          Text(
            'Where to next?',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: TravleTokens.mint,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: TravleTokens.space16),
          _SearchBarButton(onTap: onOpenSearch),
        ],
      ),
    );
  }
}

/// The read-only search field that routes to the Search tab.
class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
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

/// The recommender's flagship section: a titled horizontal carousel of rich
/// recommendation cards. Cold-start users see a "get you started" framing with no
/// per-card reasons (they'd all be the same popularity label).
class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({
    required this.items,
    required this.isColdStart,
    required this.onTap,
  });

  final List<RecommendationItem> items;
  final bool isColdStart;
  final void Function(DestinationResponse) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isColdStart ? 'Popular to get you started' : 'Recommended for you';
    final subtitle = isColdStart
        ? 'We’ll tailor these as you explore, favorite, and book.'
        : null;
    final showReason = !isColdStart;
    // The extra height beyond the card is deliberate headroom for the card's
    // elevation shadow: a horizontal ListView clips to its box, so without it the
    // shadow (and the rounded corners it softens) gets sheared flat top and bottom.
    final cardHeight = (showReason ? 272.0 : 224.0) + _carouselShadowGutter * 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: TravleTokens.space8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: TravleTokens.space4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(height: TravleTokens.space12),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TravleTokens.space16,
              vertical: _carouselShadowGutter,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: TravleTokens.space16),
            itemBuilder: (_, i) => RecommendationCard(
              item: items[i],
              showReason: showReason,
              onTap: () => onTap(items[i].destination),
            ),
          ),
        ),
        const SizedBox(height: TravleTokens.space24),
      ],
    );
  }
}

/// A titled horizontal carousel of compact destination cards (Featured / Popular).
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
          padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: TravleTokens.space12),
        SizedBox(
          // +shadow gutter so the card's elevation shadow isn't clipped flat by
          // the horizontal ListView's box (see _carouselShadowGutter).
          height: 216 + _carouselShadowGutter * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TravleTokens.space16,
              vertical: _carouselShadowGutter,
            ),
            itemCount: destinations.length,
            separatorBuilder: (_, _) => const SizedBox(width: TravleTokens.space16),
            itemBuilder: (_, i) => _MiniDestinationCard(
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

/// Compact destination card for the Featured / Popular carousels: cover thumbnail
/// on top, then name, location, and rating.
class _MiniDestinationCard extends StatelessWidget {
  const _MiniDestinationCard({required this.destination, required this.onTap});

  final DestinationResponse destination;
  final VoidCallback onTap;

  String get _location => [destination.cityName, destination.regionName]
      .where((p) => p != null && p.isNotEmpty)
      .cast<String>()
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
            mainAxisSize: MainAxisSize.min,
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
                  mainAxisSize: MainAxisSize.min,
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
