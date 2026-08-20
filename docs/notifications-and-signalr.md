# Notifications & Real-Time (SignalR) — Design and Build Log

Living document for Phase 9 (Notifications & real-time). Started 2026-07-31.

This file explains **how the notification system works** end to end: the data, the three delivery
channels, the SignalR hub, the email bridge, the 24-hour reminder scheduler, and the Flutter client.
It is written to be read top-to-bottom by someone who has never seen the code.

> **Status convention.** Sections describing behaviour already in code are written in the present
> tense. Sections marked **(planned)** describe intended behaviour not yet merged; they are edited to
> present tense as each Phase 9 sub-phase lands. The build log at the bottom tracks what shipped when.

---

## 1. The mental model: one event, three channels

When something happens that a user should know about — an organizer confirms a booking, a refund is
issued, an admin approves a destination — the platform reacts on **up to three independent channels**.
They are **complementary legs of a single event**, not alternatives:

| Channel | What it is | Durability | Job |
|---|---|---|---|
| **DB `Notification` row** | a persisted record in SQL Server | permanent (survives restarts, reconnects, everything) | the **source of truth**; the client loads it via REST whenever the notification centre opens |
| **SignalR push** | a live message over a WebSocket to the user's connected device | ephemeral, best-effort — delivered only if the user is connected *right now* | the instant "tap on the shoulder" so the unread badge lights up without a manual refresh |
| **RabbitMQ → Worker → email** | a durable queue message consumed by a separate container that sends SMTP mail | durable (queue persists, manual ack, redelivery) | offload the slow email side to a separate process, for the subset of events the spec says must email |

The key design principle: **the DB row is authoritative; SignalR is a live nudge; RabbitMQ is durable
offload.** Because the row is always written first (inside the same transaction as its cause), a dropped
socket or an unconnected client never *loses* a notification — it is simply displayed on the next REST
load instead of appearing live. This is why SignalR is allowed to be un-durable.

### 1.1 Why SignalR for the live push, and not "just RabbitMQ"?

A reasonable question, since both enqueue a message and (hopefully) deliver it. The distinction is **not**
sync vs async — both are asynchronous transports. It is **who the counterparty is** and **what delivery
guarantee you want**:

| | RabbitMQ | SignalR |
|---|---|---|
| **Talks between** | server ↔ server (API → Worker) | server → a specific end-user's device |
| **Counterparty** | a trusted, long-lived backend process | an untrusted phone/desktop that connects, disconnects, roams behind NAT |
| **Delivery** | durable, persisted, ack'd, redelivered | best-effort to whoever is connected *now*; nothing stored |
| **Auth** | broker credentials, backend-only | integrates with the app's JWT — every connection is an authenticated user |
| **Role here** | offload slow work (email) to a separate container | light up the badge instantly, no refresh |

A Flutter client *should not* be a RabbitMQ consumer: there is no per-user auth story, it would mean
handing broker credentials to every phone, and each device would need to hold an AMQP connection with
its own queue. That is not what a message broker is for. SignalR exists for exactly the "push to *this
logged-in user's* screen, now" problem — it rides on the ASP.NET Core auth pipeline, addresses a user by
a server-derived group, and handles reconnection/transport fallback for a device that comes and goes.

Conversely, SignalR is the wrong tool for the email side: email must not be lost if the sending process
is briefly down, so it goes through RabbitMQ's durable queue with manual ack and redelivery (the
existing worker pipeline — see `EMAIL-RABBITMQ-SMTP` notes and the worker project).

---

## 2. The data: `Notification`

`Travle.Services/Database/Notification.cs` (unchanged in Phase 9 — the entity was already complete):

| Field | Meaning |
|---|---|
| `UserId` | recipient; the row cascades from the user |
| `Title`, `Text` | display copy (≤200 / ≤1000 chars) |
| `Type` | a `NotificationType` enum value — drives the UI icon/grouping and the email subject |
| `IsRead`, `ReadAt` | read/unread state (constraint N) |
| `RelatedEntityId` | optional deep-link target (e.g. a booking id), interpreted per `Type` |
| `CreatedAt` | timestamp (constraint N); the client shows it as relative time in local zone |

Index on `(UserId, IsRead)` backs the unread-count and unread-filter queries. **No schema migration is
required for Phase 9**: new `NotificationType` values are just new integers, and the 24-hour reminder
de-duplicates against existing rows rather than adding a "reminded" column.

### 2.1 `NotificationType` catalog

Existing values plus the three added in Phase 9 and the batch added in the ripple-events hardening pass
(all stored as `int`; adding values is not a schema change):

`General, BookingConfirmed, BookingRejected, BookingCancelled, BookingExpired, BookingReminder,
BookingCompleted, PaymentSucceeded, RefundIssued, DestinationApproved, DestinationRejected,
RoleApplicationApproved, RoleApplicationRejected, ReviewReceived, AccountSuspended, ScheduleCancelled,
ReviewRemoved` **+ (Phase 9) `BookingPlaced`, `RoleApplicationSubmitted`, `DestinationSubmitted`**
**+ (post-P10) `AccountCreated`, `RoleGranted`, `RoleRevoked`, `PasswordChanged`**
**+ (ripple-events hardening, 2026-08-17) `DestinationUnavailable`, `DestinationAvailable`,
`AccountReinstated`, `DestinationFeatured`, `TourUpdated`, `RefundFailed`** (ints 24–29).

Two of the new events deliberately **reuse** an existing type rather than mint their own, because from the
recipient's side the outcome is identical: a booking cancelled by an **organizer suspension** reuses
`ScheduleCancelled` (the traveler's tour won't run, full refund), and low-key engagement notes (a curator's
destination picked up by a new tour; an admin removing a pending submission; a traveler's own-cancellation
confirmation) reuse `General` / `BookingCancelled`.

---

## 3. Backend architecture

### 3.1 The problem: commit the row *inside* the transaction, push *after* it

A notification row must be written **inside the same transaction** as the thing that caused it — a
booking that rolls back must not leave a "your booking is confirmed" row behind. But the SignalR push and
the email must fire **only after** that transaction has committed — you must never tell a user something
happened and then have it un-happen.

The interim pattern (pre-Phase-9) got the first half right: services called a local helper that did
`DbContext.Notifications.Add(...)` and left it **unsaved**, so the row committed with the caller's
`SaveChangesAsync`. But there was no second half — nothing pushed or emailed.

### 3.2 The solution: a dispatcher with a deferred flush ("outbox-lite")

**`INotificationDispatcher`** (scoped, `Travle.Services/Notifications/`) replaces the three ad-hoc helpers with two methods:

- **`Enqueue(userId, type, title, text, relatedId?, alsoEmail?)`** — stages the `Notification` on the
  `DbContext` (unsaved, exactly as today) **and** records a pending push in a per-request buffer. Called
  from inside the business transaction. Does *not* push or email.
- **`FlushAsync(ct)`** — called **after** the transaction has committed. For each buffered notification
  (now persisted, so it has its `Id`/`CreatedAt`): push it to the recipient's SignalR group; then, for the
  `alsoEmail` subset, batch-load recipient email/name in a single query and publish one
  `NotificationEmailMessage` per recipient to RabbitMQ. Then clear the buffer.

Because the buffer holds references to the tracked entities, `FlushAsync` reads their populated `Id`s
without re-querying. This is an in-memory "outbox": simpler than a persisted outbox table (which would be
overkill here) and sufficient because the **row** is already durable — only the live push/email are
best-effort.

### 3.3 Triggering the flush

- **HTTP flows:** a single global `IAsyncActionFilter` (`NotificationFlushFilter`, registered in
  `AddControllers`) awaits the action, and if it did not throw, resolves the scoped dispatcher and calls
  `FlushAsync`. One registration covers every controller; no call site has to remember to flush. If the
  action threw, the filter skips the flush (the row, if the transaction had committed before the throw,
  still shows up on the next REST load).
- **Background flows:** the in-process `BookingLifecycleWorker` runs outside MVC, so after its sweep
  (expiry / auto-complete / **24-hour reminder**, all of which `Enqueue` + `SaveChangesAsync`) it resolves
  the scope's dispatcher and calls `FlushAsync` explicitly. The 24-hour reminder is folded into this same
  worker rather than a separate service.

### 3.4 Read API

`NotificationService` + `NotificationsController`, all `[Authorize(Authenticated)]`, user id always from
the JWT (never from route/body — constraint J):

| Endpoint | Purpose |
|---|---|
| `GET /Notifications` | paged list (`NotificationSearch`: `IsRead`, `Type`, plus base paging; max page size 100), newest first |
| `GET /Notifications/unread-count` | badge count (`NotificationUnreadCountResponse`) |
| `PUT /Notifications/{id}/read` | mark one read (idempotent; 404 if not the caller's) |
| `PUT /Notifications/read-all` | mark all the caller's unread notifications read (bulk `ExecuteUpdate`) |

The list projects `NotificationResponse` (the `Type` enum mapped to its **name**, never the raw int).

---

## 4. The SignalR hub

- **Endpoint:** `/hubs/notifications`, mapped after auth in `Program.cs` via `AddSignalR()` +
  `MapHub<NotificationHub>(...)`.
- **Auth over WebSocket:** browsers/native WS clients cannot send an `Authorization` header on the socket
  handshake, so the SignalR client sends the JWT as an `access_token` **query-string** parameter. The JWT
  bearer options add an `OnMessageReceived` event that reads `access_token` for requests to the hub path
  and feeds it to the normal token validation. Everywhere else, the header path is untouched.
- **Groups & membership:** on `OnConnectedAsync`, the hub adds the connection to a group named
  `user-{userId}`, where `userId` comes **from the validated JWT claims — never from client input**. The
  server only ever pushes to `user-{recipientId}`. A client therefore *cannot* subscribe to another
  user's stream: there is no client-callable "join group" method, and the only group it is ever in is the
  one derived from its own token. This is what satisfies constraint J ("SignalR hubs verify membership").
- **Server → client method:** the server invokes a single client method, **`NotificationReceived`**
  (`SignalRNotificationPush.NotificationReceived`), carrying the `NotificationResponse` payload. The client
  registers a handler for that exact name to render the live notification and bump its badge. No
  client → server methods exist (`NotificationHub` has no invokable methods, only `OnConnectedAsync`).

---

## 5. The email bridge

Per the decision to keep email DRY, there is **one** generic email kind rather than a template per event:

- `MessagingConstants.EmailType.Notification` + a `NotificationEmailMessage` contract in
  `Travle.Model/Messaging/` (recipient email/name, subject, title, body).
- On flush, the dispatcher batch-loads the flagged recipients' addresses, sets the subject to
  **`"Travle — {Title}"`**, and publishes via `IEmailPublisher.PublishNotificationAsync`. The worker's new
  `EmailType.Notification` case renders one clean template from title + body. New email-worthy events need
  no worker change — they just pass `alsoEmail: true` to `Enqueue`.

Which events email is defined by the catalog in §7 (the spec §5 subset: booking confirmation, status
changes, application results, refund confirmations, 24-hour reminders). Password-reset email remains its
own existing type.

---

## 6. The 24-hour reminder

`BookingService.SendDueRemindersAsync(windowHours)` — called every tick by `BookingLifecycleWorker`
alongside expiry/auto-complete — finds **Confirmed** bookings whose schedule starts within the window and
that have **no existing `BookingReminder` notification** for that booking (a `NOT EXISTS` correlated
subquery, so no N+1), and for each `Enqueue`s a `BookingReminder` (in-app + email) then `SaveChangesAsync`.
The worker `FlushAsync`es once after the sweep. The "no existing reminder row" check is the idempotency
guard — no extra column, survives restarts.

**Window / demo:** the window is `BookingReminder:WindowHours` (`BookingReminderOptions`, default **24**).
Seed schedule dates are static, so a true 24-hour reminder can't be pre-seeded; to demo live, either book
a schedule that starts within 24 h, or temporarily widen `WindowHours` (e.g. via the `.env` /
`BookingReminder__WindowHours` env var) so all upcoming Confirmed bookings are reminded on the next tick.

---

## 7. Event catalog — who gets notified, on which app, by which channel

Traveler + Curator use the **mobile** app; Organizer + Admin use the **desktop** app. "Email" marks the
events that also enqueue a worker email (spec §5). "State" is relative to the start of Phase 9.

### Traveler (mobile)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| Payment succeeded → booking Pending | `PaymentSucceeded` | ✓ | – | wired |
| Organizer confirmed the booking | `BookingConfirmed` | ✓ | ✓ | wired (+email) |
| Organizer rejected the booking | `BookingRejected` | ✓ | ✓ | wired (+email) |
| 15-minute hold expired | `BookingExpired` | ✓ | – | wired |
| Payment declined (card failed) | `BookingExpired`¹ | ✓ | – | **ripple** |
| Booking auto-completed (leave a review) | `BookingCompleted` | ✓ | – | wired |
| Own booking cancelled (confirmation) | `BookingCancelled` | ✓ | – | **ripple** |
| Organizer cancelled this confirmed booking | `BookingCancelled`³ | ✓ | ✓ | wired (+email) |
| Organizer cancelled the slot | `ScheduleCancelled` | ✓ | ✓ | wired (+email) |
| Organizer **suspended** → booked tour cancelled | `ScheduleCancelled`² | ✓ | ✓ | **ripple (+email)** |
| A tour you booked was updated (itinerary/name) | `TourUpdated` | ✓ | – | **ripple** |
| A tour you **saved** added a new date | `TourUpdated` | ✓ | – | **ripple** |
| Refund issued | `RefundIssued` | ✓ | ✓ | wired (+email) |
| Refund delayed (an automatic refund failed) | `General` | ✓ | – | **ripple** |
| 24-hour pre-tour reminder | `BookingReminder` | ✓ | ✓ | wired (+email) |
| Role application approved/rejected | `RoleApplication…` | ✓ | ✓ | wired (+email) |
| Own review removed by admin | `ReviewRemoved` | ✓ | – | wired |

³ Same type as a traveler's own cancellation, with organizer-specific copy ("Booking cancelled by the
organizer", the reason, and a promised full refund) and emailed — unlike the self-cancel confirmation,
this is news the traveler did not cause.

¹ Same type as a lapsed hold, but a distinct title/body ("Payment failed", not "hold expired") — a card
decline immediately expires the hold, and the message says so. ² Reuses `ScheduleCancelled` because the
traveler's outcome is identical (their booked tour won't run, full refund).

### Curator (mobile)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| Destination approved/rejected | `Destination…` | ✓ | ✓ | wired (+email) |
| New review on my destination | `ReviewReceived` | ✓ | – | wired |
| My destination was **featured** | `DestinationFeatured` | ✓ | – | **ripple** |
| My destination was picked up by a new tour | `General` | ✓ | – | **ripple** |
| My pending destination was removed by an admin | `General` | ✓ | – | **ripple** |
| Own review removed by admin | `ReviewRemoved` | ✓ | – | wired |
| Role application decisions | `RoleApplication…` | ✓ | ✓ | wired |

### Organizer (desktop)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| New booking awaiting confirmation | `BookingPlaced` | ✓ | – | wired |
| A traveler cancelled a booking | `BookingCancelled` | ✓ | – | wired |
| New review on my tour | `ReviewReceived` | ✓ | – | wired |
| A destination on my tour became **unavailable** | `DestinationUnavailable` | ✓ | – | **ripple** |
| A destination on my tour is **available again** | `DestinationAvailable` | ✓ | – | **ripple** |

The two destination-availability events fan out to the **distinct organizers whose tours visit the
destination** (a `TourDestinations → Tour.OrganizerId` query, deduped), excluding the editor. They fire when
a destination leaves the published catalogue (an approved destination edited back to Pending) and when it
re-enters it (re-approval) — since either ripples through every tour built on it. Rejection needs no separate
event: a destination only reaches a tour by being approved first, so its organizers were already told
"unavailable" at the edit-to-Pending step.

### Admin (desktop)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| New role application submitted | `RoleApplicationSubmitted` | ✓ | – | wired |
| New / edited destination pending moderation | `DestinationSubmitted` | ✓ | – | wired |
| **Refund failed — action needed** (owed to a traveler) | `RefundFailed` | ✓ | ✓ | **ripple (+email)** |
| Account suspended (sent to the suspended user) | `AccountSuspended` | ✓¹ | ✓ | wired |
| Account **reinstated** (sent to the reinstated user) | `AccountReinstated` | ✓ | ✓ | **ripple (+email)** |

¹ Email is the channel that actually reaches a just-suspended (or -reinstated) user — their session is
revoked while suspended, so an in-app row alone might never be seen. The in-app row is still written for
transparency. Admin fan-out events (`RoleApplicationSubmitted`, `DestinationSubmitted`, `RefundFailed`) go to
**all** users holding the Admin role via `NotificationRecipients.AdminUserIdsAsync` (one query on `UserRoles`).

---

## 8. The Flutter client

Both apps are Flutter, so the whole realtime + data mechanism lives **once in `travle_core`**; each app
only renders its own bell + centre. Both the mobile (traveler/curator) and the desktop (organizer/admin)
UIs are built on that shared core.

### 8.1 Shared core (`travle_core`)

- **`realtime/notification_realtime_service.dart`** — wraps `signalr_netcore`'s `HubConnection` to
  `{BASE_URL}hubs/notifications`, authenticating with `accessTokenFactory: () => AuthProvider.accessToken`
  (SignalR appends it as the `access_token` query param, matching the API's bearer wiring). It registers a
  handler for the server's `NotificationReceived` method and calls back into the provider.
  `withAutomaticReconnect` covers transient drops; `connect()` is idempotent so it doubles as a retry.
- **`providers/notification_provider.dart`** — `extends BaseProvider<NotificationResponse>`, so the REST
  verbs, the auth header, and the 401→refresh→retry pass come for free. Holds the loaded list + the unread
  count; `loadFirstPage` / `loadMore` page the list, `refreshUnreadCount` drives the badge, `markRead` /
  `markAllRead` update optimistically then confirm server-side, and `_onPushed` prepends a live push +
  bumps the badge. **`syncAuth(isAuthenticated)`** ties it to the session: connect the socket + prime the
  badge on sign-in, tear everything down on sign-out (idempotent, so repeated calls are safe). It also
exposes a broadcast **`pushes`** stream so an app can react to individual push types beyond the list/badge
(used by the mobile shell — see §8.2).
- **`models/notification_response.dart`** (+ generated `.g.dart`) — the client mirror of the backend
  `NotificationResponse`; the exact same JSON shape arrives from REST **and** from SignalR, so both build
  it identically. Includes a `copyWith` for the optimistic mark-as-read.
- **`network/base_provider.dart`** — gained **`putAction(subPath, [body])`** (mirrors `postAction`) for the
  `{id}/read` and `read-all` routes.
- **`travle_core.dart`** / **`pubspec.yaml`** — barrel exports for the model + provider; the
  `signalr_netcore` dependency.

### 8.2 Mobile UI (`travle_mobile`)

- **`main.dart`** — registers the provider with a
  `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>` whose `update` calls `syncAuth`, so the
  socket follows the session automatically.
- **`widgets/notification_bell.dart`** — the app-bar bell; a Material `Badge` shows the live unread count
  (`context.select` on the provider); tap opens the centre. Mounted in
  **`layouts/bottom_nav_shell.dart`**'s `AppBar.actions`.
- **`screens/notifications_screen.dart`** — the centre: the list (type icon, bold-while-unread title,
  truncated body, relative time, unread dot), pull-to-refresh, infinite scroll, and an always-visible
  "mark all as read" app-bar action (disabled with a reason when nothing is unread) guarded by a
  confirmation dialog. A row opens the detail (it does **not** jump straight to the entity).
- **`screens/notification_detail_screen.dart`** — the full view of one notification: the complete,
  untruncated body (so a rejection reason / cancellation note is never cut off), the type, the exact local
  time, and the read state. Opening it marks the notification read; when it carries a `relatedEntityId` of
  a navigable type, a **"View booking" / "View destination"** button deep-links there. All notification
  navigation lives here.
- **`layouts/bottom_nav_shell.dart`** — besides hosting the bell, it subscribes to the provider's
  `pushes`. On a `RoleApplicationApproved` push that granted a **mobile** role the current token lacks
  (Curator — which unlocks submitting destinations), it force-logs-out via a "sign in again" dialog, so the
  next sign-in issues a JWT carrying the role and the app's permissions update. Becoming an **Organizer** (a
  desktop role) grants nothing on mobile, so it's ignored. The role check is `AuthProvider.newlyGrantedRoles()`,
  which diffs `/Access/Me`'s live DB roles against the token's. This is the SignalR-triggered resolution of
  the long-deferred "force re-login after a live role grant" item — impossible before the hub existed
  (approving a role revokes refresh tokens, but the stateless access token stayed valid for up to its
  lifetime, so the new role only appeared after natural expiry).
- **`util/notification_display.dart`** — shared presentation helpers keyed on the backend type name:
  `notificationIcon`, `notificationIsNegative` (error vs primary color), `notificationTypeLabel`
  (`"BookingConfirmed"` → `"Booking Confirmed"`), and the time formatters (both reinterpret the server's
  UTC-wall-clock timestamp via `asUtc` before display).

### 8.3 Flutter ↔ backend correspondence

What on the client talks to what on the server:

| Flutter (client) | Backend | Carries |
|---|---|---|
| `NotificationResponse` model | `Travle.Model/Responses/NotificationResponse` | identical JSON (REST **and** push) |
| `NotificationRealtimeService` → `HubConnection("…hubs/notifications")` + `accessTokenFactory` | `NotificationHub` @ `/hubs/notifications` + JWT `access_token`-in-query wiring (`Program.cs`) | the authenticated WebSocket |
| `.on('NotificationReceived', …)` | `SignalRNotificationPush.NotificationReceived` → `Clients.Group("user-{id}")` | the live push payload |
| `NotificationProvider.loadFirstPage/loadMore` → `get('Notifications')` | `NotificationsController` `GET /Notifications` (`NotificationService`) | the paged list |
| `refreshUnreadCount` → `getAction('unread-count')` | `GET /Notifications/unread-count` | the badge count |
| `markRead` → `putAction('{id}/read')` | `PUT /Notifications/{id}/read` | mark one read |
| `markAllRead` → `putAction('read-all')` | `PUT /Notifications/read-all` | mark all read |
| `notificationIcon` / `notificationTypeLabel(type)` | `NotificationType` enum **name** in the DTO | type → icon/label |
| detail screen `_openRelated` (booking/destination) | `Notification.RelatedEntityId` | the deep-link target |

### 8.4 Desktop UI (`travle_desktop`)

The management app reuses the **identical** `travle_core` core; only the shell and the deep-link targets
differ.

- **`main.dart`** — the same `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>` wiring.
- **`widgets/notification_bell.dart`** — bell + live badge, mounted in the **top bar** of
  **`layouts/side_nav_shell.dart`** (right-aligned beside the section title). It forwards an
  `onNavigateToSection` callback.
- **`screens/notifications_screen.dart`** — the centre, width-constrained for desktop; same
  list / pull-to-refresh / paging / mark-all-with-confirmation as mobile.
- **`screens/notification_detail_screen.dart`** — the same full detail, but its "view related" **jumps to
  the relevant side-nav section** (Tour Bookings, Tour Reviews, Role Requests, Destinations) rather than
  pushing an entity page. Desktop's management screens are shell-embedded lists (not pushable by id), so
  the detail calls `onNavigateToSection(key)` then pops the overlays and the shell switches its
  `_selectedKey`. Defines the `NavigateToSection` typedef and the type→section map.
- **`util/notification_display.dart`** — desktop's copy of the display helpers (icons/labels/times), on the
  desktop `formatting.dart` (`asUtc` added there for parity with mobile).

**The one deliberate divergence from mobile:** mobile deep-links to the exact **entity** (booking/destination
detail pages exist there); desktop deep-links to the **section** where the item is actioned (the shell has
no per-record pages). Everything else — the core, the bell, the centre, the detail, mark-all — is the same.

---

## 9. Reliability & failure modes

- **Client offline / socket down:** the row is committed; the client shows it on the next REST load. No
  loss.
- **API crashes between commit and flush:** the row is committed; the live push and (if any) the email
  enqueue for that one event are lost. The row still surfaces on next REST load. This is the accepted
  cost of the in-memory outbox; a persisted outbox is deliberately out of scope for a project of this
  size. (Note this is *not* the DoD's "kill the worker, lose nothing" case.)
- **Worker down / restarting:** email messages sit in the **durable** RabbitMQ queue and are consumed
  with manual ack + exponential-backoff retry when the worker returns — this is the "kill the worker
  mid-queue, lose nothing" guarantee, already provided by the existing worker.
- **Duplicate reminders:** prevented by the "no existing `BookingReminder` row" guard.

---

## 10. Constraint mapping

- **Constraint N (Notifications §7.2):** read/unread + title + text + timestamp + mark-as-read ⇒ the
  entity + read API; auto-refresh via SignalR (not manual) ⇒ the hub + client; notifications for **all**
  relevant events ⇒ the full catalog in §7.
- **Constraint J (Auth §5):** hub is `[Authorize]`; membership verified by deriving the group from the
  JWT, never from client input; `access_token` travels in the WS query string, still signature-validated.

---

## 11. Known gaps, non-goals & future events

- **OS / system push notifications are a non-goal (out of scope).** The spec lists *"FCM/OS push
  notifications"* among its hard non-goals, so notifications surface **only in-app** (the live centre +
  badge) while the app is open with a socket. Reaching a backgrounded or closed app would require Firebase
  Cloud Messaging (Android) / a local-notifications plugin and a push service — deliberately excluded, on
  both mobile and desktop. A closed client simply sees everything on its next open (REST load), which the
  durable DB row guarantees.
- **Destination removed/unpublished ⇒ notify affected organizers** — ✅ **done** in the 2026-08-17
  ripple-events pass (`DestinationUnavailable` / `DestinationAvailable`, see §7). Note a curator can never
  *delete* a destination a tour uses (`DestinationService.DeleteAsync` blocks it with a conflict); the real
  trigger is an approved destination being **edited back to Pending** (or rejected on re-moderation), which
  is where the fan-out fires.
- **Deliberately skipped ripple candidates** (surfaced in the same audit, judged not worth the noise):
  - *Schedule sold out → organizer.* Seats are consumed at **hold** time (a 15-minute `PaymentInProgress`
    booking), which may expire and free the seat again, so a "sold out" nudge fired on `SeatsTaken == Capacity`
    would frequently be a false alarm. Dropped.
  - *Booking auto-completed → organizer.* `CompleteAsync` runs **per booking**, so an organizer running a
    20-seat tour would get 20 "your tour ran" rows. Low value, high noise. Dropped (the traveler still gets
    their `BookingCompleted`). Both could be revisited as a single per-schedule digest if ever wanted.
- Any additional cross-role ripple events discovered during hardening land here first, then in §7.

---

## 12. Build log

- **2026-07-31** — Document created. Design locked: in-memory dispatcher + deferred flush; generic
  notification email; full desktop parity; full event coverage. No schema migration anticipated.
- **2026-07-31** — **Backend complete (9a–9e), compiles clean (Services/WebAPI/Worker 0/0).**
  - New: `NotificationDispatcher` + `INotificationRealtimePush` + `NotificationService`/`Controller` +
    DTOs (`NotificationResponse`, `NotificationUnreadCountResponse`, `NotificationSearch`);
    `NotificationHub` + `SignalRNotificationPush` + `NotificationFlushFilter`; `NotificationEmailMessage` +
    `EmailType.Notification` + worker case; `BookingReminderOptions`.
  - Program.cs: `AddSignalR`, global flush filter, JWT `access_token` query wiring, `MapHub("/hubs/notifications")`.
  - All prior direct `Notifications.Add(...)` sites (booking state machine, destination moderation, role
    decisions, refunds, review removal) routed through the dispatcher; `alsoEmail` set for the spec §5
    subset. Three new `NotificationType` values (`BookingPlaced`, `RoleApplicationSubmitted`,
    `DestinationSubmitted`) — no migration.
  - New events wired: organizer `BookingPlaced` (on webhook → Pending), admin `RoleApplicationSubmitted` /
    `DestinationSubmitted` (fan-out), curator/organizer `ReviewReceived`, `AccountSuspended`, 24-hour
    `BookingReminder`.
  - **Remaining:** Flutter client (§8) — `travle_core` realtime service + `NotificationProvider`, then the
    mobile and desktop notification centres.
- **2026-08-01** — Ops note: notification emails weren't arriving while password-reset emails were. Root
  cause was **not code** — the running `travle-worker` container was an older image built before the
  `EmailType.Notification` case existed, so it logged `unknown type 'notification'; discarding` and dropped
  every notification message (password-reset, a type it already knew, still sent). Fixed by rebuilding the
  worker (`docker compose up -d --build travle-worker`). Lesson recorded in §14. Added §13 (file-by-file
  reference).
- **2026-08-02** — **9f + 9g shipped: shared Flutter client + mobile UI (analyzer clean), user-verified live.**
  - `travle_core`: `NotificationRealtimeService` (signalr_netcore), `NotificationProvider`,
    `NotificationResponse` model, `putAction` on `BaseProvider`, barrel + `signalr_netcore` dep.
  - `travle_mobile`: proxy-provider wiring in `main.dart`, app-bar `NotificationBell` + badge, the
    notification **centre** (`notifications_screen.dart`), a full **detail screen**
    (`notification_detail_screen.dart` — untruncated body + "view related" deep-link; every row opens this,
    not the entity directly), shared `util/notification_display.dart`, and mark-all-as-read with a
    confirmation dialog. §8 rewritten to as-built; §8.3 adds the client↔server correspondence table.
  - Recorded the OS/system-push non-goal in §11. **Remaining:** 9h desktop centre (same shared core).
- **2026-08-02** — **9h shipped: desktop notification centre (analyzer clean).** `travle_desktop` gains its
  bell (in the side-nav top bar), centre, and detail on the shared `travle_core` core, plus its own
  `util/notification_display.dart` and `asUtc` in `util/formatting.dart`. Provider wired via the same
  proxy-provider pattern. Deep-link differs by design (see §8.4): desktop "view related" switches the
  side-nav **section** (via an `onNavigateToSection` callback threaded bell→centre→detail) instead of
  pushing a per-record page. **Phase 9 Flutter is complete on both apps.**
- **2026-08-11** — **Stretch S1: desktop live toasts (analyzer clean).** The only piece 00 §3.2 called for
  that wasn't already present. Everything else — the SignalR connection (shared `NotificationProvider`
  wired in desktop `main.dart`), the bell + live badge, the centre, and the detail — shipped back in Phase 9
  (9h); the desktop just never surfaced a *transient* toast on a live push (its `_onPush` equivalent didn't
  exist). Added `travle_desktop/widgets/notification_toast.dart` (a top-right card mirroring the centre
  row's icon/colour/title/body, slide+fade in) and wired `SideNavShell` to subscribe to
  `NotificationProvider.pushes`: it keeps a small queue (max 4), auto-dismisses each after 6 s, stacks them
  top-right over the content, and a tap opens that notification's detail (with the same `onNavigateToSection`
  deep-link). No backend change; the DB row + bell badge stay the durable record, the toast is purely the
  live nudge. (Mobile deliberately keeps no toast — its live nudge is the badge; only the management app
  asked for toasts.) Desktop force-reauth on a live *desktop* role grant is still not wired (mobile-only for
  now) — noted for later, not part of S1.
- **2026-08-17** — **Ripple-events hardening pass (backend + both Flutter clients, all analyzer/compile
  clean).** Closed the cross-role notification gaps found in the 2026-08-16 audit, plus two policy/feature
  changes that go beyond notifications. Six new `NotificationType` values (24–29, no migration).
  - **Destination availability → organizers (§7).** `DestinationService`: edit-from-approved fans out
    `DestinationUnavailable` and re-approval fans out `DestinationAvailable` to the distinct organizers whose
    tours visit the destination (new `NotifyOrganizersOfDestinationAvailabilityAsync`), plus `DestinationFeatured`
    to the curator on featuring, and a `General` "removed by admin" to the curator when an admin deletes their
    pending submission.
  - **Account reinstated → user.** `UserService.UnsuspendAsync` raises `AccountReinstated` (+email).
  - **Policy: organizer suspension cancels & refunds paid bookings.** `UserService.SuspendAsync` now, inside
    the suspension transaction, calls the new `BookingService.CancelPaidBookingsForOrganizerAsync` (cancels every
    Pending/Confirmed booking on the organizer's tours via a new `CancelForOrganizerSuspensionAsync` state
    transition — releases seats, notifies the traveler with `ScheduleCancelled`), then issues 100% refunds
    **after commit** (Stripe out of the transaction). `UserService` gained `IBookingService` + `IRefundService`
    deps (no DI cycle). Unpaid `PaymentInProgress` holds are left to expire.
  - **Tour changes → travelers.** `TourService.UpdateAsync` raises `TourUpdated` to travelers with an upcoming
    Pending/Confirmed booking when the **name or itinerary** changed (price/capacity excluded — price is
    snapshotted). `AddScheduleAsync` raises `TourUpdated` to a tour's favoriters (new date). `InsertAsync` raises
    a `General` "your destination is on a new tour" to each stop's curator. `TourService` gained
    `INotificationDispatcher`.
  - **Feature: retry an owed refund (§ payments doc).** `RefundService` now, on a Stripe refund failure,
    reassures the traveler (`General` "Refund delayed") and alerts all admins (`RefundFailed`, +email).
    `PaymentResponse.RefundOwed` (a captured payment on a cancelled booking with no refund) drives a new admin
    **"Retry refund"** action → `POST /Payments/{id}/retry-refund` → `PaymentService.RetryRefundAsync` (reuses the
    idempotent, tier-capped refund path; the tier is reconstructed from who cancelled the booking). Desktop:
    `PaginatedSearchTable` gained a generic optional row-action; the admin payments screen shows the retry button
    only on owed rows.
  - **Wording/coverage nits.** A card decline reuses `BookingExpired` but with a distinct "Payment failed"
    title/body (`ExpireAsync(booking, paymentFailed:true)`); a traveler's own cancellation now always gets a
    `BookingCancelled` confirmation (previously the 0% refund tier left no trace).
  - **Policy: tour deactivation** unchanged in behaviour (upcoming bookings are still honored) — only the
    desktop confirm dialog now spells that out ("hidden from new bookings… cancel schedules one-by-one for a
    100% refund"). No traveler notification (their booking is unaffected).
  - **Client.** New type icons/labels/negative-flags in both `notification_display.dart`s; mobile deep-links
    `TourUpdated`→tour and `DestinationFeatured`→destination; desktop deep-links `DestinationUnavailable/Available`
    →*My Tours* and `RefundFailed`→*Payments*. **Deliberately skipped:** sold-out→organizer (hold/confirm
    false-alarm) and auto-complete→organizer (per-booking spam) — see §11.
- **2026-08-18** — **Follow-ups from live testing the ripple pass.**
  - *Enforced the destination-unavailable ripple, not just the notification.* The `DestinationUnavailable`
    event told organizers a stop went under review, but the tour was still reachable by travelers (via one of
    its *approved* stops' "tours visiting here" list) and its pending stop openable from there. Now a tour with
    any non-approved stop is hidden from every traveler surface (`TourResponse.HasUnavailableDestination`;
    public browse/detail/favorites), a non-approved destination's detail is gated to submitter/admin, and the
    organizer's *My Tours* shows a "Temporarily unavailable" badge. Full write-up in `tours-and-bookings.md`
    §2.1.
  - *Seeded-payment refunds are bookkeeping-only.* Suspending a seeded organizer (or any refund of a seeded
    booking) hit Stripe with fabricated `pi_seed…` intents → a flood of "No such payment_intent" errors + the
    (correct) `RefundFailed`/retry path firing on un-refundable demo data. `RefundService` now skips Stripe for
    synthetic payments and records the refund as bookkeeping only. Details in `payments-and-stripe.md`.

---

## 13. File-by-file reference (backend)

Every file created or changed for the **backend** of this feature and why it exists. The **Flutter**
file-by-file is in §8.1–8.2, with the client↔server correspondence in §8.3.

### New files

**`Travle.Model` (contracts shared by API + worker):**

- **`Responses/NotificationResponse.cs`** — the DTO returned by the read endpoints *and* sent over SignalR,
  so the client renders the REST list and the live push identically. `Type` is the enum **name**, never the
  raw int.
- **`Responses/NotificationUnreadCountResponse.cs`** — a one-field (`Count`) response for the bell badge
  endpoint.
- **`SearchObjects/NotificationSearch.cs`** — the list filter (`IsRead`, `Type`) plus the base paging
  fields; `Type` is an int mirror of the entity enum so the Model layer stays free of a Services dependency.
- **`Messaging/NotificationEmailMessage.cs`** — the queue payload for the email leg of a notification
  (recipient, subject, title, body). One generic contract for every email-worthy event.

**`Travle.Services/Notifications/` (the pipeline core):**

- **`INotificationDispatcher.cs`** — the interface every service calls to raise a notification: `Enqueue`
  (stage the row) + `FlushAsync` (deliver after commit). The single seam that replaced the old ad-hoc
  `Notifications.Add(...)` helpers.
- **`NotificationDispatcher.cs`** — the scoped implementation: the in-memory "outbox". `Enqueue` adds the
  row to the `DbContext` and buffers it; `FlushAsync` pushes each committed row over SignalR and batch-emails
  the flagged subset, swallowing/logging push and email failures (best-effort — the row is the truth).
- **`INotificationRealtimePush.cs`** — the abstraction the dispatcher pushes through. Defined in Services so
  the dispatcher never references the WebAPI hub type (which would invert the project dependency).
  Implemented in the web layer (`SignalRNotificationPush`).
- **`INotificationService.cs` / `NotificationService.cs`** — the read/manage side backing the controller:
  paged list, unread count, mark-one-read, mark-all-read — every method scoped to the JWT user.
- **`NotificationMapper.cs`** — one place that maps a `Notification` entity to `NotificationResponse`
  (enum → name in memory), reused by the dispatcher and the read service.
- **`NotificationRecipients.cs`** — resolves fan-out recipient sets; currently `AdminUserIdsAsync` (every
  admin) for the "new item to moderate" events.

**`Travle.WebAPI` (the web/transport layer):**

- **`Hubs/NotificationHub.cs`** — the SignalR hub at `/hubs/notifications`. `[Authorize]`; on connect it
  joins the connection to `user-{id}` (id from the validated JWT, never client input). No client-callable
  methods — this is what makes membership server-verified (constraint J).
- **`Hubs/SignalRNotificationPush.cs`** — implements `INotificationRealtimePush` over `IHubContext<NotificationHub>`,
  sending to the recipient's group via the `NotificationReceived` client method. Also owns that method-name
  constant.
- **`Filters/NotificationFlushFilter.cs`** — global MVC action filter that calls `FlushAsync` after any
  action that didn't throw, so HTTP-triggered notifications deliver once their transaction has committed. It
  resolves the same request-scoped dispatcher the action's services used.
- **`Controllers/NotificationsController.cs`** — the REST surface (`GET /Notifications`,
  `/unread-count`, `PUT /{id}/read`, `/read-all`), all `[Authorize]` and JWT-scoped.
- **`Options/BookingReminderOptions.cs`** — binds `BookingReminder:WindowHours` (default 24) for the
  pre-tour reminder sweep; configurable so the reminder can be demoed live against static seed dates.

### Modified files

**`Travle.Model`:**

- **`Messaging/MessagingConstants.cs`** — added `EmailType.Notification = "notification"`, the `type` header
  value that routes a message to the worker's notification renderer. *(This exact constant is what the stale
  worker didn't recognise — see §14.)*

**`Travle.Services`:**

- **`Database/Enums.cs`** — added `NotificationType.BookingPlaced` / `RoleApplicationSubmitted` /
  `DestinationSubmitted` (ints 17–19; no migration).
- **`Messaging/IEmailPublisher.cs` + `Messaging/RabbitMqEmailPublisher.cs`** — added
  `PublishNotificationAsync`, which enqueues a `NotificationEmailMessage` under the `notification` type on
  the existing durable queue.
- **`BookingStateMachine/BaseBookingState.cs`** — `AddNotification` now routes through the dispatcher
  (resolved from the scoped provider) instead of a direct insert, and takes an `alsoEmail` flag;
  `ScheduleCancelled` emails.
- **`BookingStateMachine/PendingBookingState.cs`** — `BookingConfirmed` / `BookingRejected` now email.
- **`BookingStateMachine/PaymentInProgressBookingState.cs`** — on payment→Pending, also raises the
  organizer's `BookingPlaced` ("new booking to confirm").
- **`BookingService.cs` + `IBookingService.cs`** — inject the dispatcher and add
  `SendDueRemindersAsync(windowHours)` (the 24-hour reminder query + enqueue).
- **`RoleApplicationService.cs`** — decision notifications go through the dispatcher and email; `SubmitAsync`
  fans out `RoleApplicationSubmitted` to all admins (two-save-in-transaction so the id is known).
- **`DestinationService.cs`** — moderation notifications through the dispatcher and email; `InsertAsync` and
  edit-to-Pending fan out `DestinationSubmitted` to admins.
- **`Payments/RefundService.cs`** — `RefundIssued` through the dispatcher and email.
- **`DestinationReviewService.cs` / `TourReviewService.cs`** — `ReviewRemoved` through the dispatcher; new
  `ReviewReceived` to the destination's curator / the tour's organizer on a new review.
- **`UserService.cs`** — `SuspendAsync` raises `AccountSuspended` (in-app + email).

**`Travle.WebAPI`:**

- **`Program.cs`** — registers the dispatcher / read service / push adapter, `AddSignalR()`, the global
  flush filter, the JWT `access_token`-in-query wiring for the hub handshake, `MapHub(...)`, and the
  reminder options.
- **`Services/BookingLifecycleWorker.cs`** — its tick now also runs the reminder sweep and, after the sweep,
  flushes the scope's dispatcher so background-raised notifications (expiry / completion / reminder) deliver.

**`Travle.Worker`:**

- **`Email/EmailConsumer.cs`** — added the `EmailType.Notification` dispatch case + `SendNotificationAsync`
  (one generic template from subject/title/body). **This file lives in the worker container, so a code
  change here requires rebuilding the worker image to take effect** (see §14).

---

## 14. Operational note: the worker is a separate container

The API and the worker are **different processes in different containers**. The API you typically run
locally (`dotnet run`), so its code changes take effect on restart. The **worker only exists as its Docker
image** — editing `Travle.Worker` source does nothing until you rebuild it:

```
docker compose up -d --build travle-worker
```

If notification (or any) emails stop arriving while password-reset still works, the first thing to check is
whether the worker image predates the code: `docker ps` shows its build age, and
`docker logs travle-worker` will show `Received an email message with unknown type '<type>'; discarding`
when it's running an image older than a newly-added `EmailType`. The messages are not lost by the broker —
the (old) worker acknowledged and dropped them by choice; a rebuilt worker handles every subsequent event.
