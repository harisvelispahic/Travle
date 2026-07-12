# 02 — Architecture & Code Rules (rev. 2)

## 1. Template adoption plan

Base: course template `rsII_exam_template_2025_26`. Full step-by-step rename/purge procedure: **`06-template-adoption-guide.md`**. Summary of verdicts:

| Template piece | Verdict |
|---|---|
| Layering `*.Model` / `*.Services` / `*.WebAPI` (+ `.Common.Services`) | Keep pattern, rename to `Travle.*`, add `Travle.Worker`. |
| `BaseReadService`/`BaseCRUDService` + base controllers + SearchObjects + `PageResult` | Keep — course-approved CRUD/pagination/search backbone. |
| Mapster + FluentValidation | Keep. |
| `RefreshToken` entity + `AccessManager` + `LoginWithRefreshToken` | Keep. **Gap: no Logout endpoint** — add `POST /Access/Logout` ([Authorize]) calling the existing `RefreshTokenService.DeleteAllUserRefreshTokensAsync(userId-from-JWT)`. |
| `ProductStateMachine` (state pattern, DI-registered states) | Keep the pattern → `BookingStateMachine` (PaymentInProgress, Pending, Confirmed, Completed, Cancelled, Expired). |
| `CryptoService` | Keep only if PBKDF2/bcrypt-class + `RandomNumberGenerator`; verify before reuse. |
| `ExceptionFilter` + `ClinetException` | Replace with middleware + custom hierarchy (§3). |
| `WeatherForecastController`, `WeatherForecast`, `Class1.cs`, `QueryOptimization*` demo, eCommerce domain + migrations | Delete (no commented-out remains). |
| docker-compose (SQL Server only) | Extend: api, worker, rabbitmq, sqlserver; pinned tags; `.env`-driven. |
| Flutter `lib/{layouts,models,providers,screens,utils}` + `base_provider` | Keep structure (Haris's own templates take precedence; port base_provider/auth pieces as needed). |

## 2. Solution structure

```
travle/                     repo root: README.md, recommender-dokumentacija.md, CLAUDE.md + docs/,
│                           docker-compose.yml, .env (gitignored; committed as .env-tajne.zip), .gitignore
├── Backend/
│   ├── Travle.sln
│   ├── Travle.Model        DTOs only: Requests/, Responses/, SearchObjects/, Exceptions/, Access/
│   ├── Travle.Services     Database/ (entities + TravleDbContext + Configurations/ + Seed/),
│   │                       services, BookingStateMachine/, Recommender/, Payments/ (StripeService),
│   │                       Messaging/ (RabbitMQ publisher), Validators/, Notifications/
│   ├── Travle.WebAPI       thin Controllers/, Middleware/ (ExceptionMiddleware), Hubs/ (NotificationHub),
│   │                       AccessManager, Scheduler (IHostedService), Program.cs, Dockerfile
│   └── Travle.Worker       RabbitMQ consumers, EmailService (SMTP), retry/backoff, Dockerfile
└── UI/
    ├── travle_mobile
    └── travle_desktop
```

Decided (round 3): **UI lives beside Backend, not inside it** — the template nests UI/ inside the backend folder; we split them. `docker-compose.yml` + `.env` sit at the **repo root** (grader runs `docker compose up` right after clone); compose build contexts point into `Backend/` (e.g. `build: { context: ./Backend, dockerfile: Travle.WebAPI/Dockerfile }`). The solution file stays in `Backend/` and references only backend projects (Flutter apps are never part of a .sln).

### 2a. Entity placement — DECIDED
Entities live in **`Travle.Services/Database`** (template convention), configurations in **`Travle.Services/Database/Configurations`** — *not* in `Travle.Model`. Rationale: `Travle.Model` is the pure DTO contract (requests/responses/search objects) mirrored by the Flutter models; keeping entities inside Services reinforces the course rule that controllers only ever see DTOs; graders and the defense expect the template layout; this is a layered seminar app, not CQRS/clean-architecture — a separate Domain/Infrastructure split adds ceremony without payoff here. (In a CQRS project the Model/Infrastructure split remains the right call; different context.)

### 2b. BaseEntity — DECIDED
```csharp
public abstract class BaseEntity
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; }      // UtcNow, set in SaveChanges interceptor or service
    public DateTime? ModifiedAt { get; set; }
}
```
- All entities inherit it (join tables without meaningful attributes may stay bare per course reference-table rules).
- `BaseEntityConfiguration<T> : IEntityTypeConfiguration<T>` sets the key + timestamp defaults; concrete configurations inherit it.
- Timestamps set centrally (a `SaveChanges` override/interceptor in `TravleDbContext`) — never manually per service.
- Do **not** put `IsDeleted` on BaseEntity — soft flags are per-entity and named for their meaning (`IsRemoved` on reviews, `IsSuspended` on users), see §6a.

## 3. Exception handling

Hierarchy in `Travle.Model/Exceptions`:
```
TravleException (abstract; HttpStatusCode + error key)
├── NotFoundException 404 · BusinessRuleException 400 · ConflictException 409
├── UnauthorizedException 401 · ForbiddenException 403 · PaymentException 402/400
```
Single `ExceptionMiddleware` first in the pipeline: `TravleException` → mapped status + `{ "message", "errors": { key: [msgs] } }` (same JSON shape the template's Flutter helpers expect); `FluentValidation.ValidationException` → 400 per-property; everything else → 500, fully logged (`ILogger<ExceptionMiddleware>`), standardized client message; stack traces only in Development. Services throw; controllers contain zero try/catch.

## 4. EF Core — per-entity configurations (decided)

One `IEntityTypeConfiguration<T>` per entity (inheriting `BaseEntityConfiguration<T>`), applied via `ApplyConfigurationsFromAssembly`. Every FK explicit (`HasOne/WithMany/HasForeignKey/OnDelete`); default `Restrict`, `Cascade` only for true children. `decimal(18,2)` for money. Unique + filtered indexes declared here (03 §5). `HasData` for reference seed; runtime seeder for rich data + images; identical hash formats.

## 5. Configuration management

`.env` (+ committed `.env.example`) → compose env vars → options classes bound once at startup; env read in constructors only. Keys: `CONNECTION_STRING`, `JWT_*`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `RABBITMQ_*`, `SMTP_*`, `API_BASE_URL`, `PLATFORM_FEE_PERCENTAGE`. Nothing secret in appsettings.json. Flutter: `String.fromEnvironment('API_BASE_URL')` + `--dart-define`.

## 6. API conventions

Base CRUD controllers for standard CRUD; explicit endpoints for domain actions (confirm/reject/cancel booking, webhook, recommendations, logout). Every list endpoint: SearchObject (page, pageSize ≤ 100, ≥1 filter + text search) → `PageResult<T>`; light DTOs (thumbnails only). Stripe webhook `[AllowAnonymous]` + signature verification + idempotency. SignalR `NotificationHub`: JWT (`access_token` query param on WebSocket), users join `user-{id}` group after membership check; server pushes on notification insert. CORS once, explicit origins.

### 6a. Delete strategy — DECIDED
- **Business-process records** (Bookings, Payments, Refunds, RoleApplications, Destinations, Reviews): **never hard-deleted.** State changes via the state machine / status fields; moderation removals are soft flags (`IsRemoved` + who/when/reason). Course §7 treats hard delete instead of a status change as an error.
- **Reference data** (cities, categories, tags...): hard delete allowed, but `Restrict` FKs block deletion when in use → `ConflictException` with a human message ("Cannot delete category 'Historija': used by 12 destinations").
- **No global EF soft-delete query filter** — per-entity flags are filtered explicitly in services (keeps queries honest and the defense simple).
- If any soft-deleted data is ever purged, purge children before parents (course §3.1).

## 7. Flutter structure (both apps)

```
lib/
├── main.dart            MultiProvider, routing, theme
├── layouts/             master_screen.dart (nav shell)
├── models/              json_serializable models (*.g.dart)
├── providers/           base_provider.dart (REST + auth header + 401 refresh flow + error surfacing),
│                        per-entity providers, auth_provider
├── screens/             per-screen files (list / details / form)
├── utils/               error mapping, formatters, validators, image cache helper
└── widgets/             paginated table, image picker, map picker, confirm dialog, status pill
```
Rules: `Future.wait` for independent loads; decode DB images once (model-level `Uint8List` memoization, `Image.memory`) — never in `build()`; 401 → refresh attempt → login redirect; backend validation messages shown verbatim under fields; payments via `flutter_stripe` PaymentSheet. Mobile screen map: `07-mobile-app-structure.md`.

## 8. Background scheduling (inside the API — allowed)

One `IHostedService` with three duties: (1) expire `PaymentInProgress` bookings older than **15 minutes**, releasing seats; (2) promote past `Confirmed` → `Completed`; (3) publish 24h-reminder messages to RabbitMQ (worker emails; in-app notification row created too). Each run logs; failures never crash the host. This is *scheduling*, not the microservice worker — `Travle.Worker` remains a separate container (course hard rule).
