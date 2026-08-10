import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../theme/tokens.dart';

/// The interactive gestures Travle maps enable. Everything except rotation and —
/// deliberately — **double-tap zoom**: rapid double-tap zooming triggers a known
/// flutter_map crash (`Infinity or NaN toInt` in DiscreteTileRange.fromPixelBounds,
/// an unhandled exception in its internal tile-update stream that we can't catch).
/// Pinch-to-zoom and scroll-wheel zoom remain, so nothing real is lost.
const int kTravleMapInteractiveFlags = InteractiveFlag.all &
    ~InteractiveFlag.rotate &
    ~InteractiveFlag.doubleTapZoom &
    ~InteractiveFlag.doubleTapDragZoom;

/// Identifies the app to public tile servers (OSM fair-use policy asks for a
/// non-generic user agent). No key or account is involved.
const String kTravleMapUserAgent = 'com.travle.app';

/// Camera max-zoom cap. Past this the public tile servers (Esri World Imagery
/// especially, in rural areas) start returning "map data not available"
/// placeholder tiles — so the camera stops here rather than letting the user
/// zoom into blank/placeholder territory.
const double kMaxMapZoom = 18;

/// The two base layers a Travle map can show. `street` is the light OpenStreetMap
/// default that suits the palette; `satellite` is Esri World Imagery. Both are
/// free and need no API key. [attribution] is required by their usage terms and is
/// rendered on/under every map so no screen forgets it.
enum TravleBasemap {
  street(
    label: 'Map',
    icon: Icons.map_outlined,
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
  ),
  satellite(
    label: 'Satellite',
    icon: Icons.satellite_alt_outlined,
    // Esri World Imagery serves tiles in {z}/{y}/{x} order (not {z}/{x}/{y}).
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Tiles © Esri — Esri, Maxar, Earthstar Geographics',
  );

  const TravleBasemap({
    required this.label,
    required this.icon,
    required this.urlTemplate,
    required this.attribution,
  });

  final String label;
  final IconData icon;
  final String urlTemplate;
  final String attribution;
}

/// A compact two-segment pill that switches a map between street and satellite
/// tiles. Sits over the top-right corner of the map.
class BasemapToggle extends StatelessWidget {
  const BasemapToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TravleBasemap value;
  final ValueChanged<TravleBasemap> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final basemap in TravleBasemap.values) _segment(theme, basemap),
          ],
        ),
      ),
    );
  }

  Widget _segment(ThemeData theme, TravleBasemap basemap) {
    final selected = basemap == value;
    return InkWell(
      borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      onTap: selected ? null : () => onChanged(basemap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              basemap.icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: TravleTokens.space4),
            Text(
              basemap.label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small attribution notice overlaid on the bottom-right of a map. Kept
/// pointer-transparent so it never eats a map tap.
class MapAttributionBadge extends StatelessWidget {
  const MapAttributionBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        color: Colors.white.withValues(alpha: 0.72),
        child: Text(
          text,
          style: const TextStyle(fontSize: 9, color: Colors.black87),
        ),
      ),
    );
  }
}
