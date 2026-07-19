# CRUD Endpoints — Reference Data Layer

Status record of the generic CRUD/read services + controllers built on top of the domain schema
(`03-database-design.md`). Written 2026-07-16.

## Scope decision — which entities got endpoints

The base pipeline (`BaseCRUDService`/`BaseCRUDController`, `BaseReadService`/`BaseReadController`)
was wired up **only for the simple reference/lookup tables**, where generic CRUD is a correct fit.
Everything with real domain behaviour (state machines, moderation, payments, seat math, gated writes,
server-written rows) is deliberately **not** a generic CRUD and is left for its own phase.

### ✅ Full CRUD (GET list + GET by id + POST + PUT + DELETE)

| Entity | Route | Search params | Insert/Update fields | Delete guard (blocked-with-reason) |
|---|---|---|---|---|
| Country | `/Countries` | `Name` | `Name` (uq) | blocked if referenced by Regions |
| Region | `/Regions` | `Name`, `CountryId` | `Name`, `CountryId` (uq per country; parent must exist) | blocked if referenced by Cities or RoleApplications |
| City | `/Cities` | `Name`, `RegionId` | `Name`, `RegionId` (uq per region; parent must exist) | blocked if referenced by Destinations |
| DestinationCategory | `/DestinationCategories` | `Name` | `Name` (uq) | blocked if referenced by Destinations or UserInteractions |
| TourType | `/TourTypes` | `Name` | `Name` (uq) | blocked if referenced by Tours |
| Tag | `/Tags` | `Name` | `Name` (uq) | blocked if referenced by DestinationTags or UserInteractions |
| RefundPolicyTier | `/RefundPolicyTiers` | `Percentage` | `HoursBeforeMin`, `HoursBeforeMax?`, `Percentage` | none — nothing references a tier (refunds snapshot the %) |

`Region` and `City` responses carry the parent name (`CountryName` / `RegionName`), populated by
Mapster flattening after the service loads the parent — on **all** paths: list (`ApplyIncludes` JOIN),
get-by-id, **and create/update** (via the `LoadResponseNavigationsAsync` hook, since a saved entity
otherwise has only the FK in memory and the flattened name would be null). This backs the desktop
Country → Region → City chaining.

### 👁 Read-only (GET list + GET by id)

| Entity | Route | Why read-only |
|---|---|---|
| BookingStatus | `/BookingStatuses` | Seeded with load-bearing Ids/names the booking state machine and the filtered unique index depend on. Never created/edited/deleted through the API — only listed (e.g. for status filters). |

### ⛔ Intentionally NOT generic CRUD (deferred to their phases)

These need domain logic that a generic CRUD would model incorrectly:

- **Users** — no delete (suspension + audit), password hashing, auth. (`UserService` already exists.)
- **RoleApplications** — submit + admin decide workflow (approve/reject, audit, notification).
- **Destinations** — moderation queue, edit ⇒ back to Pending, images, map picker, denormalized rating/views.
- **DestinationImages** — composition child, thumbnails, served via dedicated endpoints.
- **Tours** — soft delete via `IsActive`, ordered multi-destination picker.
- **TourSchedules** — status-driven, seat math, mass-refund on cancel.
- **Bookings** — centralized `BookingStateMachine`, transactional capacity guard, 15-min holds.
- **Payments / Refunds** — Stripe, fee snapshots, idempotent webhook, tiered refunds. **Never** a CRUD.
- **DestinationReviews / TourReviews** — gated writes (own Completed booking), soft-remove, rating recompute.
- **Favorites** — toggle on/off + interaction diary write, not edit-in-place.
- **Notifications** — created by events + SignalR push, user clears own; not admin-authored.
- **UserInteractions / RecommendationLogs** — append-only, written server-side only. No external writes.
- **PasswordResetCodes** — technical rows, issued/purged internally.
- **RefreshTokens** — technical/auth rows, managed by the auth flow.

## What each layer contains

For every entity above:

1. **DTOs** (`Travle.Model`): `XResponse` (Responses/), `XInsertRequest` + `XUpdateRequest`
   (Requests/, CRUD only), `XSearch` (SearchObjects/, ≥1 filter each per the course rule).
2. **Validators** (`Travle.Services/Validators`, CRUD only): `XInsertValidator` + `XUpdateValidator`
   (FluentValidation; required/length/range with messages). Auto-registered via the existing
   `AddValidatorsFromAssemblyContaining` sweep — no per-validator line in `Program.cs`.
3. **Service** (`Travle.Services`): `IXService` + `XService` deriving `BaseCRUDService` (or
   `BaseReadService` for BookingStatus). Overrides `ApplyFilters`; CRUD ones add uniqueness /
   parent-existence / delete-in-use rules via the hooks below. Registered `AddScoped` in `Program.cs`.
4. **Controller** (`Travle.WebAPI/Controllers`): thin `XsController` deriving the base controller —
   inherits GetAll/GetById(/Create/Update/Delete). No business logic.

## One base-class change

`BaseCRUDService` gained three no-op business-rule hooks so reference services enforce cross-row
rules without re-implementing the whole Insert/Update/Delete (which is what `UserService` does):

- `OnBeforeInsertAsync(request, entity)` — uniqueness, parent existence.
- `OnBeforeUpdateAsync(id, request, entity)` — same, excluding the row itself.
- `OnBeforeDeleteAsync(entity)` — block deletion of reference data still in use → counted
  `ConflictException` (03 §3 delete strategy / 02 §6a).

Default implementations are `Task.CompletedTask`, so existing services (`UserService`) are unaffected.

## Errors / conventions

All failures flow through the existing exception pipeline into the standard `ErrorResponse` shape:
duplicate → **409** `ConflictException`; invalid FK in body → **400** `BusinessRuleException`;
field validation → **400** keyed by property; delete-in-use → **409** with a counted human message
(e.g. *"Cannot delete country 'Bosnia and Herzegovina': it is referenced by 6 region(s)."*). Every
list endpoint is paginated (`PageResult<T>`, PageSize clamped to 100) and filters run in SQL.

## Authorization — deferred (matches current repo state)

Controllers carry **no** authorization attributes yet, consistent with the rest of the API
(`UsersController` has its `[Authorization]` commented out; auth/roles are Phase 1). Reference-data
**writes** are Admin-only per the spec and will get `[Authorization("Admin")]` in the auth/hardening
pass; reads stay open for dropdowns.

## Verification (2026-07-16)

Built clean, then exercised live against the seeded `230172` DB. Confirmed: paginated lists +
`IncludeTotalCount`; `Name`/`CountryId`/`RegionId` filters; `CountryName`/`RegionName` flattening on
list and get-by-id; read-only BookingStatuses; **409** on duplicate insert/update; **409** counted
delete-guard on an in-use Country; **400** business-rule on a non-existent parent FK; **400**
property-keyed validation (blank name, percentage > 100); **201** create; **204** delete then **404**.
No schema change ⇒ **no migration required**.
