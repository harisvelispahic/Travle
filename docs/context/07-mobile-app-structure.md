# 07 — Mobile App Structure (text wireframes, rev. 2 — English UI)

Reference: Prijava mockups (Slike 6–11), followed in spirit, not pixel-for-pixel. **UI language: English** (decided). Cut features (gamification, autocomplete, near-you, news) are absent; the dedicated map screen is stretch (00 §3.1).

## Navigation model

**Bottom navigation (4 tabs):** `Home` · `Search` · `Favorites` · `Profile`
**App bar (persistent):** screen title + 🔔 notifications icon with unread badge → Notifications screen.
Auth screens live outside the shell; everything else inside it.

```
Login ─ Register ─ Onboarding interests ─ Forgot password
  └→ Shell(bottom nav)
       ├─ Home → DestinationDetails / TourDetails
       ├─ Search → DestinationDetails
       ├─ Favorites → DestinationDetails / TourDetails
       └─ Profile → EditProfile / ChangePassword / MyBookings → BookingDetails
                    → Curator: BecomeCurator | MyDestinations → DestinationForm
       🔔 Notifications (reachable from any screen)
```

## Screens

### 1. Auth
- **Login:** username, password, [Sign in], links: Create account · Forgot password. Errors under fields.
- **Register:** first/last name, username, email, phone, password + confirm → onboarding.
- **Onboarding interests:** "What are you interested in?" — chip grid of categories (+ popular tags), [Skip] / [Continue]. Each pick → one `UserInteractions` row (OnboardingInterest, weight 2, CategoryId/TagId set).
- **Forgot password:** email → "code sent" → code + new password + confirm.

### 2. Home (mockup Slika 6)
Search bar (tap → Search tab, focused). Horizontal-scroll sections:
- **Featured destinations** — card: thumbnail, name, city/region, rating stars.
- **Recommended for you** — recommender output; card shows the *reason line in italics* ("Because you visited historic fortresses"). Cold-start users see a "Popular right now" label instead.
- **Popular tours** — name, destination count · duration · price, rating (count), [Details].
Pull-to-refresh. Card tap → details.

### 3. Search (mockup Slika 7)
Text field (submit = search; logs a Search interaction). Filter chips: `Category ▾` `Region ▾` `Rating ▾` — bottom sheets fed from the DB + clear. Result count line ("3 results for 'castle'"). Result card: thumbnail (lists carry thumbnails only), name, city + region, category/tags, rating. Empty state with hint. Infinite scroll over the paged endpoint.

### 4. Destination details (mockup Slika 8)
Gallery carousel (full images via detail endpoint; decoded once + cached). Name; city, region. Stars + "(156 reviews)". ♡ favorite toggle (logs Favorite). Tag chips. **Description** (collapsed, "Read more"). **Location** — map preview with pin. **Available tours** — cards: name, duration · price · seats left, [Book]. **Similar destinations** — horizontal cards with reason line ("Also a medieval fortress in Bosanska Krajina"). **Reviews** — list + [Write a review] (any registered user; stars + comment dialog). Opening the screen logs a View. Back button.

### 5. Book a tour (mockup Slika 9)
Tour header: name, destination chain ("Baščaršija → Tunel spasa → Vijećnica"), duration · organizer. **Choose a time slot** — chip row of upcoming slots ("Jun 15 — 10:00", local time), selected highlighted; "8 of 15 seats available". **Number of people** — stepper capped at free seats. **Price summary** — price/person × count, **Total** (all values from the server quote). Refund line: "Free cancellation until 72h before departure" (+ link to full tiers). [**Pay**] → booking created (PaymentInProgress, 15-min hold hint) → Stripe **PaymentSheet** → success screen ("Booking awaiting organizer confirmation") → MyBookings. Failure/timeout → clear message; seats released server-side.

### 6. My bookings (mockup Slika 10) — under Profile
Filter chips: `All` `Active` `Completed`. Card: tour name + status pill (Pending = amber, Confirmed = green, Completed = blue, Cancelled = red), date—time (local), n people · amount, organizer; actions: [Cancel] (active only → confirmation dialog showing the computed refund amount + tier) · [Write a review] (Completed without review) · [Details →].
**Booking details (the master-detail form):** master = summary + status timeline (created → paid → confirmed → …); detail = tour + destinations, schedule, people/price breakdown, payment info (amount, IsPaid state), refund info if any, cancel action. Back button.

### 7. Favorites
Tabs: `Destinations` / `Tours`. Cards as in search; ♡ to remove; empty states. Tap → details.

### 8. Profile
Header: avatar, name, email. Items:
- **Edit profile** — image picker + personal data; validation under fields.
- **Change password** — old + new + confirm.
- **My bookings** → screen 6.
- **Curator section:** if not curator → [Become a curator] (motivation, region dropdown; status shown while Pending); if curator → **My destinations**: chips (Pending / Approved / Rejected — rejected shows the reason), [+ New destination] → **Destination form** (mockup Slika 11): name*, category dropdown*, description*, tag chips + add, image picker grid, **location* via map modal or address lookup** (never raw lat/lng textboxes), [Submit for approval]. Editing an approved destination warns: "Editing sends the destination back for moderation."
- **Log out** — confirmation → Logout endpoint (server revokes refresh tokens) → Login.

### 9. Notifications (🔔)
List: unread bold with dot, title, text, relative time; tap = mark read (+ navigate to the related entity when applicable); "Mark all as read". Live inserts via SignalR while the app is open; badge updates everywhere.

## Stretch: Map screen (post-Phase-11, defined in 00 §3.1)
A dedicated screen (opened from Search or a 5th tab) rendering Approved destinations as tappable markers on an interactive map (flutter_map + OpenStreetMap), fed by a light bbox-filtered endpoint; marker tap → mini card → details.

## Cross-cutting UI rules (from 01, enforced on every screen)
English UI; UTC from the API, formatted to local time for display; dropdowns fed from the DB; DateTime pickers; confirmation dialogs for irreversible actions; Back buttons; disabled actions show the reason; no DB IDs anywhere; validation under controls; meaningful success messages; images never >50% of a form; thumbnails in lists, full images in details only.
