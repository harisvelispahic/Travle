# 05 — Implementation Roadmap (rev. 3, final)

Phases ordered by dependency; each ends with its DoD plus the global checklist in `01-course-constraints.md`. All decisions are final; the reconciliation record is `00-ANALYSIS-AND-OPEN-QUESTIONS.md`.

## Phase 0 — Foundation
Adopt template per `06-template-adoption-guide.md` (rename eCommerce→Travle, purge, grep-verify). `Travle.Worker` skeleton + Dockerfile; docker-compose (api, worker, rabbitmq, sqlserver — pinned tags) + `.env`/`.env.example`; configuration bound once. `ExceptionMiddleware` + custom exceptions. `BaseEntity` + `BaseEntityConfiguration<T>`; `TravleDbContext` (timestamps in SaveChanges); DB **230172**; initial migration; seed infra. Flutter apps from Haris's templates (base_provider, auth shell, master layout, `--dart-define`).
**DoD:** `docker compose up` → all four services healthy; migrated empty DB named 230172; both Flutter apps build and reach the API.

## Phase 1 — Auth, users, roles
JWT + refresh (template) + **new `POST /Access/Logout`** deleting all user refresh tokens. Register (no roles from client) + **optional onboarding interests step** (skippable; bulk-writes OnboardingInterest interactions). Login (POST body), PBKDF2/bcrypt hashing, Roles/UserRoles seed matching authorize attributes, profile view/edit (image, MIME+magic bytes), password-change rules per course §4, password reset via emailed hashed+expiring code (RabbitMQ→worker→SMTP). RoleApplications: submit + admin decide (reason, audit, notification).
**DoD:** four seed users log in on the right apps; 401→refresh→login flow works; logout kills refresh tokens; reset email arrives; approving an application grants the role live.

## Phase 2 — Reference data + desktop CRUD backbone
All reference entities (incl. **RefundPolicyTiers**) + configurations + seed. Desktop generic paginated/searchable table + CRUD forms for every reference entity (Country→Region→City chaining); delete-blocked-with-reason UX.
**DoD:** admin CRUDs every reference table; every list searchable + paginated; in-use deletions show the friendly conflict message.

## Phase 3 — Destinations & moderation
Submit (curator mobile / organizer desktop): category dropdown, tags multi-select, images (server thumbnails), **map/address picker**. Moderation queue (approve/reject + reason + notification); featured flag. Curator "my destinations" by status; **edit ⇒ back to Pending**. Search endpoint (text + category/region/rating; writes Search interactions); details endpoint (writes View + ViewCount). Lists ship thumbnails only.
**DoD:** curator→moderation→publish loop end-to-end on devices; interaction rows appear.

## Phase 4 — Tours & schedules
Organizer: tour CRUD (ordered multi-destination picker, price, capacity, TourTypeId), schedule management, slot-cancel stub (refunds in P6). Mobile: tours on destination details; tour details with schedules + live free seats.
**DoD:** tour with 2+ destinations and future slots visible to travelers with correct seat counts.

## Phase 5 — Bookings & state machine
`BookingStateMachine` (state pattern, DI). Creation with transactional capacity guard (03 §6), duplicate + overlap checks, **15-min `ExpiresAt`**. Organizer confirm/reject (reason, audit, notification). User cancellation (tier math ready; refunds in P6). Scheduler: expire PaymentInProgress @15 min; auto-Complete past Confirmed. Mobile history + **master-detail** details; admin all-bookings view.
**DoD:** all legal transitions pass, all illegal ones throw; parallel-booking hammer can't oversell; audit fields populate; holds expire on time.

## Phase 6 — Payments (Stripe)
PaymentIntent (server amount, `bam`, fee snapshot from `PLATFORM_FEE_PERCENTAGE`); PaymentSheet in Flutter; signature-verified idempotent webhook (PaymentInProgress→Pending); Payment/Refund entities; refunds: user cancel (global tiers), organizer reject (100%), slot cancel (100% batch, transactional). `IsPaid` DTOs; paid-state UI. Admin payments screen (revenue/commission/refund totals + filters).
**DoD:** test-card flow end-to-end; replayed webhook = no double effects; refund lands in Stripe test dashboard at the right tier; second payment attempt blocked.

## Phase 7 — Reviews & favorites
DestinationReviews + TourReviews (own Completed booking, unique per booking); AverageRating recompute; admin soft-removal + reason; favorites toggle/list; ReviewHigh + Favorite interactions.
**DoD:** review gates enforced server-side; ratings roll up; favorites sync.

## Phase 8 — Recommender
Per 04 (Option A + slim C): scoring service, IMemoryCache + invalidation, `GET /recommendations`, `GET /destinations/{id}/similar`, RecommendationLogs on serve, explanations, cold-start (<3), onboarding signals consumed. Home sections: featured / recommended-with-reasons / popular. Write `recommender-dokumentacija.md`.
**DoD:** seeded `mobile` user gets non-trivial explained recommendations on first run; fresh user gets labeled popularity list; onboarding picks visibly shift results; doc matches code on weights/formula.

## Phase 9 — Notifications & real-time
Notifications entity + service (row per relevant event), SignalR hub (JWT, `user-{id}` groups, membership check), **mobile** notification center (read/unread, mark-as-read, live); desktop client is stretch. RabbitMQ publisher hardening (singleton connection); worker consumers for all email types + 24h reminders (email + in-app row); retry/backoff/logging.
**DoD:** booking confirmation pops in-app within a second and lands by email; killing the worker mid-queue loses nothing.

## Phase 10 — User management
Admin user administration (the piece deferred since Phase 1's suspensions). Backend: admin **create user** (`POST /Users`, `AdminOnly`) with any combination of the four roles, an admin-set initial password, and email/username dedupe; **grant/revoke roles** on existing users (`POST`/`DELETE /Users/{id}/Roles`) with guardrails — no removing your own Admin role, no removing the last Admin; every role change revokes the target's refresh tokens (re-auth picks up the new set, mirroring the application-approve path) and notifies them. Read-only `GET /Roles` lookup for the assignment dropdown. **No update-by-admin, no delete** — suspension stays the only removal path (03 §3); no schema change/migration. Desktop: admin **Users** list (avatar thumbnail, name, username, role chips, suspended badge; search by name/role/status; paginated) → detail pane (suspend/unsuspend with reason + role management), **create-user** form (role multi-select); shared read-only `UserDetailCard`. Desktop self-service: the sidebar account tile becomes clickable → **Account** screen (view + edit own profile + change own password), reusing `UserDetailCard`. Fix the `Users` leaf to be admin-only.
**DoD:** an admin creates an account in any role combination and it signs in; granting/revoking a role forces the target's re-auth and lands a notification; self-Admin and last-Admin removals are blocked; suspend/unsuspend unchanged; a desktop organizer/admin edits their own profile and changes their own password.

## Phase 11 — Reports & dashboard
Admin dashboard (metrics + bookings-per-month chart + recent activity). Two PDF reports (popular destinations by period; revenue by category/region) — downloadable + printable; single-GroupBy aggregates. Organizer statistics screen.
**DoD:** PDFs open with real seeded data; aggregates hand-verified once.

## Phase 12 — Hardening pass
Sweep `01-course-constraints.md` section by section: endpoint authorization matrix; pagination caps; N+1 hunt; IMemoryCache on hot reference reads; validation-message audit (both apps); UI-rules audit; greps: template leftovers, `DateTime.Now`, `.Result|.Wait(|GetAwaiter`, empty catch, commented-out code.
**DoD:** every checklist box ticks or has a written justified exception.

## Phase 13 — Packaging & submission
README (run steps + credentials table); `.env-tajne.zip` swap; `flutter clean` + release builds (APK @10.0.2.2 verified via fresh AVD install; Windows exe @localhost); `fit-build-20gg-mm-dd.zip`; enable release immutability → draft → verify → publish; DL: exact tag + password. Cold-machine test: clone → compose up → run builds → exercise every core flow.
**DoD:** a stranger runs everything from the README alone; nothing touched after the deadline.

## Stretch phases (chosen 2026-08-11 — built after Phase 11, before the Phase 12 hardening pass; order fixed)

The map *picker* + inline destination/tour maps already shipped in core scope (see `maps-and-flutter-map.md`); only the browse-map **screen** remains of the map stretch.

### Phase S1 — Desktop real-time (SignalR client) — ✅ DONE 2026-08-11
Desktop connects to the existing notification hub (JWT, `user-{id}` group) reusing `signalr_netcore` + the shared `NotificationProvider`. Desktop notification affordance in `SideNavShell` (bell + unread badge, read/mark-as-read) and **live toasts** for the events a desktop user cares about: organizer booking placed/cancelled; admin role-application submitted + destination submitted (moderation queue). No backend change — hub + Notification rows already exist.
**DoD:** an event raised elsewhere pops a desktop toast within a second and lands in the desktop centre; sign-out tears the connection down; a dropped connection reconnects and loses nothing (rows are the source of truth).
**As-built:** the SignalR connection + bell + badge + centre + detail already existed from Phase 9 (9h); S1 added only the missing **live toasts** — `notification_toast.dart` + a `pushes` subscription in `SideNavShell` (queue max 4, auto-dismiss 6 s, top-right, tap→detail). Analyzer clean; see `notifications-and-signalr.md` build log 2026-08-11. Not device-verified yet.

### Phase S2 — Mobile map browse screen — ✅ DONE 2026-08-11
New **light bbox endpoint** returning only `{id, name, lat, lng, category, rating, thumbnail}` for Approved destinations within the visible bounds (bbox = the mandatory search parameter; capped count; writes a Search interaction). Mobile map tab/screen reusing `TravleMapView`/`MapPin`: markers → tap → mini card → destination details.
**DoD:** the map shows approved destinations as markers; panning refetches by bbox; a marker's mini card opens details; result count is capped.
**As-built:** `GET /Destinations/map` → `DestinationMapPinResponse` (light DTO), `DestinationMapSearch` (bbox mandatory + validated, optional **multi-select** `categoryIds` + `minRating`), `ProjectToMapPin`, `GetMapPinsAsync` (approved-only forced, bbox filtered in SQL, capped at `MaxMapPins = 100`, best-rated first). **`minRating` filters on the computed rating** (`DestinationProjections.WhereMinRating`, suspended authors excluded — same value the card shows), not the denormalized column; the public search's rating filter was moved to the same helper (fixes a WYSIWYG bug where a 4.0 card vanished at "3+"). The map **records no interaction** (a pan-heavy surface would flood the recommender diary — the earlier category-gated write fired on every pan; dropped). A **new** `travle_ui` widget `DestinationMapBrowser` (interactive, debounced `onCameraIdle(MapBounds)` + `onMarkerTap`) rather than overloading the preview-oriented `TravleMapView`; `MapMarkerData`/`MapBounds` added; `BasemapToggle` gained `direction`/`showLabels` (browse map uses a vertical icon-only strip). Mobile `MapBrowseScreen` (request-id-guarded fetch, multi-select Category + rating chips, status pill, tap-through mini card) as a **5th, dead-centre, raised Map tab** in a custom `BottomNavShell` bar. No migration (destinations already carry coordinates). Analyzer-clean (all 3 packages) + backend builds clean; not yet device-tested. Living doc: `maps-and-flutter-map.md` §4.3 + build log. Decisions (user): raised centre button; category+rating chips (category multi-select).

### Phase S3 — Curator statistics (mobile)
Curator-scoped aggregate endpoint (their destinations' view counts, favorites, average rating, counts by moderation status) — single-GroupBy aggregates over curator-owned rows only. Mobile statistics screen mirroring the desktop organizer statistics (fl_chart).
**DoD:** a curator sees real aggregates over their own destinations; numbers hand-verified once; no cross-curator leakage.

### Phase S4 — Search autocomplete
Debounced typeahead on destination search (reuses the search endpoint; min-chars + debounce; DB-level filtering; capped suggestions).
**DoD:** typing shows live suggestions without a manual submit; selecting one opens details/search.

## Later / optional (only if time, see 00 §3): "near you" (needs a runtime geolocation permission); geocoding search in the map picker; onboarding category-card polish (needs `Category.Description`/`Image` + a migration); Stripe CLI compose profile (dev convenience).
