import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import 'tour_form_dialog.dart';
import 'tour_schedules_dialog.dart';

/// An organizer's own tours. New tours and edits open the [TourFormDialog]; the
/// "Schedules" action opens the [TourSchedulesDialog] slot manager. A tour can be
/// deactivated (hidden from travelers, history kept) or — only when it was never
/// scheduled — hard-deleted.
class OrganizerToursScreen extends StatefulWidget {
  const OrganizerToursScreen({super.key});

  @override
  State<OrganizerToursScreen> createState() => _OrganizerToursScreenState();
}

class _OrganizerToursScreenState extends State<OrganizerToursScreen> {
  // -1 = All, 1 = Active only, 0 = Inactive only.
  int _activeFilter = -1;
  String _search = '';
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  int? _totalCount;
  List<TourResponse> _items = [];
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<TourProvider>().mine(
        filter: {
          'pageSize': 50,
          'includeTotalCount': true,
          'sortBy': 'CreatedAt desc',
          if (_search.isNotEmpty) 'text': _search,
          if (_activeFilter != -1) 'isActive': _activeFilter == 1,
        },
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _totalCount = result.totalCount;
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search = value.trim();
      _load();
    });
  }

  Future<void> _openForm({TourResponse? existing}) async {
    final saved = await showTourFormDialog(context, existing: existing);
    if (saved == true && mounted) {
      AppSnackbars.success(
        context,
        existing == null ? 'Tour created.' : 'Tour updated.',
      );
      await _load();
    }
  }

  Future<void> _openSchedules(TourResponse tour) async {
    await showTourSchedulesDialog(context, tour);
    // Slots may have changed → refresh the upcoming counts on the cards.
    if (mounted) await _load();
  }

  Future<void> _toggleActive(TourResponse tour) async {
    final provider = context.read<TourProvider>();
    setState(() => _acting.add(tour.id));
    try {
      if (tour.isActive) {
        await provider.deactivate(tour.id);
      } else {
        await provider.activate(tour.id);
      }
      if (!mounted) return;
      AppSnackbars.success(
        context,
        tour.isActive ? 'Tour deactivated.' : 'Tour reactivated.',
      );
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(tour.id));
    }
  }

  Future<void> _delete(TourResponse tour) async {
    final provider = context.read<TourProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete tour',
      message:
          'Delete "${tour.name}"? This cannot be undone. If the tour has ever '
          'been scheduled, deactivate it instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _acting.add(tour.id));
    try {
      await provider.delete(tour.id);
      if (!mounted) return;
      AppSnackbars.success(context, 'Tour deleted.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(tour.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search tours by name…',
                  ),
                ),
              ),
              const SizedBox(width: TravleTokens.space12),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: -1, label: Text('All')),
                  ButtonSegment(value: 1, label: Text('Active')),
                  ButtonSegment(value: 0, label: Text('Inactive')),
                ],
                selected: {_activeFilter},
                onSelectionChanged: _loading
                    ? null
                    : (selection) {
                        setState(() => _activeFilter = selection.first);
                        _load();
                      },
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: TravleTokens.space8),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('New tour'),
              ),
            ],
          ),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: TravleTokens.space16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.tour_outlined,
        message: _search.isEmpty && _activeFilter == -1
            ? 'You have not created any tours yet.'
            : 'No tours match this view.',
        hint: _search.isEmpty && _activeFilter == -1
            ? 'Create a tour to start offering experiences.'
            : null,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_totalCount != null) ...[
          Text(
            '$_totalCount ${_totalCount == 1 ? 'tour' : 'tours'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: TravleTokens.space8),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: _items.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: TravleTokens.space12),
            itemBuilder: (context, i) => _OrganizerTourCard(
              tour: _items[i],
              busy: _acting.contains(_items[i].id),
              onEdit: () => _openForm(existing: _items[i]),
              onSchedules: () => _openSchedules(_items[i]),
              onToggleActive: () => _toggleActive(_items[i]),
              onDelete: () => _delete(_items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrganizerTourCard extends StatelessWidget {
  const _OrganizerTourCard({
    required this.tour,
    required this.busy,
    required this.onEdit,
    required this.onSchedules,
    required this.onToggleActive,
    required this.onDelete,
  });

  final TourResponse tour;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onSchedules;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tour;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThumbnailImage(base64: t.primaryThumbnail, width: 96, height: 96),
                const SizedBox(width: TravleTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                Text(t.name, style: theme.textTheme.titleMedium),
                          ),
                          const SizedBox(width: TravleTokens.space12),
                          StatusPill(
                            label: t.isActive ? 'Active' : 'Inactive',
                            tone: t.isActive
                                ? StatusTone.success
                                : StatusTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: TravleTokens.space8),
                      Wrap(
                        spacing: TravleTokens.space16,
                        runSpacing: TravleTokens.space4,
                        children: [
                          if (t.tourTypeName != null)
                            _MetaChip(
                                icon: Icons.category_outlined,
                                label: t.tourTypeName!),
                          _MetaChip(
                            icon: Icons.payments_outlined,
                            label: '${formatPrice(t.pricePerPerson)} / person',
                          ),
                          _MetaChip(
                            icon: Icons.schedule_outlined,
                            label: formatDuration(t.durationMinutes),
                          ),
                          _MetaChip(
                            icon: Icons.place_outlined,
                            label:
                                '${t.destinationCount} ${t.destinationCount == 1 ? 'stop' : 'stops'}',
                          ),
                          _MetaChip(
                            icon: Icons.event_outlined,
                            label: t.upcomingScheduleCount > 0
                                ? '${t.upcomingScheduleCount} upcoming'
                                : 'No upcoming dates',
                          ),
                          if (t.nextDepartureAt != null)
                            _MetaChip(
                              icon: Icons.flight_takeoff_outlined,
                              label: 'Next: ${formatDate(t.nextDepartureAt!)}',
                            ),
                        ],
                      ),
                      const SizedBox(height: TravleTokens.space8),
                      Text(
                        t.description,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: TravleTokens.space16),
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onSchedules,
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Schedules'),
                ),
                const SizedBox(width: TravleTokens.space12),
                FilledButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: TravleTokens.space4),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  enabled: !busy,
                  onSelected: (value) {
                    if (value == 'toggle') onToggleActive();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(t.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          const SizedBox(width: TravleTokens.space12),
                          Text(t.isActive ? 'Deactivate' : 'Reactivate'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: theme.colorScheme.error),
                          const SizedBox(width: TravleTokens.space12),
                          Text('Delete',
                              style:
                                  TextStyle(color: theme.colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: TravleTokens.space4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
