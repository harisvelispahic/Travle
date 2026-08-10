import 'dart:async';

/// Runs an app's `main` [body] with flutter_map's debug-only OpenStreetMap
/// tile-usage notice filtered out of the console.
///
/// flutter_map prints that notice via a raw `print()` for any OSM tile URL and
/// exposes no flag to silence it (and being `print`, not `debugPrint`, it can't be
/// intercepted by a `debugPrint` override). We have reviewed the OSM tile policy
/// and set a proper `User-Agent` (`kTravleMapUserAgent`), so the notice is pure
/// noise. A print-filtering [Zone] drops just that one message and forwards
/// everything else untouched.
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
    ),
  );
}
