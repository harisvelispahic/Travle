import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../../util/booking_display.dart';
import '../../util/formatting.dart';
import '../../widgets/entrance_fee_note.dart';
import '../../widgets/organizer_row.dart';
import '../../widgets/review_card.dart';
import '../../widgets/review_form_sheet.dart';
import '../tour_details_screen.dart';

/// The detail half of the traveler's booking master-detail. Shows the full
/// booking (tour, schedule, party, total, status, audit) and the actions the
/// current state permits: paying a held booking, cancelling a Pending/Confirmed
/// booking with the applicable refund-tier summary shown first, and — once the
/// booking is Completed — leaving (or editing) a review of the tour.
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  BookingResponse? _booking;
  bool _loading = true;
  bool _busy = false;
  // True while we wait for the Stripe webhook to promote a just-paid booking to Pending.
  bool _confirmingPayment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking =
          await context.read<BookingProvider>().getDetail(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _openTour() {
    final booking = _booking;
    if (booking == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TourDetailsScreen(
          tourId: booking.tourId,
          initialName: booking.tourName,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final booking = _booking!;
    final reason = await _promptCancel(booking);
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await context
          .read<BookingProvider>()
          .cancel(booking.id, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _busy = false;
      });
      AppSnackbars.success(context, 'Your booking has been cancelled.');
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  // Returns the (possibly empty) reason when confirmed, or null when dismissed.
  Future<String?> _promptCancel(BookingResponse booking) {
    final pct = booking.cancellationRefundPercentage;
    final refundLine = pct == null
        ? 'A refund will be calculated from the cancellation policy.'
        : pct > 0
            ? "You'll be refunded $pct% of ${formatPrice(booking.totalAmount)} "
                '(${formatPrice(booking.totalAmount * pct / 100)}).'
            : 'This cancellation is not eligible for a refund '
                '(less than 1 hour before departure).';

    return showReasonDialog(
      context,
      title: 'Cancel booking',
      message: refundLine,
      label: 'Reason (optional)',
      isRequired: false,
      cancelLabel: 'Keep booking',
      confirmLabel: 'Cancel booking',
    );
  }

  Future<void> _pay() async {
    final booking = _booking!;

    // Show the amount + the cancellation-refund policy before charging (spec §3.4).
    final confirmed = await _confirmPay(booking);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // 1. Server creates the PaymentIntent (amount + fee snapshot are server-side).
      final intent =
          await context.read<PaymentProvider>().createIntent(booking.id);

      // 2. Initialise the Stripe SDK with the (non-secret) publishable key the
      //    server returned, then present the PaymentSheet for the client secret.
      stripe.Stripe.publishableKey = intent.publishableKey;
      await stripe.Stripe.instance.applySettings();
      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'Travle',
        ),
      );
      await stripe.Stripe.instance.presentPaymentSheet();

      // 3. The card is confirmed. Success is recorded server-side by the webhook,
      //    which promotes the booking to Pending — poll until that lands.
      if (!mounted) return;
      setState(() => _confirmingPayment = true);
      await _awaitPaymentConfirmed(booking.id);
    } on stripe.StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _confirmingPayment = false;
      });
      // A user-cancelled sheet is not an error; anything else is surfaced. A decline
      // fails only this attempt — the booking keeps its 15-minute hold, so the Pay
      // button stays and another card can be tried until the countdown runs out.
      if (e.error.code != stripe.FailureCode.Canceled) {
        AppSnackbars.error(
            context,
            '${e.error.localizedMessage ?? 'Payment failed.'} Your seats are still '
            'held — you can try another card.');
        await _refreshQuietly();
      }
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _confirmingPayment = false;
      });
      AppSnackbars.error(context, e.message);
    }
  }

  // Re-reads the booking without flashing the loading state — used after a declined
  // card, where the screen is already populated and only the hold or the allowed
  // actions may have moved on.
  Future<void> _refreshQuietly() async {
    try {
      final booking =
          await context.read<BookingProvider>().getDetail(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = booking);
    } on ApiClientException {
      // Non-fatal: what is already on screen stays.
    }
  }

  // Amount + refund-policy confirmation shown before the PaymentSheet. Returns true
  // when the traveler confirms. The policy tiers are read live so they always match
  // what the server would actually refund.
  Future<bool?> _confirmPay(BookingResponse booking) async {
    List<RefundPolicyTierResponse> tiers = const [];
    try {
      final result = await RefundPolicyTierProvider().get();
      tiers = result.items.toList()
        ..sort((a, b) => b.hoursBeforeMin.compareTo(a.hoursBeforeMin));
    } on ApiClientException {
      // Non-fatal: still allow paying without the policy table.
    }
    if (!mounted) return false;

    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You'll be charged ${formatPrice(booking.totalAmount)} for "
              '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'seat' : 'seats'}.',
              style: theme.textTheme.bodyMedium,
            ),
            if (booking.entranceFeesPerPerson > 0) ...[
              const SizedBox(height: TravleTokens.space8),
              Text(
                'Separately, bring around ${formatPrice(booking.entranceFeesPerPerson)} '
                'per person for on-site entrance fees — not charged by Travle.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (tiers.isNotEmpty) ...[
              const SizedBox(height: TravleTokens.space16),
              Text('If you cancel later', style: theme.textTheme.titleSmall),
              const SizedBox(height: TravleTokens.space8),
              ...tiers.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: TravleTokens.space4),
                  child: Text('• ${_refundTierLine(t)}',
                      style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Pay ${formatPrice(booking.totalAmount)}'),
          ),
        ],
      ),
    );
  }

  // Human-readable line for one refund tier, e.g. "More than 72h before: 100% back".
  String _refundTierLine(RefundPolicyTierResponse t) {
    final String window;
    if (t.hoursBeforeMax == null) {
      window = 'More than ${t.hoursBeforeMin}h before departure';
    } else if (t.hoursBeforeMin == 0) {
      window = 'Less than ${t.hoursBeforeMax}h before departure';
    } else {
      window = '${t.hoursBeforeMin}–${t.hoursBeforeMax}h before departure';
    }
    return t.percentage > 0
        ? '$window: ${t.percentage}% refunded'
        : '$window: no refund';
  }

  // Polls the booking after a confirmed card payment until the webhook has promoted
  // it (paid / no longer PaymentInProgress), or a short timeout elapses.
  Future<void> _awaitPaymentConfirmed(int bookingId) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      try {
        final updated =
            await context.read<BookingProvider>().getDetail(bookingId);
        if (!mounted) return;
        if (updated.isPaid || !updated.isPaymentInProgress) {
          setState(() {
            _booking = updated;
            _busy = false;
            _confirmingPayment = false;
          });
          AppSnackbars.success(
              context, 'Payment successful — your booking is awaiting confirmation.');
          return;
        }
      } on ApiClientException {
        // Transient — keep polling.
      }
    }

    // The webhook hasn't landed yet; leave the booking as-is and let the user know.
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirmingPayment = false;
    });
    AppSnackbars.success(
        context, 'Payment received. Your booking will update shortly.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final booking = _booking!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        _Header(booking: booking, onOpenTour: _openTour),
        const SizedBox(height: TravleTokens.space16),
        OrganizerRow(
          organizerId: booking.organizerId,
          organizerName: booking.organizerName,
        ),
        const SizedBox(height: TravleTokens.space16),
        _DetailCard(booking: booking),
        if (booking.entranceFeesPerPerson > 0) ...[
          const SizedBox(height: TravleTokens.space16),
          EntranceFeeNote(amountPerPerson: booking.entranceFeesPerPerson),
        ],
        if (booking.isPaymentInProgress && booking.expiresAt != null) ...[
          const SizedBox(height: TravleTokens.space16),
          _HoldNotice(expiresAt: booking.expiresAt!),
        ],
        if (booking.rejectionReason != null &&
            booking.rejectionReason!.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space16),
          _ReasonNotice(
            icon: Icons.block_outlined,
            title: 'Rejected by the organizer',
            text: booking.rejectionReason!,
          ),
        ],
        if (booking.cancellationReason != null &&
            booking.cancellationReason!.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space16),
          _ReasonNotice(
            icon: Icons.info_outline,
            title: 'Cancellation reason',
            text: booking.cancellationReason!,
          ),
        ],
        const SizedBox(height: TravleTokens.space24),
        if (_confirmingPayment) ...[
          _ConfirmingPaymentNotice(),
          const SizedBox(height: TravleTokens.space16),
        ],
        if (booking.canCancel && booking.cancellationRefundPercentage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TravleTokens.space8),
            child: Row(
              children: [
                Icon(Icons.savings_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: TravleTokens.space8),
                Expanded(
                  child: Text(
                    'Cancel now → ${booking.cancellationRefundPercentage}% refund.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ..._actions(booking),
        _BookingReviewSection(booking: booking, onChanged: _load),
      ],
    );
  }

  List<Widget> _actions(BookingResponse booking) {
    final actions = <Widget>[];
    if (booking.canPay) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _pay,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Pay now'),
        ),
      );
    }
    if (booking.canCancel) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(height: TravleTokens.space8));
      }
      actions.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel booking'),
        ),
      );
    }
    return actions;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking, required this.onOpenTour});

  final BookingResponse booking;
  final VoidCallback onOpenTour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThumbnailImage(
          base64: booking.tourThumbnail,
          width: 96,
          height: 96,
          placeholderIcon: Icons.tour_outlined,
        ),
        const SizedBox(width: TravleTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onOpenTour,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(booking.tourName,
                          style: theme.textTheme.titleLarge),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: TravleTokens.space8),
              StatusPill(
                label: bookingStatusLabel(booking.status),
                tone: bookingStatusTone(booking.status),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.booking});

  final BookingResponse booking;

  @override
  Widget build(BuildContext context) {
    final peopleLabel =
        '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          children: [
            _Row(
              icon: Icons.event_outlined,
              label: 'Departure',
              value: formatEventScheduleRange(booking.scheduleStartsAt,
                  booking.scheduleEndsAt, booking.timeZoneId),
            ),
            const Divider(height: TravleTokens.space24),
            _Row(
              icon: Icons.group_outlined,
              label: 'Party',
              value: peopleLabel,
            ),
            const Divider(height: TravleTokens.space24),
            _Row(
              icon: Icons.payments_outlined,
              label: 'Total',
              value: formatPrice(booking.totalAmount),
            ),
            const Divider(height: TravleTokens.space24),
            _Row(
              icon: booking.isPaid
                  ? Icons.check_circle_outline
                  : Icons.pending_outlined,
              label: 'Payment',
              value: booking.isPaid ? 'Paid' : 'Not paid',
            ),
            if (booking.confirmedByName != null) ...[
              const Divider(height: TravleTokens.space24),
              _Row(
                icon: Icons.verified_outlined,
                label: 'Confirmed by',
                value: booking.confirmedByName!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: TravleTokens.space12),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        const SizedBox(width: TravleTokens.space12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// A live count-down of the 15-minute payment hold. Ticks once a second toward
/// [expiresAt] and stops at 00:00 (never goes negative). The remaining time is
/// computed in UTC on both sides (see [asUtcInstant]) so it is correct on any
/// device time zone.
class _HoldNotice extends StatefulWidget {
  const _HoldNotice({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_HoldNotice> createState() => _HoldNoticeState();
}

class _HoldNoticeState extends State<_HoldNotice> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _timeLeft();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = _timeLeft();
        if (!mounted) return;
        setState(() => _remaining = left);
        if (left <= Duration.zero) _timer?.cancel();
      });
    }
  }

  Duration _timeLeft() {
    final diff = asUtcInstant(widget.expiresAt).difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = _remaining <= Duration.zero;
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer_outlined,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seats held', style: theme.textTheme.titleSmall),
                const SizedBox(height: TravleTokens.space4),
                Text(
                  '$mm:$ss',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: expired
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: TravleTokens.space4),
                Text(
                  expired
                      ? 'This hold has expired — the seats may have been released.'
                      : 'Complete payment before the timer runs out or the seats are released.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while we wait for the Stripe webhook to promote a just-paid booking.
class _ConfirmingPaymentNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Text('Confirming your payment…',
                style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// The tour-review affordance on a completed booking (spec §2.1). For a reviewable
/// booking it offers "Leave a review"; once reviewed it shows the review with an
/// Edit action (or a notice if a moderator removed it). One review per booking is
/// enforced server-side; the booking id stays occupied even after a removal.
class _BookingReviewSection extends StatefulWidget {
  const _BookingReviewSection({required this.booking, required this.onChanged});

  final BookingResponse booking;

  /// Reloads the booking so its `canBeReviewed`/`reviewId` reflect the change.
  final VoidCallback onChanged;

  @override
  State<_BookingReviewSection> createState() => _BookingReviewSectionState();
}

class _BookingReviewSectionState extends State<_BookingReviewSection> {
  TourReviewResponse? _review;
  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.booking.reviewId != null) {
      _loadReview();
    }
  }

  Future<void> _loadReview() async {
    setState(() => _loading = true);
    try {
      final review = await context
          .read<TourReviewProvider>()
          .getById(widget.booking.reviewId!);
      if (!mounted) return;
      setState(() {
        _review = review;
        _loading = false;
      });
    } on ApiClientException {
      // The review section is secondary — fail quietly rather than block the page.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _leaveReview() async {
    final draft = await ReviewFormSheet.show(context, title: 'Review this tour');
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final created = await context.read<TourReviewProvider>().create(
            TourReviewInsertRequest(
              bookingId: widget.booking.id,
              rating: draft.rating,
              comment: draft.comment,
            ),
          );
      if (!mounted) return;
      setState(() {
        _review = created;
        _busy = false;
      });
      AppSnackbars.success(context, 'Thanks — your review has been posted.');
      widget.onChanged();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _editReview() async {
    final review = _review;
    if (review == null) return;

    final draft = await ReviewFormSheet.show(
      context,
      title: 'Edit your review',
      initialRating: review.rating,
      initialComment: review.comment,
      submitLabel: 'Save changes',
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await context.read<TourReviewProvider>().updateReview(
            review.id,
            ReviewUpdateRequest(rating: draft.rating, comment: draft.comment),
          );
      if (!mounted) return;
      setState(() {
        _review = updated;
        _busy = false;
      });
      AppSnackbars.success(context, 'Your review has been updated.');
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _removeReview() async {
    final review = _review;
    if (review == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove your review',
      message: 'Are you sure you want to remove your review of this tour? '
          'You can write a new one later.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<TourReviewProvider>().removeOwn(review.id);
      if (!mounted) return;
      // Clear the local review and reload the booking so it becomes reviewable again.
      setState(() {
        _review = null;
        _busy = false;
      });
      AppSnackbars.success(context, 'Your review has been removed.');
      widget.onChanged();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final review = _review;

    // Only relevant once the booking is Completed (reviewable or already reviewed).
    if (review == null && !booking.canBeReviewed && booking.reviewId == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: TravleTokens.space24),
        Text('Your review', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TravleTokens.space16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (review != null)
          review.isRemoved
              ? _ReasonNotice(
                  icon: Icons.gpp_bad_outlined,
                  title: 'Review removed',
                  text: review.removalReason == null
                      ? 'Your review was removed by a moderator.'
                      : 'Your review was removed by a moderator. '
                          'Reason: ${review.removalReason}',
                )
              : ReviewCard(
                  authorName: review.authorName,
                  rating: review.rating,
                  createdAt: review.createdAt,
                  comment: review.comment,
                  isMine: true,
                  onEdit: _busy ? null : _editReview,
                  onRemove: _busy ? null : _removeReview,
                )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You've completed this tour — share your experience with other travelers.",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: TravleTokens.space12),
              FilledButton.icon(
                onPressed: _busy ? null : _leaveReview,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Leave a review'),
              ),
            ],
          ),
      ],
    );
  }
}

class _ReasonNotice extends StatelessWidget {
  const _ReasonNotice({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: TravleTokens.space4),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
