import 'dart:async';

/// Runs an app's `main` [body] inside a [Zone] that hardens the app against two
/// flutter_map quirks we can't fix in the package itself:
///
///  1. **Console noise.** flutter_map prints a debug-only OpenStreetMap
///     tile-usage notice via a raw `print()` for any OSM tile URL, with no
///     opt-out flag (and being `print`, not `debugPrint`, a `debugPrint` override
///     won't catch it). We have reviewed the OSM tile policy and set a proper
///     `User-Agent` (`kTravleMapUserAgent`), so the notice is pure noise — the
///     zone's `print` handler drops just that one message.
///
///  2. **A known crash.** During a fast zoom gesture flutter_map can drive the
///     camera through a transient invalid zoom; its tile-range math then does
///     `camera.size / (scale * 2)` → `Infinity`, and `Infinity.floor().toInt()`
///     throws `Unsupported operation: Infinity or NaN toInt`
///     (`DiscreteTileRange.fromPixelBounds`). It is thrown inside flutter_map's
///     internal async tile-update stream — no widget `try/catch` can reach it —
///     but it *does* propagate through this zone, so the `handleUncaughtError`
///     handler swallows that one specific error (it is transient: the next frame
///     recomputes tiles from a valid camera). Every other error is delegated to
///     the parent zone untouched, so real failures still surface normally. We
///     also reduce how often it fires by disabling the double-tap-zoom and fling
///     gestures (see `kTravleMapInteractiveFlags`).
///
/// The **whole** of `main` must run inside the zone (bindings + `runApp`), so the
/// Flutter binding is initialised in the same zone `runApp` runs in — otherwise
/// Flutter raises a "zone mismatch" assertion. Hence this takes the entire main
/// body as a callback:
///
/// ```dart
/// void main() => runTravleApp(() {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(const MyApp());
/// });
/// ```
void runTravleApp(void Function() body) {
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (line.contains('keep OpenStreetMap available')) return;
        parent.print(zone, line);
      },
      handleUncaughtError: (self, parent, zone, error, stackTrace) {
        if (_isFlutterMapTileRangeGlitch(error, stackTrace)) {
          if (!_warnedMapTileGlitch) {
            _warnedMapTileGlitch = true;
            parent.print(
              zone,
              '[travle] Swallowed a known transient flutter_map tile-range error '
              'during a fast map zoom (recovers next frame). Further occurrences '
              'are silenced.',
            );
          }
          return;
        }
        parent.handleUncaughtError(zone, error, stackTrace);
      },
    ),
  );
}

bool _warnedMapTileGlitch = false;

/// True for the specific `Infinity or NaN toInt` failure that flutter_map throws
/// from its tile-range calculation during a fast zoom. Deliberately narrow — only
/// an [UnsupportedError] whose stack is inside flutter_map — so nothing else is
/// ever swallowed.
bool _isFlutterMapTileRangeGlitch(Object error, StackTrace stackTrace) {
  if (error is! UnsupportedError) return false;
  final stack = stackTrace.toString();
  return stack.contains('flutter_map') && stack.contains('tile_range');
}
