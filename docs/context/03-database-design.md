# 03 — Database Design (rev. 3, final)

Database name: **230172** · SQL Server · EF Core Code First · all FKs via per-entity `IEntityTypeConfiguration<T>` inheriting `BaseEntityConfiguration<T>` (02 §2b/§4). All decisions final; the reconciliation record is `00-ANALYSIS-AND-OPEN-QUESTIONS.md`.

## 0. BaseEntity

All entities inherit `BaseEntity { Id, CreatedAt (UTC), ModifiedAt? }` (timestamps set centrally in the DbContext). Pure m2m link tables without meaningful attributes may stay bare. Columns below omit these common fields.

## 1. Main tables (course minimum: 10 — final: 17)

| # | Table | Key fields | Notes |
|---|---|---|---|
| 1 | **Users** | FirstName, LastName, Username (uq), Email (uq), PhoneNumber, PasswordHash+Salt, ProfileImage (byte[]?), **IsSuspended, SuspendedAt?, SuspendedByUserId?, SuspensionReason?**, CityId FK? | PBKDF2/bcrypt; suspension = domain flag + audit (not on BaseEntity); suspending also revokes refresh tokens; login **and** refresh check the flag |
| 2 | **RefreshTokens** | UserId FK, Token (hashed), ExpiresAt, RevokedAt? | logout deletes all for user |
| 3 | **RoleApplications** | UserId FK, RoleId FK (Curator/Organizer), Motivation, RegionId FK?, Document (bytes/path)?, Status, DecidedByUserId?, DecidedAt?, RejectionReason? | audit built in |
| 4 | **Destinations** | Name, Description, CategoryId FK, CityId FK, Latitude, Longitude, SubmittedByUserId FK, Status (Pending/Approved/Rejected), ModeratedByUserId?, ModeratedAt?, RejectionReason?, IsFeatured, AverageRating (denorm.), ViewCount | any edit ⇒ back to Pending |
| 5 | **DestinationImages** | DestinationId FK, ImageData, ThumbnailData, ContentType, SortOrder | thumbnails ~15–30 KB for lists |
| 6 | **Tours** | OrganizerId FK, Name, Description, DurationMinutes, PricePerPerson decimal(18,2), Capacity, TourTypeId FK, IsActive | no refund-policy FK — policy is global |
| 7 | **TourSchedules** | TourId FK, StartsAt/EndsAt (UTC), Capacity, SeatsTaken, Status (Active/Cancelled), CancelledReason?, CancelledAt? | seats math here |
| 8 | **Bookings** | UserId FK, TourScheduleId FK, NumberOfPeople, TotalAmount, StatusId FK, StatusChangedAt, ConfirmedByUserId?, RejectionReason?, CancelledByUserId?, CancellationReason?, ExpiresAt? (**+15 min** for PaymentInProgress) | state machine only |
| 9 | **Payments** | BookingId FK, StripePaymentIntentId (uq), Amount, Currency, PlatformFeePercentage, PlatformFeeAmount, Status, SucceededAt? | fee snapshot from config |
| 10 | **Refunds** | PaymentId FK, StripeRefundId, Amount, PercentageApplied, Reason, InitiatedByUserId FK | actual-amount based |
| 11 | **DestinationReviews** | DestinationId FK, UserId FK, Rating 1–5, Comment, IsRemoved, RemovedByUserId?, RemovalReason? | open to registered users |
| 12 | **TourReviews** | TourId FK, BookingId FK (uq), UserId FK, Rating, Comment, IsRemoved (+audit) | gate: own Completed booking |
| 13 | **Favorites** | UserId FK, DestinationId FK?, TourId FK? (CHECK: exactly one; uq per pair) | |
| 14 | **Notifications** | UserId FK, Title, Text, Type (enum), IsRead, ReadAt?, RelatedEntityId? | SignalR push on insert |
| 15 | **UserInteractions** | UserId FK, DestinationId FK?, InteractionType (View/Search/Favorite/BookingConfirmed/BookingCompleted/ReviewHigh/OnboardingInterest), Weight, SearchTerm?, CategoryId FK?/TagId FK? (onboarding rows carry these directly with DestinationId null; Search rows store the matched CategoryId/TagId alongside SearchTerm so the scorer maps searches to features without re-parsing text) | recommender fuel — written at runtime |
| 16 | **PasswordResetCodes** | UserId FK, CodeHash, ExpiresAt, UsedAt? | hashed + expiring (Dodatak A.3) |
| 17 | **RecommendationLogs** | UserId FK, DestinationId FK, Score, Reason, ServedAt | audit of *served* recommendations; output-only, never an input to scoring |

Cut: News.

## 2. Reference tables

Countries · Regions (CountryId) · Cities (RegionId) · DestinationCategories · TourTypes · Tags · **DestinationTags** (m2m) · **TourDestinations** (m2m + SortOrder) · BookingStatuses (seeded exactly: PaymentInProgress, Pending, Confirmed, Completed, Cancelled, Expired — names must match the state machine and any UI/filter usage) · Roles · **UserRoles** (m2m — multi-role users are expected: course lists UserRole/Role among reference tables and the credentials table anticipates multi-role accounts; Traveler+Curator share one account) · **RefundPolicyTiers** (HoursBeforeMin, HoursBeforeMax, Percentage — seeded: >72h/100, 24–72/50, 1–24/25, <1/0).

All admin-CRUDable on desktop. Reference values always FKs — never strings.

## 3. Delete strategy — per entity (the concrete matrix)

General rules first (from 02 §6a): `Restrict` is the default FK behavior; `Cascade` only for true children; business-process records are never hard-deleted; blocked deletions surface a `ConflictException` with a human message; UI renders blocked deletes as **disabled with the reason shown**; no global EF soft-delete query filter — soft flags are per-entity, named for their meaning, and filtered explicitly in services.

### Main tables

| Entity | Strategy | Details |
|---|---|---|
| **Users** | NO deletion | Never deleted (FK target of half the schema). "Removal" = suspension (`IsSuspended` + audit). No delete endpoint exists. |
| **RefreshTokens** | HARD | Technical rows: logout deletes all for the user; the scheduler may purge expired ones. Cascade from Users. |
| **RoleApplications** | NO deletion (status-driven) | Pending → Approved/Rejected with audit; the history *is* the value. No delete endpoint. |
| **Destinations** | Conditional HARD, then status-only | Submitter (or admin) may hard-delete **only while Pending** and unreferenced (images cascade away). Once Approved/Rejected: never deleted — moderation status + `IsFeatured` toggles only; blocked with message if tours/reviews reference it. |
| **DestinationImages** | HARD | Composition child: cascade with the destination; individually hard-deletable while editing. |
| **Tours** | SOFT via `IsActive` | "Delete" from the organizer's perspective = deactivate (hidden from browsing/new bookings; history intact). Hard delete allowed only if the tour never had a schedule. |
| **TourSchedules** | Status-driven; conditional HARD | Cancellation = status change (Cancelled + reason + mass refund + notifications). Hard delete allowed only for a future slot with **zero** bookings (fixing a typo-slot). |
| **Bookings** | NEVER (status machine only) | Course §7 names this explicitly. Even `Expired` rows are kept — they are audit evidence of the hold/expiry flow. |
| **Payments** | NEVER | Financial record. No delete endpoint. |
| **Refunds** | NEVER | Financial record. No delete endpoint. |
| **DestinationReviews** | SOFT via `IsRemoved` | Admin moderation (and self-removal, if exposed) sets the flag + who/when/reason. Rating aggregates recompute excluding removed. |
| **TourReviews** | SOFT via `IsRemoved` | Same as above; the unique `BookingId` stays occupied (no re-review after removal — deliberate). |
| **Favorites** | HARD | Toggle-off deletes the row; pure preference, no audit value. The `Favorite` row in UserInteractions **stays** — the diary is append-only. |
| **Notifications** | HARD (owner) | User may clear own notifications; cascade from Users. Read/unread state is the primary lifecycle, deletion is convenience. |
| **UserInteractions** | APPEND-ONLY | Never deleted or updated — recommender integrity depends on it. |
| **PasswordResetCodes** | HARD (purge) | Consumed or expired codes purged by the scheduler. Technical rows. |
| **RecommendationLogs** | APPEND-ONLY (+ optional retention purge) | Never user-deletable; an optional maintenance purge (>90 days) is allowed as a documented job, respecting no FKs since nothing references it. |

### Reference tables

| Entity | Strategy | Details |
|---|---|---|
| Countries / Regions / Cities / DestinationCategories / TourTypes / Tags | HARD via admin CRUD | `Restrict`-blocked with a counted message when referenced ("Cannot delete category 'Historija': used by 12 destinations"). |
| DestinationTags / TourDestinations / UserRoles (m2m) | HARD | Composition rows managed through their parents' edit forms; removing a tag from a destination deletes the link row, never the Tag. |
| BookingStatuses / Roles | Effectively NO deletion | Always referenced and code depends on the seeded names; UI shows delete permanently disabled with that reason. |
| RefundPolicyTiers | HARD via admin CRUD | Editable/deletable — no FKs point at tiers (Refund rows snapshot `PercentageApplied`), so historical refunds stay correct even if tiers change. |

If any soft-flagged data is ever purged (not planned), children before parents (course §3.1).

## 4. Denormalized fields

`AverageRating`, `ViewCount`, `SeatsTaken` maintained transactionally alongside the causing write; all three are consumed (UI + recommender popularity) — no collected-but-ignored signals.

## 5. Indexes

Unique: Users.Username, Users.Email, Payments.StripePaymentIntentId, TourReviews.BookingId, Favorites(UserId, DestinationId/TourId). **Filtered unique:** Bookings(UserId, TourScheduleId) WHERE status ∈ {PaymentInProgress, Pending, Confirmed}. Search: Destinations(Name), Destinations(CategoryId, Status), TourSchedules(StartsAt), UserInteractions(UserId, CreatedAt), Notifications(UserId, IsRead).

## 6. Capacity & concurrency contract

Seat allocation inside one DB transaction at booking creation:

```sql
UPDATE TourSchedules
SET SeatsTaken = SeatsTaken + @people
WHERE Id = @scheduleId AND Status = Active
  AND SeatsTaken + @people <= Capacity;   -- 0 rows ⇒ ConflictException("slot full")
```

(EF: `ExecuteUpdateAsync` with the guard in the predicate, inside an explicit transaction with the Booking insert.) Releases (15-min expiry, cancellation, rejection) decrement the same way. The filtered unique index kills duplicates under races. Overlap rule: reject bookings whose schedule time range intersects another active booking of the same user (range query, server-side).

## 7. Seed plan (grading depends on this)

- Reference data complete: 2 countries (BiH + one extra), 6+ regions, 15+ cities, 6+ categories, 15+ tags, tour types, statuses, roles, refund tiers.
- 25–40 destinations **with images + thumbnails**: Stari Most, Kravice, Vrelo Bosne, Tvrđava Ostrožac, Stari grad Bihać, Tvrđava Srebrenik, Blagaj Tekija, Počitelj, Jajce, NP Una...
- 8–12 tours across 3+ organizers; past **and** future schedules; bookings in **every** status (Completed with reviews, Cancelled with refunds, one Expired) so state machine, refunds, statistics and reports show data on first run.
- Users: `desktop`/`test` (Admin), `mobile`/`test` (Traveler with rich interaction history incl. onboarding interests so recommendations are non-trivial immediately), `organizer`/`test`, `curator`/`test`, filler users. One pending curator application + one pending destination so moderation screens are non-empty.
- `HasData` for reference data; runtime seeder for heavy rows + images; identical hash formats in both (course rule).
