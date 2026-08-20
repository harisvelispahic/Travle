import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/pager_bar.dart';

import 'destination_form_dialog.dart';

/// An organizer's own submitted destinations, grouped by moderation status. New
/// submissions and edits open the [DestinationFormDialog]; a rejected card shows
/// the reason; a pending card can be deleted (while still unreferenced).
class OrganizerDestinationsScreen extends StatefulWidget {
  const OrganizerDestinationsScreen({super.key});

  @override
  State<OrganizerDestinationsScreen> createState() =>
      _OrganizerDestinationsScreenState();
}

class _OrganizerDestinationsScreenState
    extends State<OrganizerDestinationsScreen> {
  static const int _pageSize = 20;

  // -1 = All, 0 = Pending, 1 = Approved, 2 = Rejected.
  int _statusFilter = -1;
  int _page = 1;
  bool _loading = true;
  String? _error;
  int? _totalCount;
  List<DestinationResponse> _items = [];
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reloads from page 1 — for anything that changes *which* rows match.
  void _reload() {
    _page = 1;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<DestinationProvider>().mine(
        filter: {
          'page': _page,
          'pageSize': _pageSize,
          'includeTotalCount': true,
          'sortBy': 'CreatedAt desc',
          if (_statusFilter != -1) 'status': _statusFilter,
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

  void _goToPage(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _openForm({DestinationResponse? existing}) async {
    final saved = await showDestinationFormDialog(context, existing: existing);
    if (saved == true && mounted) {
      // Editing an already-pending destination leaves it pending — no "reviewed
      // again" nudge; only an approved/rejected edit actually re-enters moderation.
      AppSnackbars.success(
        context,
        existing == null
            ? 'Destination submitted — an admin will review it soon.'
            : !existing.isPending
                ? 'Destination updated — it will be reviewed again.'
                : 'Destination updated.',
      );
      await _load();
    }
  }

  Future<void> _delete(DestinationResponse d) async {
    final provider = context.read<DestinationProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete destination',
      message: 'Delete "${d.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _acting.add(d.id));
    try {
      await provider.delete(d.id);
      if (!mounted) return;
      AppSnackbars.success(context, 'Destination deleted.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(d.id));
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
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: -1, label: Text('All')),
                  ButtonSegment(value: 0, label: Text('Pending')),
                  ButtonSegment(value: 1, label: Text('Approved')),
                  ButtonSegment(value: 2, label: Text('Rejected')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: _loading
                    ? null
                    : (selection) {
                        setState(() => _statusFilter = selection.first);
                        _reload();
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
                label: const Text('New destination'),
              ),
            ],
          ),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(theme)),
          const Divider(height: 1),
          PagerBar(
            page: _page,
            pageSize: _pageSize,
            itemCount: _items.length,
            totalCount: _totalCount,
            loading: _loading,
            onPageChanged: _goToPage,
          ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: TravleTokens.space12),
            Text(
              _statusFilter == -1
                  ? 'You have not submitted any destinations yet.'
                  : 'No destinations in this view.',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_statusFilter == -1) ...[
              const SizedBox(height: TravleTokens.space16),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('New destination'),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_totalCount != null) ...[
          Text(
            '$_totalCount ${_totalCount == 1 ? 'destination' : 'destinations'}',
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
            itemBuilder: (context, i) => _OrganizerDestinationCard(
              destination: _items[i],
              busy: _acting.contains(_items[i].id),
              onEdit: () => _openForm(existing: _items[i]),
              onDelete: _items[i].isPending ? () => _delete(_items[i]) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrganizerDestinationCard extends StatelessWidget {
  const _OrganizerDestinationCard({
    required this.destination,
    required this.busy,
    required this.onEdit,
    this.onDelete,
  });

  final DestinationResponse destination;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  StatusTone get _tone => switch (destination.status) {
        'Approved' => StatusTone.success,
        'Pending' => StatusTone.warning,
        'Rejected' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  String get _location => [destination.cityName, destination.regionName]
      .where((p) => p != null && p.isNotEmpty)
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = destination;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThumbnailImage(base64: d.primaryThumbnail, width: 96, height: 96),
                const SizedBox(width: TravleTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(d.name, style: theme.textTheme.titleMedium),
                          ),
                          const SizedBox(width: TravleTokens.space12),
                          StatusPill(label: d.status, tone: _tone),
                          if (d.isFeatured) ...[
                            const SizedBox(width: TravleTokens.space8),
                            const StatusPill(label: 'Featured', tone: StatusTone.info),
                          ],
                        ],
                      ),
                      const SizedBox(height: TravleTokens.space8),
                      Wrap(
                        spacing: TravleTokens.space16,
                        runSpacing: TravleTokens.space4,
                        children: [
                          if (d.categoryName != null)
                            _MetaChip(
                                icon: Icons.category_outlined,
                                label: d.categoryName!),
                          if (_location.isNotEmpty)
                            _MetaChip(icon: Icons.place_outlined, label: _location),
                          _MetaChip(
                            icon: Icons.photo_library_outlined,
                            label:
                                '${d.images.length} ${d.images.length == 1 ? 'photo' : 'photos'}',
                          ),
                          if (d.averageRating > 0)
                            _MetaChip(
                                icon: Icons.star,
                                label: d.averageRating.toStringAsFixed(1)),
                        ],
                      ),
                      const SizedBox(height: TravleTokens.space8),
                      Text(
                        d.description,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (d.isRejected &&
                d.rejectionReason != null &&
                d.rejectionReason!.trim().isNotEmpty) ...[
              const SizedBox(height: TravleTokens.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(TravleTokens.space12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(TravleTokens.radius),
                ),
                child: Text(
                  'Rejected: ${d.rejectionReason}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
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
                if (onDelete != null) ...[
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                ],
                FilledButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
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
