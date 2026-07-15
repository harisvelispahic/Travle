# CLAUDE.md — Travle Agent Context

You are working on **Travle**, a tourist-destination discovery and tour-booking marketplace, built as the seminar project for *Razvoj softvera II* (FIT, 2025/26). The project is **graded against a strict written specification** — violating a constraint means the work gets rejected, no matter how good the code is. Treat the constraint files in this folder as law.

## Read order (do this before writing any code)

1. `01-course-constraints.md` — hard, non-negotiable rules extracted from the official course document. **Every task must be checked against this file before it is considered done.**
2. `02-architecture-and-code-rules.md` — how this codebase is structured: template adoption, exception middleware, EF configuration style, project layout, config management.
3. `03-database-design.md` — entities, relationships, naming, seed requirements.
4. `04-recommender-spec.md` — the recommendation module. The implementation must match this document *exactly* (the course verifies documentation-vs-implementation parity).
5. `05-implementation-roadmap.md` — phased plan with definitions of done.
6. `06-template-adoption-guide.md` — exact rename/purge steps for turning the course template into Travle (Phase 0 only).
7. `07-mobile-app-structure.md` — mobile screen map and navigation (all Flutter mobile work).
8. `08-ui-design-system.md` — design tokens, the shared `travle_ui` package, widget catalogue, theming rules (all Flutter UI work).
9. `09-exception-handling.md` — the global exception-handling pipeline: custom exception hierarchy, the chained `IExceptionHandler` design, `ErrorResponse` contract, FluentValidation wiring.
10. `../TRAVLE-SPECIFICATION.md — the full functional spec (what to build).
11. `../00-ANALYSIS-AND-OPEN-QUESTIONS.md` — the complete decision log (reconciliation is finished; no open items). Stretch features live in its §3 and are touched only after Phase 11.

## Project facts (memorize)

- **Stack:** ASP.NET Core Web API on **.NET 10 (LTS)** — all csproj target net10.0, Docker base images sdk:10.0/aspnet:10.0, Microsoft.* packages on the 10.x line — EF Core Code First, SQL Server, Flutter (mobile = traveler/curator, Windows desktop = organizer/admin), RabbitMQ, SignalR, Stripe (test mode, PaymentIntents + PaymentSheet), Docker Compose.
- **Solution layout:** `Travle.Model` / `Travle.Services` / `Travle.WebAPI` / `Travle.Worker` (separate container!) + `UI/travle_mobile` + `UI/travle_desktop`.
- **Database name:** `230172` (student index without the IB prefix).
- **Currency:** `bam` in Stripe, displayed as "KM", minor units (2500 = 25.00 KM).
- **Statuses:** Booking lifecycle `PaymentInProgress → Pending → Confirmed → Completed/Cancelled` (+ `Expired`), driven only by the centralized state machine in `Travle.Services`. PaymentInProgress holds capacity for **15 minutes**.
- **Refunds:** one **global** tier table (RefundPolicyTiers): >72h = 100%, 24–72h = 50%, 1–24h = 25%, <1h = 0% for user cancellations; organizer reject / slot cancel = always 100%; computed from the actually charged amount.
- **Commission:** 10% platform fee from `PLATFORM_FEE_PERCENTAGE` in `.env`, snapshotted per payment (`PlatformFeePercentage`, `PlatformFeeAmount`). No payouts to organizers.
- **Entities:** live in `Travle.Services/Database`, configurations in `Database/Configurations/`, all inheriting `BaseEntity { Id, CreatedAt, ModifiedAt? }` / `BaseEntityConfiguration<T>`. `Travle.Model` holds DTOs only.
- **Logout:** `POST /Access/Logout` deletes all of the user's refresh tokens (server-side invalidation). Delete strategy per 02 §6a (business records never hard-deleted; hybrid, per entity — hence no IsDeleted/IsEnabled on BaseEntity).
- **Suspension:** `Users.IsSuspended` + audit fields (SuspendedAt/By/Reason); suspending revokes refresh tokens; login and refresh both check the flag; existing Confirmed bookings are honored.
- **UI language: English** in both apps. **Time: UTC** in DB/API/code (`DateTime.UtcNow`); the UI converts to local time for display only.
- **Test credentials (seed + README):** `desktop`/`test` (admin), `mobile`/`test` (traveler), plus `organizer`/`test`, `curator`/`test`.

## Standing working rules

1. **Never** put business logic or `DbContext` access in controllers. Controller → service → DbContext, always.
2. **Never** hardcode configuration. Everything (conn string, JWT key, Stripe keys, SMTP, RabbitMQ, API URL) comes from `.env` → environment variables. If you need a new config value, add it to `.env.example` and the compose file.
3. **Never** trust the client for: prices/amounts, userId (always from JWT claims), roles, payment success.
4. All new entities get: a per-entity `IEntityTypeConfiguration<T>` class, DTOs (Response + Insert/Update requests + SearchObject), FluentValidation validators, pagination on list endpoints (max PageSize 100), at least one search parameter, seed data.
5. All errors flow through the exception middleware using the custom exception types (`NotFoundException`, `BusinessRuleException`, `ConflictException`, `ForbiddenException`, `UnauthorizedException`, `PaymentException`) — never throw or catch bare `Exception` for control flow, never return stack traces to clients.
6. Async/await end-to-end. Forbidden: `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`, `Thread.Sleep`, sync EF calls inside async methods, queries in loops (N+1), `dynamic`.
7. Multiple `SaveChangesAsync` in one operation ⇒ wrap in an explicit transaction. Booking creation/capacity math is always transactional with a conditional capacity check.
8. Every user-facing event produces both an in-app notification row (+ SignalR push) and, where specified, a RabbitMQ message for the worker to email.
9. When you finish a feature, run the checklist at the bottom of `01-course-constraints.md` for that feature before declaring it done.
10. `DateTime.UtcNow` only. `ILogger<T>` only (no `Console.WriteLine`). No dead/commented-out code, no TODO placeholders, no `NotImplementedException` left behind.
11. UI work must use `travle_ui` tokens/widgets — screens never hardcode colors or text styles — and must follow the UI rules section of `01-course-constraints.md` (dropdowns from DB, date pickers, map picker for coordinates, no raw IDs on screen, confirmation dialogs for irreversible actions, Back buttons, disabled-with-reason states, validation messages under controls).
12. Images: byte[] in DB; **thumbnails only** in list DTOs; full image via detail/dedicated endpoint; Flutter decodes once and caches — never base64-decode inside `build()`.

## Definition of done (global)

A feature is done when: it satisfies the functional spec **and** every applicable rule in `01-course-constraints.md`; it works through `docker compose up` with no manual fixes; seed data exists to demonstrate it; desktop/mobile UI follows the UI rules; and nothing new violates the performance rules (pagination, no N+1, caching of per-request static data, DB-level filtering).
