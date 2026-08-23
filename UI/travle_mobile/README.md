# travle_mobile

The Travle **mobile client** (Flutter, Android) — the traveler and curator app.

Travelers search destinations, browse tours and departures, book and pay in-app
(Stripe PaymentSheet), manage their booking history, leave reviews, and receive
explained recommendations plus real-time notifications. Curators apply for the
role, submit destinations for moderation, and track their submissions.

It depends on two path packages in this repo: `travle_core` (models, providers,
auth, networking) and `travle_ui` (design tokens and shared widgets).

Run and build instructions — including the `--dart-define=API_BASE_URL=…`
configuration and the `env*.json` files — are in [`../RUNNING.md`](../RUNNING.md)
and in the repository [`README.md`](../../README.md).
