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

Existing values plus the three added in Phase 9 (all stored as `int`; adding values is not a schema
change):

`General, BookingConfirmed, BookingRejected, BookingCancelled, BookingExpired, BookingReminder,
BookingCompleted, PaymentSucceeded, RefundIssued, DestinationApproved, DestinationRejected,
RoleApplicationApproved, RoleApplicationRejected, ReviewReceived, AccountSuspended, ScheduleCancelled,
ReviewRemoved` **+ (Phase 9) `BookingPlaced`, `RoleApplicationSubmitted`, `DestinationSubmitted`.**

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
| Booking auto-completed (leave a review) | `BookingCompleted` | ✓ | – | wired |
| Organizer cancelled the slot | `ScheduleCancelled` | ✓ | ✓ | wired (+email) |
| Refund issued | `RefundIssued` | ✓ | ✓ | wired (+email) |
| 24-hour pre-tour reminder | `BookingReminder` | ✓ | ✓ | **new** |
| Role application approved/rejected | `RoleApplication…` | ✓ | ✓ | wired (+email) |
| Own review removed by admin | `ReviewRemoved` | ✓ | – | wired |

### Curator (mobile)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| Destination approved/rejected | `Destination…` | ✓ | ✓ | wired (+email) |
| New review on my destination | `ReviewReceived` | ✓ | – | **new (wire)** |
| Own review removed by admin | `ReviewRemoved` | ✓ | – | wired |
| Role application decisions | `RoleApplication…` | ✓ | ✓ | wired |

### Organizer (desktop)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| New booking awaiting confirmation | `BookingPlaced` | ✓ | – | **new** |
| A traveler cancelled a booking | `BookingCancelled` | ✓ | – | wired |
| New review on my tour | `ReviewReceived` | ✓ | – | **new (wire)** |

### Admin (desktop)
| Event | Type | In-app | Email | State |
|---|---|:-:|:-:|---|
| New role application submitted | `RoleApplicationSubmitted` | ✓ | – | **new** |
| New / edited destination pending moderation | `DestinationSubmitted` | ✓ | – | **new** |
| Account suspended (sent to the suspended user) | `AccountSuspended` | ✓¹ | ✓ | **new** |

¹ Email is the channel that actually reaches a just-suspended user (their session is revoked). The in-app
row is still written — cheap, and it gives transparency ("suspended on X for reason Y") if the account is
later reinstated. Admin events (`RoleApplicationSubmitted`, `DestinationSubmitted`) fan out to **all** users
holding the Admin role via `NotificationRecipients.AdminUserIdsAsync` (one query on `UserRoles`).

---

## 8. The Flutter client (planned)

Both apps are Flutter, so the realtime mechanism is **shared in `travle_core`** and each app only renders
its own bell + centre:

- **`signalr_netcore`** builds a `HubConnection` to `{BASE_URL}/hubs/notifications` with
  `accessTokenFactory` returning the token from secure storage, and `withAutomaticReconnect`.
- **`NotificationProvider`** (`ChangeNotifier`, like the other providers): loads the list + unread count
  via REST when the centre opens; listens to the hub's `notificationReceived` and **prepends** the new
  item + bumps the badge; `markRead` / `markAllRead` call REST and update local state.
- **Lifecycle:** connect after login (token available), reconnect after a token refresh (the
  `accessTokenFactory` returns the *current* token on each reconnect, so rotation is handled), disconnect
  on logout.
- **UI:** an app-bar bell with an unread badge on both apps → a notification centre screen (list, unread
  emphasis, relative time, tap = mark read + navigate to the related entity, "mark all as read"), live.

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

## 11. Known gaps & future events (hardening phase)

- **Destination removed/unpublished ⇒ notify affected organizers.** When a curator's destination is
  taken down, any organizer whose tour includes it should be told, since it affects their live tours.
  Deferred to the hardening phase.
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

---

## 13. File-by-file reference (backend)

Every file created or changed for the backend of this feature and why it exists. Flutter files are added
here when §8 lands.

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
