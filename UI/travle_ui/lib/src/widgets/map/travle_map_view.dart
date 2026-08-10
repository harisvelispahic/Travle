import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/tokens.dart';
import 'map_basemap.dart';
import 'map_pin.dart';
import 'map_types.dart';

/// Read-only map showing one or more [points] on a bordered, rounded card.
///
/// One point → centered pin (e.g. a destination). Many points → the camera fits
/// them all, and with [numbered] the pins carry their 1-based order and with
/// [connect] a dashed line joins consecutive stops (a tour itinerary — a straight
/// connector for display, not routed directions). Tap the basemap toggle to swap
/// street ⇄ satellite. Non-interactive by default so it never traps page scroll.
class TravleMapView extends StatefulWidget {
  const TravleMapView({
    super.key,
    required this.points,
    this.height = 220,
    this.numbered = false,
    this.connect = false,
    this.interactive = false,
    this.showBasemapToggle = true,
    this.onTap,
    this.decorated = true,
    this.singlePointZoom = 14,
    this.boundsPadding = 44,
  });

  final List<MapPoint> points;
  final double height;

  /// Number the pins by their order in [points] (itinerary stops).
  final bool numbered;

  /// Draw a dashed connector between consecutive points (display-only).
  final bool connect;

  /// Allow pan/zoom. Off by default to avoid fighting an enclosing scroll view.
  final bool interactive;
  final bool showBasemapToggle;

  /// When set, the (non-interactive) map shows an "expand" affordance and taps
  /// anywhere on it invoke this — typically opening a fullscreen zoomable map via
  /// [showTravleMap]. Ignored when [interactive] is true.
  final VoidCallback? onTap;

  /// Wrap the map in a bordered, rounded card. Set false for a full-bleed map
  /// (e.g. the fullscreen viewer).
  final bool decorated;

  final double singlePointZoom;
  final double boundsPadding;

  @override
  State<TravleMapView> createState() => _TravleMapViewState();
}

class _TravleMapViewState extends State<TravleMapView> {
  TravleBasemap _basemap = TravleBasemap.street;
  final MapController _controller = MapController();

  // Set once the map has completed its first layout. Using the MapController
  // (move/fitCamera) before this throws, which is what caused the occasional
  // red-screen flash when points changed during an early rebuild.
  bool _mapReady = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TravleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the points change (e.g. a tour's itinerary being edited live), re-fit
    // the camera — MapOptions.initial* only apply on the first build.
    if (_mapReady &&
        widget.points.isNotEmpty &&
        !_samePoints(oldWidget.points, widget.points)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _fitToPoints();
      });
    }
  }

  bool _samePoints(List<MapPoint> a, List<MapPoint> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
        return false;
      }
    }
    return true;
  }

  void _fitToPoints() {
    final latLngs = [for (final p in widget.points) p.toLatLng()];
    if (latLngs.length == 1) {
      _controller.move(latLngs.first, widget.singlePointZoom);
    } else {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(latLngs),
          padding: EdgeInsets.all(widget.boundsPadding),
          maxZoom: 15,
        ),
      );
    }
  }

  LatLng _center(List<LatLng> points) {
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(TravleTokens.radius);

    Widget content;
    if (widget.points.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 32, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: TravleTokens.space8),
            Text('No location',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    } else {
      final latLngs = [for (final p in widget.points) p.toLatLng()];
      final single = latLngs.length == 1;
      content = Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: single ? latLngs.first : _center(latLngs),
              initialZoom: single ? widget.singlePointZoom : 6,
              initialCameraFit: single
                  ? null
                  : CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(latLngs),
                      padding: EdgeInsets.all(widget.boundsPadding),
                      maxZoom: 15,
                    ),
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? kTravleMapInteractiveFlags
                    : InteractiveFlag.none,
              ),
              minZoom: 3,
              maxZoom: kMaxMapZoom,
              onMapReady: () => _mapReady = true,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            children: [
              TileLayer(
                urlTemplate: _basemap.urlTemplate,
                userAgentPackageName: kTravleMapUserAgent,
                maxZoom: 19,
              ),
              if (widget.connect && latLngs.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: latLngs,
                      strokeWidth: 3,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      pattern: StrokePattern.dashed(segments: const [14, 8]),
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers(theme)),
            ],
          ),
          // Tap-to-expand: a full-bleed catcher under the controls (which are
          // tested first) opens a fullscreen zoomable map on a non-interactive
          // preview. Skipped when the map is already interactive.
          if (_expandable)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: MapAttributionBadge(text: _basemap.attribution),
          ),
          if (_expandable)
            const Positioned(
              left: TravleTokens.space8,
              bottom: TravleTokens.space8,
              child: IgnorePointer(child: _ExpandHint()),
            ),
          if (widget.showBasemapToggle)
            Positioned(
              top: TravleTokens.space8,
              right: TravleTokens.space8,
              child: BasemapToggle(
                value: _basemap,
                onChanged: (b) => setState(() => _basemap = b),
              ),
            ),
        ],
      );
    }

    if (!widget.decorated) {
      return SizedBox(height: widget.height, child: content);
    }
    return Container(
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: content,
    );
  }

  bool get _expandable => widget.onTap != null && !widget.interactive;

  List<Marker> _markers(ThemeData theme) {
    return [
      for (var i = 0; i < widget.points.length; i++)
        Marker(
          point: widget.points[i].toLatLng(),
          width: MapPin.width,
          height: MapPin.height,
          alignment: Alignment.topCenter,
          child: _withTooltip(
            widget.points[i].label,
            MapPin(
              number: widget.numbered ? i + 1 : null,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
    ];
  }

  Widget _withTooltip(String? message, Widget child) =>
      message == null ? child : Tooltip(message: message, child: child);
}

/// Opens a full, zoomable map — a **dialog** on wide (desktop) screens and a
/// **fullscreen route** on narrow (mobile) ones. Use it for a "View on map"
/// button, or as the `onTap` target of an inline [TravleMapView] so a
/// non-interactive preview expands into something the user can pan and zoom.
/// Renders the same single-pin / numbered-itinerary content as [TravleMapView].
Future<void> showTravleMap(
  BuildContext context, {
  required List<MapPoint> points,
  String title = 'Location',
  bool numbered = false,
  bool connect = false,
}) {
  final wide = MediaQuery.of(context).size.width >= 700;
  if (!wide) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MapViewerScreen(
          points: points,
          title: title,
          numbered: numbered,
          connect: connect,
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(TravleTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: TravleTokens.space16),
                TravleMapView(
                  points: points,
                  height: 480,
                  numbered: numbered,
                  connect: connect,
                  interactive: true,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Fullscreen zoomable map — the narrow-screen presentation of [showTravleMap].
class _MapViewerScreen extends StatelessWidget {
  const _MapViewerScreen({
    required this.points,
    required this.title,
    required this.numbered,
    required this.connect,
  });

  final List<MapPoint> points;
  final String title;
  final bool numbered;
  final bool connect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: LayoutBuilder(
        builder: (context, constraints) => TravleMapView(
          points: points,
          height: constraints.maxHeight,
          numbered: numbered,
          connect: connect,
          interactive: true,
          decorated: false,
        ),
      ),
    );
  }
}

/// The "tap to expand" pill shown on an expandable inline map.
class _ExpandHint extends StatelessWidget {
  const _ExpandHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TravleTokens.space8,
        vertical: TravleTokens.space4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.open_in_full,
              size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space4),
          Text('Tap to expand',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
