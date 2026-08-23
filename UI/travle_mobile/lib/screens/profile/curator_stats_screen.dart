import 'dart:async';

import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// A curator's impact statistics (stretch feature S3): how their submitted
/// destinations are performing — portfolio health, engagement (views / favorites /
/// ratings) and the demand they drive (bookings & travelers on tours that visit
/// them), over a per-destination breakdown that loads page by page as the user
/// scrolls. Read-only; scoped server-side to the caller. The headline totals come
/// from `GET /Reports/curator-stats`; the breakdown is paginated via
/// `GET /Reports/curator-stats/destinations`. Curators earn no money, so there are
/// no revenue figures here.
class CuratorStatsScreen extends StatefulWidget {
  const CuratorStatsScreen({super.key});

  @override
  State<CuratorStatsScreen> createState() => _CuratorStatsScreenState();
}

class _CuratorStatsScreenState extends State<CuratorStatsScreen> {
  static const int _pageSize = 5;

  final ReportProvider _provider = ReportProvider();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';

  CuratorStatsResponse? _headline;
  final List<CuratorDestinationStatRow> _rows = [];
  int _page = 1;
  int _totalCount = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Narrows the breakdown to matching destination names (server-side, accent-aware).
  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _search = value.trim());
      _loadBreakdown();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Map<String, dynamic> _buildFilter(int page) => <String, dynamic>{
        'page': page,
        'pageSize': _pageSize,
        'includeTotalCount': true,
        if (_search.isNotEmpty) 'name': _search,
      };

  // Reloads only the per-destination breakdown (the headline totals cover the whole
  // portfolio and never change with the filter).
  Future<void> _loadBreakdown() async {
    setState(() => _loadingMore = true);
    try {
      final firstPage =
          await _provider.getCuratorDestinations(filter: _buildFilter(1));
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(firstPage.items);
        _totalCount = firstPage.totalCount ?? firstPage.items.length;
        _page = 1;
        _loadingMore = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackbars.error(context, e.message);
    }
  }

  // Loads the headline and the first page of the breakdown together (initial open
  // and pull-to-refresh). The two calls are independent, so they run concurrently.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _provider.getCuratorStats(),
        _provider.getCuratorDestinations(filter: _buildFilter(1)),
      ]);
      if (!mounted) return;
      final headline = results[0] as CuratorStatsResponse;
      final firstPage = results[1] as SearchResult<CuratorDestinationStatRow>;
      setState(() {
        _headline = headline;
        _rows
          ..clear()
          ..addAll(firstPage.items);
        _totalCount = firstPage.totalCount ?? firstPage.items.length;
        _page = 1;
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

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_rows.length >= _totalCount) return;

    setState(() => _loadingMore = true);
    try {
      final next =
          await _provider.getCuratorDestinations(filter: _buildFilter(_page + 1));
      if (!mounted) return;
      setState(() {
        _rows.addAll(next.items);
        _totalCount = next.totalCount ?? _totalCount;
        _page += 1;
        _loadingMore = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackbars.error(context, e.message);
    }
  }

  static String _rating(double value) =>
      value <= 0 ? '—' : value.toStringAsFixed(1);

  static String _plural(int n, String singular) =>
      '$n ${n == 1 ? singular : '${singular}s'}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My statistics')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        message: 'Could not load your statistics',
        hint: _error,
        action: ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    final headline = _headline!;
    final showEmpty = _rows.isEmpty;
    final hasMore = _rows.length < _totalCount;
    final bodyCount = showEmpty ? 1 : _rows.length + (hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(TravleTokens.space16),
        itemCount: 1 + bodyCount,
        itemBuilder: (context, i) {
          if (i == 0) return _header(headline);
          if (showEmpty) return _breakdownEmpty();

          final rowIndex = i - 1;
          if (rowIndex >= _rows.length) {
            return const Padding(
              padding: EdgeInsets.all(TravleTokens.space16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: TravleTokens.space12),
            child: _DestinationStatCard(row: _rows[rowIndex]),
          );
        },
      ),
    );
  }

  Widget _header(CuratorStatsResponse d) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tiles(d),
        const SizedBox(height: TravleTokens.space24),
        Text('Destination performance', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space4),
        Text(
          _rows.isEmpty && _search.isEmpty
              ? 'Your submissions and their reach appear here.'
              : 'Ordered by bookings reached',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TravleTokens.space12),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search my destinations',
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();
                      _debounce?.cancel();
                      setState(() => _search = '');
                      _loadBreakdown();
                    },
                  ),
          ),
        ),
        const SizedBox(height: TravleTokens.space12),
      ],
    );
  }

  // The headline metrics, laid out mobile-first as three rows of two tiles.
  Widget _tiles(CuratorStatsResponse d) {
    return Column(
      children: [
        _statRow(
          StatTile(
            label: 'Approved',
            value: d.approvedDestinations.toString(),
            sub: '${d.pendingDestinations} pending · ${d.rejectedDestinations} rejected',
            icon: Icons.verified_outlined,
            emphasize: true,
          ),
          StatTile(
            label: 'Submitted',
            value: d.totalDestinations.toString(),
            sub: 'destinations',
            icon: Icons.travel_explore_outlined,
          ),
        ),
        const SizedBox(height: TravleTokens.space12),
        _statRow(
          StatTile(
            label: 'Total views',
            value: d.totalViews.toString(),
            icon: Icons.visibility_outlined,
          ),
          StatTile(
            label: 'Favorites',
            value: d.totalFavorites.toString(),
            icon: Icons.favorite_outline,
          ),
        ),
        const SizedBox(height: TravleTokens.space12),
        _statRow(
          StatTile(
            label: 'Average rating',
            value: _rating(d.averageRating),
            sub: _plural(d.reviewCount, 'review'),
            icon: Icons.star_outline,
          ),
          StatTile(
            label: 'Bookings reached',
            value: d.totalBookings.toString(),
            sub: _plural(d.totalTravelers, 'traveler'),
            icon: Icons.event_available_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statRow(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: TravleTokens.space12),
          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _breakdownEmpty() {
    if (_search.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message: 'No matches',
        hint: 'No destination of yours matches "$_search".',
      );
    }
    return EmptyState(
      icon: Icons.travel_explore_outlined,
      message: 'No destinations yet',
      hint: 'Submit a destination to start seeing its stats here.',
    );
  }
}

/// One destination's line in the breakdown: its name and moderation status over a
/// compact metric row (views, favorites, rating, bookings). Mobile-appropriate — a
/// stack of cards rather than the desktop's wide data table.
class _DestinationStatCard extends StatelessWidget {
  const _DestinationStatCard({required this.row});

  final CuratorDestinationStatRow row;

  StatusTone get _tone => switch (row.status) {
        'Approved' => StatusTone.success,
        'Pending' => StatusTone.warning,
        'Rejected' => StatusTone.danger,
        _ => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = row.reviewCount == 0
        ? '—'
        : '${row.averageRating.toStringAsFixed(1)} (${row.reviewCount})';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.destinationName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: TravleTokens.space8),
                StatusPill(label: row.status, tone: _tone),
              ],
            ),
            const SizedBox(height: TravleTokens.space12),
            Wrap(
              spacing: TravleTokens.space16,
              runSpacing: TravleTokens.space8,
              children: [
                _metric(context, Icons.visibility_outlined, row.views.toString(), 'views'),
                _metric(context, Icons.favorite_outline, row.favorites.toString(), 'favorites'),
                _metric(context, Icons.star_outline, rating, 'rating'),
                _metric(context, Icons.event_available_outlined, row.bookings.toString(), 'bookings'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, IconData icon, String value, String label) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: TravleTokens.space4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: TravleTokens.space4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
