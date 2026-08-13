import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../theme/tokens.dart';
import 'map_basemap.dart';
import 'map_pin.dart';
import 'map_types.dart';

/// Imperative handle for a [DestinationMapBrowser]: lets a screen recentre the map
/// on a coordinate (e.g. after the user picks a destination from search) without
/// importing flutter_map — the map library stays an implementation detail of the
/// design system (doc 08 §5). Create one, pass it to the browser, and call [move];
/// it is a no-op until the browser is mounted and again after it is disposed.
class DestinationMapController {
  _DestinationMapBrowserState? _state;

  void _bind(_DestinationMapBrowserState state) => _state = state;

  void _unbind(_DestinationMapBrowserState state) {
    if (identical(_state, state)) _state = null;
  }

  /// Recentres the map on [target] at [zoom]. No-op while detached.
  void move(MapCoordinate target, {double zoom = 14}) =>
      _state?._moveTo(target, zoom);
}

/// A full-bleed, interactive browse map: it renders tappable [markers], reports
/// the visible [MapBounds] whenever the camera settles (debounced), and reports
/// per-marker taps by id — the caller fetches markers for the reported box and
/// looks up the tapped id. Model-agnostic: it never sees a destination, so
/// flutter_map / latlong2 stay an implementation detail of the design system
/// (doc 08 §5). This is the interactive sibling of the preview-oriented
/// [TravleMapView]; the two intentionally stay separate.
class DestinationMapBrowser extends StatefulWidget {
  const DestinationMapBrowser({
    super.key,
    required this.markers,
    required this.onCameraIdle,
    required this.onMarkerTap,
    this.onBackgroundTap,
    this.selectedId,
    this.controller,
    this.initialCenter = const MapCoordinate(43.8563, 18.4131), // Sarajevo
    this.initialZoom = 7.5,
  });

  final List<MapMarkerData> markers;

  /// Optional imperative handle to recentre the map programmatically.
  final DestinationMapController? controller;

  /// Fired once the camera has settled (after the first layout, and ~400 ms after
  /// the last gesture) with the currently visible bounds — the box to fetch.
  final ValueChanged<MapBounds> onCameraIdle;

  /// Fired when a marker is tapped, with its id.
  final ValueChanged<int> onMarkerTap;

  /// Fired when the map background (not a marker) is tapped — used to dismiss the
  /// mini card / clear the selection.
  final VoidCallback? onBackgroundTap;

  /// The currently selected marker id, drawn on top of the others.
  final int? selectedId;

  final MapCoordinate initialCenter;
  final double initialZoom;

  @override
  State<DestinationMapBrowser> createState() => _DestinationMapBrowserState();
}

class _DestinationMapBrowserState extends State<DestinationMapBrowser> {
  final MapController _controller = MapController();
  TravleBasemap _basemap = TravleBasemap.street;

  // Debounce so a pan/zoom fires a single fetch when it settles, not one per frame.
  Timer? _idleTimer;
  static const Duration _idleDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(this);
  }

  @override
  void didUpdateWidget(covariant DestinationMapBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._unbind(this);
      widget.controller?._bind(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._unbind(this);
    _idleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Recentres the map; called through [DestinationMapController.move]. The move
  /// fires `onPositionChanged`, so the browse screen refetches the new bounds.
  void _moveTo(MapCoordinate target, double zoom) =>
      _controller.move(target.toLatLng(), zoom);

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleDelay, () {
      if (mounted) widget.onCameraIdle(_toBounds(camera.visibleBounds));
    });
  }

  MapBounds _toBounds(LatLngBounds b) =>
      MapBounds(south: b.south, west: b.west, north: b.north, east: b.east);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.initialCenter.toLatLng(),
            initialZoom: widget.initialZoom,
            interactionOptions: const InteractionOptions(
              flags: kTravleMapInteractiveFlags,
            ),
            minZoom: 3,
            maxZoom: kMaxMapZoom,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            onMapReady: () => widget.onCameraIdle(
              _toBounds(_controller.camera.visibleBounds),
            ),
            onPositionChanged: _onPositionChanged,
            onTap: (_, _) => widget.onBackgroundTap?.call(),
          ),
          children: [
            TileLayer(
              urlTemplate: _basemap.urlTemplate,
              userAgentPackageName: kTravleMapUserAgent,
              maxZoom: 19,
            ),
            MarkerLayer(markers: _markers(theme)),
          ],
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: MapAttributionBadge(text: _basemap.attribution),
        ),
        // A slim, icon-only vertical strip pinned to the right edge (map on top,
        // satellite below) so it never sits under the centred status pill.
        Positioned(
          top: TravleTokens.space8,
          right: TravleTokens.space8,
          child: BasemapToggle(
            value: _basemap,
            direction: Axis.vertical,
            showLabels: false,
            onChanged: (b) => setState(() => _basemap = b),
          ),
        ),
      ],
    );
  }

  // Ordered so the selected marker is built last (drawn on top of any overlapping
  // pins). Every pin is a fixed-size, top-centre-anchored MapPin (matching the
  // rest of the app); the selected one is tinted with the container colour so it
  // reads as picked without shifting the tip off its coordinate.
  List<Marker> _markers(ThemeData theme) {
    final ordered = [
      ...widget.markers.where((m) => m.id != widget.selectedId),
      ...widget.markers.where((m) => m.id == widget.selectedId),
    ];
    return [
      for (final m in ordered)
        Marker(
          point: m.toLatLng(),
          width: MapPin.width,
          height: MapPin.height,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onMarkerTap(m.id),
            child: MapPin(
              color: m.id == widget.selectedId
                  ? Colors.red
                  : theme.colorScheme.primary,
            ),
          ),
        ),
    ];
  }
}
