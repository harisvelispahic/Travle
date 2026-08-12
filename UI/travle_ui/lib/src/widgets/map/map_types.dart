import 'package:latlong2/latlong.dart';

/// A geographic coordinate in plain doubles. travle_ui's map widgets speak this
/// type (and [MapPoint]) so screens never import flutter_map / latlong2 — the map
/// library stays an implementation detail of the design system (doc 08 §5).
class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Internal bridge to the map library's coordinate type.
  LatLng toLatLng() => LatLng(latitude, longitude);

  /// Human-readable "lat, lng" used in coordinate read-backs.
  @override
  String toString() =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is MapCoordinate &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// A labelled point rendered on a [TravleMapView]. [label] (e.g. a destination
/// name) shows as a tooltip on hover/long-press.
class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

  LatLng toLatLng() => LatLng(latitude, longitude);
}

/// A tappable marker on the interactive browse map (`DestinationMapBrowser`).
/// [id] identifies the marker so the screen can look up its full data when tapped
/// — the widget stays model-agnostic (it never sees the destination itself).
class MapMarkerData {
  const MapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final double latitude;
  final double longitude;

  LatLng toLatLng() => LatLng(latitude, longitude);
}

/// The edges of a map's visible area, in plain WGS84 degrees — the browse map's
/// way of telling a screen which bounding box to fetch, without the screen ever
/// importing flutter_map / latlong2 (doc 08 §5).
class MapBounds {
  const MapBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;
}
