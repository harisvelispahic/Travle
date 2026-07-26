import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/destination_card.dart';
import 'destination_details_screen.dart';

/// Search the approved destination catalogue (mockup Slika 7). The text term is
/// submitted to `GET /Destinations` (which logs a Search interaction server-side);
/// Category / Region / Rating filters are fed from the DB via bottom sheets. Results
/// paginate with infinite scroll and carry thumbnails only.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.focusRequests});

  /// Bumped by the shell when the user taps the Home search bar, so this screen
  /// takes focus as the Search tab opens.
  final ValueNotifier<int>? focusRequests;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const int _pageSize = 10;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Active filters.
  String _query = '';
  int? _categoryId;
  String? _categoryName;
  int? _regionId;
  String? _regionName;
  double? _minRating;

  // Reference lists, loaded lazily the first time a sheet opens.
  List<DestinationCategoryResponse>? _categories;
  List<RegionResponse>? _regions;

  // Results / paging.
  final List<DestinationResponse> _results = [];
  int _page = 1;
  int _totalCount = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.focusRequests?.addListener(_onFocusRequested);
    // Show something immediately: the top-rated catalogue with no filters.
    _runSearch();
  }

  @override
  void dispose() {
    widget.focusRequests?.removeListener(_onFocusRequested);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _onFocusRequested() {
    if (!mounted) return;
    _textFocus.requestFocus();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  bool get _hasActiveFilters =>
      _categoryId != null || _regionId != null || _minRating != null;

  Map<String, dynamic> _buildFilter(int page) => <String, dynamic>{
        'page': page,
        'pageSize': _pageSize,
        'includeTotalCount': true,
        'sortBy': 'AverageRating desc',
        if (_query.isNotEmpty) 'text': _query,
        if (_categoryId != null) 'categoryId': _categoryId,
        if (_regionId != null) 'regionId': _regionId,
        if (_minRating != null) 'minRating': _minRating,
      };

  Future<void> _runSearch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<DestinationProvider>()
          .get(filter: _buildFilter(1));
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(result.items);
        _totalCount = result.totalCount ?? result.items.length;
        _page = 1;
        _loading = false;
        _hasSearched = true;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _hasSearched = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_results.length >= _totalCount) return;

    setState(() => _loadingMore = true);
    try {
      final result = await context
          .read<DestinationProvider>()
          .get(filter: _buildFilter(_page + 1));
      if (!mounted) return;
      setState(() {
        _results.addAll(result.items);
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
    _textFocus.unfocus();
    _runSearch();
  }

  Future<List<DestinationCategoryResponse>> _ensureCategories() async {
    if (_categories != null) return _categories!;
    final result = await context
        .read<DestinationCategoryProvider>()
        .get(filter: {'pageSize': 100, 'sortBy': 'Name'});
    _categories = result.items;
    return _categories!;
  }

  Future<List<RegionResponse>> _ensureRegions() async {
    if (_regions != null) return _regions!;
    final result = await context
        .read<RegionProvider>()
        .get(filter: {'pageSize': 100, 'sortBy': 'Name'});
    _regions = result.items;
    return _regions!;
  }

  Future<void> _openCategorySheet() async {
    final List<DestinationCategoryResponse> categories;
    try {
      categories = await _ensureCategories();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
      return;
    }
    if (!mounted) return;
    final choice = await _showChoiceSheet<int>(
      title: 'Category',
      selected: _categoryId,
      items: [
        const _Choice<int>(null, 'Any category'),
        for (final c in categories) _Choice<int>(c.id, c.name),
      ],
    );
    if (choice == null) return;
    setState(() {
      _categoryId = choice.value;
      _categoryName = choice.value == null ? null : choice.label;
    });
    _runSearch();
  }

  Future<void> _openRegionSheet() async {
    final List<RegionResponse> regions;
    try {
      regions = await _ensureRegions();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
      return;
    }
    if (!mounted) return;
    final choice = await _showChoiceSheet<int>(
      title: 'Region',
      selected: _regionId,
      items: [
        const _Choice<int>(null, 'Any region'),
        for (final r in regions) _Choice<int>(r.id, r.name),
      ],
    );
    if (choice == null) return;
    setState(() {
      _regionId = choice.value;
      _regionName = choice.value == null ? null : choice.label;
    });
    _runSearch();
  }

  Future<void> _openRatingSheet() async {
    final choice = await _showChoiceSheet<double>(
      title: 'Minimum rating',
      selected: _minRating,
      items: const [
        _Choice<double>(null, 'Any rating'),
        _Choice<double>(3.0, '3+ stars'),
        _Choice<double>(4.0, '4+ stars'),
        _Choice<double>(4.5, '4.5+ stars'),
      ],
    );
    if (choice == null) return;
    setState(() => _minRating = choice.value);
    _runSearch();
  }

  Future<_Choice<T>?> _showChoiceSheet<T>({
    required String title,
    required List<_Choice<T>> items,
    required T? selected,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<_Choice<T>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(TravleTokens.space16, 0,
                  TravleTokens.space16, TravleTokens.space8),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item.label),
                      trailing: item.value == selected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(DestinationResponse destination) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailsScreen(
          destinationId: destination.id,
          initialName: destination.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchField(),
        _buildFilterRow(),
        _buildResultCount(),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(TravleTokens.space16, TravleTokens.space12,
          TravleTokens.space16, TravleTokens.space8),
      child: TextField(
        controller: _textController,
        focusNode: _textFocus,
        textInputAction: TextInputAction.search,
        onSubmitted: _submitQuery,
        decoration: InputDecoration(
          hintText: 'Search destinations',
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
        onChanged: (_) => setState(() {}), // toggles the clear button
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
      child: Row(
        children: [
          _FilterButton(
            label: _categoryName ?? 'Category',
            active: _categoryId != null,
            onTap: _openCategorySheet,
          ),
          const SizedBox(width: TravleTokens.space8),
          _FilterButton(
            label: _regionName ?? 'Region',
            active: _regionId != null,
            onTap: _openRegionSheet,
          ),
          const SizedBox(width: TravleTokens.space8),
          _FilterButton(
            label: _minRating == null
                ? 'Rating'
                : '${_minRating!.toStringAsFixed(_minRating! % 1 == 0 ? 0 : 1)}+',
            active: _minRating != null,
            onTap: _openRatingSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCount() {
    if (!_hasSearched || _loading || _error != null) {
      return const SizedBox(height: TravleTokens.space8);
    }
    final theme = Theme.of(context);
    final label = _query.isEmpty
        ? '$_totalCount ${_totalCount == 1 ? 'result' : 'results'}'
        : '$_totalCount ${_totalCount == 1 ? 'result' : 'results'} for "$_query"';
    return Padding(
      padding: const EdgeInsets.fromLTRB(TravleTokens.space16, TravleTokens.space8,
          TravleTokens.space16, TravleTokens.space4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final theme = Theme.of(context);

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
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _runSearch, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.travel_explore_outlined,
        message: 'No destinations found',
        hint: _query.isEmpty && !_hasActiveFilters
            ? 'Try searching for a place or category.'
            : 'Try a different search or clear the filters.',
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(TravleTokens.space16, TravleTokens.space8,
          TravleTokens.space16, TravleTokens.space24),
      itemCount: _results.length + (_results.length < _totalCount ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
      itemBuilder: (_, i) {
        if (i >= _results.length) {
          return const Padding(
            padding: EdgeInsets.all(TravleTokens.space16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final destination = _results[i];
        return DestinationCard(
          destination: destination,
          onTap: () => _openDetails(destination),
        );
      },
    );
  }
}

/// One option in a filter bottom sheet. A null [value] represents the "Any" /
/// clear choice.
class _Choice<T> {
  const _Choice(this.value, this.label);

  final T? value;
  final String label;
}

/// A pill button that opens a filter sheet; highlighted while a value is selected.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ActionChip(
      onPressed: onTap,
      backgroundColor: active ? theme.colorScheme.primaryContainer : null,
      side: active
          ? BorderSide(color: theme.colorScheme.primary)
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: active
                ? TextStyle(color: theme.colorScheme.onPrimaryContainer)
                : null,
          ),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: active ? theme.colorScheme.onPrimaryContainer : null,
          ),
        ],
      ),
    );
  }
}
