# Auth Token Invalidation (Security Stamp + Gate) — Design and Build Log

Living document for making Travle's stateless JWT access tokens **revocable**, so an auth change
(suspension, role grant/revoke, password change, logout) takes effect **on the account's next request**
instead of lingering until the token naturally expires. Started 2026-08-11.

Written to be read top-to-bottom by someone who has never seen the code.

> **Status.** The **server-side boundary** described here is implemented and compiles clean. The
> **client force-logout UX** (an immediate SignalR-driven sign-out + friendly message) is a **planned**
> follow-up — the boundary already produces correct behaviour on the client's *next* action without it.

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

Force-logout over SignalR is **not** a fix for either: it's best-effort UX (an offline or uncooperative
client never receives the push). The fix has to be **server-side**.

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
| **Grant role** (other user) | ✔ | ✔ | next request 401 → refresh fails → re-login → token carries the new role |
| **Revoke role** (other user) | ✔ | ✔ | next request 401 → refresh fails → re-login → token no longer carries the role |
| **Admin grants/revokes their _own_ non-admin role** | ✔ | ✖ | next request 401 → **silent** refresh (refresh kept) → new token with updated claims, **no visible logout** |
| **Password change** (self) | ✔ | ✔ | every session ends; signs in again with the new password |
| **Password reset** (forgot-password) | ✔ | ✔ | same — every session ends |
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
  `RoleApplicationApproved`) it attempts a **silent `tryRefresh()`**:
  - **succeeds** → the refresh token was kept (an admin changing their **own non-admin** role) → the new
    claims apply seamlessly, **no dialog**;
  - **fails** → the session was hard-invalidated → it routes to login and shows `showSessionEndedDialog`
    with a reason drawn from the notification (e.g. *"…the Curator role has been approved. You need to sign
    in again to continue."*).
- **Reactive (a 401 with a failed refresh).** `BaseProvider` hands off to `AuthProvider.onSessionEnded`,
  which the `AuthGate` points at the same handler — so instead of the caller being stuck on a per-screen
  "session expired" error with a dead *Retry*, the app **pops to the login screen** and shows the same
  dialog. (This is the fix for the old stuck-Retry screen.)

`tryRefresh()` is **single-flight**, so the proactive refresh and a concurrent 401 can't both spend the
rotating refresh token and log the user out spuriously.

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
Backend/Travle.Services/UserService.cs                    bumps on suspend/unsuspend/grant/revoke/change-password; InvalidateAllSessionsAsync (logout)
Backend/Travle.Services/PasswordResetService.cs           bump on reset
Backend/Travle.WebAPI/Services/AccessManager/JwtTokenService.cs   emits the claim
Backend/Travle.WebAPI/Services/AccessManager/AccessManager.cs     logout → InvalidateAllSessionsAsync
Backend/Travle.WebAPI/Program.cs                          IUserSecurityStore registration + OnTokenValidated gate
Backend/Travle.Services/Migrations/20260811144440_AddUserSecurityStamp.cs
```

## 9. Build log

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
