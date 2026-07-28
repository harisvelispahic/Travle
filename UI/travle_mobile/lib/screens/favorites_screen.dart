import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/destination_card.dart';
import '../widgets/tour_card.dart';
import 'destination_details_screen.dart';
import 'tour_details_screen.dart';

/// The traveler's saved destinations and tours, in two tabs. Each tab is a
/// paginated, searchable list backed by `GET /Favorites/destinations` and
/// `GET /Favorites/tours` and reuses the shared browse cards. The list reloads
/// when the Favorites tab is opened (via [reloadRequests] from the shell) and when
/// the user returns from a details screen where they may have toggled a favorite.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, this.reloadRequests});

  /// Bumped by the shell each time the Favorites tab becomes active.
  final ValueNotifier<int>? reloadRequests;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Destinations'),
              Tab(text: 'Tours'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FavoritesTab<DestinationResponse>(
                  reloadRequests: reloadRequests,
                  searchHint: 'Search saved destinations',
                  emptyMessage: 'No saved destinations',
                  emptyHint: 'Tap the heart on a destination to save it here.',
                  fetch: (filter) =>
                      context.read<FavoriteProvider>().destinations(filter: filter),
                  cardBuilder: (destination, onTap) =>
                      DestinationCard(destination: destination, onTap: onTap),
                  openDetail: (ctx, destination) => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => DestinationDetailsScreen(
                        destinationId: destination.id,
                        initialName: destination.name,
                      ),
                    ),
                  ),
                ),
                _FavoritesTab<TourResponse>(
                  reloadRequests: reloadRequests,
                  searchHint: 'Search saved tours',
                  emptyMessage: 'No saved tours',
                  emptyHint: 'Tap the heart on a tour to save it here.',
                  fetch: (filter) =>
                      context.read<FavoriteProvider>().tours(filter: filter),
                  cardBuilder: (tour, onTap) => TourCard(tour: tour, onTap: onTap),
                  openDetail: (ctx, tour) => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => TourDetailsScreen(
                        tourId: tour.id,
                        initialName: tour.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single favorites list (destinations or tours): a search field over a
/// paginated, infinite-scroll list with pull-to-refresh. Generic over the item
/// type so both tabs share one implementation.
class _FavoritesTab<T> extends StatefulWidget {
  const _FavoritesTab({
    super.key,
    required this.reloadRequests,
    required this.fetch,
    required this.cardBuilder,
    required this.openDetail,
    required this.searchHint,
    required this.emptyMessage,
    required this.emptyHint,
  });

  final ValueNotifier<int>? reloadRequests;
  final Future<SearchResult<T>> Function(Map<String, dynamic> filter) fetch;
  final Widget Function(T item, VoidCallback onTap) cardBuilder;
  final Future<void> Function(BuildContext context, T item) openDetail;
  final String searchHint;
  final String emptyMessage;
  final String emptyHint;

  @override
  State<_FavoritesTab<T>> createState() => _FavoritesTabState<T>();
}

class _FavoritesTabState<T> extends State<_FavoritesTab<T>>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 10;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<T> _items = [];
  String _query = '';
  int _page = 1;
  int _totalCount = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loaded = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.reloadRequests?.addListener(_onReloadRequested);
    _load();
  }

  @override
  void dispose() {
    widget.reloadRequests?.removeListener(_onReloadRequested);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onReloadRequested() {
    if (mounted) _load();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Map<String, dynamic> _filter(int page) => <String, dynamic>{
        'page': page,
        'pageSize': _pageSize,
        'includeTotalCount': true,
        if (_query.isNotEmpty) 'text': _query,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(_filter(1));
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _totalCount = result.totalCount ?? result.items.length;
        _page = 1;
        _loading = false;
        _loaded = true;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loaded = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_items.length >= _totalCount) return;

    setState(() => _loadingMore = true);
    try {
      final result = await widget.fetch(_filter(_page + 1));
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _totalCount = result.totalCount ?? _totalCount;
        _page += 1;
        _loadingMore = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackbars.error(context, e.message);
    }
  }

  void _submitQuery(String value) {
    setState(() => _query = value.trim());
    _load();
  }

  Future<void> _open(T item) async {
    await widget.openDetail(context, item);
    // The user may have un-favorited it on the details screen — refresh.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
              TravleTokens.space12, TravleTokens.space16, TravleTokens.space8),
          child: TextField(
            controller: _textController,
            textInputAction: TextInputAction.search,
            onSubmitted: _submitQuery,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _textController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear',
                      onPressed: () {
                        _textController.clear();
                        _submitQuery('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final theme = Theme.of(context);

    if (_loading && !_loaded) {
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
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: EmptyState(
                icon: Icons.favorite_border,
                message: _query.isEmpty
                    ? widget.emptyMessage
                    : 'No matches for "$_query"',
                hint: _query.isEmpty
                    ? widget.emptyHint
                    : 'Try a different search.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
            TravleTokens.space8, TravleTokens.space16, TravleTokens.space24),
        itemCount: _items.length + (_items.length < _totalCount ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(TravleTokens.space16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[i];
          return widget.cardBuilder(item, () => _open(item));
        },
      ),
    );
  }
}
