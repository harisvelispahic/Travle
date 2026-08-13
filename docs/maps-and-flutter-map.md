# Maps (flutter_map) — Design and Build Log

Living document for the map feature (destination location picker + read-only destination/tour maps),
built pre-Phase-12 to replace the interim manual latitude/longitude textboxes. Started 2026-08-10.

This file explains **how maps work** across both Flutter apps: the library and tile choice, the shared
widgets, where maps appear, the interaction model, and — importantly — the **caveats and crashes we hit
and how each was resolved**. It is written to be read top-to-bottom by someone who has never seen the
code.

> **Status convention.** Everything here describes behaviour already in code unless marked
> **(planned)**. The build log at the bottom tracks what shipped when.

---

## 1. The mental model

A map in Travle is never a source of truth — it is a **view of coordinates the domain already owns**.
`Destination` has `latitude`/`longitude`; a tour's itinerary (`TourDestinationRef`) already ships each
stop's coordinates and `sortOrder`. So the entire feature is **client-only: no backend change, no
migration, no new endpoint.** Maps render data that already crosses the wire.

There are three jobs:

| Job | Widget | Used by |
|---|---|---|
| **Pick** a coordinate (add/edit) | `MapCoordinatePicker` (via `MapLocationField`) | curator (mobile) + organizer (desktop) destination forms |
| **Show** coordinates (read-only) | `TravleMapView` | destination details, moderation, tour itineraries |
| **Browse** many destinations on a live map | `DestinationMapBrowser` | traveler (mobile) — the Map tab |

Everything lives in the shared **`travle_ui`** package so both apps use one implementation, and the map
library stays an internal detail — screens speak plain `MapCoordinate` / `MapPoint` / `MapMarkerData` /
`MapBounds`, never `LatLng`.

The **browse** job is the one exception to "no backend change": panning the map needs a *light,
bbox-filtered* list of markers, so it has a dedicated endpoint (see §4.3). Pick and show still render data
that already crosses the wire.

---

## 2. Why flutter_map (and not the alternatives)

- **Leaflet** is JavaScript — it can't run natively in a Flutter app. **`flutter_map`** is the
  Flutter-native equivalent: the same model (a raster **tile server** + marker/polyline layers), pure
  Dart, no native plugins, and it runs on **both Android and Windows desktop**.
- **OpenRouteService** is a routing/geocoding API — overkill; we only display, we don't route.
- **google_maps_flutter / Mapbox** need an API key, billing, and don't support Windows desktop well.

flutter_map needs no key and no account. Version: **`flutter_map: ^8.2.1`** (resolves to 8.3.x) +
**`latlong2: ^0.9.1`**, declared in `travle_ui`'s `pubspec.yaml` only.

---

## 3. Tiles: street vs satellite

flutter_map just renders tiles from whatever URL you give a `TileLayer`, so "map vs satellite" is purely
a choice of tile source. Both of ours are **free and keyless**:

| Basemap | Source | URL template | Notes |
|---|---|---|---|
| **Street** (default) | OpenStreetMap standard | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | light, matches the palette |
| **Satellite** | Esri World Imagery | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | note the **`{z}/{y}/{x}`** order, not `{z}/{x}/{y}` |

A small pill (`BasemapToggle`) switches between them by swapping the `TileLayer` URL. All of this is
centralised in the `TravleBasemap` enum (`map_basemap.dart`).

**Attribution is mandatory** under both providers' terms, so it's baked into every map
(`MapAttributionBadge` on the read-only view; a line in the picker's bottom bar) — no screen can forget
it. We also set `userAgentPackageName: 'com.travle.app'` (`kTravleMapUserAgent`) per OSM's fair-use
policy. For a graded student demo at low volume this usage is within policy; a production deployment at
scale would move to self-hosted or commercial tiles.

---

## 4. The shared widgets (`travle_ui/lib/src/widgets/map/`)

- **`map_types.dart`** — `MapCoordinate(lat, lng)`, `MapPoint(lat, lng, label?)`, and (for the browse
  map) `MapMarkerData(id, lat, lng)` + `MapBounds(south, west, north, east)`. The plain-double types every
  screen uses; they hide `latlong2` behind a `toLatLng()` bridge.
- **`map_basemap.dart`** — `TravleBasemap` enum (URLs + attribution + labels), `BasemapToggle`,
  `MapAttributionBadge`, `kTravleMapUserAgent`, `kMaxMapZoom`, and `kTravleMapInteractiveFlags`.
- **`map_pin.dart`** — `MapPin`: a teardrop marker with a **true white outline** and an optional number
  badge (for itinerary order). See §6.1 for why the outline is drawn the way it is.
- **`travle_map_view.dart`** — `TravleMapView`, the read-only map, plus the `showTravleMap` presenter and
  its fullscreen viewer.
- **`map_coordinate_picker.dart`** — the full-screen tap-to-place `MapCoordinatePicker`, the
  `showMapCoordinatePicker` route helper, and **`MapLocationField`** (a `FormField<MapCoordinate>` that
  replaced the old raw textboxes and validates inline).
- **`travle_map_browser.dart`** — `DestinationMapBrowser`, the interactive browse map (§4.3).

### 4.1 `TravleMapView`

Read-only map on a bordered rounded card. One point → a centred pin. Many points → the camera fits all
of them, and with `numbered: true` the pins carry their 1-based order, with `connect: true` a **dashed
connector** joins consecutive stops (a straight display line for a tour itinerary — **not** routed
directions). It re-fits the camera when its `points` change (so the desktop tour-form preview follows
edits live), guarded by an `onMapReady` flag (§6.2).

### 4.2 Interaction model: non-interactive inline, tap to expand

Inline maps embedded in a scrolling page are **non-interactive by default** (`interactive: false`). This
is deliberate: a directly-zoomable map inside a `ListView` fights the page scroll (drag-to-pan vs
drag-to-scroll) and, on desktop, would hijack the mouse wheel from the form.

Instead, an inline map takes an **`onTap`** that opens a full, zoomable map via **`showTravleMap`**,
which is **responsive**:

- **width ≥ 700 (desktop)** → a properly-proportioned **dialog** with an interactive map;
- **narrow (mobile)** → a **fullscreen route** (`_MapViewerScreen`, `decorated: false`, interactive).

A small "Tap to expand" hint sits on expandable previews. The picker itself is fully interactive (you
tap the map to drop/move the pin).

### 4.3 `DestinationMapBrowser` — the browse map (Phase S2)

The mobile **Map tab** is a full-screen, always-interactive map of the approved catalogue. Unlike
`TravleMapView` (a preview of a *known, fixed* set of points), the browser's markers are **discovered by
where you look**, so it is a different widget rather than a flag on the old one:

- It is **model-agnostic**: it takes `List<MapMarkerData>` (`{id, lat, lng}`), a `selectedId`, and three
  callbacks — `onMarkerTap(id)`, `onBackgroundTap()`, and **`onCameraIdle(MapBounds)`**. It never sees a
  destination, so `travle_core` models and flutter_map never meet.
- **`onCameraIdle` is debounced** (~400 ms after the last gesture, plus once on `onMapReady`): each settle
  reads the camera's `visibleBounds`, converts to a plain `MapBounds`, and hands it to the screen — which
  fetches the markers for exactly that box. So panning/zooming re-queries; mid-gesture frames don't.
- The **selected** marker is tinted with `colorScheme.tertiary` and drawn last (on top of overlaps); the
  rest are the usual forest-green `MapPin`. Reuses the same `kTravleMapInteractiveFlags` and basemap
  toggle as every other map.

**The endpoint — `GET /Destinations/map`** (the one backend addition, no migration). It returns a
deliberately light shape, `DestinationMapPinResponse` = `{id, name, lat, lng, categoryName, averageRating,
primaryThumbnail}` — marker + mini-card only, never full image bytes (§8.2 / rule 12). Rules:

- **The bbox is the mandatory search parameter** (`south/west/north/east`, validated for presence + valid
  WGS84 ranges + `south<north`, `west<east`); it filters **in SQL**. Optional `categoryIds` (multi-select,
  any-of) / `minRating` mirror the search filters (the map's filter chips).
- **`minRating` filters on the *computed* rating** — the same suspended-author-excluded value the marker
  shows (`DestinationProjections.WhereMinRating`), **not** the denormalized `AverageRating` column. Both the
  map and the search screen use it, so a "3+ stars" filter can never hide a card that displays 4.0. (The
  denorm column keeps suspended reviewers for the recommender, so it can sit *below* the displayed rating —
  filtering on it was the WYSIWYG bug.)
- **Approved-only**, forced server-side (a caller can't widen it), exactly like the public search.
- **Capped** at `MaxMapPins = 100`, ordered by rating desc so a dense view keeps its best markers; the
  screen shows a "zoom in for more" hint when it receives a full page.
- **No interaction recorded.** The map is a pan-heavy browse surface — writing a `Search` interaction per
  bbox fetch would flood the recommender diary (every pan while a category is selected), so the endpoint
  records nothing; category interest is captured by the text/category **Search** screen instead.

The screen (`travle_mobile/lib/screens/map_browse_screen.dart`) owns the fetch (guarded by a request-id so
out-of-order responses from fast panning are dropped), the Category/Rating filter chips (same bottom-sheet
pattern as Search), a top status pill (loading / error-retry / empty / capped), and the tap-through **mini
card** (thumbnail + name + category + rating → destination details).

---

## 5. Where maps appear (the surface)

| Surface | Widget | App / role |
|---|---|---|
| Destination submit/edit form | `MapLocationField` → `MapCoordinatePicker` | curator (mobile), organizer (desktop) |
| Destination details → location panel | `TravleMapView` (1 pin, tap-to-expand) | traveler (mobile) |
| Moderation card → "View on map" button | `showTravleMap` (1 pin) | admin (desktop) |
| Tour details → itinerary | `TravleMapView` (numbered + connector, tap-to-expand) | traveler (mobile) |
| Tour create/edit → itinerary preview | `TravleMapView` (numbered + connector, live, tap-to-expand) | organizer (desktop) |
| **Map tab** → browse approved catalogue | `DestinationMapBrowser` (many markers, bbox fetch, mini card) | traveler (mobile) |

The desktop Destinations list uses an **on-demand button** rather than an inline map per row: rendering
a map in every card made the list lag at ~10 rows and squished the map to a ~1:4 aspect.

---

## 6. Caveats & problems we hit (the war stories)

Six real issues surfaced during device testing. Each is resolved; they're recorded here so nobody
re-discovers them.

### 6.1 Pins invisible on satellite → **white outline** (done)

The forest-green pin blends into grass/trees on satellite imagery. **First attempt** — a larger white
pin drawn *behind* the green one — looked like two overlapping pins. **Fix:** render the *same*
`location_on` glyph twice at the *same* size — once **stroked** in white (`Paint..style = stroke`), once
filled green on top — so the white hugs the pin's edge as a real border. (This also fixed §6.3.)

### 6.2 Occasional red-screen flash → **`onMapReady` gate** (done)

`TravleMapView` re-fits the camera in `didUpdateWidget` when its points change. Calling
`MapController.fitCamera`/`move` **before the map's first layout completes** throws (it recovers next
frame, hence a *flash*). Fixed by gating every camera move behind a `_mapReady` flag set from
`MapOptions.onMapReady`.

### 6.3 "Ghost" pin left behind while panning → **no blurred shadow** (done)

The pin originally had a blurred drop `Shadow`. A blur paints **outside** the marker's declared bounds,
so when the map panned, Flutter's dirty-region tracking never repainted those stale pixels → a lingering
phantom pin. Removing the blur (the §6.1 outline replaces it, entirely within bounds) fixed it.

### 6.4 Zooming in far shows "map data not available" → **zoom cap** (done)

Past a certain depth the tile servers (Esri especially, in rural areas) return placeholder "no imagery"
tiles. Fixed with `maxZoom: kMaxMapZoom` (**18**) + `minZoom: 3` on `MapOptions`, so the camera stops
before it reaches missing-tile territory.

### 6.5 Fast zoom **crashes the app** (NaN / OOM) → **swallow at the zone + tame gestures** (done)

Fast zooming — double-tap first, but later **plain pinch-zoom and even a basemap toggle** — crashed with
`Unsupported operation: Infinity or NaN toInt` in flutter_map's `DiscreteTileRange.fromPixelBounds`
(`_onTileUpdateEvent`), and sometimes an **Out-of-Memory** red screen. It is **intermittent / cold-start**:
it tends to hit in the first interactions and then not reproduce.

**Root cause** (in `tile_range_calculator.dart`): the visible pixel bounds are
`halfSize = camera.size / (scale * 2)`, where `scale = camera.getZoomScale(viewingZoom, tileZoom)`. When a
fast gesture drives the camera through a **transient invalid/near-zero zoom**, `scale` collapses and
`camera.size / (scale*2)` blows up to **Infinity** → `Infinity.floor().toInt()` throws. When it comes out
**huge-but-finite** instead, flutter_map allocates a giant tile grid → OOM. Same underlying glitch, two
faces. It's thrown inside flutter_map's **internal async tile-update stream**, so no widget `try/catch` can
reach it, and `flutter_map` is already at its latest version.

**Fix — two parts:**
1. **Zone-level safety net (decisive).** The crash propagates through the custom `Zone` we already wrap
   `main` in (§6.6), so `runTravleApp`'s `handleUncaughtError` **swallows this one specific error** — an
   `UnsupportedError` whose stack is inside `flutter_map`/`tile_range` — logs it once, and delegates every
   other error to the parent zone untouched. The glitch is transient (the next frame recomputes tiles from
   a valid camera), so swallowing it costs at most one skipped frame and **makes the crash impossible**.
2. **Tame the gestures (reduce frequency + kill the OOM path).** `kTravleMapInteractiveFlags` =
   `InteractiveFlag.all` minus `rotate`, `doubleTapZoom`, `doubleTapDragZoom`, and **`flingAnimation`**
   (post-release momentum is what overshoots into the extreme zoom behind the OOM). **Pinch-to-zoom, drag,
   and scroll-wheel zoom remain** — the gestures people actually use.

### 6.6 Noisy OSM tile-usage notice in the console → **print-filtering zone** (done)

flutter_map prints a multi-line "keep OpenStreetMap available…" notice for any OSM tile URL, in debug
mode, via a raw `print()` with **no opt-out flag** (and being `print`, not `debugPrint`, a `debugPrint`
override won't catch it). It is purely informational — we've reviewed the policy and set a proper
`User-Agent`. Fix: **`runTravleApp`** (in `travle_ui`) wraps each app's `main` in a `Zone` whose `print`
handler drops just that one message and forwards everything else. Wrapping *all* of `main` (bindings +
`runApp`) keeps them in one zone, avoiding a "zone mismatch" assertion.

---

## 7. File map

```
UI/travle_ui/lib/src/
  app_bootstrap.dart                 runTravleApp (print-filtering zone, §6.6)
  widgets/map/
    map_types.dart                   MapCoordinate, MapPoint, MapMarkerData, MapBounds
    map_basemap.dart                 TravleBasemap, BasemapToggle, MapAttributionBadge,
                                     kTravleMapUserAgent, kMaxMapZoom, kTravleMapInteractiveFlags
    map_pin.dart                     MapPin (white-outlined teardrop, optional number)
    travle_map_view.dart             TravleMapView, showTravleMap, _MapViewerScreen, _ExpandHint
    travle_map_browser.dart          DestinationMapBrowser (browse map, §4.3)
    map_coordinate_picker.dart       MapCoordinatePicker, showMapCoordinatePicker, MapLocationField

UI/travle_mobile/lib/main.dart                        wrapped in runTravleApp
UI/travle_desktop/lib/main.dart                       wrapped in runTravleApp
UI/travle_mobile/lib/screens/profile/destination_form_screen.dart   MapLocationField
UI/travle_desktop/lib/screens/destination_form_dialog.dart          MapLocationField
UI/travle_mobile/lib/screens/destination_details_screen.dart        TravleMapView (1 pin)
UI/travle_mobile/lib/screens/tour_details_screen.dart               TravleMapView (itinerary)
UI/travle_mobile/lib/screens/map_browse_screen.dart                 DestinationMapBrowser (Map tab)
UI/travle_mobile/lib/layouts/bottom_nav_shell.dart                  5-tab bar, raised centre Map button
UI/travle_desktop/lib/screens/destinations_moderation_screen.dart   showTravleMap button
UI/travle_desktop/lib/screens/tour_form_dialog.dart                 TravleMapView (live itinerary)

Backend (the browse endpoint):
Backend/Travle.Model/Responses/DestinationMapPinResponse.cs         light marker DTO
Backend/Travle.Model/SearchObjects/DestinationMapSearch.cs          bbox + optional category/rating
Backend/Travle.Services/Validators/DestinationMapSearchValidator.cs bbox validation
Backend/Travle.Services/Projections/DestinationProjections.cs       ProjectToMapPin
Backend/Travle.Services/DestinationService.cs                       GetMapPinsAsync (cap, approved-only)
Backend/Travle.WebAPI/Controllers/DestinationsController.cs         GET /Destinations/map
```

---

## 8. Build log

- **2026-08-10** — Feature built: `flutter_map`/`latlong2` added to `travle_ui`; `MapCoordinatePicker` +
  `MapLocationField` replace the manual textboxes in both destination forms (clears the last violation of
  constraint K); `TravleMapView` added to destination details, desktop moderation, and both tour
  itineraries; doc-08 widget catalogue updated. Decisions (user): standard OSM street + Esri satellite;
  numbered pins + dashed connector; geocoding search + dedicated browse-map screen left as stretch.
- **2026-08-10** — Device-test fixes: white-outline pin (§6.1, §6.3), `onMapReady` gate (§6.2), zoom cap
  (§6.4), inline maps became tap-to-expand with responsive `showTravleMap` (§4.2), double-tap-zoom crash
  worked around (§6.5), OSM console notice silenced (§6.6).
- **2026-08-11 — Phase S2, browse map (§4.3).** Added `DestinationMapBrowser` + `MapMarkerData` /
  `MapBounds`; the mobile nav gained a **5th, dead-centre, raised Map tab** (custom bottom bar so the
  lifted forest-green circle sits cleanly, no Material indicator behind it). One backend addition, no
  migration: `GET /Destinations/map` (light `DestinationMapPinResponse`, bbox mandatory + validated,
  approved-only, capped at 100, category filter feeds the recommender). Decisions (user): raised centre
  button; Category + rating filter chips on the map. Analyzer-clean across all three packages + backend
  builds clean; **not yet device-tested.**
- **2026-08-12 — S2 filter fixes (device feedback).** (1) The rating filter compared against the
  *denormalized* `AverageRating` (which keeps suspended reviewers) while the card shows the *computed*
  rating (which drops them), so e.g. Baščaršija displayed 4.0 yet vanished at "3+". Both the map and the
  public search now filter via `DestinationProjections.WhereMinRating` (computed rating), so filter =
  display. (2) Category chips became **multi-select** (`categoryIds`, any-of; checkbox sheet + Apply).
  (3) Removed the per-fetch `Search` interaction write from the map (it fired on every pan while a category
  was selected — recommender-diary flooding). (4) Basemap toggle on the browse map is now an icon-only
  **vertical** strip (shared `BasemapToggle` gained `direction` + `showLabels`), so it clears the centred
  status pill. Backend compiles; all three packages analyzer-clean; not yet device-tested.

- **2026-08-13 — S5 destination search on the browse map.** The parked "geocoding search in the picker"
  idea was reinterpreted (user) into an in-app **destination search on the S2 browse map** — more useful,
  and with **no external geocoder**. A read-only "Search destinations" bar pinned below the map opens a
  full-screen `DestinationSearchPickerScreen` that reuses the exact S4 typeahead (`GET /Destinations/suggest`,
  min 2 chars / 300 ms debounce / seq-guard / city·category rows) but returns the pick via `Navigator.pop`.
  On pick, `MapBrowseScreen._goToDestination` fetches `getDetail` (for coordinates + card fields), injects
  the pin so its mini card shows before the bounds fetch lands, **clears the active category/rating filters**
  (explicit "take me here" → the recentre's bounds fetch re-includes it with its neighbours), then recentres
  via a new design-system handle **`DestinationMapController`** (speaks `MapCoordinate`, keeps flutter_map
  hidden per doc 08 §5) wired into `DestinationMapBrowser` (attach/detach + `_moveTo` → `MapController.move`,
  whose `onPositionChanged` drives the refetch). No backend change, no migration. Side effect: `getDetail`
  logs a `View` (approved, not-own) — a defensible signal for a deliberate jump. travle_ui + travle_mobile
  analyzer-clean; **not yet device-tested.**

## 9. Not built (stretch, post-Phase-12)

- **Geocoding / address search** in the **coordinate picker** (type a place → jump the pin, via
  Nominatim/Photon) stays unbuilt and is now **superseded** by S5's in-app destination search on the browse
  map (above). The picker's tap-to-place is sufficient for the constraint.
