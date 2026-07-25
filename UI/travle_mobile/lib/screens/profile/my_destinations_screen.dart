import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import 'destination_form_screen.dart';

/// A curator/organizer's own destinations, grouped by moderation status. New
/// submissions and edits open the [DestinationFormScreen]; a rejected card shows
/// the reason; a pending card can be deleted (while still unreferenced).
class MyDestinationsScreen extends StatefulWidget {
  const MyDestinationsScreen({super.key});

  @override
  State<MyDestinationsScreen> createState() => _MyDestinationsScreenState();
}

class _MyDestinationsScreenState extends State<MyDestinationsScreen> {
  static const List<String?> _statusFilters = [null, 'Pending', 'Approved', 'Rejected'];

  List<DestinationResponse> _all = [];
  String? _statusFilter;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await context
          .read<DestinationProvider>()
          .mine(filter: {'pageSize': 100, 'sortBy': 'CreatedAt desc'});
      if (!mounted) return;
      setState(() {
        _all = result.items;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  List<DestinationResponse> get _visible => _statusFilter == null
      ? _all
      : _all.where((d) => d.status == _statusFilter).toList();

  Future<void> _openForm({DestinationResponse? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DestinationFormScreen(existing: existing),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _delete(DestinationResponse destination) async {
    // Capture the provider before the confirm dialog's async gap.
    final provider = context.read<DestinationProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete destination',
      message: 'Delete "${destination.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await provider.delete(destination.id);
      if (!mounted) return;
      AppSnackbars.success(context, 'Destination deleted.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My destinations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New destination'),
      ),
      body: SafeArea(child: _buildBody(Theme.of(context))),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _visible.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      TravleTokens.space16,
                      TravleTokens.space8,
                      TravleTokens.space16,
                      // Leave room for the FAB.
                      TravleTokens.space32 * 2.5,
                    ),
                    itemCount: _visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: TravleTokens.space12),
                    itemBuilder: (_, i) => _DestinationCard(
                      destination: _visible[i],
                      onTap: () => _openForm(existing: _visible[i]),
                      onDelete: _visible[i].isPending
                          ? () => _delete(_visible[i])
                          : null,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: TravleTokens.space16,
        vertical: TravleTokens.space8,
      ),
      child: Row(
        children: [
          for (final status in _statusFilters) ...[
            ChoiceChip(
              label: Text(status ?? 'All'),
              selected: _statusFilter == status,
              onSelected: (_) => setState(() => _statusFilter = status),
            ),
            const SizedBox(width: TravleTokens.space8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      // A ListView keeps pull-to-refresh working even when empty.
      children: [
        const SizedBox(height: TravleTokens.space32 * 2),
        EmptyState(
          icon: Icons.travel_explore_outlined,
          message: _statusFilter == null
              ? 'No destinations yet'
              : 'No ${_statusFilter!.toLowerCase()} destinations',
          hint: _statusFilter == null
              ? 'Submit your first destination for review.'
              : 'Try a different filter.',
          action: _statusFilter == null
              ? ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('New destination'),
                )
              : null,
        ),
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.onTap,
    this.onDelete,
  });

  final DestinationResponse destination;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  StatusTone get _tone => switch (destination.status) {
        'Approved' => StatusTone.success,
        'Pending' => StatusTone.warning,
        'Rejected' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  String get _location {
    final parts = [destination.cityName, destination.regionName]
        .where((p) => p != null && p.isNotEmpty)
        .join(', ');
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ThumbnailImage(base64: destination.primaryThumbnail, width: 72, height: 72),
                  const SizedBox(width: TravleTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_location.isNotEmpty) ...[
                          const SizedBox(height: TravleTokens.space4),
                          Row(
                            children: [
                              Icon(Icons.place_outlined,
                                  size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: TravleTokens.space4),
                              Expanded(
                                child: Text(
                                  _location,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: TravleTokens.space8),
                        Row(
                          children: [
                            StatusPill(
                              label: destination.status,
                              tone: _tone,
                            ),
                            const Spacer(),
                            if (destination.averageRating > 0) ...[
                              Icon(Icons.star,
                                  size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: TravleTokens.space4),
                              Text(
                                destination.averageRating.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                    ),
                ],
              ),
              if (destination.isRejected &&
                  destination.rejectionReason != null &&
                  destination.rejectionReason!.trim().isNotEmpty) ...[
                const SizedBox(height: TravleTokens.space12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(TravleTokens.space12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(TravleTokens.radius),
                  ),
                  child: Text(
                    'Rejected: ${destination.rejectionReason}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
