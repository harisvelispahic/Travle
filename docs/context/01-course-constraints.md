# 01 — Course Constraints (extracted from "Upute za izradu seminarskog rada", RS2 2025/26)

> **Hard rules.** Work that deviates from these is rejected outright ("Radovi koji na bilo koji način odstupaju od pravila... neće biti prihvaćeni"). This file is the graded contract. Section letters/numbers reference the original document. Dodatak A ("Preporuke" — the *suggested things*) is included at the end and treated as mandatory for this project.

## A. General (§2.1)

- [ ] Every functionality listed in the approved topic application is implemented and **fully functional**.
- [ ] The implementation matches the topic application's description (recommender approach included).
- [ ] Class-specific implementation items are demonstrated: centralized configuration management, recommender algorithm + how its model/data is managed.

## B. Desktop application (§2.2)

- [ ] Desktop = administrative part; includes a **reporting module**.
- [ ] Every data list view has **at least one search parameter** (unless genuinely inapplicable, e.g. "top 5" views).
- [ ] **Minimum two PDF reports**, downloadable **and** printable.
- [ ] CRUD forms for **all reference data** (countries, regions, cities, categories, tour types, tags, statuses...), even those not named in the topic application.

## C. Mobile application (§2.3)

- [ ] Overview of offerings (destinations/tours).
- [ ] Order/booking creation + activity history for registered users.
- [ ] Booking details view; profile view + edit (personal data, image); **password reset**.
- [ ] **At least one master-detail form** (booking details).
- [ ] Payment declared in the topic ⇒ implemented via a **real sandbox** (Stripe) — never simulated — **including refund logic through the payment integration**.

## D. REST API (§2.4)

- [ ] CRUD for **all** main and reference entities; JWT auth/z; **filters + search on every list endpoint**; server-side input validation; error logging detailed enough to reproduce problems.
- [ ] Recommender module using a known algorithm (content-based + popularity here).
- [ ] Recommendations are **explainable** — every recommendation tells the user *why*.
- [ ] Data feeding the recommender (search history, interactions...) is **actually written** by the application at runtime.
- [ ] Recommender implementation **matches** `recommender-dokumentacija.md` exactly.
- [ ] **Every signal collected is used in scoring** — collecting (e.g. AvgRating) and ignoring it is a rejection reason.

## E. Database (§3.1)

- [ ] **≥10 main tables**, excluding reference tables. Insufficient scope ⇒ add functionality.
- [ ] SQL Server (or relational). DB named **230172** (index, no IB prefix).
- [ ] **All FKs defined through EF configuration**; referential integrity at DB level; all tables connected by FKs.
- [ ] Reference tables = static/rarely-changed support data (cities, categories, roles, m2m link tables without meaningful attributes). They never store main-functionality data.
- [ ] Required fields NOT NULL and mirrored as required in the UI.
- [ ] Seed contains **all data needed to test** (created via migrations/startup is fine) — including **images** since the domain uses them. Too few records ⇒ work not evaluated in detail.
- [ ] Code First allowed. Deletion: cascade only where sensible; blocked (with a clear user message) when records are referenced; soft-delete purge respects FK order (children before parents).
- [ ] Reference data always FK to its table — **never string fields**; models/DTOs/requests consistent (never `string City` in one place and `CityId` in another).
- [ ] Seed hash formats consistent between HasData and runtime seeders.
- [ ] No superfluous tables without a functional purpose.

## F. Microservice architecture (§3.2)

- [ ] Minimum two services: main API + helper worker in a **separate project + separate Dockerfile + separate container**. `BackgroundService`/Hangfire inside the API does **not** count.
- [ ] RabbitMQ is the broker; API publishes, worker consumes in the background and performs **real work** (emails), not just logging.
- [ ] All services (api, worker, rabbitmq, sqlserver) in `docker-compose.yml`, each functional and network-connected.
- [ ] **Docker image tags explicitly versioned** (no bare `latest` on key services).
- [ ] Enough log output to reproduce failures, especially crashes during grading.

## G. Configuration (§3.3)

- [ ] Centralized config management, defined in exactly one place.
- [ ] All config in **.env**, never hardcoded in source or appsettings.json: RabbitMQ (host/sender/port), SMTP (host/user/pass/ssl/port), **Stripe key**, **JWT key**, connection string, API path, everything else.
- [ ] Flutter API address configurable: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000`, read via `String.fromEnvironment('API_BASE_URL')`.

## H. Code quality (§3.4)

- [ ] No unused code, no widgets without implemented functionality; controls load only the data they need.
- [ ] No magic numbers/strings — enums/constants; role names in a static class.
- [ ] Controllers: no business logic, no direct DbContext (controller → service → DbContext).
- [ ] Services using DbContext registered **Scoped** (never Transient).
- [ ] Multiple `SaveChangesAsync()` in one operation ⇒ **explicit transaction**.
- [ ] **Custom exception types** (e.g. BusinessException, NotFoundException) + ExceptionFilter **or middleware** mapping to HTTP statuses (we use middleware — see 02 §3).
- [ ] Never expose stack traces / internal or infrastructure errors to clients outside development; log server-side, return standardized messages.
- [ ] Controllers return **DTOs**, never entities. No `dynamic`.
- [ ] Avoid service-in-service calls that each call SaveChanges — share the DbContext/transaction.
- [ ] `IHttpContextAccessor` injected into services (no manual token parsing).
- [ ] `HttpClient` only via `IHttpClientFactory`.
- [ ] CORS configured **once**, explicit origins. No duplicate registrations in Program.cs (UseCors, AddHttpContextAccessor, AddSwaggerGen each at most once).

## I. Input validation (§4)

- [ ] Complete validation **including edit forms**; error messages state the expected format/limits explicitly.
- [ ] Editing must not force re-entering every field. Password rules: editing a user never demands a new password; use a "change password" checkbox/button revealing new+confirm fields (or empty fields validated only when filled); admin editing a user never enters the old password; a user changing their own password confirms the old one.
- [ ] No false-positive validation. Messages displayed **below the controls** — not inside inputs, not dialogs.
- [ ] Email/phone format validation. Success feedback is meaningful (never bare "Success"/"Bad request").

## J. Authentication & authorization (§5)

- [ ] `[Authorize]` on every controller touching user data; `[AllowAnonymous]` **only** login/register; write operations never open.
- [ ] Admin endpoints: `[Authorize(Roles = "Admin")]` (role names must match seed).
- [ ] `userId` never from route/body for current-user operations — always from JWT; users can modify only their own data; admin may manage others'.
- [ ] Register never accepts role/isAdmin from the client.
- [ ] Dev/test endpoints removed or guarded with `env.IsDevelopment()` — no test controllers reachable in production.
- [ ] JWT parsing validates the signature. **Logout invalidates server-side** (refresh-token revocation), not just client-side deletion.
- [ ] Credentials only in POST bodies, never query strings.
- [ ] Upload/download endpoints: authorization + **ownership checks**. File upload validates **MIME type and magic bytes**, not extension.
- [ ] SignalR hubs verify membership (user only receives/joins their own groups).
- [ ] README.md: all run steps + credentials table — `desktop`/`test`, `mobile`/`test`, plus `roleName`/`test` per extra role.

## K. UI (§6)

- [ ] Clean, readable forms; no garish colors/transparency; expected affordances (X close button top-right on forms).
- [ ] Dropdowns populated **from the database** (cities etc. never free-text). Booleans = checkbox/switch; dates = DateTime picker; coordinates via **map picker or address lookup**, never raw textboxes.
- [ ] After a successful save: fields clear if staying on the form; otherwise auto-redirect to the list with the newest record on top, list refreshed automatically.
- [ ] Never display DB IDs; m2m displays never show or consist solely of IDs.
- [ ] Where business flow allows, related FK records can be added in-flow via a modal.
- [ ] No overlapping controls; images ≤50% of a form; two-column label/value layouts (aligned); icons encouraged.
- [ ] Block opening insert forms when prerequisites are missing (e.g. FK table empty).
- [ ] Lists/tables for image-bearing entities show the image next to the name.
- [ ] Confirmation dialog for every irreversible action (delete, payment, order/booking submission).
- [ ] "Back" button everywhere; unavailable actions rendered **disabled with the reason shown**.

## L. Core business logic (§7)

- [ ] Status field with `Pending → Confirmed → Cancelled/Completed`; hard delete instead of a status change = error.
- [ ] **Centralized state machine** with explicit allowed transitions; never spread across controllers.
- [ ] Business-rule checks on transitions (no rejecting an approved item, no reviewing before completion, no cancelling a paid item without the refund flow).
- [ ] Capacity/occupancy **and schedule-overlap checks on the backend**, not just frontend; server-side precondition validation (capacity, availability, validity windows).
- [ ] Unique constraint or service check against duplicates (same user + same slot).
- [ ] **Audit trail**: who approved/rejected, when, and the description/reason stored on the record.
- [ ] Cancellation available to user and administrator; rejection stores a reason **and** sends a notification.
- [ ] Price computation correct in edge cases (25h/48h durations etc.).

## M. Payments (§7.1)

- [ ] Payment finalized **server-side via webhook** (or server-side API verification); the client never records success.
- [ ] Confirm is **idempotent** — completed payments never re-execute effects.
- [ ] Multiple payment attempts for the same item prevented (open/finished payment check).
- [ ] UI shows a clear "Paid" state after success; pay button hidden for paid items (`IsPaid` in the response DTO).
- [ ] Mobile payment **in-app** (Stripe SDK/PaymentSheet or deep-link return) — never an external browser without return.
- [ ] Declared refund logic implemented; refunds based on the **actually charged amount**, not a recalculated price.
- [ ] Server owns the catalog and the amount — never trust the client for the price.

## N. Notifications (§7.2)

- [ ] Notifications have: read/unread status, title, text, date/time, and a "mark as read" option.
- [ ] **Auto-refresh via SignalR or polling** — manual refresh unacceptable.
- [ ] Notifications for **all** relevant events (booking, cancellation, status change, payment...), not just one.
- [ ] News/announcements (if present): title, text, image, date/time.

## O. Technical standards (§8.1)

- [ ] No template leftovers (**WeatherForecastController is called out by name**), dead code, unused imports, commented-out blocks, duplicated classes/services (DRY), "thinking out loud" comments, or NotImplementedException stubs.
- [ ] `ILogger<T>` — never `Console.WriteLine`.
- [ ] Fix naming mistakes / copy-paste leftovers from other projects (e.g. the template's `ClinetException` typo).
- [ ] README accurate and matching the actual code. Client apps never call nonexistent backend routes.

## P. Performance, pagination, validation (§8.2)

- [ ] **async/await through the whole stack**; forbidden: `.GetAwaiter().GetResult()`, `.Wait()`, `.Result`, `Thread.Sleep` (use `await Task.Delay`); async EF variants inside async methods.
- [ ] No SQL-in-a-loop (N+1) — Include/GroupBy/batch; mapping methods never re-query entities.
- [ ] Background jobs via `IHostedService`/`BackgroundService` (inside the API is fine for *scheduling*; the worker container is a separate matter) — never `Task.Run` fire-and-forget.
- [ ] Aggregations in a single GroupBy query. Filtering/price checks in the DB (`Where`), never load-all-then-LINQ.
- [ ] Per-request static data cached with `IMemoryCache` at the service level (never instance dictionaries on Transient services). Env vars read once (constructor).
- [ ] **Pagination on every list endpoint**, PageSize capped (e.g. 100). Unbounded RetrieveAll = rejection (DoS surface).
- [ ] List endpoints never return heavy payloads (PDF blobs, large base64 images) — display data only; details on separate endpoints.

## Q. Submission (§9) — pre-flight

- [ ] Public GitHub repo, correct `.gitignore`, complete source, `recommender-dokumentacija.md`.
- [ ] `flutter clean` → `flutter build apk --release` (API base `10.0.2.2`) and `flutter build windows --release` (API base `localhost`); verify APK in AVD (fresh install) and the Windows exe.
- [ ] One **immutable GitHub Release** per submission: enable release immutability in repo Settings → create as **draft** → attach `fit-build-20gg-mm-dd.zip` (APK + `build/windows/x64/runner/Release` folder) → verify → publish. No `.env` or secrets in the release.
- [ ] `.env` in the repo replaced by `.env-tajne.zip` (password "fit" or random) sitting where the original would be.
- [ ] DL system: link to the **exact release tag** (never `/latest`) + the zip password.
- [ ] **No repo/release modifications after the deadline** — any change disqualifies the submission for that term.
- [ ] App must start and be fully testable with zero code/config interventions; test outside the dev environment first. Prefer plain HTTP for the API (self-signed certs expire).
- [ ] Defense: must know every part of the system in detail.

## R. Dodatak A — "Suggested things" (treated as mandatory here)

**RabbitMQ / messaging (A.1)**
- [ ] `AsyncEventingBasicConsumer` for async handlers (not `EventingBasicConsumer`).
- [ ] Singleton connection / connection pool — never a new connection per publish.
- [ ] Consumer retry with exponential backoff (1s → 2s → 4s → 8s); no empty catch blocks; the worker never dies silently — always log the reason.

**Flutter / mobile (A.2)**
- [ ] Parallelizable HTTP calls via `Future.wait()` instead of sequential awaits.
- [ ] Never base64-decode images inside `build()` — decode once + cache, or use URLs.
- [ ] Deep links handle both initial-link and resumed-app scenarios.
- [ ] HTTP 401 handled properly (redirect to login or refresh-token flow); expired tokens never ignored.
- [ ] Specific error messages: `_handleResponse`-style helpers must surface backend validation messages, not mask them.
- [ ] No mock/test file names carrying production code.

**Crypto & passwords (A.3)**
- [ ] Security values (codes, tokens, referral codes) from `System.Security.Cryptography.RandomNumberGenerator` — never `System.Random`.
- [ ] Password hashing: bcrypt / Argon2 / PBKDF2 only (no unsalted SHA256, no HMAC-SHA512, no custom schemes).
- [ ] Reset tokens/codes: expiry (`ExpiryTime`) mandatory; never stored in plain text.

**Date/time (A.4)**
- [ ] `DateTime.UtcNow` standardized app-wide (mixing with `DateTime.Now` breaks Docker timestamps).

**Resources (A.5)**
- [ ] Every disposable (`Stream`, `HttpResponseMessage`, `DbConnection`...) in a `using` statement/declaration.

---

## Per-feature completion checklist (run for every finished feature)

1. Matches the topic application + `TRAVLE-SPECIFICATION.md`.
2. List endpoints: paginated + searchable + light DTOs.
3. Validation server-side (FluentValidation) + client-side messages under controls.
4. Auth: correct attributes, roles, userId-from-JWT, ownership checks.
5. Status changes only via the state machine; audit fields written.
6. Notifications/RabbitMQ messages emitted where the event list requires.
7. Seed data demonstrates the feature.
8. No constraint from sections A–R violated.
