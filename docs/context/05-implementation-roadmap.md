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

## Phase 10 — Reports & dashboard
Admin dashboard (metrics + bookings-per-month chart + recent activity). Two PDF reports (popular destinations by period; revenue by category/region) — downloadable + printable; single-GroupBy aggregates. Organizer statistics screen.
**DoD:** PDFs open with real seeded data; aggregates hand-verified once.

## Phase 11 — Hardening pass
Sweep `01-course-constraints.md` section by section: endpoint authorization matrix; pagination caps; N+1 hunt; IMemoryCache on hot reference reads; validation-message audit (both apps); UI-rules audit; greps: template leftovers, `DateTime.Now`, `.Result|.Wait(|GetAwaiter`, empty catch, commented-out code.
**DoD:** every checklist box ticks or has a written justified exception.

## Phase 12 — Packaging & submission
README (run steps + credentials table); `.env-tajne.zip` swap; `flutter clean` + release builds (APK @10.0.2.2 verified via fresh AVD install; Windows exe @localhost); `fit-build-20gg-mm-dd.zip`; enable release immutability → draft → verify → publish; DL: exact tag + password. Cold-machine test: clone → compose up → run builds → exercise every core flow.
**DoD:** a stranger runs everything from the README alone; nothing touched after the deadline.

## Stretch (only after Phase 11): dedicated mobile map screen (see 00 §3.1), desktop SignalR client, curator statistics, autocomplete.
