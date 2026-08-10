# Running the Travle Flutter apps

Both apps read the API base URL from a **build-time** variable `BASE_URL`, supplied
via `--dart-define`. Nothing is hardcoded (project rule: config comes from the
environment, never source).

## How configuration is passed

`env*.json` files hold `{ "BASE_URL": "..." }`. They are **not** read
automatically — a bare `flutter run` or the IDE ▶ button ignores them. You must
pass one explicitly:

```bash
flutter run --dart-define-from-file=env.json
```

…or use the VS Code launch configs (below), which pass the right file per target.
If nothing is passed, the built-in default in `travle_core/lib/src/app_config.dart`
(`http://localhost:5126/`) is used.

## API ports differ by how you run the backend

| Backend run mode | API URL on the host |
|---|---|
| `dotnet run` (dev, `launchSettings` http profile) | `http://localhost:5126` |
| `docker compose up` (`API_HOST_PORT=5121`) | `http://localhost:5121` |

## Desktop (Windows)

Same machine as the API, so `localhost` just works:

```bash
cd UI/travle_desktop
flutter run -d windows --dart-define-from-file=env.json      # → localhost:5126
```

For Docker, change the port in `env.json` to `5121`.

## Mobile — the device / emulator switch

Two env files; pick one per run:

| File | BASE_URL | Use when |
|---|---|---|
| `env.json` | `http://localhost:5126/` | **Physical phone over USB or Wi-Fi** (with `adb reverse`), dev API — the default |
| `env.docker.json` | `http://localhost:5121/` | **Physical phone**, `docker compose` API (with `adb reverse`) |
| `env.emulator.json` | `http://10.0.2.2:5126/` | **Android emulator** (AVD) |

`10.0.2.2` is a magic alias that exists **only inside the emulator** — it points at
the host's loopback. On a real phone it is meaningless, which is why a physical
device times out (`errno 110` / `103`) when pointed at it.

### Physical phone over USB (recommended)

`adb reverse` tunnels the phone's own `localhost:5126` to the laptop's
`localhost:5126` over the cable — no WiFi, no firewall, and the API can stay bound
to `localhost` (exactly what the desktop app already uses).

1. Enable USB debugging, connect the phone, confirm it is authorized:
   ```bash
   adb devices          # your device must show as "device", not "unauthorized"
   ```
2. Open the tunnel (**re-run after replug / phone reboot / adb restart** — it does
   not survive those, but it does survive app restarts and hot reload):
   ```bash
   adb reverse tcp:5126 tcp:5126        # Docker: adb reverse tcp:5121 tcp:5121
   ```
   VS Code shortcut: **Terminal → Run Task → "adb reverse (dev 5126)"**.
3. Run the API normally (`dotnet run`) and the app with `env.json`:
   ```bash
   cd UI/travle_mobile
   flutter run --dart-define-from-file=env.json
   ```
4. **Verify** from the phone's browser: `http://localhost:5126/scalar/` should load.
   If it does, login will work too.

### Physical phone over Wi-Fi (no cable) — `run-mobile-wifi.ps1`

Same setup as USB, minus the cable: the script establishes the adb link over
Wi-Fi instead. The important part is that **`adb reverse` works over the wireless
adb transport exactly like over USB**, so the API can stay bound to `localhost`,
`BASE_URL` stays `http://localhost:5126/`, and no firewall rule or `0.0.0.0` rebind
is needed. It uses "ADB over TCP/IP" (`adb tcpip 5555`), auto-detects and remembers
the phone's IP, then runs `adb reverse` + `flutter run` for you.

```powershell
UI\run-mobile-wifi.ps1              # dev API on 5126 (env.json)
UI\run-mobile-wifi.ps1 -Docker      # docker-compose API on 5121 (env.docker.json)
UI\run-mobile-wifi.ps1 -Ip 192.168.1.42   # skip auto-detect, use this IP
UI\run-mobile-wifi.ps1 -Reset       # forget the saved IP, redo USB setup
```

VS Code shortcut: **Terminal → Run Task → "run mobile over Wi-Fi (dev 5126)"**.

Prerequisites: compilable Flutter code, and the phone on the **same Wi-Fi** as the
laptop. The one exception is the **first run** (and any run after the phone reboots,
which clears TCP/IP mode): plug the phone in via USB once so the script can flip it
to Wi-Fi and learn its IP. It prints "you can UNPLUG the USB cable now" once the
wireless link is up; after that, runs are cable-free.

What it does, in order:

1. Reuses an existing Wi-Fi adb link if one is up; else `adb connect`s the
   saved/`-Ip` address; else (cable present) runs `adb tcpip 5555`, reads the phone's
   Wi-Fi IP, connects, and saves the IP to `%USERPROFILE%\.travle-phone`.
2. `adb reverse tcp:5126 tcp:5126` (or `5121` with `-Docker`).
3. Starts a background **watchdog** that re-connects the device and re-asserts
   `adb reverse` every few seconds. A wireless adb link drops when the phone sleeps
   or Wi-Fi hiccups, which silently wipes the reverse tunnel — the watchdog restores
   it automatically so you never have to run `adb reverse` by hand mid-session. It is
   stopped when `flutter run` exits.
4. `flutter run -d <phone> --dart-define-from-file=env.json` (or `env.docker.json`).

It does **not** start the backend — run `dotnet run` (or `docker compose up`)
yourself as usual; the script warns if nothing is listening on the API port yet.

> Why Option 1 (`adb tcpip`) and not Android 11 "Wireless debugging"? Wireless
> debugging hands out a random port on every toggle and needs a fresh pair/connect,
> which is worse to script. `adb tcpip` uses a fixed port (5555) and reconnects
> cleanly from the saved IP.

### Android emulator (AVD)

The emulator reaches the host via `10.0.2.2`, but a `localhost`-bound API will not
accept that traffic. Bind the API to all interfaces and allow the port:

```bash
dotnet run --project Backend/Travle.WebAPI --urls "http://0.0.0.0:5126"
```

If a Windows Defender Firewall prompt appears for `dotnet`, click **Allow** (Private
is enough). Otherwise add the rule once, in an **elevated** PowerShell:

```powershell
New-NetFirewallRule -DisplayName "Travle API 5126" -Direction Inbound -Protocol TCP -LocalPort 5126 -Action Allow
```

Then run the app with the emulator config:

```bash
cd UI/travle_mobile
flutter run --dart-define-from-file=env.emulator.json
```

Under Docker the emulator uses `http://10.0.2.2:5121/` and needs **no** rebind or
firewall rule — Docker already publishes the port on `0.0.0.0`.

## VS Code launch configs (the one-click switch)

`.vscode/launch.json` (repo root) provides three entries in the Run and Debug
dropdown:

- **mobile • physical device (localhost + adb reverse)** → `env.json`
- **mobile • Android emulator (10.0.2.2)** → `env.emulator.json`
- **desktop • Windows (localhost)** → `env.json`

Pick one and press ▶. (For the physical-device config, run the `adb reverse` task
once per session first.)

## Android manifest (already configured)

`android/app/src/main/AndroidManifest.xml` already contains what mobile networking
needs:

- `<uses-permission android:name="android.permission.INTERNET"/>`
- `android:usesCleartextTraffic="true"` on `<application>` — **required** because
  the API is plain HTTP; without it Android 9+ blocks the requests outright.

## Troubleshooting `SocketException` errno

| errno | meaning | usual cause |
|---|---|---|
| 110 `ETIMEDOUT` | no response at all | phone can't reach the address (e.g. `10.0.2.2` on a real device), or a firewall is dropping packets |
| 103 `ECONNABORTED` | connection aborted | same class of reachability problem |
| 111 `ECONNREFUSED` | port closed | API not running, or wrong port (5126 vs 5121) |
| 113 `EHOSTUNREACH` | no route to host | wrong host/IP for your setup |

A message like *"Cleartext HTTP … not permitted"* instead means
`usesCleartextTraffic` is missing (already set here).
