# 08 — UI Design System & Theming (both Flutter apps)

Covers: when theming happens, design tokens, how Flutter theming actually works (translated from Angular habits), the shared `travle_ui` package, the widget catalogue, and the concrete build order. UI language: English. Course UI rules from `01 §K` apply to everything here.

## 1. When this happens

**Tokens, theme, and the shared package are Phase 0 work** — defining them costs an hour at scaffold time and a week if retrofitted after twenty screens exist. Screens start _consuming_ the system in Phase 2 (desktop CRUD backbone) and Phase 3 (mobile). Standing rule from then on: **screens never hardcode colors or text styles** — everything reads the theme. Phase 11 enforces it with a grep: `Colors\.` and `TextStyle(` outside `travle_ui` should return (near) zero hits.

## 2. Design tokens — PASTE YOUR PALETTE HERE

Fill the hex values once; everything else derives from this table. (Slots follow Material 3's `ColorScheme` naming so wiring is mechanical.)

| Token        | Hex       | Used for                                                       |
| ------------ | --------- | -------------------------------------------------------------- |
| `primary`    | `#______` | app bars, primary buttons, active nav item, selected chips     |
| `onPrimary`  | `#______` | text/icons on primary                                          |
| `secondary`  | `#______` | secondary actions, accents                                     |
| `surface`    | `#______` | cards, dialogs, sheets                                         |
| `background` | `#______` | screen background                                              |
| `error`      | `#______` | validation text, destructive actions                           |
| `success`    | `#______` | Confirmed pill, success snackbars                              |
| `warning`    | `#______` | Pending pill, hold-countdown hints                             |
| `info`       | `#______` | Featured badge, informational banners                          |
| `neutral`    | `#______` | Expired/disabled states, dividers, muted text                  |
| `completed`  | `#5AFFFF` | Completed pill (on-color = `#000000` — far too light to carry white) |

Status-pill mapping (fixed): Pending → `warning` · Confirmed → `success` · Completed → `completed` · Cancelled → `error` · Expired → `neutral` · PaymentInProgress → `warning`.

Non-color tokens: spacing scale **4 / 8 / 12 / 16 / 24 / 32**; corner radius **12** (cards, dialogs, inputs), **999** (chips, pills); one type ramp via `TextTheme` (display/title/body/label) — no ad-hoc font sizes.

## 3. How theming works in Flutter (the Angular translation)

- **`ThemeData` is your global stylesheet.** It carries a `ColorScheme` (semantic slots — think CSS variables, not literal colors), a `TextTheme`, and **component themes**: `ElevatedButtonThemeData`, `InputDecorationTheme`, `CardThemeData`, `ChipThemeData`, `DialogThemeData`, `DataTableThemeData`, `SnackBarThemeData`… Configure these once and every _standard_ widget in the app picks the styling up automatically.
- **The mindset shift from Angular:** in Angular you often built a styled component to standardize a button. In Flutter you _don't wrap widgets to restyle them_ — you configure the component theme and keep using the stock `ElevatedButton`. Custom widgets are for **structure and behavior** (a status pill, a paginated table), not for re-skinning primitives.
- **`ThemeExtension`** covers tokens `ColorScheme` doesn't have (success/warning/info, spacing). You define a `TravleColors` extension class and read it anywhere via `Theme.of(context).extension<TravleColors>()!` — typed, autocompleted, no magic strings.
- **Desktop vs mobile:** same tokens, same `buildTravleTheme()`; the desktop app additionally sets `visualDensity: VisualDensity.compact` and uses a different layout shell (sidebar vs bottom nav). One design language, two densities.

## 4. Your own UI library — yes: the `travle_ui` package

Your Angular shared-components module maps directly to a **local Dart package**, path-referenced by both apps:

```
UI/
├── travle_ui/                        flutter create --template=package travle_ui
│   └── lib/
│       ├── travle_ui.dart            barrel export
│       ├── theme/
│       │   ├── tokens.dart           the §2 values as consts
│       │   ├── travle_colors.dart    ThemeExtension (success/warning/info/neutral, spacing)
│       │   └── travle_theme.dart     buildTravleTheme() → ThemeData incl. component themes
│       └── widgets/                  shared widgets (see §5)
├── travle_mobile/                    pubspec: travle_ui: { path: ../travle_ui }
└── travle_desktop/                   pubspec: travle_ui: { path: ../travle_ui }
```

Path dependencies inside one repo are standard Flutter monorepo practice and work fine in `flutter build apk/windows --release`. **Placement rule:** tokens/theme + widgets used by _both_ apps → `travle_ui`; app-specific composites (a mobile destination card, the desktop sidebar) → that app's own `widgets/` folder. Acceptable fallback if the package ever feels heavy: per-app `widgets/` folders only — but the package is the direct analogue of your Angular setup, keeps DRY across the two apps, and costs ~10 minutes to create.

## 5. Widget catalogue (each maps to a course rule)

**Shared — `travle_ui/widgets`:**
`StatusPill(status)` (fixed color mapping from §2) · `RatingStars(value, count)` · `ConfirmDialog` (required for every irreversible action: delete, pay, cancel) · `showReasonDialog(...)` (the single "why?" prompt behind every destructive decision — reject a booking/application, remove a review, suspend a user, call off a schedule; owns its controller, returns null on dismissal so a back-out is never mistaken for an empty reason) · `TravleImage(bytes)` (memoized `Uint8List` decode + placeholder — never decode in `build()`, Dodatak A.2) · `EmptyState(message, hint)` · `LoadingOverlay` · `AppSnackbars.success/error` (meaningful messages, never bare "Success") · `FormFieldWrapper` (renders validation text **below** the control) · `DisableableButton(onPressed, disabledReason)` (disabled state always explains why) · `SectionHeader` · `MapCoordinatePicker` + `MapLocationField` (flutter_map tap-to-place modal replacing raw coordinate textboxes, constraint K) · `TravleMapView` (read-only map — one pin for a destination, or numbered pins + dashed connector for a tour itinerary; street ⇄ satellite toggle) · `LocationCascadeField(depth)` (Country → Region → City, or → Region; each level a real `FormField` so validation lands under its own control, children disabled-with-reason until their parent is picked — see §5a) · `showMultiSelectSheet` + `multiSelectChipLabel` (the checkbox bottom sheet behind every "any of these" mobile filter, plus the matching chip label: the filter name, the single pick's name, or a count).

**Desktop-only — `travle_desktop/widgets`:**
`SideNavShell` (green sidebar layout from the mockups) · `PaginatedSearchTable` (search row + server-side pagination + image column for image-bearing entities + per-row actions honoring `disabledReason`) · `PagerBar` (the "Page 2 of 7 · 63 total" + prev/next footer, extracted from `PaginatedSearchTable` so every card-based list — bookings, moderation queues, tours, role requests, the notification centre, the itinerary picker — pages identically) · `CrudFormDialog` (X close top-right, Back, aligned two-column label/value layout, images ≤50% of the form) · `PdfReportBar` (download + print actions).

**Mobile-only — `travle_mobile/widgets`:**
`BottomNavShell` · `DestinationCard` / `TourCard` (thumbnail, name, location, rating) · `ReasonBanner` (italic recommendation-reason line) · `FilterChipsRow` + bottom-sheet pickers (DB-fed) · `ScheduleChipPicker` · `PeopleStepper` (capped at free seats) · `PriceSummary` (server-quoted values only) · `NotificationBell` (unread badge).

No "widget gallery" screen in the final build — the course removes points for controls without real functionality; develop widgets directly against their first consuming screen.

## 5a. Cross-cutting rules for lists, pickers and dialogs

**Long lists page on desktop and scroll infinitely on mobile.** Every list endpoint is paged server-side, so no screen may fetch "a big enough page" and call it done — a `pageSize: 50` list is not a short list, it is a list that silently ends at 50. Desktop uses `PagerBar` (20 rows for card lists and tables, 30 for the notification centre); mobile appends the next page near the end of the scroll and shows a trailing spinner (canonical implementations: `search_screen`, `favorites_screen`). A list nested inside a detail page's own scroll does neither: it shows a capped preview (10) with a "Show all N" button onto a dedicated, infinitely-scrolled screen, because an infinite scroll inside an outer scroll fights the user and a long inline list buries everything under it. Filters and searches always reset to page 1 and filter **server-side** — never fetch one page and `where()` it in memory, which caps the result at whatever that page happened to hold. `includeTotalCount: true` is what lets a pager say "Page 2 of 7"; without it it degrades to "there is probably more".

**Every location input is a cascade, never a flat list.** The seeded reference geography spans ~200 countries and 600+ cities, so a single page of options (`pageSize` ≤ 100) doesn't merely bury the right row — it makes most rows unreachable. So: pick a place by narrowing (`LocationCascadeField` in both apps; `CrudField.dependsOn` in the desktop reference forms; a `ReferenceFilter.grandparent` above a reference table's parent filter). Map pickers are exempt — they answer "where exactly", not "which reference row".

_The country level is itself over the cap._ ~190 seeded countries against a 100-row page means one `get()` returns barely half of them, so every country picker goes through `CountryProvider.getAll()`, which pages until exhausted. Regions and cities are always scoped to a parent and fit one page.

_Gotcha when wiring one by hand:_ `DropdownButton` asserts that exactly one of its items carries its value, and there are two easy ways to break that. A **truncated options list** is one — a field prefilled from an entity whose option fell off page 1 (this is what crashed the mobile destination form: a city sorted past the hundredth alphabetically). A `DropdownButtonFormField` reading `initialValue` **once** is the other, so clearing a child's selection from the parent's `onChanged` leaves the field holding a value the reloaded items no longer contain. Either give the child a `ValueKey` derived from the parent's value (forcing a fresh `FormField`), or swap it for a non-`FormField` spinner while the reload is in flight, as `CrudFormDialog` does.

**Every dialog closes three ways:** its Cancel/Back button, the Escape key, and a click on the barrier. Escape and the barrier are the same switch — `showDialog`'s `barrierDismissible` (default `true`), which routes through `Navigator.maybePop` — so never pass `barrierDismissible: false`. To protect an in-flight save, wrap the dialog body in `PopScope(canPop: !busy)`: that blocks Escape and the barrier while the request is away, and the Cancel/X buttons already disable themselves on the same flag.

_Gotcha — a dialog's `TextEditingController` must be owned by a `State`._ `showDialog`'s future completes **synchronously** when the route is popped, while the dialog is still animating out with a live `EditableText`, so `showDialog(...).whenComplete(controller.dispose)` disposes the controller out from under the field and throws _"A TextEditingController was used after being disposed"_ — surfacing in the running app as a duplicate `_OverlayEntryWidgetState` GlobalKey cascade. It fires only when the field still holds focus, i.e. precisely the Escape and barrier paths (tapping a button moves focus off the field first), which is what makes it look like a dismissal bug rather than a lifetime bug. Make the dialog a `StatefulWidget` and dispose in `State.dispose` — or just call `showReasonDialog`, which every destructive "why?" prompt now shares (`travle_desktop/test/reason_dialog_test.dart` locks the behaviour down).

## 6. Concrete build order (the Phase 0 UI slice)

1. Paste the palette into §2 of this file (single source of truth for hex values).
2. `flutter create --template=package travle_ui`; add the path dependency to both apps.
3. Write `tokens.dart` → `TravleColors` ThemeExtension → `buildTravleTheme()` with the component themes from §3; set it as `theme:` in both `MaterialApp`s (desktop adds compact density).
4. Build the **shared** widgets from §5 as their first consumer screens appear (Phase 2 desktop table/forms, Phase 3 mobile cards) — never speculatively.
5. From Phase 2 onward: no `Colors.*`, no inline `TextStyle(...)`, no hex literals outside `travle_ui`. Phase 11 greps for violations.

## 7. Course-rule tie-ins (why these widgets exist)

Readability / no garish colors → tokens + component themes enforce one palette. X close on forms → `CrudFormDialog`. Validation below controls → `FormFieldWrapper`. Confirmation for irreversible actions → `ConfirmDialog`. Disabled actions show the reason → `DisableableButton` / table actions. Images in lists for image-bearing entities → `PaginatedSearchTable` image column + cards. Images ≤50% of a form → `CrudFormDialog` layout. Dropdowns/date pickers/map pickers instead of textboxes → `FilterChipsRow`, pickers, `MapCoordinatePicker`. Back everywhere → both shells. Meaningful success messages → `AppSnackbars`.
