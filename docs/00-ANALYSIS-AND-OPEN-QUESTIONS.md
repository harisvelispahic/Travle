# Travle — Document Analysis & Decision Log

> Cross-check of the source documents:
> **A** = Topic application (Prijava) · **B** = Course specification (Upute 2025/26) · **C** = Old draft documentation · **T** = course template repo
>
> **Status: reconciliation COMPLETE (round 2, 2026-07-10). No open questions.** Section 1 = findings with final resolutions. Section 2 = decision log. Section 3 = defined stretch features (post-Phase-11 only). This file stays in the repo as the living reconciliation record — update it, never delete it.

---

## 1. Findings and resolutions

### 1.1 Stripe Checkout vs. in-app payment — RESOLVED
A's mockup said "Stripe checkout"; B §7.1 requires in-app payment. **Final: Stripe PaymentIntents + PaymentSheet (`flutter_stripe`).** Never a browser redirect.

### 1.2 Payment in-flight state — RESOLVED
Booking created in internal `PaymentInProgress` status with a **transactional capacity hold and a 15-minute expiry**; the signature-verified webhook promotes it to `Pending`; the API scheduler expires stale holds and releases seats.

### 1.3 Refund policy — RESOLVED
**Global tiers:** >72h = 100% · 24–72h = 50% · 1–24h = 25% · <1h = 0%, seeded in `RefundPolicyTiers` reference data (admin CRUD). No per-tour policies. Refunds computed from the **actually charged amount**.

### 1.4 Organizer rejects / cancels — RESOLVED
Always **100% refund** (tiers apply only to user-initiated cancellations). Reason mandatory, audited, notified.

### 1.5 `Completed` automation — RESOLVED
API `IHostedService` scheduler promotes past `Confirmed` bookings hourly.

### 1.6 Pre-tour reminder — RESOLVED
24h before departure: email via worker + in-app Notification row (SignalR when connected). No OS push (FCM) — out of scope.

### 1.7 Curator edits approved destination — RESOLVED
**Any edit returns the destination to Pending moderation.**

### 1.8 Scope additions inherited from C — RESOLVED
| # | Feature | Decision |
|---|---|---|
| 1 | Curator gamification badges | Cut |
| 2 | Curator statistics | Cut/Postpone |
| 3 | Per-tour refund policies | Cut (global policy) |
| 4 | Search autocomplete | Cut/Postpone |
| 5 | Dedicated **map screen** (all destinations as markers, Google-Maps-style) | **Feasible, POSTPONED → stretch** (see §3.1) |
| 6 | "Near you" section | Cut/Postpone |
| 7 | News/announcements | Cut/Postpone |
| 8 | "Similar destinations" section on destination details | **KEEP** (item-to-item similarity; works for new users too; reuses recommender feature vectors) |
| 9 | Booking overlap check | Keep (B §7 cites it) |

### 1.9 Images — RESOLVED
byte[] in DB + server thumbnails; lists carry thumbnails only; full images via detail endpoint; Flutter decodes once outside `build()`.

### 1.10 Server-side logout — RESOLVED
Template has refresh flow but no Logout endpoint. Add `POST /Access/Logout` ([Authorize]) → `DeleteAllUserRefreshTokensAsync(userId-from-JWT)`.

### 1.11 Template hygiene — RESOLVED (extended round 3)
Delete: WeatherForecast*, Class1.cs ×2, ClinetException (typo), QueryOptimization demo, full eCommerce domain + migrations, `fit/fit.sqlproj` (SQL DB project, redundant with Code First), `.vscode/` (its only task builds fit.sqlproj via a path hardcoded to the template author's machine), `eCommerce.WebAPI.http` (its only request targets `/weatherforecast/`). Keep: root `.gitignore` (already ignores `*.user` and `*.env`), `Properties/launchSettings.json` (dev profiles, no secrets), Flutter per-project .gitignore/.metadata files. `*.csproj.user` files are per-developer VS state — never committed (gitignored), delete freely if seen. Procedure: `06-template-adoption-guide.md`.

### 1.12 Currency — RESOLVED
Stripe supports **BAM**; charge in `bam`, display "KM", minor units.

### 1.13 Commission — RESOLVED
10% from `PLATFORM_FEE_PERCENTAGE` (.env), snapshotted per Payment. No payouts (no Stripe Connect).

### 1.14 Reviews — RESOLVED
Two tables: `DestinationReviews` (any registered user), `TourReviews` (own Completed booking). Moderation = soft flag + audit.

### 1.15 Real-time — RESOLVED
A promises real-time only on mobile. **v1: backend SignalR hub + mobile client.** Desktop client = stretch (§3.2); the same `signalr_netcore` package runs on Flutter Windows, so it's a cheap later add.

### 1.16 Password reset — RESOLVED
Emailed 6-digit code via worker; `RandomNumberGenerator`, hashed at rest, expiring.

### 1.17 User suspension — RESOLVED
Promised in A (*Administrator → "Upravljanje korisnicima (pregled, suspenzija)"*). **Semantics:** suspension blocks login and any new activity; ongoing/Confirmed bookings are honored. **Flag:** domain-specific `Users.IsSuspended` + audit fields (`SuspendedAt`, `SuspendedByUserId`, `SuspensionReason`) — NOT a generic `IsEnabled` on `BaseEntity` (a base-class flag would imply every entity is toggleable, force hidden filtering everywhere, and leave unused columns on most tables, which B forbids). Suspension also revokes the user's refresh tokens (immediate lockout); login and token refresh both check the flag.

### 1.18 Table count — OK (17 main tables; minimum 10).

### 1.19 Recommender technology — RESOLVED
ML.NET's recommendation support is matrix factorization (collaborative filtering); it has no content-based component, and assembling one from ML.NET text-featurization + a classifier would not implement A's explicitly promised *per-interaction weights* and would make per-recommendation explanations indirect. **Final: hand-written deterministic scorer** (weighted user profile + cosine similarity + popularity fallback) — a known algorithm, literal A parity, explanations derived from the score itself. Full spec + defense notes: `04-recommender-spec.md`.

### 1.20 Multi-role users — RESOLVED
B lists UserRole/Role among expected reference tables; B §5 anticipates multi-role accounts. Keep Users↔Roles m2m; Traveler+Curator share one account.

### 1.21 Entity placement — RESOLVED
Entities in `Travle.Services/Database`, configurations in `Database/Configurations/`. Rationale: 02 §2a.

### 1.22 BaseEntity — RESOLVED
`BaseEntity { Id, CreatedAt, ModifiedAt? }` + `BaseEntityConfiguration<T>`. No `IsDeleted`/`IsEnabled` on the base (see 1.17 and 1.23).

### 1.23 Delete strategy — RESOLVED (hybrid, per entity)
Business-process records (bookings, payments, applications, destinations, reviews): never hard-deleted — statuses/soft flags + audit (B §7). Reference data: hard delete allowed, Restrict-blocked with a human message when in use (B §3.1). No global EF soft-delete query filter. This hybrid is exactly why `BaseEntity` carries no delete/enable flag.

### 1.24 Recommender storage — RESOLVED
**Option A + slim Option C:** only `UserInteractions` persisted as input; profile + scores computed on demand and cached in `IMemoryCache` (~15 min, invalidated on strong interactions); every *served* recommendation logged to `RecommendationLogs` (user, destination, score, reason, timestamp) as an audit trail. Plain-language rationale + defense answer: `04-recommender-spec.md` §4a.

### 1.25 Onboarding interests — RESOLVED (KEEP)
Skippable category/tag picker after registration. Storage: one `UserInteractions` row per pick (`InteractionType = OnboardingInterest`, `Weight = 2`, `CategoryId` or `TagId` set, `DestinationId` null). Consumed by the same scorer as every other signal — so the "collected signals must be used" rule holds by construction. Shrinks (does not replace) the cold-start window; popularity fallback remains for users who skip.

### 1.26 UI language — RESOLVED (round 2)
**Both apps in English**, consistently. Wireframes in `07-mobile-app-structure.md` use English labels.

### 1.27 Time handling — RESOLVED (round 2)
**UTC everywhere:** DB stores UTC, API transfers UTC (ISO 8601), `DateTime.UtcNow` only in code (B Dodatak A.4); Flutter converts to the device's local time **for display only**.

### 1.28 Repository layout — RESOLVED (round 3)
Repo root `travle/` contains `Backend/` (Travle.sln + all .NET projects) and `UI/` (travle_mobile, travle_desktop) as **siblings** — UI moves out of the backend folder where the template nests it. `docker-compose.yml`, `.env` (committed as `.env-tajne.zip`), `README.md` and `recommender-dokumentacija.md` live at the repo root; compose build contexts point into `Backend/`. Nothing in the Upute constrains layout — release-zip paths are arbitrary folder names.

### 1.29 Target framework — RESOLVED (round 4)
**.NET 10 (LTS)** for all backend projects. The template targets net9.0, but .NET 9 is an STS release whose support ended May 2026; .NET 10 is the current LTS (supported to Nov 2028). Cost is near zero because retargeting happens at scaffold time (Phase 0): five one-line `<TargetFramework>` edits, Microsoft.* packages to their 10.x lines, third-party packages to latest, Docker base images `sdk:10.0`/`aspnet:10.0` (authored fresh anyway — the template ships none). Grading runs through Docker, so the runtime is self-contained in the image. While bumping: keep one OpenAPI pipeline (OpenApi + Scalar), drop the template's parallel Swashbuckle — also satisfies the no-duplicate-registration rule.

### 1.30 Per-entity delete matrix — RESOLVED (round 5)
The hybrid policy (02 §6a) is now made concrete per entity in **03 §3**: every main and reference table has an explicit strategy (hard / soft flag / status-only / append-only / no deletion) with conditions.

### 1.31 UI system — RESOLVED (round 5)
Theming happens at **Phase 0**: design tokens + `buildTravleTheme()` + a shared **`travle_ui` local package** (path-referenced by both apps) holding tokens, ThemeExtension, and cross-app widgets; app-specific composites stay per-app. Screens never hardcode colors/text styles (Phase 11 grep enforces). Full system: `08-ui-design-system.md`. Pending input (not a decision): Haris pastes his palette hex values into 08 §2.

## 2. Decision log

Round 1: Q1 hold+15 min · Q2 tiers 100/50/25/0, global · Q3 24h email + in-app · Q4 edits→Pending · Q5 per table 1.8 · Q6 fee from config · Q7 two review tables · Q11 cold-start <3 · Q12 TourTypeId yes · entity placement · logout endpoint · delete policy · BaseEntity · m2m roles.
Round 5: per-entity delete matrix (03 §3) · travle_ui shared package + Phase-0 theming (08).
Round 4: .NET 10 LTS target + package/base-image bumps at Phase 0 · both OpenAPI pipelines kept for now (bumped to latest); consolidation deferred.
Round 3: Backend/UI sibling layout · compose + .env at repo root · template file hygiene extended (.vscode, .http, fit.sqlproj delete; launchSettings, .gitignore keep).
Round 2: Q5.5 map screen → stretch · Q5.8 similar destinations → keep · Q8 SignalR mobile-first, desktop stretch · Q9 semantics + `IsSuspended` with audit · Q10 Option A + slim C · Q13 onboarding keep · English UI · UTC everywhere · reference-project traces removed from documentation.

## 3. Stretch features (defined, only after Phase 11)

1. **Map screen (mobile):** a dedicated screen/tab rendering Approved destinations as markers on an interactive map (flutter_map + OpenStreetMap tiles — free, no API key; `google_maps_flutter` would work but needs an API key + billing setup). Data: a light map endpoint returning only `{id, name, lat, lng, category, rating, thumbnail}` filtered by the visible map bounding box (the bbox doubles as the mandatory search parameter) with a capped result count — this respects B's pagination/light-list rules. Marker tap → mini card → destination details. The map *picker* (input) and details-map ship in core scope regardless.
2. **Desktop SignalR client:** organizer new-booking/cancellation toasts, admin pending-request toasts — same hub, same Flutter package.
3. Curator statistics · search autocomplete · "near you".

## 4. Source-of-truth order

1. **B — course specification** · 2. **A — topic application** · 3. **this package** · 4. C (history only).
