import 'dart:async';

import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// A review normalized across the two review types so one list widget can render
/// either destination or tour reviews.
class ReviewRow {
  const ReviewRow({
    required this.id,
    required this.targetName,
    required this.authorName,
    required this.username,
    required this.rating,
    required this.isRemoved,
    required this.createdAt,
    this.comment,
    this.removedByUsername,
    this.removalReason,
  });

  final int id;
  final String targetName;
  final String authorName;
  final String username;
  final int rating;
  final String? comment;
  final bool isRemoved;
  final String? removedByUsername;
  final String? removalReason;
  final DateTime createdAt;

  factory ReviewRow.fromDestination(DestinationReviewResponse r) => ReviewRow(
        id: r.id,
        targetName: r.destinationName,
        authorName: r.authorName,
        username: r.username,
        rating: r.rating,
        comment: r.comment,
        isRemoved: r.isRemoved,
        removedByUsername: r.removedByUsername,
        removalReason: r.removalReason,
        createdAt: r.createdAt,
      );

  factory ReviewRow.fromTour(TourReviewResponse r) => ReviewRow(
        id: r.id,
        targetName: r.tourName,
        authorName: r.authorName,
        username: r.username,
        rating: r.rating,
        comment: r.comment,
        isRemoved: r.isRemoved,
        removedByUsername: r.removedByUsername,
        removalReason: r.removalReason,
        createdAt: r.createdAt,
      );
}

typedef ReviewFetch = Future<SearchResult<ReviewRow>> Function(
    Map<String, dynamic> filter);

typedef ReviewRemove = Future<void> Function(int id, String reason);

/// A paginated, filterable card list of reviews. Used by the admin moderation
/// screen (with [onRemove] set, so each active review can be soft-removed with a
/// mandatory reason) and by the organizer's read-only "reviews of my tours" view
/// (with [onRemove] null and [showStatusFilter] false). The list view's search
/// parameters (course §2.2) are a debounced free-text box over the reviewed
/// destination/tour and the author, plus a minimum-rating filter — and picking a
/// minimum rating also re-orders the list to start at that rating, so the effect
/// of the filter is visible in the first card instead of being buried under the
/// newest 5-star reviews.
class ReviewModerationList extends StatefulWidget {
  const ReviewModerationList({
    super.key,
    required this.fetch,
    required this.targetNoun,
    this.onRemove,
    this.showStatusFilter = true,
    this.emptyMessage = 'No reviews in this view.',
  });

  final ReviewFetch fetch;

  /// "destination" or "tour" — used in labels and the removal notice.
  final String targetNoun;

  /// When set, active reviews get a Remove action (soft removal + reason). Null =
  /// read-only.
  final ReviewRemove? onRemove;

  /// Whether to offer the Active/All toggle (only admins can read removed rows).
  final bool showStatusFilter;

  final String emptyMessage;

  @override
  State<ReviewModerationList> createState() => _ReviewModerationListState();
}

class _ReviewModerationListState extends State<ReviewModerationList> {
  static const int _pageSize = 20;

  /// Same typing pause the reference tables use, so search feels identical app-wide.
  static const _searchDebounce = Duration(milliseconds: 350);

  /// Preferred width of the search box; it shrinks below this on a narrow window.
  static const double _searchWidth = 320;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _includeRemoved = false;
  String _search = '';
  int? _minRating;
  int _page = 1;
  int _totalCount = 0;
  bool _loading = true;
  String? _error;
  List<ReviewRow> _rows = [];
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// With a minimum rating chosen, the lowest kept rating comes first (2+ → the
  /// 2-star reviews, then 3, 4, 5) so changing the filter visibly changes the top
  /// of the list — those borderline reviews are the ones a moderator is after.
  /// Unfiltered, the newest review still leads.
  String get _sortBy =>
      _minRating == null ? 'CreatedAt desc' : 'Rating asc, CreatedAt desc';

  Map<String, dynamic> _filter() => <String, dynamic>{
        'page': _page,
        'pageSize': _pageSize,
        'includeTotalCount': true,
        'sortBy': _sortBy,
        if (widget.showStatusFilter && _includeRemoved) 'includeRemoved': true,
        if (_minRating != null) 'minRating': _minRating,
        if (_search.isNotEmpty) 'text': _search,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(_filter());
      if (!mounted) return;
      setState(() {
        _rows = result.items;
        _totalCount = result.totalCount ?? result.items.length;
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

  void _resetAndLoad() {
    _page = 1;
    _load();
  }

  void _onSearchChanged(String value) {
    // Rebuild so the clear (x) affordance tracks the field's contents live.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      final term = value.trim();
      if (term == _search) return;
      _search = term;
      _resetAndLoad();
    });
  }

  Future<void> _remove(ReviewRow row) async {
    final remove = widget.onRemove;
    if (remove == null) return;

    final reason = await _promptReason();
    if (reason == null) return;

    setState(() => _acting.add(row.id));
    try {
      await remove(row.id, reason);
      if (!mounted) return;
      AppSnackbars.success(context, 'Review removed — the author was notified.');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(row.id));
    }
  }

  Future<String?> _promptReason() => showReasonDialog(
        context,
        title: 'Remove review',
        label: 'Reason (sent to the author)',
        confirmLabel: 'Remove',
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(Theme.of(context))),
          const SizedBox(height: TravleTokens.space8),
          _buildPager(Theme.of(context)),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        if (widget.showStatusFilter)
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Active')),
              ButtonSegment(value: true, label: Text('All')),
            ],
            selected: {_includeRemoved},
            onSelectionChanged: _loading
                ? null
                : (selection) {
                    setState(() => _includeRemoved = selection.first);
                    _resetAndLoad();
                  },
          ),
        if (widget.showStatusFilter) const SizedBox(width: TravleTokens.space16),
        // The two filters share what the trailing controls leave over, so the row
        // still fits the app's minimum window width (see PaginatedSearchTable).
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _searchWidth),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search ${widget.targetNoun}s or authors…',
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Clear',
                              onPressed: () {
                                _searchController.clear();
                                _debounce?.cancel();
                                if (_search.isNotEmpty) {
                                  _search = '';
                                  _resetAndLoad();
                                } else {
                                  setState(() {});
                                }
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TravleTokens.space16),
              // The second search parameter: minimum rating — which also decides the
              // order (see _sortBy), so the reviews at that rating lead the list.
              DropdownButton<int?>(
                value: _minRating,
                hint: const Text('Any rating'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any rating')),
                  DropdownMenuItem(value: 5, child: Text('5 stars')),
                  DropdownMenuItem(value: 4, child: Text('4+ stars')),
                  DropdownMenuItem(value: 3, child: Text('3+ stars')),
                  DropdownMenuItem(value: 2, child: Text('2+ stars')),
                  DropdownMenuItem(value: 1, child: Text('1+ stars')),
                ],
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _minRating = value);
                        _resetAndLoad();
                      },
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(right: TravleTokens.space16),
            child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _rows.isEmpty) {
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
    if (_rows.isEmpty) {
      return EmptyState(
        icon: Icons.reviews_outlined,
        message: widget.emptyMessage,
      );
    }
    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
      itemBuilder: (context, i) => _ReviewCard(
        row: _rows[i],
        targetNoun: widget.targetNoun,
        busy: _acting.contains(_rows[i].id),
        onRemove:
            widget.onRemove == null ? null : () => _remove(_rows[i]),
      ),
    );
  }

  Widget _buildPager(ThemeData theme) {
    final hasPrev = _page > 1;
    final hasNext = _page * _pageSize < _totalCount;
    final totalPages =
        _totalCount == 0 ? 1 : ((_totalCount + _pageSize - 1) ~/ _pageSize);
    return Row(
      children: [
        Text('Page $_page of $totalPages · $_totalCount total',
            style: theme.textTheme.bodySmall),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: hasPrev && !_loading
              ? () {
                  setState(() => _page--);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: hasNext && !_loading
              ? () {
                  setState(() => _page++);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.row,
    required this.targetNoun,
    required this.busy,
    required this.onRemove,
  });

  final ReviewRow row;
  final String targetNoun;
  final bool busy;
  final VoidCallback? onRemove;

  static String _dateTime(DateTime utc) {
    final d = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasComment = row.comment != null && row.comment!.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.targetName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: TravleTokens.space4),
                      Text(
                        '${row.authorName} · @${row.username} · ${_dateTime(row.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TravleTokens.space12),
                StatusPill(
                  label: row.isRemoved ? 'Removed' : 'Active',
                  tone: row.isRemoved ? StatusTone.danger : StatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space12),
            RatingStars(value: row.rating.toDouble(), size: 18),
            if (hasComment) ...[
              const SizedBox(height: TravleTokens.space8),
              Text(row.comment!.trim(), style: theme.textTheme.bodyMedium),
            ],
            if (row.isRemoved) ...[
              const SizedBox(height: TravleTokens.space12),
              _RemovedNotice(row: row),
            ],
            if (!row.isRemoved && onRemove != null) ...[
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
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error),
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

class _RemovedNotice extends StatelessWidget {
  const _RemovedNotice({required this.row});

  final ReviewRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
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
              Icon(Icons.gpp_bad_outlined, color: color, size: 20),
              const SizedBox(width: TravleTokens.space8),
              Text(
                row.removedByUsername != null
                    ? 'Removed by @${row.removedByUsername}'
                    : 'Removed',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          if (row.removalReason != null &&
              row.removalReason!.trim().isNotEmpty) ...[
            const SizedBox(height: TravleTokens.space4),
            Text('Reason: ${row.removalReason!}',
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
