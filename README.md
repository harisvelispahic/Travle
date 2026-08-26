# Travle

**Platform for discovering tourist destinations and booking experiences.**
Seminar project for _Razvoj softvera II_ — Fakultet informacijskih tehnologija, Univerzitet „Džemal Bijedić" u Mostaru, 2025/26.

Travle is a marketplace. It does not run tours itself: **curators** submit local destinations for
moderation, **organizers** build tours on the approved ones and manage their departures, **travelers**
discover, book and pay for them, and **administrators** moderate everything and report on it. The
platform books a 10 % commission on every transaction.

---

## 1. What is in the box

| Part                                          | Project                   | Runs as                                    |
| --------------------------------------------- | ------------------------- | ------------------------------------------ |
| REST API                                      | `Backend/Travle.WebAPI`   | container `travle-api`, host port **5121** |
| Background worker (RabbitMQ → SMTP e-mail)    | `Backend/Travle.Worker`   | container `travle-worker`                  |
| Domain, entities, EF configurations, services | `Backend/Travle.Services` | class library                              |
| DTOs, requests, search objects, exceptions    | `Backend/Travle.Model`    | class library                              |
| Mobile app (traveler + curator)               | `UI/travle_mobile`        | Flutter                                    |
| Desktop app (organizer + administrator)       | `UI/travle_desktop`       | Flutter                                    |
| Shared client logic (models, providers, auth) | `UI/travle_core`          | Flutter package                            |
| Shared design system (tokens, widgets, maps)  | `UI/travle_ui`            | Flutter package                            |

Also in the repo: `recommender-dokumentacija.md` (the required recommender document) and `docs/`
(specification, database design, and one living document per subsystem).

**Stack:** ASP.NET Core 10 · EF Core (Code First) · SQL Server 2022 · RabbitMQ · SignalR ·
Stripe (test mode) · QuestPDF · Flutter 3.44 · Docker Compose.

---

## 2. What it does

**Mobile — traveler**

- _Recommended for you_ on the home screen, where **every card states why it was picked**
- Map browse with category pins, and a search that flies the map to its result
- Search with autocomplete, accent-insensitive text (`Pocitelj` finds _Počitelj_), multi-select
  categories, a country → region cascade and a minimum-rating filter
- Destination pages with gallery, map, reviews and the tours that visit them; favourites
- Booking a departure: server-side capacity check, a 15-minute seat hold, **in-app Stripe
  PaymentSheet**, and a tiered refund on cancellation
- Booking history as a master-detail view; reviewing unlocks once a tour is completed
- Live notifications over SignalR, profile with photo, e-mail password reset

**Mobile — curator**

- Submit a destination with images, tags, a category and a map-picked location
- Follow it through moderation, and see its reach on a personal statistics screen

**Desktop — administrator**

- Dashboard with charts over bookings, revenue and the catalogue
- Two PDF reports, both downloadable and printable
- Moderation queues for destinations, role applications and reviews
- Every booking and every payment, searchable and filterable
- User management — create accounts, grant or revoke roles, suspend
- CRUD over all eight reference tables, with deletion blocked **and explained** where a record is in use

**Desktop — organizer**

- Build a tour across several approved destinations, with a live itinerary map
- Publish departures, confirm or reject bookings, cancel a departure (every booking on it is refunded
  automatically), and read the statistics for their own tours

**API and worker**

- JWT with rotating refresh tokens and server-side invalidation; role-based policies on admin endpoints
- One centralized booking state machine — no transition logic in controllers
- Stripe PaymentIntents finalized only by the signature-verified webhook; refunds computed from the
  amount actually charged; 10 % commission snapshotted per payment
- Content-based + popularity recommender that returns a written explanation with every result
- RabbitMQ → a separate worker container → SMTP e-mail
- SignalR hub for live notifications
- Pagination, filtering and at least one search parameter on every list endpoint
- Global exception middleware over a custom exception hierarchy; FluentValidation on every request

---

## 3. Prerequisites

- **Docker Desktop** (Compose v2) — runs the API, worker, SQL Server and RabbitMQ.
- **Flutter SDK 3.44+** (Dart 3.11+) — only if you want to build the apps from source; the release
  builds are attached to the GitHub Release.
- For the Windows desktop build: Visual Studio 2022/2026 with the _Desktop development with C++_
  workload. For the Android build: the Android SDK that ships with Flutter.

Nothing else has to be installed — the database is created, migrated and seeded automatically on
the API's first start.

---

## 4. Running the backend

```bash
# 1. from the repository root, create the configuration file
cp .env.example .env          # Windows: copy .env.example .env

# 2. edit .env and fill in the values marked "replace me" (see §5)

# 3. start everything
docker compose up --build
```

That single command starts four services:

| Service            | Image / project                                         | Host port                              |
| ------------------ | ------------------------------------------------------- | -------------------------------------- |
| `travle-sqlserver` | `mcr.microsoft.com/mssql/server:2022-CU14-ubuntu-22.04` | `1435`                                 |
| `travle-rabbitmq`  | `rabbitmq:3.13-management`                              | `5672` (AMQP), `15672` (management UI) |
| `travle-api`       | `Backend/Travle.WebAPI/Dockerfile`                      | **`5121`**                             |
| `travle-worker`    | `Backend/Travle.Worker/Dockerfile`                      | — (no HTTP surface)                    |

The API waits for SQL Server and RabbitMQ to report healthy, then **applies all migrations and seeds
the database** (reference data, ~40 users, the Bosnia-and-Herzegovina destination catalogue with
images, tours, departures, bookings, payments, refunds, reviews, favourites, notifications and
recommender interactions). The first run takes a minute or two; later runs find the data present and
skip seeding.

When it is up:

- API root — <http://localhost:5121>
- Interactive API reference (Scalar) — <http://localhost:5121/scalar>
- RabbitMQ management — <http://localhost:15672> (user/password from `.env`)

> The API is served over plain **HTTP** on purpose — self-signed certificates expire and break the
> review (course §9.2).

Stop with `Ctrl+C`; `docker compose down -v` also drops the database volume, so the next start
re-seeds from scratch.

---

## 5. Configuration

**Every** configuration value lives in the repository-root `.env` file — nothing is hardcoded in
source and nothing infrastructural sits in `appsettings.json` (no connection string, no JWT key, no
RabbitMQ, no SMTP, no Stripe key). `docker compose` interpolates `.env` into each container's
environment; a local `dotnet run` loads the same file through DotNetEnv and
`Travle.Model/Configuration/EnvironmentConfigurationAliases.cs`, so each secret is written **once**.

`.env.example` documents every key. The ones you must fill before the first run:

| Key                                           | What to put there                                                                                                                          |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `MSSQL_SA_PASSWORD` + `CONNECTION_STRING`     | one strong password, identical in both                                                                                                     |
| `JWT_SECRET_KEY`                              | 32+ random characters (`openssl rand -hex 32`)                                                                                             |
| `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY` | your Stripe **test-mode** keys (`sk_test_…`, `pk_test_…`)                                                                                  |
| `STRIPE_WEBHOOK_SECRET`                       | `whsec_…` printed by `stripe listen` (see §8)                                                                                              |
| `SMTP_*`                                      | any SMTP provider — Mailtrap's sandbox is easiest. Leave `SMTP_HOST` empty to disable sending; the worker still runs and drains the queue. |

> **A word on the e-mail quota.** Mailtrap's free sandbox accepts **50 e-mails a month**, and Travle
> mails on every notable event (registration, booking confirmed, refund issued, password reset…). One
> action can spend a lot of it at once: suspending an organizer cancels and refunds *every* paid
> booking on their tours, and each affected traveler gets a refund e-mail. So suspend an organizer
> with a couple of bookings rather than one of the seeded busy ones (`amir_tours`), or leave
> `SMTP_HOST` empty to stop sending altogether — the worker still runs and drains the queue, and the
> in-app/SignalR notifications are unaffected either way.

At submission the real `.env` ships as a password-protected `.env-tajne.zip` in the same folder; the
password is supplied through the DL system.

---

## 6. Running the Flutter apps

Both apps read the API address from the build-time variable **`API_BASE_URL`**, exactly as the course
requires:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5121
```

The checked-in `env*.json` files hold the same value for the common targets, and are passed with
`--dart-define-from-file`. A trailing slash is optional.

| App     | File              | `API_BASE_URL`          | Target                                                        |
| ------- | ----------------- | ----------------------- | ------------------------------------------------------------- |
| mobile  | `env.json`        | `http://10.0.2.2:5121`  | **Android emulator** against Docker — the release/APK default |
| mobile  | `env.device.json` | `http://localhost:5121` | physical phone with `adb reverse tcp:5121 tcp:5121`           |
| mobile  | `env.local.json`  | `http://localhost:5126` | physical phone against a local `dotnet run`                   |
| desktop | `env.json`        | `http://localhost:5121` | Windows against Docker — the release default                  |
| desktop | `env.local.json`  | `http://localhost:5126` | Windows against a local `dotnet run`                          |

> **On a physical Android phone, forward the port first.** The phone has no route to the host's
> `localhost`, so `env.device.json` only works once the port is bridged over USB. With the phone
> plugged in and USB debugging on, run:
>
> ```bash
> adb reverse tcp:5121 tcp:5121
> ```
>
> Re-run it after unplugging the phone, rebooting it, or restarting the adb server — the forward does
> not survive any of those. Without it the app builds and starts fine but every request fails with a
> `SocketException`, even though the stack is healthy. Against a local `dotnet run` (`env.local.json`)
> forward that port instead: `adb reverse tcp:5126 tcp:5126`. The **emulator needs nothing** — it
> reaches the host at `10.0.2.2`, which is what `env.json` already uses. `UI/RUNNING.md` covers the
> Wi-Fi variant and the VS Code task that runs this for you.

**First time, resolve all four packages** — not just the two apps. `travle_core` and `travle_ui`
are path dependencies, and an app's own `flutter pub get` does **not** create a package resolution
inside them. Without it the analyzer cannot resolve their imports and the IDE shows a thousand-plus
phantom errors (the apps still build — it is an analysis-only problem):

```bash
cd UI/travle_core  && flutter pub get
cd ../travle_ui    && flutter pub get
cd ../travle_mobile && flutter pub get
cd ../travle_desktop && flutter pub get
```

Then run either app:

```bash
# desktop (Windows)
cd UI/travle_desktop
flutter run -d windows --dart-define-from-file=env.json

# mobile (Android emulator)
cd UI/travle_mobile
flutter run --dart-define-from-file=env.json
```

`UI/RUNNING.md` covers the remaining setups (physical device over USB or Wi-Fi, firewall notes,
`SocketException` troubleshooting) and the VS Code launch configurations in `.vscode/launch.json`.

### Release builds

```bash
# Android APK  → build/app/outputs/flutter-apk/app-release.apk
cd UI/travle_mobile
flutter clean && flutter pub get
flutter build apk --release --dart-define-from-file=env.json

# Windows exe  → build/windows/x64/runner/Release/
cd UI/travle_desktop
flutter clean && flutter pub get
flutter build windows --release --dart-define-from-file=env.json
```

Both builds are attached to the GitHub Release as a single ZIP archive; they are never committed to
the repository. **Archive the whole `Release` folder**, not just `travle_desktop.exe` — the DLLs and
the `data/` directory beside it are part of the application and it will not start without them.

---

## 7. Login credentials

All seeded accounts use the password **`test`**.

| Context                            | Username    | Password |
| ---------------------------------- | ----------- | -------- |
| Desktop — Administrator            | `desktop`   | `test`   |
| Mobile — Traveler                  | `mobile`    | `test`   |
| Desktop — Organizer                | `organizer` | `test`   |
| Mobile — Curator (also a Traveler) | `curator`   | `test`   |

Two further organizers with a richer catalogue — `amir_tours` and `selma_travel` — plus ~35 generated
travelers, curators and organizers all share the same password. New travelers can also register
themselves from the mobile app.

Roles decide which app an account can use: the desktop app admits **Administrator** and **Organizer**,
the mobile app admits **Traveler** and **Curator**.

---

## 8. Payments (Stripe test mode)

Payment is real Stripe sandbox, never simulated: the server creates the PaymentIntent (it owns the
amount), the mobile app confirms it **in-app** through the Stripe PaymentSheet, and the booking is
promoted to _Pending_ **only** by the signature-verified webhook. Refunds go back through the Stripe
Refund API against the amount actually charged.

Stripe cannot reach a machine behind NAT on its own, so a payment only completes while the Stripe CLI is
forwarding webhooks. Run it alongside the stack, passing the **same `sk_test_…` that is in `.env`**:

```bash
stripe listen --api-key sk_test_… --forward-to localhost:5121/Payments/Webhook
```

`--api-key` matters: it binds the listener to the account that owns the key — the account the API creates
its PaymentIntents on — and skips the interactive `stripe login`. Without it the CLI listens to whichever
account it was last logged into, forwards nothing, and the booking sits at *PaymentInProgress* until its
15-minute hold expires. The `whsec_…` the CLI prints is stable per account and normally already matches
`STRIPE_WEBHOOK_SECRET`; if it differs, paste it in and restart the API.

Test cards — any future expiry date, any CVC:

| Card                  | Scenario                                                                          |
| --------------------- | --------------------------------------------------------------------------------- |
| `4242 4242 4242 4242` | payment succeeds                                                                  |
| `4000 0000 0000 0002` | card declined — the attempt fails, the booking keeps its hold and can be retried |

Details and the full state machine are in `docs/payments-and-stripe.md`.

---

## 9. What to try after signing in

- **Mobile / traveler** — the home screen's _Recommended for you_ section (every card states _why_ it
  was picked), search with category/region/rating filters, the map browse tab, a destination's detail
  page with its gallery, map, reviews and tours, then book a departure, pay with the test card, watch
  the notification arrive live, and cancel to see the tiered refund.
- **Mobile / curator** — sign in as `curator`, submit a destination (category dropdown, tags, images,
  map picker) and watch it move through moderation; _My statistics_ shows its reach.
- **Desktop / administrator** — dashboard, pending applications and destination moderation, review
  moderation, all bookings and payments, user management, the two PDF reports, and CRUD over all eight
  reference tables.
- **Desktop / organizer** — create a tour over several approved destinations, add departures, confirm
  or reject bookings, cancel a departure (every booking on it is refunded automatically), and check
  the statistics screen.

---

## 10. Repository layout

```
travle/
├── docker-compose.yml          all four services; run from here
├── .env / .env.example         every configuration value (the real .env is gitignored)
├── recommender-dokumentacija.md
├── Backend/
│   ├── Travle.sln
│   ├── Travle.Model            DTOs, requests, search objects, exceptions, constants
│   ├── Travle.Services         entities + EF configurations, services, state machine,
│   │                           recommender, payments, notifications, reports, seeding
│   ├── Travle.WebAPI           controllers, middleware, SignalR hub, scheduler, Dockerfile
│   └── Travle.Worker           RabbitMQ consumer → SMTP, own Dockerfile and container
├── UI/
│   ├── travle_core             shared models/providers/auth
│   ├── travle_ui               shared design system
│   ├── travle_mobile           Android app
│   ├── travle_desktop          Windows app
│   └── RUNNING.md              every run/build configuration in detail
└── docs/                       specification, database design, per-subsystem documents
```

---

## 11. Notes for the review

- `[AllowAnonymous]` appears only where authentication is impossible by definition: login, register,
  refresh-token, the password-reset pair, and the Stripe webhook — and the webhook verifies Stripe's
  signature before trusting anything.
- Interactive API documentation (Scalar) is mapped only in the Development environment, which is what
  `.env.example` ships.
- Errors always come back in one envelope — `{ message, errors, traceId }`. It never carries a stack
  trace or any other internal detail, in *any* environment; the full exception is logged server-side
  against that same `traceId`.
- Times are stored and transported as UTC. Tour departure times are displayed in the destination
  city's own zone (marked "local time"); audit timestamps are shown in the device's zone. See
  `docs/time-and-timezones.md`.
- **Two harmless login failures appear in the SQL Server log on the very first start**, before the
  database exists: the compose healthcheck probing while SQL Server is still initialising the `sa`
  password, and EF Core testing whether database `230172` exists. The second is immediately followed
  by `CREATE DATABASE [230172]` and the migrations. Neither appears on later starts.
- The reminder sweep looks 24 hours ahead. Seed dates are static, so raise
  `BOOKING_REMINDER_WINDOW_HOURS` in `.env` (e.g. to `2000`) if you want to see a reminder fire during
  a short review session.
