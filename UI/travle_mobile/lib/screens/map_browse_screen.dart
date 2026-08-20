import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'destination_details_screen.dart';
import 'destination_search_picker_screen.dart';

/// Browse the approved destination catalogue on an interactive map (stretch S2).
/// Panning/zooming refetches the markers within the visible bounding box from the
/// light `GET /Destinations/map` endpoint (capped server-side); tapping a marker
/// opens a mini card that leads to the full details. Category / rating chips filter
/// the markers, mirroring the Search screen.
class MapBrowseScreen extends StatefulWidget {
  const MapBrowseScreen({super.key});

  @override
  State<MapBrowseScreen> createState() => _MapBrowseScreenState();
}

class _MapBrowseScreenState extends State<MapBrowseScreen> {
  /// Mirrors the backend `MaxMapPins` cap — a full page hints "zoom in for more".
  static const int _pinCap = 100;

  /// Recentres the map when the user picks a destination from search.
  final DestinationMapController _mapController = DestinationMapController();

  // Active filters. Categories are multi-select (any of the chosen ones).
  final Set<int> _categoryIds = {};
  double? _minRating;

  // Categories, loaded lazily the first time the sheet opens.
  List<DestinationCategoryResponse>? _categories;

  // The last settled map bounds; refilter reuses it so a chip change refetches
  // without waiting for a pan.
  MapBounds? _bounds;

  // Results, keyed by id for the mini-card lookup on marker tap.
  List<DestinationMapPin> _pins = const [];
  Map<int, DestinationMapPin> _byId = const {};
  int? _selectedId;

  bool _loading = false;
  String? _error;

  // Guards against out-of-order responses: only the latest request applies.
  int _requestId = 0;

  DestinationMapPin? get _selected =>
      _selectedId == null ? null : _byId[_selectedId];

  bool get _capped => _pins.length >= _pinCap;

  Future<void> _onCameraIdle(MapBounds bounds) async {
    _bounds = bounds;
    await _fetch();
  }

  Future<void> _fetch() async {
    final bounds = _bounds;
    if (bounds == null) return;

    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pins = await context.read<DestinationProvider>().mapPins(
            south: bounds.south,
            west: bounds.west,
            north: bounds.north,
            east: bounds.east,
            categoryIds: _categoryIds.toList(),
            minRating: _minRating,
          );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _pins = pins;
        _byId = {for (final p in pins) p.id: p};
        if (_selectedId != null && !_byId.containsKey(_selectedId)) {
          _selectedId = null;
        }
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<List<DestinationCategoryResponse>> _ensureCategories() async {
    if (_categories != null) return _categories!;
    final result = await context
        .read<DestinationCategoryProvider>()
        .get(filter: {'pageSize': 100, 'sortBy': 'Name'});
    _categories = result.items;
    return _categories!;
  }

  Future<void> _openCategorySheet() async {
    final List<DestinationCategoryResponse> categories;
    try {
      categories = await _ensureCategories();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
      return;
    }
    if (!mounted) return;
    final result = await showMultiSelectSheet(
      context,
      title: 'Categories',
      options: [
        for (final c in categories) MultiSelectOption(c.id, c.name),
      ],
      selected: _categoryIds,
    );
    if (result == null) return; // dismissed without applying
    setState(() {
      _categoryIds
        ..clear()
        ..addAll(result);
    });
    _fetch();
  }

  Future<void> _openRatingSheet() async {
    final choice = await _showChoiceSheet<double>(
      title: 'Minimum rating',
      selected: _minRating,
      items: const [
        _Choice<double>(null, 'Any rating'),
        _Choice<double>(3.0, '3+ stars'),
        _Choice<double>(4.0, '4+ stars'),
        _Choice<double>(4.5, '4.5+ stars'),
      ],
    );
    if (choice == null) return;
    setState(() => _minRating = choice.value);
    _fetch();
  }

  Future<_Choice<T>?> _showChoiceSheet<T>({
    required String title,
    required List<_Choice<T>> items,
    required T? selected,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<_Choice<T>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TravleTokens.space16, 0,
                  TravleTokens.space16, TravleTokens.space8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item.label),
                      trailing: item.value == selected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(DestinationMapPin pin) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailsScreen(
          destinationId: pin.id,
          initialName: pin.name,
        ),
      ),
    );
  }

  /// Opens the destination search picker (same typeahead as the Search tab); a
  /// pick flies the map to that destination and selects it.
  Future<void> _openSearch() async {
    final picked = await Navigator.of(context).push<DestinationSuggestion>(
      MaterialPageRoute(builder: (_) => const DestinationSearchPickerScreen()),
    );
    if (picked == null || !mounted) return;
    await _goToDestination(picked);
  }

  /// Fetches the picked destination's detail (for its coordinates + card data),
  /// drops and selects its pin, and recentres the map on it. A search is an explicit
  /// "take me here", so it clears the active filters — the follow-up bounds fetch
  /// (triggered by the recentre) then re-includes it alongside its neighbours.
  Future<void> _goToDestination(DestinationSuggestion suggestion) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final DestinationResponse detail;
    try {
      detail = await context.read<DestinationProvider>().getDetail(suggestion.id);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbars.error(context, e.message);
      return;
    }
    if (!mounted) return;

    // Build a marker from the detail so its card shows instantly, before the
    // bounds fetch that the recentre kicks off has a chance to land.
    final pin = DestinationMapPin(
      id: detail.id,
      name: detail.name,
      latitude: detail.latitude,
      longitude: detail.longitude,
      averageRating: detail.averageRating,
      categoryName: detail.categoryName,
      primaryThumbnail: detail.primaryThumbnail,
      primaryThumbnailContentType: detail.primaryThumbnailContentType,
    );
    setState(() {
      _categoryIds.clear();
      _minRating = null;
      _byId = {..._byId, pin.id: pin};
      _pins = [
        for (final p in _pins)
          if (p.id != pin.id) p,
        pin,
      ];
      _selectedId = pin.id;
      _loading = false;
    });
    _mapController.move(
      MapCoordinate(detail.latitude, detail.longitude),
      zoom: 14,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterRow(),
        Expanded(
          child: Stack(
            children: [
              DestinationMapBrowser(
                controller: _mapController,
                markers: [
                  for (final p in _pins)
                    MapMarkerData(
                      id: p.id,
                      latitude: p.latitude,
                      longitude: p.longitude,
                    ),
                ],
                selectedId: _selectedId,
                onCameraIdle: _onCameraIdle,
                onMarkerTap: (id) => setState(() => _selectedId = id),
                onBackgroundTap: () {
                  if (_selectedId != null) setState(() => _selectedId = null);
                },
              ),
              _buildStatusBanner(),
              if (_selected != null) _buildMiniCard(_selected!),
            ],
          ),
        ),
        _buildSearchBar(),
      ],
    );
  }

  // A read-only search field pinned below the map; tapping it opens the full-screen
  // destination picker (the same typeahead as the Search tab).
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
            TravleTokens.space8, TravleTokens.space16, TravleTokens.space12),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: StadiumBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openSearch,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: TravleTokens.space16,
                  vertical: TravleTokens.space12),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: TravleTokens.space12),
                  Text(
                    'Search destinations',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(TravleTokens.space16, TravleTokens.space8,
          TravleTokens.space16, TravleTokens.space8),
      child: Row(
        children: [
          _FilterButton(
            label: multiSelectChipLabel(
              emptyLabel: 'Category',
              selected: _categoryIds,
              options: [
                for (final c in _categories ??
                    const <DestinationCategoryResponse>[])
                  MultiSelectOption(c.id, c.name),
              ],
              pluralNoun: 'categories',
            ),
            active: _categoryIds.isNotEmpty,
            onTap: _openCategorySheet,
          ),
          const SizedBox(width: TravleTokens.space8),
          _FilterButton(
            label: _minRating == null
                ? 'Rating'
                : '${_minRating!.toStringAsFixed(_minRating! % 1 == 0 ? 0 : 1)}+',
            active: _minRating != null,
            onTap: _openRatingSheet,
          ),
        ],
      ),
    );
  }

  // A single small pill at the top of the map that reflects the current state —
  // loading, an error (tap to retry), an empty box, or a capped result set.
  Widget _buildStatusBanner() {
    if (_loading) {
      return const _MapPill(
        icon: null,
        text: 'Loading destinations…',
        showSpinner: true,
      );
    }
    if (_error != null) {
      return _MapPill(
        icon: Icons.error_outline,
        text: 'Couldn’t load — tap to retry',
        onTap: _fetch,
      );
    }
    if (_pins.isEmpty) {
      return const _MapPill(
        icon: Icons.location_off_outlined,
        text: 'No destinations in this area',
      );
    }
    if (_capped) {
      return const _MapPill(
        icon: Icons.travel_explore_outlined,
        text: 'Showing the top $_pinCap — zoom in for more',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMiniCard(DestinationMapPin pin) {
    final theme = Theme.of(context);
    return Positioned(
      left: TravleTokens.space16,
      right: TravleTokens.space16,
      bottom: TravleTokens.space16,
      child: Card(
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetails(pin),
          child: Padding(
            padding: const EdgeInsets.all(TravleTokens.space12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThumbnailImage(
                  base64: pin.primaryThumbnail,
                  width: 72,
                  height: 72,
                  placeholderIcon: Icons.photo_outlined,
                ),
                const SizedBox(width: TravleTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pin.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pin.categoryName != null &&
                          pin.categoryName!.isNotEmpty) ...[
                        const SizedBox(height: TravleTokens.space4),
                        Text(
                          pin.categoryName!,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                      const SizedBox(height: TravleTokens.space8),
                      Row(
                        children: [
                          RatingStars(value: pin.averageRating, size: 15),
                          const Spacer(),
                          Text(
                            'View details',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18, color: theme.colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedId = null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact status pill floated at the top-centre of the map.
class _MapPill extends StatelessWidget {
  const _MapPill({
    required this.icon,
    required this.text,
    this.showSpinner = false,
    this.onTap,
  });

  final IconData? icon;
  final String text;
  final bool showSpinner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: TravleTokens.space8,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 2,
          borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: TravleTokens.space12, vertical: TravleTokens.space8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSpinner)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (icon != null)
                    Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: TravleTokens.space8),
                  Text(text, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One option in a filter bottom sheet. A null [value] is the "Any" / clear choice.
class _Choice<T> {
  const _Choice(this.value, this.label);

  final T? value;
  final String label;
}

/// A pill button that opens a filter sheet; highlighted while a value is selected.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: onTap,
      backgroundColor: active ? theme.colorScheme.primaryContainer : null,
      side: active ? BorderSide(color: theme.colorScheme.primary) : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: active
                ? TextStyle(color: theme.colorScheme.onPrimaryContainer)
                : null,
          ),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: active ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ],
      ),
    );
  }
}
