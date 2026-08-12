# Auth Token Invalidation (Security Stamp + Gate) — Design and Build Log

Living document for making Travle's stateless JWT access tokens **revocable**, so an auth change
(suspension, role grant/revoke, password change, logout) takes effect **on the account's next request**
instead of lingering until the token naturally expires. Started 2026-08-11.

Written to be read top-to-bottom by someone who has never seen the code.

> **Status.** Fully implemented and device-verified. Three layers stack up:
> (1) the **server-side boundary** — a per-user security stamp + an `OnTokenValidated` gate that revokes
> access tokens the instant an auth change happens (§2–§6); (2) **seamless, device-aware role changes** —
> a grant/revoke keeps the refresh token, so the client silently refreshes to the new claims instead of
> being logged out, and reacts only where the role is actually usable (§7); and (3) **immediate SignalR
> force-logout** for the hard cases — suspension and password change/reset push a *session-affecting*
> notification that bounces every connected device to the login screen within a second (§7).

---

## 1. The problem

A JWT access token is **stateless**: once signed, the server doesn't look it up anywhere — it verifies
the signature and expiry and trusts the contents. That's normally a feature, but it means we could not
*revoke* a token mid-life. Two concrete holes we hit:

1. **Suspended user could still act.** Suspension is a mutable DB flag (`Users.IsSuspended`) the token
   can't carry, and we only checked it at **login/refresh** — so a suspended user's already-issued access
   token (lifetime `JwtToken:DurationInMinutes`, 30 min) still passed every request. They could book, pay,
   and get confirmed while suspended.
2. **Revoked role still worked.** Removing a user's Curator role revoked their refresh token, but their
   **access token still carried `role: Curator`** until it expired — so they could keep submitting
   destinations for up to 30 minutes.

Force-logout over SignalR is **not** a fix for either on its own: it's best-effort UX (an offline or
uncooperative client never receives the push). The *authoritative* fix has to be **server-side** — the
security stamp below. SignalR then layers the *immediate* client reaction on top of that boundary (§7).

## 2. The mechanism: a security stamp + a validation gate

**One new value per user** — `Users.SecurityStamp`, a random GUID — acts as a *version number for the
account's identity/permissions*. **No tokens are stored anywhere** (not in the DB, not in the cache); the
token carries a *copy* of the stamp, and we compare.

- **Issue:** every access token embeds the user's current stamp as a `security_stamp` claim
  (`JwtTokenService`).
- **Validate:** on every authenticated request, the JwtBearer `OnTokenValidated` gate (`Program.cs`)
  compares the token's `security_stamp` claim to the user's *current* stamp and rejects the token if they
  differ — or if the account is suspended.
- **Revoke:** any auth change overwrites the stamp with a **fresh GUID**. Instantly, every token that user
  holds carries the *old* stamp → fails the next comparison → the client's normal `401 → refresh →
  (re-login or silent refresh)` flow gives them a fresh token (with updated claims) or bounces them to
  login. Changing one GUID invalidates all of that user's outstanding access tokens.

Think of the stamp as the version printed on an ID badge: every badge shows the current version, the guard
checks it, and bumping the expected version retires every old badge at once — without keeping copies of
the badges.

## 3. What each piece is

| Piece | File | Role |
|---|---|---|
| `User.SecurityStamp` | `Travle.Services/Database/User.cs` | the per-user GUID; new accounts get a unique one from the initializer |
| `security_stamp` claim | `Travle.Services/AccessManager/JwtTokenService.cs` (+ `TravleClaimTypes`) | the stamp copy embedded at mint time |
| `IUserSecurityStore` | `Travle.Services/Security/UserSecurityStore.cs` | read-through **cache** of `(SecurityStamp, IsSuspended)` per user; `Invalidate(userId)` evicts |
| `OnTokenValidated` gate | `Travle.WebAPI/Program.cs` | rejects suspended accounts + stale stamps on every request |
| bump sites | `UserService`, `PasswordResetService`, `AccessManager` | roll the stamp + evict cache on each auth change |

### 3.1 The gate (`OnTokenValidated`)
For every authenticated request: parse the user id, load `(SecurityStamp, IsSuspended)` through the store,
then `context.Fail(...)` (→ 401) if the user is missing, **suspended**, or the token's `security_stamp`
doesn't match. A failed token is treated as unauthenticated, so the client's existing 401 handling runs.

### 3.2 The cache (`IUserSecurityStore`)
The gate runs on *every* request, so the two tiny values are read through `IMemoryCache` (course §8.2 —
cache per-request static data) instead of a DB round-trip each time. A short TTL (2 min) is only a
backstop: **every bump site calls `Invalidate(userId)`**, so a change is reflected on the very next
request, not after the TTL. It caches *state*, never tokens.

## 4. When the stamp is bumped (and what happens to the session)

| Event | Stamp bumped | Refresh tokens dropped | Net effect on the user's session |
|---|---|---|---|
| **Suspend** | ✔ | ✔ | locked out on next request (gate rejects on stamp **and** `IsSuspended`); can't refresh or log in (both check the flag) |
| **Unsuspend** | ✔ | — | no live session existed; can log in again |
| **Grant role** (anyone, incl. self / application approve) | ✔ | ✖ | next request 401 → **silent** refresh (refresh kept) → new token carries the role. **No forced logout** — the role appears where it's usable and does nothing where it isn't. The client shows "You're now a X" only when X is usable on *that* device |
| **Revoke role** (anyone, incl. self) | ✔ | ✖ | next request 401 → **silent** refresh → new token without the role (seamless downgrade). The client shows "You're no longer a X" — and leaves any screen that role gated — only when X mattered on *that* device |
| **Password change** (self) | ✔ | ✔ | every session ends **immediately on all devices** — a `PasswordChanged` SignalR push force-logs-out every connected device (like suspension); signs in again with the new password |
| **Password reset** (forgot-password) | ✔ | ✔ | same — a `PasswordChanged` push force-logs-out every still-connected device immediately |
| **Logout** | ✔ | ✔ | `AccessManager.LogoutAsync` → `InvalidateAllSessionsAsync`: the access token dies now, not at expiry (satisfies course §5 "logout must invalidate the token server-side") |

The **self non-admin role change** is the one deliberate soft path: bumping the stamp but *keeping* the
admin's refresh token lets their client silently refresh to the new claim set, so an admin toggling their
own Organizer/Curator role isn't kicked out. (Removing your own **Admin** role, and removing the **last**
Admin, remain blocked outright.)

## 5. Why this is correct (and cheap)

- **Security, not UX.** The gate is server-side and unconditional, so a suspended user or a stale role is
  blocked regardless of whether the client cooperates or is even online.
- **No token storage.** One GUID per *user*; the alternative — a server-side denylist of token ids — stores
  identifiers per *token* and grows unbounded. Security stamp is the lighter, standard choice (it's what
  ASP.NET Identity uses internally).
- **Cheap per request.** One in-memory cache read almost always; a DB read only on a cache miss/after a
  bump.

## 6. Deploy note

Adding the column backfills existing non-seed rows with `SecurityStamp = ""` (the seed users get explicit
stamps via the migration). Any token minted **before** this change carries no `security_stamp` claim, so
the gate rejects it once → those users re-login a single time after deploy. That's expected for a security
rollout, not a bug.

## 7. Client force-logout UX (built)

The boundary alone already blocks/bounces a suspended or demoted user on their next request. On top of it,
the client now reacts **immediately and gracefully** to a session change. It's owned by the **`AuthGate`**
(the stable root of each app — it never unmounts), which handles both directions:

- **Proactive (live push).** `AuthGate` subscribes to the notification feed. On a *session-affecting* type
  (`sessionAffectingNotificationTypes` = `AccountSuspended`, `RoleGranted`, `RoleRevoked`,
  `RoleApplicationApproved`, `PasswordChanged`) it snapshots the current roles, then attempts a **silent
  `tryRefresh()`**:
  - **fails** → the session was hard-invalidated (suspension, **password change/reset**, or a truly dropped
    refresh) → it routes to login and shows `showSessionEndedDialog` with a reason drawn from the push
    (`sessionEndedReason`).
  - **succeeds** (every role change — refresh tokens are kept) → the new claims apply seamlessly. It then
    calls `refreshCurrentUser()` so the cached profile's roles (which gate menu items — e.g. the mobile
    "My destinations" entry) match the new token, and diffs the roles: **only for a change usable on *this*
    device** (`AppRole.mobile` / `AppRole.desktop`) a **gain** shows *"You're now a X"*; a **loss** pops off
    any screen that role gated, resets the mobile shell to the **Home tab** (`BottomNavShell.homeReset`) so
    the user isn't stranded in a now-forbidden context, and shows *"You're no longer a X"*. A change that
    does nothing on this device (e.g. an Organizer role granted to a phone) is **silent** — no dialog, no
    logout. This is the device-aware behaviour restored from the pre-stamp shell, now generalised.
- **Reactive (a 401 with a failed refresh).** `BaseProvider` hands off to `AuthProvider.onSessionEnded`,
  which the `AuthGate` points at the same handler — so instead of the caller being stuck on a per-screen
  "session expired" error with a dead *Retry*, the app **pops to the login screen** and shows the same
  dialog. (This is the fix for the old stuck-Retry screen.)

`tryRefresh()` is **single-flight**, so the proactive refresh and a concurrent 401 can't both spend the
rotating refresh token and log the user out spuriously.

### 7.1 Immediate force-logout: suspension & password change/reset
Suspension, password change and password reset are the **hard** cases — they drop the refresh token, so the
silent `tryRefresh()` above *fails* and the device is bounced to login. The trigger is a SignalR push:
suspension enqueues `AccountSuspended`; a password change/reset enqueues `PasswordChanged`
(`UserService.ChangePasswordAsync` / `PasswordResetService.ResetPasswordAsync`, `alsoEmail: true`). Both ride
the existing outbox: the request-scoped `INotificationDispatcher` stages the row, and the global
`NotificationFlushFilter` pushes it to the user's `user-{id}` group once the action commits — so **every**
connected device reacts within a second, not on its own next request. The device that *initiated* an in-app
password change additionally calls `AuthProvider.endSessionAfterPasswordChange()` for a guaranteed instant
local logout even if its own SignalR is momentarily down; the local and pushed paths **dedupe** via a
`_sessionEndedShowing` guard, so there's never a double dialog. (No schema change — `PasswordChanged` is a
new `NotificationType` enum value, stored as the existing int column.)

### 7.2 Desktop forgot-password
The two-step reset flow (request a code → set a new password) now also lives on the **desktop** login screen
(`ForgotPasswordScreen` + a "Forgot password?" link), reusing the shared
`AuthProvider.forgotPassword`/`resetPassword` endpoints. So a reset — and its all-device force-logout above —
is reachable from both apps, not just mobile.

The **admin self-service** case is now unblocked in the desktop user dialog: an admin can grant/revoke their
own non-admin roles (own **Admin** stays non-removable), and the dialog calls `tryRefresh()` right after so
the sidebar reflects the new permissions immediately — the seamless path in action.

## 8. File map

```
Backend/Travle.Model/Constants/TravleClaimTypes.cs        security_stamp claim name
Backend/Travle.Model/Responses/UserResponse.cs            [JsonIgnore] SecurityStamp (server-side only)
Backend/Travle.Services/Database/User.cs                  SecurityStamp column (GUID initializer)
Backend/Travle.Services/Database/Configurations/UserConfiguration.cs   required, maxlength 64
Backend/Travle.Services/Database/TravleSeed.cs            fixed stamps for the 7 seed users
Backend/Travle.Services/Security/UserSecurityStore.cs     cached (stamp, isSuspended) + Invalidate
Backend/Travle.Services/UserService.cs                    bumps on suspend/unsuspend/grant/revoke/change-password; enqueues PasswordChanged on change; InvalidateAllSessionsAsync (logout)
Backend/Travle.Services/PasswordResetService.cs           bump on reset; + INotificationDispatcher, enqueues PasswordChanged
Backend/Travle.Services/Database/Enums.cs                 NotificationType.PasswordChanged (session-affecting; no migration)
Backend/Travle.Services/RoleApplicationService.cs         Approve bumps the stamp, keeps refresh (seamless grant)
Backend/Travle.WebAPI/Services/AccessManager/JwtTokenService.cs   emits the claim
Backend/Travle.WebAPI/Services/AccessManager/AccessManager.cs     logout → InvalidateAllSessionsAsync
Backend/Travle.WebAPI/Program.cs                          IUserSecurityStore registration + OnTokenValidated gate
Backend/Travle.Services/Migrations/20260811144440_AddUserSecurityStamp.cs

--- client (Flutter) ---
UI/travle_core/lib/src/auth/auth_provider.dart            tryRefresh (single-flight), refreshCurrentUser, endSessionAfterPasswordChange, onSessionEnded hook
UI/travle_core/lib/src/auth/session_notifications.dart    sessionAffectingNotificationTypes (+ PasswordChanged) + sessionEndedReason
UI/travle_core/lib/src/network/base_provider.dart         401 → tryRefresh → onSessionEnded handoff
UI/travle_ui/lib/src/widgets/session_ended_dialog.dart    showSessionEndedDialog + showRoleChangeDialog
UI/travle_mobile|desktop/lib/app/auth_gate.dart           owns session-ended handling (proactive push + reactive 401)
UI/travle_mobile/lib/layouts/bottom_nav_shell.dart        homeReset signal (return to Home on a role loss)
UI/travle_desktop/lib/screens/auth/forgot_password_screen.dart   desktop two-step password reset (+ login link)
UI/travle_mobile|desktop/lib/util/notification_display.dart      PasswordChanged icon (Icons.lock_reset)
UI/travle_mobile/lib/screens/profile/change_password_screen.dart, UI/travle_desktop/lib/screens/account_screen.dart   self change → endSessionAfterPasswordChange
```

## 9. Build log

- **2026-08-13** — Whole client force-logout flow **device-verified** end-to-end on both apps: seamless
  role grant/revoke, immediate SignalR force-logout on suspension **and** on password change/reset (every
  connected device), the role-loss Home reset, and desktop forgot-password. Doc body brought up to the
  current state — top status note, §1 forward-reference, §7 (now including `PasswordChanged` +
  `refreshCurrentUser` + the Home reset), new §7.1/§7.2, and the §8 file map. Behaviour unchanged since the
  2026-08-12 entry; this is the verification + doc-sync pass.
- **2026-08-12** — Follow-up polish (three items; all Flutter packages analyze clean):
  1. **Desktop forgot-password.** Ported the mobile two-step reset flow to a desktop
     `ForgotPasswordScreen` (reuses the shared `AuthProvider.forgotPassword`/`resetPassword`
     endpoints — no backend change) + a "Forgot password?" link on the desktop login screen.
  2. **Immediate force-logout on password change/reset (all devices, like suspension).** A new
     `NotificationType.PasswordChanged` is enqueued on both `UserService.ChangePasswordAsync` (in-app
     change) and `PasswordResetService.ResetPasswordAsync` (forgot-password) — `alsoEmail: true` — so
     the existing dispatcher→SignalR push (flushed by the global `NotificationFlushFilter`) reaches
     **every** connected device on the `user-{id}` group. The client treats `'PasswordChanged'` as a
     `sessionAffectingNotificationType`: its silent refresh fails (refresh tokens are already dropped),
     so it routes straight to login with a "sign in again" message — the same path suspension uses.
     `PasswordResetService` gained an `INotificationDispatcher` dependency. On top of the push, the
     **acting** device also calls the new `AuthProvider.endSessionAfterPasswordChange()` for a
     guaranteed instant local logout (belt-and-suspenders if its own SignalR is momentarily down);
     the two paths dedupe via the `_sessionEndedShowing` guard. Notification-centre icon added on both
     apps (`Icons.lock_reset`).
  3. **Seamless role-loss UX fix.** After a silent refresh the client's cached profile
     (`currentUser`, whose `roles` gate the mobile profile menu) was stale, so a revoked role's
     entry (e.g. "My destinations") lingered and led to a dead-end "forbidden" screen. Both AuthGates
     now call the new `AuthProvider.refreshCurrentUser()` after the silent refresh; on a **role loss**
     the mobile shell is additionally reset to the Home tab (`BottomNavShell.homeReset` signal) so the
     user isn't left in a now-forbidden context. Desktop nav already read the live JWT roles, so it
     only needed the profile re-fetch for its Account screen.


- **2026-08-11** — Server-side boundary shipped (compiles clean, 0/0). `SecurityStamp` column + migration;
  `security_stamp` claim; cached `IUserSecurityStore`; `OnTokenValidated` gate (suspended + stale-stamp →
  401); stamp bumps on suspend/unsuspend, role grant/revoke (self non-admin keeps refresh), password
  change, password reset, and logout. Client force-logout UX intentionally deferred (§7). Verified by Haris
  against the two original repro cases (and others).
- **2026-08-11** — Client force-logout UX shipped (§7). `AuthGate` (both apps) made stateful and now owns
  session-ended handling: session-affecting push → silent `tryRefresh` (seamless) or `showSessionEndedDialog`
  + route to login; reactive `AuthProvider.onSessionEnded` from `BaseProvider` does the same (fixes the
  stuck "session expired / Retry" screen). `tryRefresh` made single-flight. `RoleApplicationService.Approve`
  now bumps the stamp too (consistency). Desktop user dialog: **admin self role grant/revoke unblocked**
  (own Admin non-removable) with a post-change `tryRefresh` so permissions apply seamlessly. Mobile shell's
  old role-reauth logic removed (moved to the gate); desktop toast skips session-affecting types. **Not yet
  device-tested.**
- **2026-08-11** — Role changes made **seamless & device-aware** (all Flutter packages analyze clean).
  Grants, revokes and application-approve now **keep** the refresh token (still bump the stamp) → the client
  silently refreshes to the new claims instead of being forced to log out; a role that does nothing on the
  current device is completely silent. `AuthGate` diffs old→new roles and shows `showRoleChangeDialog`
  (*"You're now / no longer a X"*, new in travle_ui) only for a device-usable change, popping off any gated
  screen on a loss. Only suspension / password change / logout still drop refresh (hard). Fixed the
  now-inaccurate "they will be signed out" revoke copy. **Not yet device-tested.**
