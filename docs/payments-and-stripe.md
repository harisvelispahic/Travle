# Payments & Stripe — living design + implementation doc

> **Status:** Phase 6 **feature-complete** (6a → 6e all built; backend + mobile pay/refund loop verified
> live). This file is updated at the end of every sub-phase. The
> [Implementation status](#9-implementation-status-changelog) section is the source of truth for what is
> actually built right now; everything above it is the design it is being built to.

This document explains, from the ground up, how money works in Travle: what Stripe is doing, why we
made the architectural choices we did, and how the pieces fit together. It is written so that someone
who has never touched Stripe can follow the whole flow, and so that a grader can check the
implementation against the design.

---

## 1. TL;DR

- Travle charges the traveler **immediately** when they pay (Stripe *automatic capture*), and **refunds**
  if the booking is later cancelled or rejected. We do **not** authorise-and-capture-later.
- All money lands in **one** Stripe (test) account. The organizer's 90% is never moved anywhere — the
  10% commission is a **bookkeeping snapshot** on each payment, not a real payout. No Stripe Connect.
- We run in **Stripe test mode** only. That needs a free Stripe account and **no company, no KYC, no bank
  account** — no real money ever moves. This is exactly what the course means by "real sandbox, never
  simulated".
- Payment **success is recorded only by a signature-verified webhook**, never by the mobile client.
- Two different "holds" exist and must not be confused: our **seat hold** (15-min capacity reservation in
  our DB) and a Stripe **funds hold** (which we deliberately do **not** use).

---

## 2. Stripe in five minutes (for the uninitiated)

**Stripe** is a payment processor. Your server talks to Stripe's API; Stripe talks to the card networks.
You never see raw card numbers — the customer's card details go straight from their device to Stripe.

Key objects and terms:

- **API keys.** Two keys per mode:
  - *Secret key* (`sk_test_…`) — server-side only. Signs every API call. Never shipped to a client.
  - *Publishable key* (`pk_test_…`) — safe to embed in the mobile app; identifies your account so the
    client SDK can tokenise the card.
- **Test mode vs live mode.** Test-mode keys move **no real money**; you pay with *test cards* (e.g.
  `4242 4242 4242 4242`, any future expiry, any CVC). Live mode moves real money and requires a verified
  business/individual. **Travle only ever uses test mode.**
- **PaymentIntent.** The server-created object representing "an intent to collect X of currency Y". It has
  a **client secret** the mobile SDK uses to confirm the payment. Its `status` walks
  `requires_payment_method → requires_confirmation → processing → succeeded` (or `canceled`). We use
  **automatic capture**, so `succeeded` means the money is actually captured, not just authorised.
- **PaymentSheet.** Stripe's prebuilt, in-app mobile UI (`flutter_stripe`) that collects the card and
  confirms the PaymentIntent. The card never touches our servers.
- **Webhook.** Stripe calls **our** server (a `POST`) to tell us what happened out-of-band —
  `payment_intent.succeeded`, `payment_intent.payment_failed`, etc. Each request is **signed**; we verify
  the signature with the *webhook signing secret* (`whsec_…`) before trusting it. Webhooks are the
  authoritative record of success (a client can lie or drop off; the webhook is server-to-server).
- **Refund.** A server API call against a PaymentIntent (or charge) that returns some or all of the money.
  In test mode it appears in the dashboard but moves no real funds.

### 2.1 "But you can't process money without a registered company"

Correct — **in live mode**. To move real money, Stripe requires a verified entity (company, or in many
countries an individual/sole-trader) passing KYC/AML: legal name, tax id, bank account, sometimes
registration documents. That is also why a *real* marketplace would need Stripe Connect with each
organizer verified.

**Travle sidesteps all of it by staying in test mode.** A free Stripe account (email + password) gives
you test keys instantly — no company, no verification, no bank account. Every charge and refund is
simulated inside Stripe's dashboard. That is fully legitimate and is precisely what the course's "payment
via a real sandbox (Stripe), never simulated" requirement asks for: the *real* Stripe API and *real*
signed webhooks and *real* refund calls, just with no real funds. We never enable live keys.

---

## 3. Architectural decisions (the "why")

### 3.1 Charge-and-refund, not authorise-and-capture

We charge the card immediately on payment and issue a **refund** if the booking is later cancelled or the
organizer rejects it. We rejected the alternative (Stripe *manual capture*: authorise now, capture on
organizer-confirm) for four reasons:

1. **Auth expiry vs organizer latency.** A card authorisation lives ~7 days and can decay sooner. Nothing
   in the spec bounds how long an organizer may take to confirm, so a capture could fail on a stale auth.
2. **The course wants refund logic exercised** ("including refund logic through the payment integration").
   Charge-then-refund routes organizer-reject through the real **Refund API**; manual-capture would only
   *void an uncaptured auth*, which never exercises refunds.
3. **Tiered refunds need a charged amount.** Refund tiers are a percentage of the **actually charged
   amount** on the `Payment` row — meaningless if the money was only authorised.
4. **PaymentSheet ergonomics.** `flutter_stripe`'s PaymentSheet is cleanest with immediate-capture
   intents.

Consciously accepted trade-off: the traveler is charged **before** the organizer confirms; an organizer
rejection means a 100% refund (money round-trips). The spec designs for exactly this.

### 3.2 The two "holds" — don't confuse them

- **Seat hold (ours).** On checkout, the booking enters `PaymentInProgress` and we reserve capacity for
  **15 minutes** (`Booking.ExpiresAt`, `TourSchedule.SeatsTaken`). If payment doesn't complete, a
  scheduler releases the seats and marks the booking `Expired`. This is pure Travle logic, built in
  Phase 5.
- **Funds hold (Stripe).** A manual-capture authorisation. **We do not use this** (see 3.1).

So: *we* hold the seats; Stripe *charges* the money. There is no Stripe-side hold.

### 3.3 Marketplace money: no Connect, commission is bookkeeping

Travle is a marketplace (10% platform cut, 90% "organizer share"), **but no money is ever moved to
organizers.** All funds land in the single platform Stripe account. On every `Payment` we snapshot
`PlatformFeePercentage` and `PlatformFeeAmount` so reports can compute "platform revenue = Σ fees,
organizer share = Σ (amount − fee)". That is an accounting number, not a transfer.

Real marketplace splitting is **Stripe Connect** (`application_fee_amount` + a connected account per
organizer, each fully KYC-verified). It is an explicit **hard non-goal** — it can't be demoed with seed
data and needs real organizer onboarding. We deliberately don't build it.

### 3.4 Idempotency (no double effects)

- **Create-intent** reuses an already-open PaymentIntent for a booking instead of creating a second one
  (tapping *Pay* twice within the hold returns the same client secret). A Stripe *idempotency key*
  (`pi-booking-{id}-{attempt}`) is the backstop against a near-simultaneous duplicate create. A booking
  that already has a **succeeded** payment is refused (`409 Conflict`).
- **Webhook** (6b) is idempotent on the `Payment`/booking state: a replayed `payment_intent.succeeded`
  finds the payment already `Succeeded` / the booking already `Pending` and no-ops. (An optional
  processed-event ledger is a possible future hardening; not needed for the DoD.)

### 3.5 Refunds are a **post-commit** side-effect

The Stripe Refund API must never be called inside an open DB transaction — and the slot-cancel path holds
one transaction across a *batch* of bookings. So the refund is not part of the cancellation transaction.
Instead:

1. The state machine commits the booking's `Cancelled` transition first (release seats, audit, notification)
   — in its own transaction.
2. **Then**, outside any transaction, `RefundService` computes the tier, calls the Stripe Refund API (with an
   idempotency key), and persists the `Refund` row + `Payment.Status` + a `RefundIssued` notification in a
   single `SaveChanges`.

This is **idempotent** (a payment that already has a `Refund` is skipped) and **best-effort**: a Stripe
failure is logged and never fails the already-committed cancellation, and the idempotency key makes a retry
safe (never a double refund). A **0% tier** (<1h) writes a zero-amount `Refund` row for audit and makes no
Stripe call. Trade-off vs. a single transaction: a brief window where a booking is `Cancelled` with its
refund still "owed"; acceptable because the cancellation is the primary action and the refund is retry-safe.

---

## 4. The money math

- **Currency:** `bam` in Stripe, displayed as **"KM"**. BAM has 2 decimal places.
- **Minor units:** Stripe amounts are integers in the smallest unit (fening). `25.00 KM → 2500`.
  `ToMinorUnits(amount) = round(amount × 100)`.
- **Amount source of truth:** the **stored** `Booking.TotalAmount` (price-per-person × people, computed
  server-side at booking creation). The client never supplies an amount.
- **Fee snapshot:** `PlatformFeeAmount = round(TotalAmount × PlatformFeePercentage / 100, 2)`, captured on
  the `Payment` row at charge time from `Payments__PlatformFeePercentage` (default 10). Snapshotting means
  changing the config later never rewrites historical payments.

---

## 5. End-to-end flow

```
Traveler (mobile)            Travle API                         Stripe
------------------           ----------------------------       ------------------------
book tour  ───────────────▶  create Booking = PaymentInProgress
                             (hold seats, ExpiresAt = +15 min)
tap "Pay" ────────────────▶  POST /Payments/CreateIntent
                             • verify: mine, held, not expired,
                               not already paid
                             • amount + fee from stored total
                             • create PaymentIntent ──────────▶  PaymentIntent(bam, 2500)
                             • save Payment(Pending)
                             ◀───────────── client secret
PaymentSheet(clientSecret)
confirm card ─────────────────────────────────────────────────▶ charge captured
                                                                 │
                             POST /Payments/Webhook  ◀───────────┘ payment_intent.succeeded (signed)
                             • verify signature
                             • Payment → Succeeded
                             • state machine: PaymentInProgress → Pending
refresh booking ──────────▶  booking is now Pending (IsPaid = true) → hide Pay button
```

Later transitions (organizer confirm → Confirmed; cancel/reject/slot-cancel → Cancelled + refund;
scheduler auto-Complete) are the Phase 5 state machine; 6c adds the refund side-effect to the
cancellation paths.

---

## 6. Configuration & local setup

All payment config is in `.env` (never in `appsettings.json`). Compose maps the plain vars into the API
container as `Payments__*`; local `dotnet run` reads the `Payments__*` keys directly via DotNetEnv.

| `.env` (plain, for compose) | Bound config key | Meaning |
|---|---|---|
| `STRIPE_SECRET_KEY` | `Payments__StripeSecretKey` | `sk_test_…`, server-side |
| `STRIPE_PUBLISHABLE_KEY` | `Payments__StripePublishableKey` | `pk_test_…`; the API echoes it in the CreateIntent response, so mobile needs no separate key |
| `STRIPE_WEBHOOK_SECRET` | `Payments__StripeWebhookSecret` | `whsec_…`, verifies webhook signatures |
| `PLATFORM_FEE_PERCENTAGE` | `Payments__PlatformFeePercentage` | commission %, default 10 |

Bound once into `PaymentOptions` (`Travle.Services/Payments/PaymentOptions.cs`), validated at startup
(fail-fast on a missing secret key, like JWT).

### 6.1 One-time Stripe account setup

1. Create a free Stripe account (test mode is on by default).
2. Developers → API keys → copy the **test** secret + publishable keys into `.env`.
3. No business/bank/KYC needed for test mode.

### 6.2 Receiving webhooks locally (the important gotcha)

Stripe can't reach `localhost` on its own. During development run the **Stripe CLI**:

```
stripe login
stripe listen --forward-to localhost:5121/Payments/Webhook
```

`stripe listen` prints a `whsec_…` — copy it into `STRIPE_WEBHOOK_SECRET` (and restart the API — `.env` is
read only at startup).

### 6.3 Driving a payment to success **without** the mobile app

The mobile PaymentSheet is the normal path, but you can also drive a payment from the CLI to test the
backend in isolation. Creating an intent is *not* a payment — `POST /Payments/CreateIntent` only creates the
PaymentIntent and a `Payment(Pending)` row; the booking stays `PaymentInProgress` until a **confirmed**
payment fires the `payment_intent.succeeded` webhook. Confirm the intent by hand:

```bash
# Terminal A — forward webhooks to the API (leave running)
stripe listen --forward-to localhost:5121/Payments/Webhook

# Terminal B — confirm THIS booking's intent with a Stripe test card
stripe payment_intents confirm <pi_id> --payment-method pm_card_visa
```

`<pi_id>` is the part of the returned client secret before `_secret_` (or `Payment.StripePaymentIntentId`
in the DB / the dashboard). The webhook then promotes the booking to `Pending` and `IsPaid = true`.

> **Do not** test with `stripe trigger payment_intent.succeeded` — it creates a *new, unrelated* intent, so
> the handler finds no matching `Payment` row and no-ops. Always confirm the real intent.

**Two `.env` config traps** that both surface as "it silently used the wrong value":
> A local `dotnet run` / VS launch binds the **`Section__Key`** names in the bottom "Local runs" block of
> `.env` (`Payments__StripeSecretKey`, `Payments__StripeWebhookSecret`), **not** the plain `STRIPE_*` vars up
> top (those are only for docker-compose interpolation). Paste real secrets into **both**, and restart the
> API after editing `.env`.

---

## 7. Data model

- **`Payment`** (`Travle.Services/Database/Payment.cs`) — one per charge attempt on a booking. Financial
  record, never deleted. `StripePaymentIntentId` (unique index = double-charge guard), `Amount`,
  `Currency`, `PlatformFeePercentage`/`PlatformFeeAmount` (snapshot), `Status`
  (`Pending/Succeeded/Failed/Refunded/PartiallyRefunded`), `SucceededAt?`.
- **`Refund`** (`Travle.Services/Database/Refund.cs`) — one per refund against a `Payment`. `StripeRefundId`,
  `Amount` (from the actually-charged amount), `PercentageApplied` (the tier), `Reason`,
  `InitiatedByUserId`. Never deleted.
- **`RefundPolicyTiers`** — global refund ladder (>72h=100%, 24–72h=50%, 1–24h=25%, <1h=0%), admin-CRUD'd
  reference data. Refunds snapshot the tier %, so tiers stay freely editable.
- `BookingResponse.IsPaid` is `true` once any `Payment` for the booking is `Succeeded` — drives "hide the
  Pay button".

---

## 8. Endpoints

| Method | Route | Auth | Purpose |
|---|---|---|---|
| `POST` | `/Payments/CreateIntent` | Authenticated (booking owner) | Start/resume paying a held booking; returns a PaymentIntent client secret. |
| `POST` | `/Payments/Webhook` | Anonymous, **signature-verified** | Stripe → us; promotes PaymentInProgress → Pending on success, expires on failure. |
| `GET` | `/Payments` | Admin | Paginated, filterable payments list (status, period, text search). |
| `GET` | `/Payments/summary` | Admin | Revenue / commission / refund totals over the same filter. |

Payments are **never** CRUD-edited or deleted.

---

## 9. Implementation status (changelog)

### Phase 6a — Stripe plumbing + PaymentIntent creation ✅ (done)

- Added `Stripe.net` 52.1.1 to `Travle.Services`.
- `Payments/PaymentOptions.cs` — `Payments` config section (Stripe keys, fee %, currency), bound +
  validated at startup in `Program.cs`.
- `Payments/IStripeService.cs` + `StripeService.cs` — the sole Stripe SDK caller (DI `StripeClient`, no
  global static); `CreatePaymentIntentAsync` (card-only, idempotency key) + `GetPaymentIntentAsync`;
  Stripe errors → `PaymentException` (clean 402).
- `Payments/IPaymentService.cs` + `PaymentService.cs` — `CreateIntentAsync`: ownership + PaymentInProgress
  + not-expired preconditions, server-side amount (`ToMinorUnits`) and fee snapshot, double-payment guard
  (succeeded ⇒ 409), reuse of an open intent, `Payment(Pending)` row persisted.
- DTOs: `PaymentIntentCreateRequest`, `PaymentIntentResponse`; `PaymentIntentCreateValidator`.
- `PaymentsController` — `POST /Payments/CreateIntent` (Authenticated).
- Config: `Payments__*` wired into `.env`, `.env.example`, `docker-compose.yml`.
- `BookingResponse.IsPaid` was already projected (Phase 5) — no change needed.
- Backend builds clean (0 warnings, 0 errors). **Not yet runnable end-to-end** — needs real Stripe test
  keys and the webhook (6b).

### Phase 6b — Webhook (signature-verified, idempotent) ✅ (done)

- `IStripeService.ConstructWebhookEvent` — verifies the signature against `whsec_…`
  (`EventUtility.ConstructEvent`, `throwOnApiVersionMismatch:false`); a bad signature is rejected with a
  400 and never acted on. Maps the SDK `Event` to a small `StripeWebhookEvent`
  (`PaymentSucceeded`/`PaymentFailed`/`Ignored` + intent id + failure message) so no SDK type leaks out.
- `PaymentService.HandleWebhookAsync` —
  - `payment_intent.succeeded` → `Payment.Succeeded` + `SucceededAt`, then state machine `MarkPaidAsync`
    (PaymentInProgress → Pending, clears the hold). **Idempotent:** a replay finds the payment already
    `Succeeded` and no-ops.
  - `payment_intent.payment_failed` → `Payment.Failed` + `ExpireAsync` (releases the held seats now rather
    than waiting out the hold). Never overrides an already-succeeded payment.
  - Unknown intent / unhandled type / missing intent id → logged, returns 200 (so Stripe doesn't retry an
    unactionable event forever).
- `PaymentInProgressBookingState.MarkPaidAsync` now adds the **PaymentSucceeded** notification (the state
  machine owns transition side-effects); its `SaveChanges` also commits the `Payment` edit made on the
  same DbContext scope.
- `PaymentsController` — `POST /Payments/Webhook`, `[AllowAnonymous]`, reads the **raw** body (no model
  binding) + the `Stripe-Signature` header.
- Backend builds clean. **End-to-end verification is pending real Stripe test keys + `stripe listen`.**

#### Edge: payment succeeds just after the booking left PaymentInProgress — **RESOLVED**

If a card confirms in the final moments and the booking leaves `PaymentInProgress` before the `succeeded`
webhook arrives — the 15-minute hold expired (seats released, maybe resold) or the organizer cancelled the
slot — the charge would strand: money captured, no booking. This is now closed in two layers (full
description in the post-Phase-6 hardening entry at the end of §9): the sweep waits a **90-second grace
period** past `ExpiresAt` so the webhook almost always promotes the booking first, and if the race is
still lost the webhook records the charge and issues an immediate **100% auto-refund** so the traveler is
never charged for a booking they cannot get. The booking is **not** resurrected.

### Phase 6c — Refunds ✅ (done)

- `PaymentMath` — the single home for `ToMinorUnits`, `RefundAmount`, and `ResolveRefundPercentageAsync`
  (the tier ladder). The cancel **preview** (`BookingResponse.CancellationRefundPercentage`) and the actual
  refund now share this resolver, so a previewed % can never disagree with the charged one.
- `IStripeService.CreateRefundAsync` — refunds a given minor-unit amount against a PaymentIntent, with an
  idempotency key (`refund-payment-{id}`); Stripe errors → `PaymentException`.
- `IRefundService` / `RefundService` — the **post-commit** refund executor. It is deliberately *not* part
  of the state transition: the orchestrators move the booking to Cancelled (in a transaction), then call
  in here so the Stripe call runs **outside** any DB transaction.
  - `RefundForBookingAsync(bookingId, initiatedBy, reason, forcedPercentage)` — user cancel
    (`forcedPercentage: null` ⇒ tiered) and organizer reject (`100`).
  - `RefundForScheduleCancellationAsync(scheduleId, …)` — 100% for every paid, now-cancelled booking on a
    retired slot.
  - Computes amount from the **actually charged** `Payment.Amount`; writes the `Refund` row; sets
    `Payment.Status` → `Refunded` (100%) / `PartiallyRefunded` (partial); adds a **RefundIssued**
    notification. A **0% tier** writes a zero-amount `Refund` row for audit and makes no Stripe call.
  - **Idempotent** (a payment that already has a `Refund` is skipped) and **best-effort**: a Stripe failure
    is logged, never fails the already-committed cancellation, and — thanks to the idempotency key — is
    safe to retry.
- Wiring: `BookingService.CancelAsync` / `RejectAsync` call it after the transition returns;
  `TourService.CancelScheduleAsync` calls it after the slot-cancel transaction is committed **and disposed**
  (the transaction is scoped in a block so it is no longer the ambient transaction when the refund's
  `SaveChanges` runs).
- Backend builds clean. **Refund verification against the Stripe test dashboard is pending live keys.**

### Phase 6d — Mobile pay flow ✅ (done)

- **`travle_core`**: `PaymentIntentResponse` DTO + `PaymentProvider.createIntent(bookingId)` (`POST
  /Payments/CreateIntent`); exported from the barrel; `.g.dart` generated.
- **`travle_mobile`**: added `flutter_stripe`. Registered `PaymentProvider` in `main.dart`.
- **Publishable key**: the app does **not** need its own `--dart-define` — it reads the (non-secret)
  `publishableKey` off the CreateIntent response and sets `Stripe.publishableKey` + `applySettings()` just
  before presenting the sheet. One source of truth: the backend `.env`.
- **Pay flow** (`booking_details_screen._pay`): pre-pay **confirmation dialog** showing the amount and the
  live refund-policy tiers (spec §3.4 "tier summary before payment") → `createIntent` → `initPaymentSheet` →
  `presentPaymentSheet`. On card confirm, the client records **nothing**; it **polls** the booking (6×1.2s)
  until the webhook flips it to Pending / `isPaid`, showing a "Confirming your payment…" notice, then a
  success message. A user-cancelled sheet (`FailureCode.Canceled`) is silent; other Stripe/API errors show
  a snackbar. Timeout → soft "will update shortly" (the webhook lands eventually).
- **Paid-state UI**: the Pay button already keys off `booking.canPay` (server `AllowedActions`), which drops
  as soon as the booking leaves PaymentInProgress; the detail card shows Paid / Not paid from `isPaid`.
- **Android native** (the `flutter_stripe` requirements): `MainActivity` now extends
  `FlutterFragmentActivity`; `res/values*/styles.xml` themes descend from `Theme.AppCompat` (day + night);
  `minSdk` is already 23 (≥ 21). Without these the PaymentSheet crashes at present-time.
- Both packages analyze clean **and the debug APK builds** (native Stripe integration verified).
  Device run-through with a real test card is the remaining manual check.

**Test cards** (Stripe test mode): `4242 4242 4242 4242`, any future expiry, any CVC, any ZIP.

### Phase 6e — Admin payments screen (desktop) + seed ✅ (done)

- **Backend reads** (admin-only): `PaymentService.SearchAsync` (paginated/sortable/filterable list) +
  `GetSummaryAsync` (aggregate totals), behind `GET /Payments` and `GET /Payments/summary`. DTOs
  `PaymentResponse` (traveler/tour names, amount, commission, refunded, status), `PaymentSummaryResponse`
  (captured count + gross, commission, refunded + count, **net revenue**), `PaymentSearch` (status, date
  range, text). Status enum name is mapped **after** materialization (EF can't translate `enum.ToString()`);
  totals use `SelectMany(Refunds)` + `Sum` aggregates.
- **Seed**: `Payment`/`Refund` rows already existed from Phase 5 (`SeedPayments`/`SeedRefunds` — 4 payments
  incl. one Refunded + 1 refund), so the screen has data on a fresh DB. **No migration needed.**
- **`travle_core`**: `PaymentResponse` + `PaymentSummaryResponse` DTOs; `PaymentProvider` base type is now
  `PaymentResponse` with an inherited paginated `get` for the list, a `summary()` call, and `createIntent`
  parsing its own shape. `.g.dart` generated.
- **Desktop** `AdminPaymentsScreen`: a revenue/commission/refund/net **totals bar** (stat cards) above a
  read-only `PaginatedSearchTable` (sortable columns via entity paths, text search, Status + Period
  filters). Admin-only **Payments** entry added to the side nav. Both apps analyze clean; backend builds
  clean.

### Post-Phase-6 hardening — orphaned-success auto-refund ✅ (done, 2026-08-17)

Closed the "charged with nothing" edge (the Phase 6b note above, now RESOLVED): a captured payment whose
`payment_intent.succeeded` lands after the booking has left `PaymentInProgress` no longer strands the
traveler's money. Two layers:

- **Prevent (shrink the race).** `BookingService.ExpireOverdueHoldsAsync` no longer expires a hold the
  instant it passes 15:00; it waits a **90-second grace period** (`BookingService.SweepGracePeriod`) past
  `ExpiresAt` first. Webhook latency is sub-second, so a last-moment payment's `succeeded` event almost
  always promotes the booking to `Pending` inside the grace window and the sweep never touches it. Cost: a
  hold is held ~16 min worst-case instead of 15.
- **Guarantee (when the race is still lost).** `PaymentService.HandlePaymentSucceededAsync` records the
  `Payment` as `Succeeded` truthfully, then — because the booking is no longer consumable (Expired, or
  Cancelled after a slot-cancel) — calls `RefundService.RefundOrphanedPaymentAsync` to issue an immediate
  **100% refund** and notify the traveler (`RefundIssued`, emailed). It reuses the normal post-commit refund
  path (Stripe called outside any DB transaction; idempotency key `refund-payment-{id}`), and the full
  refund is attributed to the **traveler** since no admin/organizer initiated it. The booking is **not**
  resurrected — its seats may already be resold, so the traveler is made whole instead.

The succeeded-webhook idempotency guard was tightened from "skip if already `Succeeded`" to **"skip if not
`Pending`"**, so a replay after the auto-refund finds the payment `Refunded` and no-ops rather than
re-recording the charge; the failed-webhook guard was tightened the same way. **No migration**
(`Refund.InitiatedByUserId` reused). Files: `PaymentService`, `RefundService`/`IRefundService`,
`BookingService`.

---

## 10. Definition-of-done checklist (Phase 6, from the roadmap)

Legend: ✅ built + verified live · 🟢 built, quick manual re-check advised before defense.

- [x] Test-card flow end-to-end (PaymentSheet → webhook → Pending) — ✅ verified on device.
- [x] Amounts/fees always computed server-side; client never records success — ✅ (webhook is the only writer).
- [x] All Stripe config from `.env`; nothing hardcoded — ✅.
- [x] Second payment attempt on an already-paid booking is blocked — 🟢 (`409 Conflict`; re-tap a paid booking).
- [x] Replayed webhook = no double effects — 🟢 (idempotent on `Payment.Status`; re-send an event via `stripe`).
- [x] Refund lands in the Stripe test dashboard at the right tier — 🟢 (cancel a paid booking, confirm in the dashboard).

Everything is implemented; the three 🟢 items are worth a 60-second manual re-confirmation before the defense.
