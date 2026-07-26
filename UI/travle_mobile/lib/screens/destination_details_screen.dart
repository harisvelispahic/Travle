import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Traveler-facing destination details (mockup Slika 8). Opening the screen
/// fetches the detail via `GET /Destinations/{id}`, which logs a View interaction
/// and bumps ViewCount server-side (for an approved destination viewed by someone
/// other than its submitter). Shows the full-image gallery (fetched from the image
/// endpoint, decoded once), header + rating, tags, an expandable description, and a
/// location panel.
///
/// Tours, reviews, similar destinations, and the favorite toggle arrive in their
/// own phases (4 / 7 / 8) and are intentionally not stubbed here.
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

  @override
  Widget build(BuildContext context) {
    final title = _destination?.name ?? widget.initialName ?? 'Destination';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
