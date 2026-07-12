# 08 — UI Design System & Theming (both Flutter apps)

Covers: when theming happens, design tokens, how Flutter theming actually works (translated from Angular habits), the shared `travle_ui` package, the widget catalogue, and the concrete build order. UI language: English. Course UI rules from `01 §K` apply to everything here.

## 1. When this happens

**Tokens, theme, and the shared package are Phase 0 work** — defining them costs an hour at scaffold time and a week if retrofitted after twenty screens exist. Screens start *consuming* the system in Phase 2 (desktop CRUD backbone) and Phase 3 (mobile). Standing rule from then on: **screens never hardcode colors or text styles** — everything reads the theme. Phase 11 enforces it with a grep: `Colors\.` and `TextStyle(` outside `travle_ui` should return (near) zero hits.

## 2. Design tokens — PASTE YOUR PALETTE HERE

Fill the hex values once; everything else derives from this table. (Slots follow Material 3's `ColorScheme` naming so wiring is mechanical.)

| Token | Hex | Used for |
|---|---|---|
| `primary` | `#______` | app bars, primary buttons, active nav item, selected chips |
| `onPrimary` | `#______` | text/icons on primary |
| `secondary` | `#______` | secondary actions, accents |
| `surface` | `#______` | cards, dialogs, sheets |
| `background` | `#______` | screen background |
| `error` | `#______` | validation text, destructive actions |
| `success` | `#______` | Confirmed pill, success snackbars |
| `warning` | `#______` | Pending pill, hold-countdown hints |
| `info` | `#______` | Completed pill, informational banners |
| `neutral` | `#______` | Expired/disabled states, dividers, muted text |

Status-pill mapping (fixed): Pending → `warning` · Confirmed → `success` · Completed → `info` · Cancelled → `error` · Expired → `neutral` · PaymentInProgress → `neutral` (rarely user-visible).

Non-color tokens: spacing scale **4 / 8 / 12 / 16 / 24 / 32**; corner radius **12** (cards, dialogs, inputs), **999** (chips, pills); one type ramp via `TextTheme` (display/title/body/label) — no ad-hoc font sizes.

## 3. How theming works in Flutter (the Angular translation)

- **`ThemeData` is your global stylesheet.** It carries a `ColorScheme` (semantic slots — think CSS variables, not literal colors), a `TextTheme`, and **component themes**: `ElevatedButtonThemeData`, `InputDecorationTheme`, `CardThemeData`, `ChipThemeData`, `DialogThemeData`, `DataTableThemeData`, `SnackBarThemeData`… Configure these once and every *standard* widget in the app picks the styling up automatically.
- **The mindset shift from Angular:** in Angular you often built a styled component to standardize a button. In Flutter you *don't wrap widgets to restyle them* — you configure the component theme and keep using the stock `ElevatedButton`. Custom widgets are for **structure and behavior** (a status pill, a paginated table), not for re-skinning primitives.
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

Path dependencies inside one repo are standard Flutter monorepo practice and work fine in `flutter build apk/windows --release`. **Placement rule:** tokens/theme + widgets used by *both* apps → `travle_ui`; app-specific composites (a mobile destination card, the desktop sidebar) → that app's own `widgets/` folder. Acceptable fallback if the package ever feels heavy: per-app `widgets/` folders only — but the package is the direct analogue of your Angular setup, keeps DRY across the two apps, and costs ~10 minutes to create.

## 5. Widget catalogue (each maps to a course rule)

**Shared — `travle_ui/widgets`:**
`StatusPill(status)` (fixed color mapping from §2) · `RatingStars(value, count)` · `ConfirmDialog` (required for every irreversible action: delete, pay, cancel) · `TravleImage(bytes)` (memoized `Uint8List` decode + placeholder — never decode in `build()`, Dodatak A.2) · `EmptyState(message, hint)` · `LoadingOverlay` · `AppSnackbars.success/error` (meaningful messages, never bare "Success") · `FormFieldWrapper` (renders validation text **below** the control) · `DisableableButton(onPressed, disabledReason)` (disabled state always explains why) · `SectionHeader`.

**Desktop-only — `travle_desktop/widgets`:**
`SideNavShell` (green sidebar layout from the mockups) · `PaginatedSearchTable` (search row + server-side pagination + image column for image-bearing entities + per-row actions honoring `disabledReason`) · `CrudFormDialog` (X close top-right, Back, aligned two-column label/value layout, images ≤50% of the form) · `MapCoordinatePicker` (flutter_map modal — coordinates are never raw textboxes) · `PdfReportBar` (download + print actions).

**Mobile-only — `travle_mobile/widgets`:**
`BottomNavShell` · `DestinationCard` / `TourCard` (thumbnail, name, location, rating) · `ReasonBanner` (italic recommendation-reason line) · `FilterChipsRow` + bottom-sheet pickers (DB-fed) · `ScheduleChipPicker` · `PeopleStepper` (capped at free seats) · `PriceSummary` (server-quoted values only) · `NotificationBell` (unread badge).

No "widget gallery" screen in the final build — the course removes points for controls without real functionality; develop widgets directly against their first consuming screen.

## 6. Concrete build order (the Phase 0 UI slice)

1. Paste the palette into §2 of this file (single source of truth for hex values).
2. `flutter create --template=package travle_ui`; add the path dependency to both apps.
3. Write `tokens.dart` → `TravleColors` ThemeExtension → `buildTravleTheme()` with the component themes from §3; set it as `theme:` in both `MaterialApp`s (desktop adds compact density).
4. Build the **shared** widgets from §5 as their first consumer screens appear (Phase 2 desktop table/forms, Phase 3 mobile cards) — never speculatively.
5. From Phase 2 onward: no `Colors.*`, no inline `TextStyle(...)`, no hex literals outside `travle_ui`. Phase 11 greps for violations.

## 7. Course-rule tie-ins (why these widgets exist)

Readability / no garish colors → tokens + component themes enforce one palette. X close on forms → `CrudFormDialog`. Validation below controls → `FormFieldWrapper`. Confirmation for irreversible actions → `ConfirmDialog`. Disabled actions show the reason → `DisableableButton` / table actions. Images in lists for image-bearing entities → `PaginatedSearchTable` image column + cards. Images ≤50% of a form → `CrudFormDialog` layout. Dropdowns/date pickers/map pickers instead of textboxes → `FilterChipsRow`, pickers, `MapCoordinatePicker`. Back everywhere → both shells. Meaningful success messages → `AppSnackbars`.
