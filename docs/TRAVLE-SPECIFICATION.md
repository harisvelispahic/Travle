# Travle — Consolidated Project Specification

> **Platform for discovering destinations and booking tourist experiences**
> Course: Razvoj softvera II, FIT · Student: Haris Velispahić (IB230172)
> Status: **Source of truth**, revision 3 (2026-07-10) — **reconciliation complete, no open items**. Decision history: `00-ANALYSIS-AND-OPEN-QUESTIONS.md`.

---

## 1. Overview

Travle is a **marketplace**: it does not organize tours itself. Organizers offer tours/experiences built on moderated destinations; travelers discover, book, and pay for them; the platform earns a **10% commission** per transaction (bookkeeping only — configured via `PLATFORM_FEE_PERCENTAGE` in `.env` and snapshotted on every payment; no organizer payouts / Stripe Connect). Initial scope: Bosnia and Herzegovina, extensible via the Country → Region → City hierarchy.

| Component | Tech | Users |
|---|---|---|
| REST API + Worker | ASP.NET Core Web API (C#), SQL Server, EF Core Code First, RabbitMQ, SignalR, Stripe, Docker | — |
| Mobile app | Flutter (latest) | Traveler, Curator |
| Desktop app | Flutter Windows (latest) | Organizer, Administrator |

Currency: **BAM** (`bam` in Stripe, displayed "KM", minor units). Database name: **230172**. UI language: **English** (both apps). Time: **UTC** in DB/API/code; converted to local time in the UI for display only.

## 2. Roles and capabilities

### 2.1 Traveler (mobile)
Registration (+ optional skippable onboarding interest picker feeding the recommender), login, profile view/edit (personal data + image), password reset (emailed code via worker). Destination search: text + filters (category, region, rating), list results (thumbnail, name, location, category, rating). Destination details: gallery, description, tags, map, reviews, related tours, favorite toggle, "Similar destinations" section. Favorites for destinations and tours. Tour browsing with schedules and free seats. Booking: schedule + people count, server-side price, refund tiers shown before payment, **in-app Stripe PaymentSheet**. Booking history with status filters; booking details as the **master-detail form**; cancellation with automatic tiered refund. Reviews: destination reviews (any registered user), tour reviews (own Completed booking only). Personalized, **explained** recommendations. Real-time in-app notifications (SignalR): read/unread, mark-as-read, live updates.

### 2.2 Curator (mobile)
Role application (motivation + region) → admin approves/rejects with reason + notification. Adds destinations (name, category dropdown, description, tags, images, map/address location picker) → moderation. "My destinations" by status with rejection reasons. **Any edit of an approved destination returns it to Pending moderation.** Approval/rejection notifications. Does not manage tours, bookings, payments.

### 2.3 Organizer (desktop)
Role application (form + documentation) → admin decision. May add destinations (moderated). Tours: one or more approved destinations (ordered m2m), name, description, duration, price per person, capacity, tour type (FK). Schedules (date/time slots); slot cancellation requires a reason and triggers **automatic 100% refund to every booking on the slot** + notifications. Bookings: view, confirm, or reject with mandatory reason (reject ⇒ 100% refund + notification). Statistics: bookings, revenue, average rating. Reviews of own tours.

### 2.4 Administrator (desktop)
Dashboard (users, active tours, pending requests, monthly revenue, bookings-per-month chart, recent activity). Application + destination moderation (reason mandatory; documents downloadable). Review moderation (soft removal + reason). CRUD for **all reference data** (countries, regions, cities, categories, tour types, tags, statuses, refund tiers...). Featured destinations. All bookings (filters: user/status/period/organizer) and all payments (revenue / commission / refund totals; filters). User management: view + **suspend** (`IsSuspended` + audit fields; blocks login, token refresh, and new activity; revokes refresh tokens; existing Confirmed bookings honored). **Two+ PDF reports**, downloadable and printable: most popular destinations by period; revenue by category/region.

Cut from scope: curator gamification, curator statistics, search autocomplete, "near you", news module. **Stretch (post-Phase-11 only):** dedicated mobile map screen (destinations as markers), desktop SignalR client — defined in `00 §3`.

## 3. Booking system

### 3.1 Structure
Tour ⇢ 1..n Destinations (ordered m2m). Tour ⇢ 1..n Schedules (slots with capacity). Booking = user + schedule + people; total = price-per-person × people, **computed server-side only**.

### 3.2 Lifecycle (centralized state machine — service layer only)

```
[checkout] → PaymentInProgress ──(webhook: payment_intent.succeeded)──→ Pending
                    │ (15-min expiry / payment failed) → Expired (seats released)
Pending   → Confirmed   (organizer confirms; notification)
Pending   → Cancelled   (user cancels → tiered refund; organizer rejects w/ reason → 100%)
Confirmed → Completed   (scheduler, after schedule end time)
Confirmed → Cancelled   (user cancels → tiered refund; organizer cancels slot → 100%)
```

Server-side on every transition: state-machine-only changes, no hard deletes; transactional capacity guard; **schedule-overlap check** (a user cannot hold two active bookings whose time ranges intersect); slot-in-future, tour-active, seats-available preconditions; filtered unique constraint on active (user, schedule); audit trail (who, when, reason); edge-case-correct pricing.

### 3.3 Refund policy (global, final)
User-initiated cancellation: **>72h = 100% · 24–72h = 50% · 1–24h = 25% · <1h = 0%.** Organizer-initiated rejection/slot cancellation: always 100%. Tiers live in seeded `RefundPolicyTiers` reference data (admin CRUD). Refunds execute via the Stripe Refund API against the **actually charged amount** from the Payment record. The applicable tier summary is displayed before payment.

### 3.4 Payment (Stripe sandbox — real, never simulated)
Server creates the PaymentIntent (server-side amount, `bam`); mobile confirms via **PaymentSheet**. Success recorded **only** by the signature-verified webhook; idempotent handling (intent/event-id guards); double-payment prevention; `IsPaid` in DTOs and pay button hidden once paid. Payment rows snapshot amount + `PlatformFeePercentage`/`PlatformFeeAmount`; Refund rows record amount, percentage tier, reason, initiator.

## 4. Recommender (full spec: `claude-context/04-recommender-spec.md`)

Content-based filtering: weighted user profile from **actually recorded** interactions (views, searches, favorites, bookings, high reviews, onboarding interests) matched by cosine similarity against destination feature vectors (category, tags, region); **popularity fallback** for users with <3 weighted interactions. Every recommendation carries a human-readable explanation. Hand-written deterministic scorer in C# (ML.NET has no content-based component — analysis §1.19); storage: on-demand computation + IMemoryCache + `RecommendationLogs` audit of served recommendations. `recommender-dokumentacija.md` ships in the repo and stays in lockstep with the code.

## 5. Notifications

In-app: `Notifications` rows (title, text, timestamp, read/unread, mark-as-read) pushed over **SignalR** to mobile (auto-refresh; manual refresh unacceptable) for **all** relevant events: booking created/confirmed/rejected/cancelled, payment/refund, application decisions, destination moderation decisions, slot cancellations, 24h pre-tour reminder. Desktop client: stretch.
Email (worker): booking confirmation, status changes, application results, refund confirmations, 24h reminders, password-reset codes — consumed from RabbitMQ with retry + exponential backoff (1s→2s→4s→8s) and mandatory error logging.

## 6. Architecture

```
docker-compose.yml
├── api        Travle.WebAPI   (REST, JWT+refresh, SignalR hub, Stripe, recommender, state machine,
│                               RabbitMQ publisher, IHostedService scheduler: 15-min expiry /
│                               auto-Complete / 24h reminders)
├── worker     Travle.Worker   (RabbitMQ consumer → SMTP; separate project + Dockerfile + container)
├── rabbitmq   pinned version, management image
└── sqlserver  mcr.microsoft.com/mssql/server:2022-<pinned>
```

All config in `.env` only (RabbitMQ, SMTP, Stripe keys + webhook secret, JWT key, connection string, API URL, `PLATFORM_FEE_PERCENTAGE`). Flutter reads `API_BASE_URL` via `--dart-define`/`String.fromEnvironment` (Android `10.0.2.2`, Windows `localhost`). Layering: `Travle.Model` (DTOs) → `Travle.Services` (entities in `Database/`, per-entity EF configurations, services, `BookingStateMachine`, recommender, validators) → thin `Travle.WebAPI`. Errors via **ExceptionMiddleware + custom exception hierarchy** (02 §3). Entities inherit `BaseEntity { Id, CreatedAt, ModifiedAt? }`. Logout: `POST /Access/Logout` deletes all of the user's refresh tokens (server-side invalidation).

## 7. Database (full design: `claude-context/03-database-design.md`)

17 main tables (minimum 10): Users, RefreshTokens, RoleApplications, Destinations, DestinationImages, Tours, TourSchedules, Bookings, Payments, Refunds, DestinationReviews, TourReviews, Favorites, Notifications, UserInteractions, PasswordResetCodes, RecommendationLogs.
Reference: Countries, Regions, Cities, DestinationCategories, TourTypes, Tags, DestinationTags, TourDestinations (ordered m2m), BookingStatuses, Roles, UserRoles (m2m — multi-role users are expected by the course), RefundPolicyTiers.
All FKs via per-entity `IEntityTypeConfiguration<T>`; reference data as FKs, never strings; NOT NULL mirrored in UI; rich seed with images and full-lifecycle demo data.

## 8. Security & auth (hard rules: `claude-context/01-course-constraints.md`)

JWT + refresh tokens (revoked on logout). `[Authorize]` everywhere; `[AllowAnonymous]` only login/register/reset-request; `[Authorize(Roles=...)]` matching seeded role names; userId from JWT only; register accepts no roles; credentials in POST bodies; upload ownership + MIME/magic-byte checks; PBKDF2/bcrypt/Argon2 hashing; `RandomNumberGenerator` for codes; hashed + expiring reset codes; no dev endpoints in production; `DateTime.UtcNow` everywhere.

## 9. Delivery

Public GitHub repo (.gitignore, full source, `recommender-dokumentacija.md`, README with run steps + credentials: `desktop`/`test`, `mobile`/`test`, `organizer`/`test`, `curator`/`test`). Immutable GitHub Release (draft → `fit-build-20gg-mm-dd.zip` with APK + Windows Release folder → publish); `.env` swapped for password-protected `.env-tajne.zip`; DL gets exact tag link + password. Zero-intervention startup.

## 10. Explicit non-goals

Hard non-goals: Stripe Connect payouts · production hosting/SSL · iOS builds · collaborative filtering · FCM/OS push notifications · chat between users · multi-language UI · curator gamification · news module.
Cut from v1, allowed **only** as post-Phase-11 stretch (defined in `00 §3`): mobile map screen · desktop SignalR client · curator statistics · search autocomplete · "near you".
