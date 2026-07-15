# 09 — Exception Handling Pipeline

How Travle turns thrown exceptions into HTTP responses. This replaces the template's
`ExceptionFilter` (MVC filter) + `ClientException` with a modern `IExceptionHandler` chain and a
proper custom exception hierarchy. It implements the design sketched in `02-architecture-and-code-rules.md` §3
and satisfies course constraints §3.4 / §8.1 (custom exception types, middleware mapping to HTTP
statuses, **no stack traces to clients outside Development**, `ILogger<T>` only).

## 1. Design at a glance

```
Service throws  ──►  UseExceptionHandler  ──►  chain of IExceptionHandler (registration order)
                                                 1. TravleExceptionHandler   (domain hierarchy)
                                                 2. ValidationExceptionHandler (FluentValidation)
                                                 3. GlobalExceptionHandler    (fallback, 500)
                                                        │
                                                        ▼
                                                 ErrorResponse (JSON) written to the client
```

- **Controllers contain zero `try/catch`.** Services throw; the pipeline maps.
- Every response uses one shape — `ErrorResponse` — so the Flutter clients parse a single format.
- Anything not recognised as an expected error becomes a generic **500 with no internals leaked**.

## 2. Why a *chain* of handlers (and not one middleware)

The user asked whether to chain multiple `IExceptionHandler`s, positioned most-generic-last, like
`try/catch/catch`. **We did, and here is the reasoning.**

ASP.NET Core (8+) invokes registered `IExceptionHandler`s in **registration order**; the first one
whose `TryHandleAsync` returns `true` wins and stops the chain. Returning `false` means "not mine,
pass it on". That is exactly a `try { … } catch (TravleException) { } catch (ValidationException) { } catch (Exception) { }`
ladder, expressed as composable, single-responsibility classes.

**Pros (why we chose it):**
- One concern per class: domain errors, validation errors, and the catch-all are independent and
  individually testable.
- Open/closed: adding a new category (say, a dedicated Stripe-webhook handler) is a new class + one
  registration line — no editing of an existing handler.
- Reads like the try/catch mental model everyone already knows; easy to defend.

**Cons we accepted:**
- Registration **order matters** — the fallback *must* be last. We mitigate this by keeping the
  three registrations together in `Program.cs` with a comment, and `GlobalExceptionHandler` always
  returns `true`, so nothing can slip past the end of the chain.
- Slightly more indirection than a single `switch`. For a fixed, small set of categories the
  extensibility payoff is modest — but the clarity is worth it and it matches how the app will grow
  (payments, webhooks, external services later).

**When a single handler would have been fine:** if the whole app only ever produced two or three
error shapes and never grew. Travle will keep adding domain actions, so the chain is the better fit.

The `TravleException` hierarchy is itself handled by a **single** handler (`TravleExceptionHandler`)
because each exception already carries its own status code and error key — so we get per-type
behaviour without a per-type `catch`. The chain only splits where the *shape* of the response
genuinely differs (domain vs. validation vs. opaque 500).

## 3. The exception hierarchy

Location: `Travle.Model/Exceptions`. All expected, client-facing errors derive from the abstract
`TravleException`, which carries the HTTP status and a machine-readable error key.

| Exception | HTTP | `ErrorKey` | Throw it when… |
|---|---|---|---|
| `NotFoundException` | 404 | `notFound` | A requested resource does not exist. Has a `(entityName, key)` overload for the standard message. |
| `BusinessRuleException` | 400 | `businessRule` | A well-formed request violates a domain rule (replaces the old `ClientException`). |
| `ConflictException` | 409 | `conflict` | State conflict — duplicate (same user + slot), or deleting reference data still in use. |
| `UnauthorizedException` | 401 | `unauthorized` | Not authenticated / bad or expired credentials. |
| `ForbiddenException` | 403 | `forbidden` | Authenticated but not allowed (other user's data, suspended account). |
| `PaymentException` | 402 (or 400) | `payment` | Payment/refund failure. Defaults to 402; pass 400 for a malformed payment request. |

Rule of thumb: **only expected, safe-to-show errors derive from `TravleException`.** Anything else
(a null-reference, an EF failure, a Stripe SDK crash) is left to bubble to `GlobalExceptionHandler`,
which logs it fully and returns an opaque 500.

## 4. The response contract — `ErrorResponse`

Location: `Travle.Model/Responses/ErrorResponse.cs`. Shape (matches what the template's Flutter
error helpers expect, plus two additive fields):

```jsonc
{
  "message": "Human-readable summary safe to show the user",
  "errors":  { "<key>": ["message", ...] },   // key = property name (validation) or category (domain)
  "traceId": "0HNN...",                         // always present; ties to the server log line
  "details": null                               // full exception text — ONLY in Development
}
```

Verified live output (from the behavioural check we ran against the real handlers):

| Thrown | HTTP | Body (abridged) |
|---|---|---|
| `NotFoundException("Destination", 5)` | 404 | `{"message":"Destination with id 5 was not found.","errors":{"notFound":[…]}}` |
| `BusinessRuleException(…)` | 400 | `{"errors":{"businessRule":[…]}}` |
| `ConflictException(…)` | 409 | `{"errors":{"conflict":[…]}}` |
| `UnauthorizedException(…)` | 401 | `{"errors":{"unauthorized":[…]}}` |
| `ForbiddenException(…)` | 403 | `{"errors":{"forbidden":[…]}}` |
| `PaymentException(…)` | 402 | `{"errors":{"payment":[…]}}` |
| `ValidationException` (Email ×2, Price ×1) | 400 | `{"message":"Email is required.","errors":{"Email":["Email is required.","Email format is invalid."],"Price":[…]}}` |
| `InvalidOperationException` **(Development)** | 500 | `{"message":"An unexpected error occurred. Please try again later.","errors":{"server":[…]},"details":"System.InvalidOperationException: …"}` |
| `InvalidOperationException` **(Production)** | 500 | same, but **`"details": null`** — the internal message is not leaked |

`traceId` prefers `Activity.Current?.Id` (distributed tracing) and falls back to
`HttpContext.TraceIdentifier`. It is safe to show the user and lets support correlate a report with
the server logs without exposing internals.

## 5. Validation with FluentValidation

- Validators live in `Travle.Services/Validators` and are registered in one sweep:
  `builder.Services.AddValidatorsFromAssemblyContaining<UserInsertValidator>()`
  (Scoped). New validators are picked up automatically — no per-validator line in `Program.cs`.
- The generic `BaseCRUDService` runs the insert/update validator and, on failure, throws
  `FluentValidation.ValidationException(result.Errors)`. Services that validate directly use
  `validator.ValidateAndThrowAsync(request)`.
- `ValidationExceptionHandler` turns that into a 400 whose `errors` dictionary is **keyed by
  property name** (all messages for one field grouped together), so the mobile/desktop UIs can show
  each message under its control (course constraint §4: messages below the control).
- **Model-binding** failures (malformed JSON, a missing non-nullable) are produced by
  `[ApiController]` *before* our services run. We override `InvalidModelStateResponseFactory` in
  `Program.cs` so those 400s use the **same** `ErrorResponse` shape — clients never see two formats.

## 6. Wiring (`Program.cs`)

```csharp
// registration order = execution order; fallback last
builder.Services.AddExceptionHandler<TravleExceptionHandler>();
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();        // backing service required by UseExceptionHandler()

var app = builder.Build();
app.UseExceptionHandler();                    // FIRST middleware — wraps the whole pipeline
```

`AddProblemDetails()` is required for the parameterless `app.UseExceptionHandler()` to resolve; our
handlers write the response themselves, so the ProblemDetails writer is never actually invoked, but
the service must be present.

## 7. Files

**Added**
- `Travle.Model/Exceptions/TravleException.cs` (abstract base) + `NotFoundException`,
  `BusinessRuleException`, `ConflictException`, `UnauthorizedException`, `ForbiddenException`,
  `PaymentException`.
- `Travle.Model/Responses/ErrorResponse.cs`.
- `Travle.WebAPI/Middleware/ErrorResponseWriter.cs` (shared trace-id + JSON writer),
  `TravleExceptionHandler.cs`, `ValidationExceptionHandler.cs`, `GlobalExceptionHandler.cs`.
- `Travle.WebAPI` references `FluentValidation.DependencyInjectionExtensions` (12.1.1).

**Removed**
- `Travle.Model/Exceptions/ClientException.cs` — replaced by `BusinessRuleException`.
- `Travle.WebAPI/Filters/ExceptionFilter.cs` — replaced by the handler chain.

**Migrated to the new hierarchy** (kept code)
- `AccessManager` — login failures → `UnauthorizedException` (single generic message, no username
  enumeration); refresh-token flow → `Unauthorized`/`Forbidden`/`BusinessRule`.
- `RefreshTokenService`, `UserService` (not-found → `NotFoundException`, duplicate email/username →
  `ConflictException`, password-change checks → `BusinessRuleException`), `BaseReadService`,
  `BaseCRUDService` (`KeyNotFoundException` → `NotFoundException`; also switched sync `.Find` to
  `await FindAsync` per the async rule), `BaseReadController` (dropped its `try/catch`).

> **Follow-up (domain purge):** a few eCommerce services still on the delete list
> (`ProductService`, `ProductStateMachine/*`, `AssetService`) retain BCL `KeyNotFoundException`,
> which currently falls through to a 500. They disappear with the Phase-0 purge; **new Travle
> services must throw `NotFoundException`, never `KeyNotFoundException`.**

## 8. How to use it (going forward)

```csharp
// In a service — just throw. No try/catch, no manual HTTP codes.
var destination = await _db.Destinations.FindAsync(id)
    ?? throw new NotFoundException("Destination", id);

if (booking.Status == BookingStatus.Completed)
    throw new BusinessRuleException("A completed booking cannot be cancelled.");

if (await _db.Bookings.AnyAsync(b => b.UserId == userId && b.SlotId == slotId))
    throw new ConflictException("You already have a booking for this slot.");
```

Controllers stay thin: call the service, return the DTO. The pipeline does the rest.
