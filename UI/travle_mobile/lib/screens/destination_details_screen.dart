import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/review_card.dart';
import '../widgets/review_form_sheet.dart';
import '../widgets/tour_card.dart';
import 'tour_details_screen.dart';

/// Traveler-facing destination details (mockup Slika 8). Opening the screen
/// fetches the detail via `GET /Destinations/{id}`, which logs a View interaction
/// and bumps ViewCount server-side (for an approved destination viewed by someone
/// other than its submitter). Shows the full-image gallery (fetched from the image
/// endpoint, decoded once), header + rating, tags, an expandable description, a
/// location panel, the reviews (with the favorite toggle in the app bar), and the
/// tours that visit this destination (§Phase 4 / 7).
///
/// The "Similar destinations" section is the recommender surface and arrives in
/// Phase 8; it is intentionally not stubbed here.
class DestinationDetailsScreen extends StatefulWidget {
  const DestinationDetailsScreen({
    super.key,
    required this.destinationId,
    this.initialName,
  });

  final int destinationId;

  /// Shown in the app bar while the detail loads, so the title isn't blank.
  final String? initialName;

  @override
  State<DestinationDetailsScreen> createState() =>
      _DestinationDetailsScreenState();
}

class _DestinationDetailsScreenState extends State<DestinationDetailsScreen> {
  DestinationResponse? _destination;
  bool _loading = true;
  bool _isFavorite = false;
  bool _favoriteBusy = false;
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
    try {
      final destination = await context
          .read<DestinationProvider>()
          .getDetail(widget.destinationId);
      if (!mounted) return;
      setState(() {
        _destination = destination;
        _isFavorite = destination.isFavorite;
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

  Future<void> _toggleFavorite() async {
    final destination = _destination;
    if (destination == null || _favoriteBusy) return;

    setState(() => _favoriteBusy = true);
    try {
      final result = await context
          .read<FavoriteProvider>()
          .toggleDestination(destination.id);
      if (!mounted) return;
      setState(() {
        _isFavorite = result.isFavorite;
        _favoriteBusy = false;
      });
      AppSnackbars.success(
        context,
        result.isFavorite
            ? 'Added to your favorites.'
            : 'Removed from your favorites.',
      );
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _favoriteBusy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _destination?.name ?? widget.initialName ?? 'Destination';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_destination != null)
            IconButton(
              onPressed: _favoriteBusy ? null : _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Theme.of(context).colorScheme.error : null,
              ),
              tooltip:
                  _isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
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

    final destination = _destination!;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (destination.images.isNotEmpty)
          _DestinationGallery(
            destinationId: destination.id,
            images: destination.images,
          ),
        Padding(
          padding: const EdgeInsets.all(TravleTokens.space16),
          child: _DetailsContent(destination: destination),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TravleTokens.space16,
            0,
            TravleTokens.space16,
            TravleTokens.space16,
          ),
          child: _DestinationReviewsSection(
            destinationId: destination.id,
            // Posting/editing/removing a review changes the rolled-up average, so
            // reload the whole detail to refresh the header rating.
            onChanged: _load,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TravleTokens.space16,
            0,
            TravleTokens.space16,
            TravleTokens.space16,
          ),
          child: _ToursSection(
            destinationId: destination.id,
            destinationName: destination.name,
          ),
        ),
      ],
    );
  }
}

/// The reviews for a destination: the average summary, the list, and — for the
/// signed-in user — a "Write a review" / "Edit your review" affordance. Any
/// registered user may review an approved destination once (the server enforces
/// the one-active-review rule and the rating rollup). Loads its own list and, on
/// any change, calls [onChanged] so the parent refreshes the header rating.
class _DestinationReviewsSection extends StatefulWidget {
  const _DestinationReviewsSection({
    required this.destinationId,
    required this.onChanged,
  });

  final int destinationId;
  final VoidCallback onChanged;

  @override
  State<_DestinationReviewsSection> createState() =>
      _DestinationReviewsSectionState();
}

class _DestinationReviewsSectionState
    extends State<_DestinationReviewsSection> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<DestinationReviewResponse> _reviews = [];
  int _total = 0;

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
    try {
      final result =
          await context.read<DestinationReviewProvider>().forDestination(
        widget.destinationId,
        filter: {
          'pageSize': 50,
          'includeTotalCount': true,
          'sortBy': 'CreatedAt desc',
        },
      );
      if (!mounted) return;
      setState(() {
        _reviews = result.items;
        _total = result.totalCount ?? result.items.length;
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

  DestinationReviewResponse? get _myReview {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return null;
    for (final r in _reviews) {
      if (r.userId == userId) return r;
    }
    return null;
  }

  Future<void> _write() async {
    final draft = await ReviewFormSheet.show(
      context,
      title: 'Write a review',
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<DestinationReviewProvider>().create(
            DestinationReviewInsertRequest(
              destinationId: widget.destinationId,
              rating: draft.rating,
              comment: draft.comment,
            ),
          );
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.success(context, 'Thanks — your review has been posted.');
      widget.onChanged();
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _edit(DestinationReviewResponse review) async {
    final draft = await ReviewFormSheet.show(
      context,
      title: 'Edit your review',
      initialRating: review.rating,
      initialComment: review.comment,
      submitLabel: 'Save changes',
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<DestinationReviewProvider>().updateReview(
            review.id,
            ReviewUpdateRequest(rating: draft.rating, comment: draft.comment),
          );
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.success(context, 'Your review has been updated.');
      widget.onChanged();
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _remove(DestinationReviewResponse review) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove your review',
      message: 'Are you sure you want to remove your review of this destination?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<DestinationReviewProvider>().removeOwn(review.id);
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.success(context, 'Your review has been removed.');
      widget.onChanged();
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myReview = _myReview;
    final currentUserId = context.read<AuthProvider>().userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _total > 0 ? 'Reviews ($_total)' : 'Reviews',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (!_loading && _error == null)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : myReview == null
                        ? _write
                        : () => _edit(myReview),
                icon: Icon(
                  myReview == null ? Icons.rate_review_outlined : Icons.edit_outlined,
                  size: 18,
                ),
                label: Text(myReview == null ? 'Write a review' : 'Edit yours'),
              ),
          ],
        ),
        const SizedBox(height: TravleTokens.space8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TravleTokens.space16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (_reviews.isEmpty)
          Text(
            'No reviews yet. Be the first to share your experience.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final review in _reviews)
            ReviewCard(
              authorName: review.authorName,
              rating: review.rating,
              createdAt: review.createdAt,
              comment: review.comment,
              isMine: review.userId == currentUserId,
              onEdit: review.userId == currentUserId && !_busy
                  ? () => _edit(review)
                  : null,
              onRemove: review.userId == currentUserId && !_busy
                  ? () => _remove(review)
                  : null,
            ),
      ],
    );
  }
}

/// The tours that visit this destination (`GET /Tours?destinationId=…`, active
/// only). Loads independently; the whole section hides when there are none, so a
/// destination with no tours shows nothing rather than an empty header.
class _ToursSection extends StatefulWidget {
  const _ToursSection({required this.destinationId, required this.destinationName});

  final int destinationId;
  final String destinationName;

  @override
  State<_ToursSection> createState() => _ToursSectionState();
}

class _ToursSectionState extends State<_ToursSection> {
  bool _loading = true;
  String? _error;
  List<TourResponse> _tours = [];

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
    try {
      final result = await context.read<TourProvider>().get(
        filter: {
          'destinationId': widget.destinationId,
          'isActive': true,
          'pageSize': 20,
          'sortBy': 'CreatedAt desc',
        },
      );
      if (!mounted) return;
      setState(() {
        _tours = result.items;
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

  void _openTour(TourResponse tour) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TourDetailsScreen(tourId: tour.id, initialName: tour.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Nothing to show and nothing to retry → take up no space at all.
    if (!_loading && _error == null && _tours.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tours visiting here', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TravleTokens.space16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else
          for (final tour in _tours)
            Padding(
              padding: const EdgeInsets.only(bottom: TravleTokens.space8),
              child: TourCard(tour: tour, onTap: () => _openTour(tour)),
            ),
      ],
    );
  }
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({required this.destination});

  final DestinationResponse destination;

  String get _location => [
        destination.cityName,
        destination.regionName,
        destination.countryName,
      ].where((p) => p != null && p.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(destination.name, style: theme.textTheme.headlineSmall),
        if (_location.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space8),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: muted),
              const SizedBox(width: TravleTokens.space4),
              Expanded(
                child: Text(
                  _location,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: TravleTokens.space12),
        Row(
          children: [
            RatingStars(value: destination.averageRating, size: 20),
            const Spacer(),
            Icon(Icons.visibility_outlined, size: 16, color: muted),
            const SizedBox(width: TravleTokens.space4),
            Text(
              '${destination.viewCount} views',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
        if (destination.categoryName != null &&
            destination.categoryName!.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space16),
          Row(
            children: [
              Icon(Icons.category_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: TravleTokens.space8),
              Text(
                destination.categoryName!,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
        if (destination.tags.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space12),
          Wrap(
            spacing: TravleTokens.space8,
            runSpacing: TravleTokens.space8,
            children: [
              for (final tag in destination.tags)
                Chip(
                  label: Text(tag.name),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],
        if (destination.entranceFee != null) ...[
          const SizedBox(height: TravleTokens.space16),
          _EntranceFeeReminder(fee: destination.entranceFee!),
        ],
        const SizedBox(height: TravleTokens.space24),
        Text('About', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        _ExpandableText(text: destination.description),
        const SizedBox(height: TravleTokens.space24),
        Text('Location', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        _LocationPanel(destination: destination),
      ],
    );
  }
}

/// A friendly, informative reminder that the destination charges an entrance fee
/// paid on site — deliberately worded as an approximate "bring around X" nudge,
/// since the amount may be out of date and is never part of a tour's price.
class _EntranceFeeReminder extends StatelessWidget {
  const _EntranceFeeReminder({required this.fee});

  final double fee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.confirmation_number_outlined,
              color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Text(
              'Heads up: bring around ${fee.toStringAsFixed(2)} KM in cash for the '
              'entrance fee, paid at the destination. It is not included in any tour '
              'price, and the amount is approximate — it may have changed.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// The description with a "Read more" / "Read less" toggle. Long descriptions are
/// collapsed to a few lines until expanded (mockup Slika 8).
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const int _collapsedLines = 4;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;

    // Only offer the toggle when the text would actually overflow the collapsed
    // height — otherwise a short description shows a pointless "Read more".
    final overflows = _overflows(context, style);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: style,
          maxLines: _expanded ? null : _collapsedLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (overflows)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Read less' : 'Read more'),
          ),
      ],
    );
  }

  bool _overflows(BuildContext context, TextStyle? style) {
    final maxWidth = MediaQuery.of(context).size.width - TravleTokens.space16 * 2;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: _collapsedLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}

/// A simple location panel: the full address chain plus coordinates. A dedicated
/// interactive map preview is a documented stretch feature (00 §3.1); until then
/// this presents the location without raw IDs.
class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.destination});

  final DestinationResponse destination;

  String get _address => [
        destination.cityName,
        destination.regionName,
        destination.countryName,
      ].where((p) => p != null && p.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_address.isNotEmpty)
            Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: TravleTokens.space8),
                Expanded(child: Text(_address, style: theme.textTheme.bodyMedium)),
              ],
            ),
          const SizedBox(height: TravleTokens.space8),
          Text(
            '${destination.latitude.toStringAsFixed(5)}, '
            '${destination.longitude.toStringAsFixed(5)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// Full-image gallery for the details screen (mockup Slika 8). Fetches every
/// image's bytes from the image endpoint once (in [initState], never in build),
/// caches them in state, and pages through them with `Image.memory` (which caches
/// the decode) — satisfying the "decode once, never in build" image rule (§12).
class _DestinationGallery extends StatefulWidget {
  const _DestinationGallery({
    required this.destinationId,
    required this.images,
  });

  final int destinationId;
  final List<DestinationImageResponse> images;

  @override
  State<_DestinationGallery> createState() => _DestinationGalleryState();
}

class _DestinationGalleryState extends State<_DestinationGallery> {
  static const double _height = 260;

  final PageController _controller = PageController();
  List<Uint8List>? _bytes;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final provider = context.read<DestinationProvider>();
    try {
      final ordered = [...widget.images]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final bytes = await Future.wait(
        ordered.map((img) => provider.imageBytes(widget.destinationId, img.id)),
      );
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = _bytes;

    if (_error != null) {
      return Container(
        height: _height,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined,
            size: 48, color: theme.colorScheme.onSurfaceVariant),
      );
    }
    if (bytes == null) {
      return Container(
        height: _height,
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return SizedBox(
      height: _height,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: bytes.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Image.memory(bytes[i], fit: BoxFit.cover),
          ),
          if (bytes.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: TravleTokens.space12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < bytes.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(
                          horizontal: TravleTokens.space4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
