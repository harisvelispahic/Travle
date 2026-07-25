import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Admin moderation queue for submitted destinations: filter by status (and search
/// by text), review a submission's details and photos, then approve (publishes it)
/// or reject with a mandatory reason. Approved destinations can be toggled as
/// featured (drives the mobile "Featured" home section).
class DestinationsModerationScreen extends StatefulWidget {
  const DestinationsModerationScreen({super.key});

  @override
  State<DestinationsModerationScreen> createState() =>
      _DestinationsModerationScreenState();
}

class _DestinationsModerationScreenState
    extends State<DestinationsModerationScreen> {
  // 0 = Pending, 1 = Approved, 2 = Rejected (matches the backend enum).
  int _statusFilter = 0;
  final _search = TextEditingController();
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final text = _search.text.trim();
    try {
      final result = await context.read<DestinationProvider>().moderationQueue(
        filter: {
          'status': _statusFilter,
          'pageSize': 50,
          'includeTotalCount': true,
          if (text.isNotEmpty) 'text': text,
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

  Future<void> _approve(DestinationResponse d) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Approve destination',
      message: 'Publish "${d.name}"? It will become visible to travelers.',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    await _runAction(d.id, () async {
      await context.read<DestinationProvider>().approve(d.id);
      return 'Destination approved and published.';
    });
  }

  Future<void> _reject(DestinationResponse d) async {
    final reason = await _promptReason();
    if (reason == null) return;
    await _runAction(d.id, () async {
      await context.read<DestinationProvider>().reject(d.id, reason);
      return 'Destination rejected.';
    });
  }

  Future<void> _toggleFeatured(DestinationResponse d, bool value) async {
    await _runAction(d.id, () async {
      await context.read<DestinationProvider>().setFeatured(d.id, value);
      return value ? 'Destination featured.' : 'Destination unfeatured.';
    });
  }

  Future<void> _runAction(int id, Future<String> Function() action) async {
    setState(() => _acting.add(id));
    try {
      final message = await action();
      if (!mounted) return;
      AppSnackbars.success(context, message);
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  Future<String?> _promptReason() {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Reject destination'),
              content: TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Reason (sent to the submitter)',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setLocal(() => errorText = 'A reason is required');
                      return;
                    }
                    Navigator.of(context).pop(text);
                  },
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  void _viewPhotos(DestinationResponse d) {
    showDialog<void>(
      context: context,
      builder: (_) => _ImageGalleryDialog(
        destination: d,
        provider: context.read<DestinationProvider>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Pending')),
                  ButtonSegment(value: 1, label: Text('Approved')),
                  ButtonSegment(value: 2, label: Text('Rejected')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: _loading
                    ? null
                    : (selection) {
                        setState(() => _statusFilter = selection.first);
                        _load();
                      },
              ),
              const SizedBox(width: TravleTokens.space16),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search name or description',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear',
                            onPressed: _loading
                                ? null
                                : () {
                                    _search.clear();
                                    _load();
                                  },
                          ),
                  ),
                  onChanged: (_) => setState(() {}), // toggle the clear button
                  onSubmitted: (_) => _load(),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(Theme.of(context))),
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
        child: Text(
          'No destinations in this view.',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            itemBuilder: (context, i) => _DestinationModerationCard(
              destination: _items[i],
              busy: _acting.contains(_items[i].id),
              onApprove: () => _approve(_items[i]),
              onReject: () => _reject(_items[i]),
              onViewPhotos: () => _viewPhotos(_items[i]),
              onToggleFeatured: (value) => _toggleFeatured(_items[i], value),
            ),
          ),
        ),
      ],
    );
  }
}

class _DestinationModerationCard extends StatelessWidget {
  const _DestinationModerationCard({
    required this.destination,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onViewPhotos,
    required this.onToggleFeatured,
  });

  final DestinationResponse destination;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewPhotos;
  final ValueChanged<bool> onToggleFeatured;

  static String _dateTime(DateTime utc) {
    final d = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  StatusTone get _tone => switch (destination.status) {
        'Approved' => StatusTone.success,
        'Pending' => StatusTone.warning,
        'Rejected' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  String get _location => [
        destination.cityName,
        destination.regionName,
        destination.countryName,
      ].where((p) => p != null && p.isNotEmpty).join(', ');

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
                ThumbnailImage(
                  base64: d.primaryThumbnail,
                  width: 120,
                  height: 120,
                ),
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
                          if (d.submittedByUsername != null)
                            _MetaChip(
                                icon: Icons.person_outline,
                                label: '@${d.submittedByUsername}'),
                          _MetaChip(
                            icon: Icons.schedule,
                            label: 'Submitted ${_dateTime(d.createdAt)}',
                          ),
                          _MetaChip(
                            icon: Icons.my_location_outlined,
                            label:
                                '${d.latitude.toStringAsFixed(4)}, ${d.longitude.toStringAsFixed(4)}',
                          ),
                        ],
                      ),
                      if (d.tags.isNotEmpty) ...[
                        const SizedBox(height: TravleTokens.space8),
                        Wrap(
                          spacing: TravleTokens.space8,
                          runSpacing: TravleTokens.space4,
                          children: [
                            for (final tag in d.tags)
                              Chip(
                                label: Text(tag.name),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space12),
            Text(d.description, style: theme.textTheme.bodyMedium),
            if (d.images.isNotEmpty) ...[
              const SizedBox(height: TravleTokens.space8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onViewPhotos,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    'View ${d.images.length} ${d.images.length == 1 ? 'photo' : 'photos'}',
                  ),
                ),
              ),
            ],
            if (!d.isPending) ...[
              const SizedBox(height: TravleTokens.space12),
              _DecisionSummary(destination: d),
            ],
            if (d.isApproved) ...[
              const SizedBox(height: TravleTokens.space8),
              Row(
                children: [
                  Switch(
                    value: d.isFeatured,
                    onChanged: busy ? null : onToggleFeatured,
                  ),
                  const SizedBox(width: TravleTokens.space8),
                  Text('Featured', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: TravleTokens.space8),
                  Text(
                    'shown in the mobile Featured section',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if (d.isPending) ...[
              const SizedBox(height: TravleTokens.space16),
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
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DecisionSummary extends StatelessWidget {
  const _DecisionSummary({required this.destination});
  final DestinationResponse destination;

  static String _dateTime(DateTime utc) {
    final d = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = destination;
    final approved = d.isApproved;
    final color = approved
        ? theme.extension<TravleColors>()!.success
        : theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(approved ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: color, size: 20),
              const SizedBox(width: TravleTokens.space8),
              Text(
                approved ? 'Approved' : 'Rejected',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              if (d.moderatedByUsername != null) ...[
                const SizedBox(width: TravleTokens.space8),
                Text(
                  'by @${d.moderatedByUsername}${d.moderatedAt != null ? ' · ${_dateTime(d.moderatedAt!)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (d.isRejected &&
              d.rejectionReason != null &&
              d.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: TravleTokens.space4),
            Text('Reason: ${d.rejectionReason!}',
                style: theme.textTheme.bodySmall),
          ],
        ],
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

/// Full-image viewer for a destination's photos, fetched lazily from the image
/// endpoint (decoded once, here — not in build). Pages through the images.
class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({required this.destination, required this.provider});

  final DestinationResponse destination;
  final DestinationProvider provider;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  final _controller = PageController();
  List<Uint8List>? _images;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final d = widget.destination;
    try {
      final ordered = [...d.images]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final bytes = await Future.wait(
        ordered.map((img) => widget.provider.imageBytes(d.id, img.id)),
      );
      if (!mounted) return;
      setState(() => _images = bytes);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final images = _images;
    return Dialog(
      child: SizedBox(
        width: 760,
        height: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
                  TravleTokens.space12, TravleTokens.space8, TravleTokens.space12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.destination.name,
                        style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)))
                  : images == null
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            PageView.builder(
                              controller: _controller,
                              itemCount: images.length,
                              onPageChanged: (i) => setState(() => _page = i),
                              itemBuilder: (_, i) => InteractiveViewer(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(TravleTokens.space16),
                                  child: Image.memory(images[i],
                                      fit: BoxFit.contain),
                                ),
                              ),
                            ),
                            if (images.length > 1) ...[
                              Positioned(
                                left: TravleTokens.space8,
                                child: _NavArrow(
                                  icon: Icons.chevron_left,
                                  onPressed: _page == 0
                                      ? null
                                      : () => _controller.previousPage(
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeOut,
                                          ),
                                ),
                              ),
                              Positioned(
                                right: TravleTokens.space8,
                                child: _NavArrow(
                                  icon: Icons.chevron_right,
                                  onPressed: _page == images.length - 1
                                      ? null
                                      : () => _controller.nextPage(
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeOut,
                                          ),
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
            if (images != null && images.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(TravleTokens.space12),
                child: Text('${_page + 1} / ${images.length}',
                    style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(icon: Icon(icon), onPressed: onPressed),
    );
  }
}
