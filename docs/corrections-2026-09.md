# Corrections — August 2026 review

Answers the nine mandatory items in the review of **IB230172**, for the
academic year 2025/26 resubmission.

This document is both the working tracker and the write-up: each finding records what was wrong, the
rule adopted to fix it, and where that rule now lives in the code. Kept up to date as the batches land.

| #   | Finding                                                 | Status  |
| --- | ------------------------------------------------------- | ------- |
| 1   | Payment could complete after the tour had started       | Done    |
| 2   | Missing time rules for `Pending` / `Confirmed` bookings | Done    |
| 3   | Refund amount re-decided on every retry                 | Done    |
| 4   | Refund policy validated per row, not as a scale         | Done    |
| 5   | Traveler visibility / bookability rules inconsistent    | Done    |
| 6   | `Organizer` role revocable with live tours and bookings | Done    |
| 7   | `IsDeletable` disagreed with the real delete rule       | Done    |
| 8   | No Print action on the PDF reports                      | Done    |
| 9   | No filter on the desktop notifications list             | Done    |

Two migrations, both additive and nullable:
`20260903171501_AddTourBookingCutoff`, `20260908160920_AddBookingCancellationSnapshot`.

---

## The rules introduced

Three ideas do most of the work, each kept in one place, so the fixes are consistent rather than nine
separate patches.

**`BookingTimeRules`** — every deadline in the booking lifecycle. There are two, both relative to
`TourSchedule.StartsAt`: the **booking cutoff** (bookings and payments close this long before
departure) and the **departure** itself (the wall for confirm / reject / cancel). Booking creation, the
payment hold, the Stripe webhook, the lifecycle sweeps, the schedule-creation guard and the capability
flags the apps render all read these, so no two paths can disagree about what "too late" means.

**The refund obligation is snapshotted, never recomputed.** The moment a booking is cancelled, the
cancelling transition freezes who cancelled it, when, and the percentage and amount owed — in the same
transaction as the status change. Every later execution, including an admin retry hours afterwards, pays
that stored figure.

**Capability flags come from the server.** Where the apps used to re-derive a rule locally
(`isDeletable`, `isBookable`, the allowed booking actions), the server now computes it from the same
condition it enforces and sends the verdict, with the reason when the answer is no.

---

## 1. Payment could complete after the tour had started

**Was:** `InitialBookingState.CreateAsync` refused a booking on a departed schedule but then set
`ExpiresAt` to a flat 15 minutes, unbounded by the departure — book one minute before a tour and the
payment hold stayed valid a quarter of an hour into it. `PaymentService.HandlePaymentSucceededAsync`
promoted a `PaymentInProgress` booking to paid `Pending` on the sole condition that it was still
`PaymentInProgress`; it never re-read `TourSchedule.StartsAt`.

**Now:** booking closes a configurable interval **before** departure (`Tour.BookingCutoffMinutes`, or
the platform default `Booking:DefaultCutoffMinutes`, two hours). The hold is clamped to
`min(now + 15 min, StartsAt − cutoff)`, so it can never outlive the cutoff. The webhook re-checks the
clock at the moment of promotion and accepts only while the hold is honoured (the same 90-second grace
the expiry sweep gives it) and the tour has not started. A charge that arrives too late is recorded
truthfully, the booking is expired so its seats are released, and the money is refunded in full through
the existing orphaned-payment path.

The cutoff is deliberately earlier than departure rather than exactly at it: it guarantees the organizer
real time to confirm or reject, and it makes the "payment lands on a running tour" race unreachable in
normal operation instead of merely handled.

**Organizers are held to the same rule.** `AddScheduleAsync` refuses a date starting inside its own
tour's cutoff — a schedule published already closed is a mistake worth catching where it is made.

## 2. Missing time rules for `Pending` and `Confirmed` bookings

**Was:** `ConfirmAsync`, `RejectAsync`, `CancelAsync` and `CancelByOrganizerAsync` never looked at
`StartsAt`, so a tour that ran last week could still be confirmed, rejected or cancelled — the last of
which released seats and owed a refund for a tour that had been delivered. Meanwhile the lifecycle
automation expired held payments and completed confirmed bookings, but nothing resolved a **paid
`Pending`** booking: if the organizer never acted, it stayed `Pending` through the departure and past the
end of the tour, indefinitely.

**Now:** all four transitions are gated at `StartsAt` by `BookingTimeRules.EnsureNotStarted`. A new
lifecycle sweep, `ResolveUnconfirmedPendingAsync`, cancels any booking still `Pending` at its departure
and refunds it **in full** — the traveler paid and was never accepted, so the money goes back; both
parties are notified. It runs before auto-completion, so an unconfirmed booking is never quietly
completed as though it had happened.

`ResolveAllowedActionNames` now takes the schedule's start and the hold's expiry, so the apps stop
offering buttons the server would reject, and the pre-cancellation refund preview keys off that same
list rather than re-testing the status.

Two related holes closed by the same rule: organizer suspension now cancels only **upcoming** bookings
(it was refunding tours travelers had already been on), and schedule cancellation was already guarded
this way — the booking-level transitions had simply never been given the same rule.

## 3. Refund amount re-decided on every retry

**Was:** `RefundService.IssueRefundAsync` resolved the tier against `DateTime.UtcNow` — the moment the
refund _executed_. When Stripe failed, no `Refund` row was written, so nothing about the obligation was
persisted anywhere, and `PaymentService.RetryRefundAsync` re-resolved the ladder against a new clock: the
same cancellation could drop from 50% to 25% because an admin retried it three hours later. Worse, the
retry inferred the percentage from _who_ cancelled (anyone but the traveler meaning 100%), while the
original admin-initiated cancellation went down the tiered path — so the first attempt and the retry of
one obligation carried different financial meaning.

**Now:** `Booking` carries `CancelledAt`, `CancellationSource`, `RefundPercentageOwed` and
`RefundAmountOwed`, written **once** by `BaseBookingState.SnapshotRefundObligationAsync` inside the
cancelling transition. Only a traveler's own cancellation is tiered; every other source is a full refund.
The amount is computed from the charge actually captured, because that is what Stripe can give back.

`RefundService` no longer decides anything — `IssueRefundAsync` is handed the percentage and amount and
executes them. `RefundForBookingAsync` lost its `forcedPercentage` parameter, and the inference inside
`RetryRefundAsync` is gone entirely. The obligation survives a failed Stripe call, so the admin payments
screen can now name the figure a retry will pay instead of describing it vaguely.

**Locked decision:** an admin cancelling on a traveler's behalf owes **100%**. One sentence then covers
the whole system — _the traveler is penalised only for their own decision_ — and it removes the
divergence the review identified.

`RefundOrphanedPaymentAsync` deliberately stays outside this: it is a payment-level remedy for money
captured against a booking that could not be honoured at all (often `Expired`, not `Cancelled`), so there
is no cancellation obligation to read.

## 4. Refund policy validated per row, not as a scale

**Was:** the insert and update validators checked one tier in isolation — minimum not negative, maximum
above minimum, percentage within 0–100. Nothing looked at the other rows, so an admin could create
overlapping intervals, leave an uncovered gap, or define several open-ended tiers. There was no delete
guard at all. `PaymentMath.ResolveRefundPercentageAsync` then resolved an overlap arbitrarily by sort
order and a gap silently to 0% — deciding real money with no error anywhere.

**Now:** `RefundPolicyLadder.EnsureContiguous` validates the scale the write would **produce**, from all
three `OnBefore*` hooks (insert, update and delete). The resulting tiers must start at 0 hours, meet
exactly with no gap and no overlap, and contain exactly one open-ended tier which must be the highest; at
least one tier must survive. So for every possible number of hours before departure there is exactly one
refund rule. Messages name the offending boundary.

**Consequence worth knowing:** deleting a tier is now usually refused, because removing a middle row
leaves a gap and removing the top row leaves no open end. That is the contiguity rule working as
specified — an admin widens a neighbour first.

## Refund policy editor (follow-on from #4)

Making the ladder contiguous had a consequence worth recording: it made the per-row reference CRUD screen
unusable. A ladder that tiles every hour before departure has no room for another row, so **every**
single-row edit to a valid policy is correctly refused — adding a tier overlaps a neighbour, deleting one
leaves a gap, and capping the top one removes the open end. The rule was right and the screen was now wrong.

The tiers are one aggregate, so they are now edited as one: `PUT /RefundPolicyTiers/ladder` replaces the
whole set in a transaction after validating it, and the console has a dedicated editor in place of the
generic CRUD screen. In it the boundary between two tiers is a single shared value, so a gap or an overlap
is not something an admin can express — moving a boundary moves both sides at once. That leaves two
structural actions, both of which preserve coverage by construction: **split** a tier at a new boundary and
**merge** a tier into the one below. Validation runs live against the same rules the server enforces.

The per-row endpoints remain and still enforce the ladder rule; they are simply no longer how the policy is
edited.

## 5. Traveler visibility and bookability were spelled out differently at each entry point

**Was:** four versions of one rule. Public search and `GetDetailAsync` hid a tour that was inactive, whose
organizer was suspended, or that had a stop back under moderation. `GetSchedulesAsync` checked only that the
slot was active and future. `InitialBookingState.CreateAsync` checked the slot, the tour's activation and the
organizer's suspension — but not whether the stops were still approved. So a tour could disappear from
search and detail while a remembered `scheduleId` remained enough to book it: unreachable and bookable at the
same time. Three more places had their own partial versions — the recommender re-hydrated cached destination
ids without re-checking approval, favorited destinations were not filtered at all, and the organizer's public
profile listed tours on activation alone.

**Now:** one `TravelerVisibility` class holds the condition — active, organizer not suspended, every stop
approved — and every entry point composes it: public search, the schedules endpoint (which now returns
nothing to a non-owner for a tour that is not traveler-visible), the booking guard, both favorites lists, the
recommender's final read, and the organizer profile. One condition to read, one to change, one to defend.

Organizer- and admin-facing reads deliberately do not apply it: an organizer must still see their own
deactivated or temporarily unavailable tour in order to act on it.

## 6. `Organizer` role revocable with live tours and bookings

**Was:** `RevokeRoleAsync` guarded self-lockout and the last-admin case, and nothing else. Removing Organizer
from someone with live tours left those tours active and bookable while their owner no longer passed the
role check on confirm and reject — so a traveler could pay for a seat nobody had the authority to confirm.

**Now:** the revoke is refused while the organizer has an active tour with upcoming dates, or an unresolved
booking on an upcoming date. The message names both counts and the two ways forward. Past tours and finished
bookings are irrelevant: the role governs what happens next, not what already happened.

See the decisions log for why this blocks rather than cascades.

## 7. `IsDeletable` disagreed with the real delete rule

**Was:** the flag was `active && future && SeatsTaken == 0`, but `DeleteScheduleAsync` additionally
refuses when **any** booking row exists, including cancelled and expired ones — which do not count
toward `SeatsTaken`. A slot that had once held an expired booking reported `IsDeletable: true`, the
desktop enabled Delete, and the server returned 409.

**Now:** the projection carries `BookingCount` (every booking row ever made on the slot) and the flag
uses it, matching `DeleteScheduleAsync` exactly. The response also carries `DeleteBlockedReason`, and the
console shows that server-authored sentence in its tooltip instead of a hardcoded local one, so the
explanation and the eventual error can never tell different stories.

## 8. No Print action on the PDF reports

**Was:** both reports offered only Download. `report_download.dart` saved the file and its snackbar offered
to open it in the OS viewer, where the user could then choose to print — and the file's own comment claimed
that satisfied "downloadable and printable". RS2 asks for Download *and* Print as two actions in the app, so
delegating to an external viewer did not meet it.

**Now:** `printReportPdf` hands the same bytes to the platform print pipeline via the `printing` package, and
each report has a Print button beside Download with its own busy flag. Nothing is written to disk on that
path, and the backend's QuestPDF output is printed exactly as it is downloaded — the generation and download
flows are untouched.

## 9. No filter on the desktop notifications list

**Was:** the list had paging, unread emphasis and Mark all as read, but no filter. The backend already
supported one — `NotificationSearch.IsRead` exists and `NotificationService.GetMineAsync` applies it — the
client simply never sent it.

**Now:** an All / Unread / Read control drives the fetch, alongside a debounced free-text search over a
notification's title and body (`NotificationSearch.Text`, applied with the shared accent-aware
`TextSearch.WhereContains`). Both filters live on the shared provider rather than the screen, so paging
preserves them and they compose; changing either refetches from page one, since the old page number belongs
to a different result set.

The search is beyond the review's ask. It earns its place because a notification is the only record of
several events — a refund, a rejection reason, a schedule cancellation — so being able to find one by what
it said is how an admin gets back to it once it has fallen off the first page.

Two details that decide whether it behaves: mobile shares this provider, so the filter is opt-in and mobile
is untouched; and a live SignalR push (always unread) is no longer prepended while the Read filter is
active, which would otherwise put a row on screen that the filter says is not there. The empty state also
distinguishes "nothing at all" from "nothing matches this filter".

---

## Decisions log

| Decision                             | Choice                            | Why                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------------------------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Unresolved `Pending` at departure    | Cancel with a 100% refund         | The traveler paid and was never accepted, and an unconfirmed seat cannot be honoured. Auto-confirming would hand out a place the organizer never agreed to.                                                                                                                                                                                                                                                                                                               |
| Admin-initiated cancellation         | 100%                              | Only the traveler's own decision is tiered. Makes the first attempt and any retry identical by construction.                                                                                                                                                                                                                                                                                                                                                              |
| Refund percentages | Must strictly increase with notice | A policy paying less for more notice would punish the behaviour it exists to encourage. Two adjacent tiers paying the same are one rule written twice, so they must be merged rather than duplicated. |
| Booking cutoff scope                 | Per tour, over a platform default | The lead time an organizer needs in order to confirm is a property of the tour. `null` uses the platform default, `0` keeps a date bookable until it starts.                                                                                                                                                                                                                                                                                                              |
| Revoking `Organizer` with live tours | Block and inform                  | **The cascading variant already exists as account suspension**, which deactivates the organizer's upcoming tours and cancels and refunds their outstanding bookings. Building a second cascade behind a role toggle would duplicate a working flow and hide a lot of irreversible work behind one click. The revoke therefore refuses while active future tours or unresolved bookings exist, and points the admin at deactivating those tours or suspending the account. |

## Configuration added

```json
"Booking": {
  "DefaultCutoffMinutes": 120
}
```

Platform-wide default, in minutes, for how long before a departure bookings and completed payments
close. A tour may override it; `0` keeps a date bookable right up to departure.
