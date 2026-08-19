# Time & Time Zones — Design and Build Log

Living document for how Travle handles time. Started 2026-08-19.

This file explains **how dates and times flow through the whole stack** — the database, the API wire
format, and both Flutter apps — and the one distinction that everything hinges on: **absolute instants**
vs **event times**. It is written to be read top-to-bottom by someone who has never seen the code.

> **Status convention.** Everything described here is in code unless marked **(planned)**. The build
> log at the bottom tracks what shipped when.

---

## 1. The mental model: two kinds of time

Every timestamp in Travle is stored as a **UTC instant**. But not every timestamp *means* the same kind
of thing, and that changes how it is **displayed**:

| Kind | Examples | Stored as | Displayed in |
|---|---|---|---|
| **Absolute / audit instant** | `CreatedAt`, `ModifiedAt`, booking `ExpiresAt` (the 15-min hold), `StatusChangedAt`, payment `SucceededAt`, notification `CreatedAt`, `SuspendedAt` | UTC instant | the **viewer's device** zone ("created 2 min ago", "expires in 12:30") |
| **Event time** | a tour schedule's `StartsAt` / `EndsAt`, and the booking's copy of them, `NextDepartureAt` | UTC instant | the zone of the **tour's destination**, labelled **"(local time)"** |

The reasoning:

- An **audit instant** is about *the viewer's own "now"* — "you booked this 5 minutes ago", "your hold
  expires at 14:32". It should read in the viewer's device zone.
- An **event time** is about *a physical event at a place*. A tour departs at 10:00 **at the
  destination**. A traveler in Tokyo planning to attend a Sarajevo tour needs to see **"10:00 Sarajevo
  time"**, because that's where they'll be standing when it starts — not "18:00 Tokyo time". So event
  times are shown in the **destination's** zone, the same for everyone, regardless of the viewer's
  device zone.

This is the opposite of the naïve "store UTC, convert to device-local everywhere" rule — and doing that
naïvely would actively mislead a traveler about when to show up.

---

## 2. Where a tour's zone comes from

A tour visits one or more **destinations** (ordered by `SortOrder`). A destination is located in a
**City**, and the zone lives on the city as an **IANA identifier**:

```
City.TimeZoneId  (e.g. "Europe/Sarajevo")   ← the source of truth
```

A tour's zone is resolved as **its ordered-first destination's city zone**:

```
TourSchedule → Tour → first TourDestination (by SortOrder) → Destination → City.TimeZoneId
```

- `City.TimeZoneId` is **required** (non-nullable). A migration backfills existing rows and the column
  has a DB default of `Europe/Sarajevo`, so every city always has a zone.
- Storing the zone on the **City** (not on each Destination) is the normalised realisation of
  "per-destination zone": a city sits in exactly one zone, so two destinations in the same city can't
  disagree, and it's still per-destination *in effect* (each destination resolves its own zone via its
  city).
- **`PLATFORM_TIMEZONE`** (env → `Time__PlatformTimeZoneId`, default `Europe/Sarajevo`) is the fallback
  used when a city somehow has no zone and the default the seeder/admin form pre-fills. Travle operates
  in Bosnia and Herzegovina, so every seeded city resolves to `Europe/Sarajevo`.

Admins set a city's zone in the desktop **Reference Data → Cities** form (an optional IANA-id text
field; blank inherits the platform default). A provided value is validated against the IANA database
server-side — a bogus id is rejected with a friendly message.

---

## 3. The write path (organizer picks a schedule time)

When an organizer adds a schedule slot on the desktop, they pick a **wall-clock** date + time. The
desktop builds a plain local `DateTime` and sends it over the wire with no zone marker — it represents
**"this wall-clock, at the destination"** (the picker is labelled *"Times are local to the tour's
destination."*).

The server (`TourService.AddScheduleAsync`) then:

1. Resolves the tour's zone (`ResolveTourTimeZoneAsync` — the chain in §2).
2. Interprets the picked wall-clock **as local to that zone** and converts it to a true UTC instant via
   `ITimeZoneService.ConvertLocalToUtc` (DST-aware).
3. Stores the UTC instant. `EndsAt = StartsAt(UTC) + durationMinutes` (UTC arithmetic → the true elapsed
   duration, correct even across a DST boundary).

Because the stored value is now a **real instant**, the lifecycle comparisons that were historically
skewed are exact: the "must start in the future" check, auto-complete of past-end bookings, the 24-hour
reminder, and — importantly — the **refund-tier** math (`>72h / 24–72h / 1–24h / <1h`), which compares
the schedule start against `DateTime.UtcNow`.

### DST edge cases

`ITimeZoneService` uses **NodaTime** (see §6) and resolves the two awkward wall-clocks **leniently**, so
the whole system behaves the same way:

- **Spring-forward gap** (a wall-clock that never happens, e.g. 02:30 on the switch night): **rolls
  forward** to the next valid instant (02:30 → 03:30).
- **Autumn fall-back ambiguity** (a wall-clock that happens twice): resolved deterministically to the
  **earlier** occurrence.

Why lenient (not a hard rejection): the Flutter picker builds a plain `DateTime(y,m,d,h,min)`, and Dart's
constructor **already normalises a non-existent local time forward** in the device's zone. So in the
common case (device zone = destination zone), the client never even *sends* a gap time — the backend
sees 03:30, not 02:30. Making the backend lenient keeps the rare cross-zone case (device zone ≠
destination zone) consistent with that same roll-forward instead of surprising the organizer with a
rejection. Either way, an organizer never schedules a real tour at 02:xx on the switch night.

### Duration across a DST boundary

`EndsAt = StartsAt(UTC) + durationMinutes` is a fixed **real** duration. Displayed in the destination
zone, a slot that *spans* a transition therefore shows a wall-clock span an hour off: a 3.5 h tour
starting **01:30 on the spring-forward night** ends at **06:00** local (4.5 h on the clock, because the
clock jumped 02:00 → 03:00), while a 3.5 h tour that doesn't cross the boundary shows 3.5 h. This is
**correct** — the tour is always the same number of real hours; only the clock moved.

---

## 4. The read path (display)

Responses carry the event time as a **UTC instant** plus the resolved **`timeZoneId`**:

- `TourScheduleResponse.TimeZoneId`, `TourResponse.TimeZoneId`, `BookingResponse.TimeZoneId` — all
  populated in the SQL projections from the resolution chain in §2 (coalescing to the platform default
  only if a tour somehow has no stops).

The Flutter apps convert the UTC instant to that zone for display. The single conversion point is
`travle_core`'s `time_display.dart`:

- `eventLocalTime(utcInstant, ianaZone)` → the wall-clock in that zone (falls back to device-local if
  the id is empty/unknown or the tz database isn't loaded). Used by `formatEvent*` in each app's
  `formatting.dart`, which append the **"(local time)"** label.
- `deviceLocalTime(instant)` → device-local, for audit timestamps.
- `asUtcInstant(instant)` → the true UTC instant a server value represents, for durations (the hold
  countdown).

Both apps call `initTravleTimeZones()` at startup (loads the bundled IANA database via the `timezone`
package) before any conversion runs.

The reminder **email** (composed server-side, in `BookingService`) shows the start converted to the
tour's zone and labelled "(local time)" — not "UTC", which it used to (mis)say.

---

## 5. The wire format (why every `DateTime` ends with `Z`)

SQL Server `datetime2` columns **don't persist `DateTimeKind`**, so a value read back from the database
arrives as `Unspecified`. With default `System.Text.Json`, an `Unspecified` `DateTime` serialises
**without** any zone marker (`"2026-08-17T10:00:00"`), while a value straight from `DateTime.UtcNow`
(Kind `Utc`) serialises **with** a `Z` — so the same field could go over the wire two different ways
depending on whether it round-tripped the DB. A client then has to guess, and `DateTime.parse` on a
marker-less string tags it **device-local**, silently shifting it by the device offset.

Travle removes the ambiguity: **`UtcDateTimeConverter`** (registered on both the MVC JSON options and
the SignalR JSON protocol) serialises **every** `DateTime` as a UTC instant with a `Z`
(`"2026-08-17T10:00:00.000Z"`), treating `Unspecified` as UTC (which it always is here). On the client,
`DateTime.parse` then always yields a true UTC value, and the old per-app `asUtc` reinterpretation hack
is gone — replaced by the explicit helpers in §4.

---

## 6. Why NodaTime (not `TimeZoneInfo`)

The API container is Linux; `TimeZoneInfo.FindSystemTimeZoneById("Europe/Sarajevo")` there reads the
OS's `/usr/share/zoneinfo` files, which a slim base image may not ship (`tzdata`). That would fail only
in the container, and only at runtime — exactly the "cold-machine `docker compose up`" path the project
is graded on. **NodaTime bundles its own IANA database**, so the conversion is identical on the
developer's Windows machine and in the container, with no OS dependency. `TimeZoneService` is stateless
and registered as a singleton.

On the client, the `timezone` package plays the same role (bundled IANA db, loaded once at startup).

---

## 7. Seed data

The `BulkSeeder` generates each schedule at a nice local departure hour (08:00–16:00) **at the platform
zone** and stores the true UTC instant it represents (`PlatformLocalToUtc`, lenient — the 08:00–16:00
range never lands on a DST transition), exactly mirroring the write path. So on a fresh
`docker compose up` every seeded slot displays back at those clean hours. Cities are created with the
entity default `Europe/Sarajevo`.

> **Existing dev databases.** A database seeded *before* this change holds old schedule values that were
> stored as raw wall-clock labelled UTC; after the change they'd display shifted by the offset. The fix
> is to reset/re-seed (drop the DB and let startup re-migrate + re-seed). Fresh runs are correct.

---

## 8. Never send a client clock in a filter (the "upcoming" toggle)

A time **filter** is a subtle version of the same trap. A query param like `fromDate=<client local now>`
gets bound server-side by `DateTime.Parse`, whose handling of a `Z`/offset depends on the *server's* zone
— so a client's local "now" (or even `.toUtc()`) can arrive off by the offset and silently exclude rows.
The schedule list's "hide past" toggle originally sent `fromDate: DateTime.now()`, which (in summer, +2)
hid every slot starting within the next ~2 h — including a just-created imminent one, even though it was
already bookable.

The rule: **don't ship a client instant for a "from now" filter — ship intent.** The toggle now sends a
boolean `upcomingOnly: true`, and the backend filters `StartsAt > DateTime.UtcNow` server-side. A boolean
has no zone to misbind, so it's correct regardless of client or server zone.

---

## 9. What deliberately did **not** change

- **Booking creation** sends no time from the client (the traveler picks a schedule *slot* by id).
- **The 15-minute hold** was already pure UTC instant math (`ExpiresAt = DateTime.UtcNow.AddMinutes(15)`,
  expired when `ExpiresAt <= DateTime.UtcNow`, countdown via `asUtcInstant(...).difference(now.toUtc())`)
  — UTC has no DST, so a hold is always exactly 15 real minutes, even across a transition.
- **A 0% refund** (user cancels <1 h before start) still writes a `Refund` row (`Amount = 0`,
  `PercentageApplied = 0`) — silently, with no Stripe call and no notification. It's an audit record that
  the cancellation was processed at the 0% tier, not a bug.
- **Audit stamps** are still set centrally in `TravleDbContext.SaveChanges` via `DateTime.UtcNow`.
- **All backend code** uses `DateTime.UtcNow` only (no `DateTime.Now`, no `TimeZoneInfo`).

---

## 10. Build log

**2026-08-19 — Time model reworked (event times → destination zone).**
- **Backend:** `City.TimeZoneId` (IANA, required, DB default `Europe/Sarajevo`) + migration
  `AddCityTimeZoneId`; `TimeOptions` (`PLATFORM_TIMEZONE` → `Time__PlatformTimeZoneId`) + NodaTime-backed
  `ITimeZoneService` (`ConvertLocalToUtc` with strict DST resolution, `ConvertUtcToZone`, `IsKnownZone`).
  Zone-aware schedule write path (replaced the old blind `NormalizeToUtc`). `TimeZoneId` added to
  `TourScheduleResponse` / `TourResponse` / `BookingResponse` and populated in the tour/schedule/booking
  projections. Reminder email localised to the tour's zone. `UtcDateTimeConverter` registered on MVC +
  SignalR so every `DateTime` ships as `…Z`. City DTOs/validators + `CityService` map overrides (default
  + validate the zone). `BulkSeeder` stores schedule instants via `PlatformLocalToUtc`. NodaTime 3.3.3.
- **Flutter:** `timezone` package in `travle_core`; `time_display.dart` (`eventLocalTime`,
  `deviceLocalTime`, `asUtcInstant`, `initTravleTimeZones`); `timeZoneId` on the four DTOs (build_runner);
  `formatEvent*` helpers in both apps' `formatting.dart`; retired the per-app `asUtc`. Event-time display
  sites (tour details, booking details/card, tour card, desktop schedules dialog + organizer tours +
  booking review card) now show the destination zone with "(local time)". Desktop City CRUD gained an
  optional zone field; the schedule picker notes times are destination-local. `initTravleTimeZones()`
  wired into both `main.dart`.
- All backend builds clean; all three Flutter packages analyze clean. Not yet device-tested.

**2026-08-19 — Follow-up after device testing.**
- **Fixed:** the schedule "hide past" toggle hid imminent (<offset) slots. Root cause: it sent
  `fromDate: DateTime.now()` (client local), bound server-side and compared against UTC-stored `StartsAt`.
  Replaced with a server-side `UpcomingOnly` flag (`StartsAt > DateTime.UtcNow`). See §8.
- **Changed:** `ConvertLocalToUtc` DST resolution from strict (reject the spring-forward gap) to
  **lenient** (roll forward), matching the Flutter client's own `DateTime` normalisation. See §3.
- **Confirmed correct (no change):** a fixed-duration slot spanning a DST transition shows a wall-clock
  span ±1 h (§3, "Duration across a DST boundary"); a 0% refund writes a silent `Refund` row (§9).
- **Noted (out of scope):** a Stripe idempotency-key collision surfaced during re-seed testing — the key
  `pi-booking-{id}-{paymentCount}` is deterministic from booking id, so it clashes with Stripe's 24 h
  memory of the same key + a different amount after a DB re-seed. Unrelated to time; tracked separately.
- **Added:** a searchable IANA **time-zone picker** for the desktop City form (new
  `CrudFieldKind.timezone` → `RawAutocomplete` over `allTimeZoneIds()` from the bundled tz database, with
  client-side validation that a non-empty value is a real id). `TravleTextField` gained a `focusNode`
  param. No backend/API change — the server already validates + defaults the zone.
