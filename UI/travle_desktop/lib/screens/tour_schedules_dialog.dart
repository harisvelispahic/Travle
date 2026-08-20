import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';

/// Opens the schedule (slot) manager for a tour. Resolves when the dialog is
/// closed; the caller then refreshes the tour list (upcoming counts may change).
Future<void> showTourSchedulesDialog(BuildContext context, TourResponse tour) {
  return showDialog<void>(
    context: context,
    builder: (_) => TourSchedulesDialog(tour: tour),
  );
}

class TourSchedulesDialog extends StatefulWidget {
  const TourSchedulesDialog({super.key, required this.tour});

  final TourResponse tour;

  @override
  State<TourSchedulesDialog> createState() => _TourSchedulesDialogState();
}

class _TourSchedulesDialogState extends State<TourSchedulesDialog> {
  bool _includePast = false;

  bool _loading = true;
  String? _error;
  List<TourScheduleResponse> _items = [];
  final Set<int> _acting = {};

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
      final result = await context.read<TourProvider>().schedules(
        widget.tour.id,
        filter: {
          'pageSize': 100,
          'includeTotalCount': true,
          if (!_includePast) ...{
            'activeOnly': true,
            // Server-side "starts after now" (compared to UtcNow) — never our local clock, which would
            // be off by the UTC offset and hide imminent slots. See docs/time-and-timezones.md.
            'upcomingOnly': true,
          },
        },
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
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

  Future<void> _addSchedule() async {
    final request = await showDialog<TourScheduleInsertRequest>(
      context: context,
      builder: (_) => _AddScheduleDialog(tour: widget.tour),
    );
    if (request == null || !mounted) return;
    final provider = context.read<TourProvider>();
    try {
      await provider.addSchedule(widget.tour.id, request);
      if (!mounted) return;
      AppSnackbars.success(context, 'Schedule added.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _cancel(TourScheduleResponse slot) async {
    final reason = await _promptReason(context);
    if (reason == null || !mounted) return;
    final provider = context.read<TourProvider>();
    setState(() => _acting.add(slot.id));
    try {
      await provider.cancelSchedule(slot.id, reason);
      if (!mounted) return;
      AppSnackbars.success(context, 'Schedule cancelled.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(slot.id));
    }
  }

  Future<void> _delete(TourScheduleResponse slot) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete schedule',
      message: 'Delete the slot on '
          '${formatEventDateTime(slot.startsAt, slot.timeZoneId)}? '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final provider = context.read<TourProvider>();
    setState(() => _acting.add(slot.id));
    try {
      await provider.deleteSchedule(slot.id);
      if (!mounted) return;
      AppSnackbars.success(context, 'Schedule deleted.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(slot.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Schedules', style: theme.textTheme.titleLarge),
                        Text(
                          widget.tour.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: TravleTokens.space16),
              Row(
                children: [
                  FilterChip(
                    label: const Text('Show past & cancelled'),
                    selected: _includePast,
                    onSelected: _loading
                        ? null
                        : (v) {
                            setState(() => _includePast = v);
                            _load();
                          },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: TravleTokens.space8),
                  FilledButton.icon(
                    onPressed: _addSchedule,
                    icon: const Icon(Icons.add),
                    label: const Text('Add schedule'),
                  ),
                ],
              ),
              const SizedBox(height: TravleTokens.space16),
              Flexible(child: _buildBody(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const SizedBox(
        height: 240, child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return SizedBox(
        height: 240,
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          message: _includePast
              ? 'This tour has no schedules.'
              : 'No upcoming schedules.',
          hint: 'Add a schedule so travelers can book this tour.',
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
      itemBuilder: (context, i) => _ScheduleTile(
        slot: _items[i],
        busy: _acting.contains(_items[i].id),
        onCancel: () => _cancel(_items[i]),
        onDelete: () => _delete(_items[i]),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.slot,
    required this.busy,
    required this.onCancel,
    required this.onDelete,
  });

  final TourScheduleResponse slot;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatEventScheduleRange(
                        slot.startsAt, slot.endsAt, slot.timeZoneId),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                StatusPill(
                  label: slot.isActive ? 'Active' : 'Cancelled',
                  tone: slot.isActive ? StatusTone.success : StatusTone.danger,
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space8),
            Row(
              children: [
                Icon(Icons.event_seat_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: TravleTokens.space4),
                Text(
                  '${slot.seatsTaken} of ${slot.capacity} booked · ${slot.freeSeats} free',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (slot.isCancelled &&
                slot.cancelledReason != null &&
                slot.cancelledReason!.trim().isNotEmpty) ...[
              const SizedBox(height: TravleTokens.space8),
              Text(
                'Cancelled: ${slot.cancelledReason}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: TravleTokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: TravleTokens.space16),
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                _ReasonedButton(
                  label: 'Cancel',
                  icon: Icons.event_busy_outlined,
                  onPressed: busy ? null : onCancel,
                  disabledReason: slot.isCancellable
                      ? null
                      : 'Only a future, active slot can be cancelled.',
                ),
                const SizedBox(width: TravleTokens.space12),
                _ReasonedButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  destructive: true,
                  onPressed: busy ? null : onDelete,
                  disabledReason: slot.isDeletable
                      ? null
                      : 'Only a future, active slot with no bookings can be deleted.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An outlined action button that, when [disabledReason] is non-null, renders
/// disabled with the reason shown as a tooltip (the "disabled with the reason"
/// UI rule).
class _ReasonedButton extends StatelessWidget {
  const _ReasonedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.disabledReason,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? disabledReason;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = disabledReason != null;
    final button = OutlinedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: destructive
          ? OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error)
          : null,
    );
    if (!disabled) return button;
    return Tooltip(message: disabledReason!, child: button);
  }
}

/// Prompts for a mandatory cancellation reason. Returns the trimmed reason, or
/// null if cancelled.
Future<String?> _promptReason(BuildContext context) => showReasonDialog(
      context,
      title: 'Cancel schedule',
      label: 'Reason',
      confirmLabel: 'Cancel schedule',
      requiredError: 'A reason is required',
    );

/// A small form to add a new schedule slot: a date, a start time, and an optional
/// per-slot capacity. The end time is derived from the tour's duration (shown as
/// a live preview). Returns a [TourScheduleInsertRequest] or null on cancel.
class _AddScheduleDialog extends StatefulWidget {
  const _AddScheduleDialog({required this.tour});

  final TourResponse tour;

  @override
  State<_AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<_AddScheduleDialog> {
  DateTime? _date;
  TimeOfDay? _time;
  final _capacity = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  DateTime? get _startsAt {
    if (_date == null || _time == null) return null;
    return DateTime(
        _date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final startsAt = _startsAt;
    if (startsAt == null) {
      setState(() => _error = 'Please pick a date and a start time.');
      return;
    }
    if (!startsAt.isAfter(DateTime.now())) {
      setState(() => _error = 'The schedule must start in the future.');
      return;
    }
    int? capacity;
    final capText = _capacity.text.trim();
    if (capText.isNotEmpty) {
      capacity = int.tryParse(capText);
      if (capacity == null || capacity < 1 || capacity > 1000) {
        setState(() => _error = 'Capacity must be a whole number from 1 to 1000.');
        return;
      }
    }
    Navigator.of(context)
        .pop(TourScheduleInsertRequest(startsAt: startsAt, capacity: capacity));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startsAt = _startsAt;
    final endsAt =
        startsAt?.add(Duration(minutes: widget.tour.durationMinutes));
    return AlertDialog(
      title: const Text('Add schedule'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_date == null ? 'Pick date' : formatDate(_date!)),
                  ),
                ),
                const SizedBox(width: TravleTokens.space12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(
                        _time == null ? 'Pick time' : _time!.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space8),
            Text(
              'Times are local to the tour’s destination.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: TravleTokens.space12),
            TravleTextField(
              controller: _capacity,
              label: 'Capacity (optional)',
              hint: 'Defaults to ${widget.tour.capacity}',
              prefixIcon: Icons.groups_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            if (startsAt != null && endsAt != null) ...[
              const SizedBox(height: TravleTokens.space16),
              Row(
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: TravleTokens.space8),
                  Expanded(
                    child: Text(
                      'Ends ${formatScheduleRange(startsAt, endsAt)} '
                      '(${formatDuration(widget.tour.durationMinutes)})',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: TravleTokens.space12),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
