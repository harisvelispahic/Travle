import 'dart:async';

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

  /// Autocomplete: fire only once the term is worth suggesting on (a 1-char probe
  /// matches nearly everything; the server enforces the same floor), and wait for a
  /// pause in typing before hitting the network.
  static const int _minSuggestChars = 2;
  static const int _suggestDebounceMs = 300;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Autocomplete state.
  Timer? _suggestDebounce;
  List<DestinationSuggestion> _suggestions = const [];
  bool _suggestLoading = false;
  // Bumped on every keystroke / submit so a slow, out-of-order suggestion response
  // is discarded (the same request-id guard the map browse screen uses).
  int _suggestSeq = 0;

  // Active filters.
  String _query = '';
  /// Multi-select: a destination matches if it is in **any** chosen category.
  /// Empty means "every category".
  final Set<int> _categoryIds = {};
  // Country → Region cascade: a region is chosen within a selected country, so the
  // Region filter is disabled until a country is picked and resets when it changes.
  int? _countryId;
  String? _countryName;
  int? _regionId;
  String? _regionName;
  double? _minRating;

  // Reference lists, loaded lazily the first time a sheet opens.
  List<DestinationCategoryResponse>? _categories;
  List<CountryResponse>? _countries;
  // Regions for the currently-selected country (dropped when the country changes).
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
    // Rebuild when focus changes so the suggestions overlay shows/hides as the field
    // gains or loses focus.
    _textFocus.addListener(_onFocusChanged);
    widget.focusRequests?.addListener(_onFocusRequested);
    // Show something immediately: the top-rated catalogue with no filters.
    _runSearch();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    widget.focusRequests?.removeListener(_onFocusRequested);
    _textFocus.removeListener(_onFocusChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
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
      _categoryIds.isNotEmpty ||
      _countryId != null ||
      _regionId != null ||
      _minRating != null;

  /// The filter chips as query parameters — the single source of truth shared by the
  /// full search and the typeahead, so a suggestion can never survive one and be
  /// dropped by the other (which read as "the suggestion does nothing").
  Map<String, dynamic> _activeFilters() => <String, dynamic>{
        if (_categoryIds.isNotEmpty) 'categoryIds': _categoryIds.toList(),
        if (_countryId != null) 'countryId': _countryId,
        if (_regionId != null) 'regionId': _regionId,
        if (_minRating != null) 'minRating': _minRating,
      };

  Map<String, dynamic> _buildFilter(int page) => <String, dynamic>{
        'page': page,
        'pageSize': _pageSize,
        'includeTotalCount': true,
        'sortBy': 'AverageRating desc',
        if (_query.isNotEmpty) 'text': _query,
        ..._activeFilters(),
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
    _suggestDebounce?.cancel();
    _suggestSeq++; // discard any in-flight suggestion response
    setState(() {
      _query = value.trim();
      _suggestions = const [];
      _suggestLoading = false;
    });
    _textFocus.unfocus();
    _runSearch();
  }

  /// Whether the live-suggestions panel takes over the results area: the field is
  /// focused and the term has reached the minimum length. Below that we keep the
  /// last result list in place.
  bool get _showSuggestions =>
      _textFocus.hasFocus && _textController.text.trim().length >= _minSuggestChars;

  /// Debounced typeahead: every keystroke invalidates older fetches; a term below the
  /// floor clears the panel; a qualifying term shows the spinner immediately and hits
  /// the network after a pause in typing.
  void _onQueryChanged(String value) {
    _suggestDebounce?.cancel();
    final term = value.trim();
    final seq = ++_suggestSeq;
    if (term.length < _minSuggestChars) {
      setState(() {
        _suggestions = const [];
        _suggestLoading = false;
      });
      return;
    }
    setState(() => _suggestLoading = true); // spinner during the debounce + fetch
    _suggestDebounce = Timer(
      const Duration(milliseconds: _suggestDebounceMs),
      () => _fetchSuggestions(term, seq),
    );
  }

  Future<void> _fetchSuggestions(String term, int seq) async {
    final provider = context.read<DestinationProvider>();
    try {
      // Narrowed by every active filter, exactly as the submitted search is — otherwise
      // the typeahead offers a destination the search then (correctly) finds nothing for.
      final items = await provider.suggest(term, filters: _activeFilters());
      if (!mounted || seq != _suggestSeq) return; // a newer keystroke superseded this
      setState(() {
        _suggestions = items;
        _suggestLoading = false;
      });
    } on ApiClientException {
      if (!mounted || seq != _suggestSeq) return;
      // A typeahead shouldn't shout: on error drop the suggestions quietly and let the
      // user submit the term to see the full (error-reporting) search.
      setState(() {
        _suggestions = const [];
        _suggestLoading = false;
      });
    }
  }

  void _onSuggestionTap(DestinationSuggestion suggestion) {
    _suggestDebounce?.cancel();
    _suggestSeq++;
    _textController.text = suggestion.name;
    _textController.selection =
        TextSelection.collapsed(offset: suggestion.name.length);
    setState(() {
      _query = suggestion.name;
      _suggestions = const [];
      _suggestLoading = false;
    });
    _textFocus.unfocus();
    // Runs the full search (applying any active filters) — this is where the real
    // Search interaction is recorded server-side.
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

  /// Loads every country for the Country filter (the reference set is larger than
  /// one page — see [CountryProvider.getAll]). The Country sheet is searchable, so
  /// the full list stays usable. Cached after the first open.
  Future<List<CountryResponse>> _ensureCountries() async =>
      _countries ??= await context.read<CountryProvider>().getAll();

  /// Regions of the currently-selected country (the cascade's second step). A
  /// country has at most a handful of regions, so a single page covers it. Cached
  /// per country; the cache is dropped when the country changes.
  Future<List<RegionResponse>> _ensureRegions() async {
    if (_regions != null) return _regions!;
    final result = await context
        .read<RegionProvider>()
        .get(filter: {'countryId': _countryId, 'pageSize': 100, 'sortBy': 'Name'});
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
    final result = await showMultiSelectSheet(
      context,
      title: 'Categories',
      options: [for (final c in categories) MultiSelectOption(c.id, c.name)],
      selected: _categoryIds,
    );
    if (result == null) return; // dismissed without applying
    setState(() {
      _categoryIds
        ..clear()
        ..addAll(result);
    });
    _runSearch();
  }

  Future<void> _openCountrySheet() async {
    final List<CountryResponse> countries;
    try {
      countries = await _ensureCountries();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
      return;
    }
    if (!mounted) return;
    final choice = await _showSearchableChoiceSheet<int>(
      title: 'Country',
      selected: _countryId,
      anyLabel: 'Any country',
      searchHint: 'Search countries',
      items: [for (final c in countries) _Choice<int>(c.id, c.name)],
    );
    if (choice == null) return;
    setState(() {
      _countryId = choice.value;
      _countryName = choice.value == null ? null : choice.label;
      // A region belongs to a country, so a country change invalidates the region
      // pick and its cached list.
      _regionId = null;
      _regionName = null;
      _regions = null;
    });
    _runSearch();
  }

  Future<void> _openRegionSheet() async {
    // The Region filter is the second step of the cascade — it needs a country.
    if (_countryId == null) {
      AppSnackbars.info(context, 'Pick a country first to choose a region.');
      return;
    }
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

  /// Resets every filter chip in one tap (the text term is the search field's own
  /// business — its ✕ clears that). Disabled while nothing is filtered.
  void _clearFilters() {
    if (!_hasActiveFilters) return;
    setState(() {
      _categoryIds.clear();
      _countryId = null;
      _countryName = null;
      // The region cascade hangs off the country, so its pick and cached list go too.
      _regionId = null;
      _regionName = null;
      _regions = null;
      _minRating = null;
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

  /// A choice sheet with a client-side search box over an in-memory list — for a
  /// long reference list (e.g. ~190 countries) that a plain sheet can't surface
  /// usefully. The "Any" clear option sits at the top when the box is empty.
  Future<_Choice<T>?> _showSearchableChoiceSheet<T>({
    required String title,
    required List<_Choice<T>> items,
    required T? selected,
    required String anyLabel,
    required String searchHint,
  }) {
    return showModalBottomSheet<_Choice<T>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SearchableChoiceSheet<T>(
        title: title,
        items: items,
        selected: selected,
        anyLabel: anyLabel,
        searchHint: searchHint,
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
        Expanded(
          child: _showSuggestions ? _buildSuggestions() : _buildResults(),
        ),
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
        onChanged: _onQueryChanged, // toggles the clear button + drives suggestions
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space16),
      child: Row(
        children: [
          _ClearFiltersButton(
            enabled: _hasActiveFilters,
            onTap: _clearFilters,
          ),
          const SizedBox(width: TravleTokens.space8),
          _FilterButton(
            label: multiSelectChipLabel(
              emptyLabel: 'Category',
              selected: _categoryIds,
              options: [
                for (final c in _categories ??
                    const <DestinationCategoryResponse>[])
                  MultiSelectOption(c.id, c.name),
              ],
              pluralNoun: 'categories',
            ),
            active: _categoryIds.isNotEmpty,
            onTap: _openCategorySheet,
          ),
          const SizedBox(width: TravleTokens.space8),
          _FilterButton(
            label: _countryName ?? 'Country',
            active: _countryId != null,
            onTap: _openCountrySheet,
          ),
          const SizedBox(width: TravleTokens.space8),
          _FilterButton(
            label: _regionName ?? 'Region',
            active: _regionId != null,
            // Disabled-looking until a country is chosen; tapping it then explains why.
            enabled: _countryId != null,
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
    // The count describes the result list; hide it while the suggestions panel is up.
    if (_showSuggestions || !_hasSearched || _loading || _error != null) {
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

  Widget _buildSuggestions() {
    final theme = Theme.of(context);

    if (_suggestLoading && _suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(TravleTokens.space24),
        child: Align(
          alignment: Alignment.topCenter,
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(TravleTokens.space24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            'No matching destinations',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Keep the keyboard up (and thus the field focused) while the list is scrolled —
    // dismissing it on drag would drop focus and swap this panel out for the results
    // list mid-gesture, so the list would appear to snap back instead of scrolling.
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space8),
      itemCount: _suggestions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final suggestion = _suggestions[i];
        final subtitle = [suggestion.cityName, suggestion.categoryName]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(' · ');
        return ListTile(
          leading: const Icon(Icons.search),
          title: Text(
            suggestion.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _onSuggestionTap(suggestion),
        );
      },
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

/// The filter strip's leading action: one tap resets every chip after it. Always in
/// place so its position never moves, greyed out while there is nothing to clear.
class _ClearFiltersButton extends StatelessWidget {
  const _ClearFiltersButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = enabled
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    return ActionChip(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      // Icon-only: the strip is horizontal real estate on a phone, and the icon sits
      // right next to the chips it clears. The chip's own tooltip (long-press) and the
      // semantics label carry the meaning.
      label: Icon(
        Icons.filter_alt_off_outlined,
        size: 18,
        color: foreground,
        semanticLabel: 'Clear all filters',
      ),
      labelPadding: EdgeInsets.zero,
      tooltip: 'Clear all filters',
    );
  }
}

/// A pill button that opens a filter sheet; highlighted while a value is selected.
/// When [enabled] is false it reads as disabled (muted) but stays tappable, so the
/// tap can explain why it isn't ready yet (e.g. "pick a country first").
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color? foreground = !enabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
        : active
            ? theme.colorScheme.onPrimaryContainer
            : null;
    return ActionChip(
      onPressed: onTap,
      backgroundColor: active ? theme.colorScheme.primaryContainer : null,
      side: active ? BorderSide(color: theme.colorScheme.primary) : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: foreground == null ? null : TextStyle(color: foreground)),
          Icon(Icons.arrow_drop_down, size: 18, color: foreground),
        ],
      ),
    );
  }
}

/// A bottom sheet that filters a (possibly long) list of [_Choice]s with a search
/// box, resolving to the picked choice via [Navigator.pop]. Used for the Country
/// filter, whose reference list is far too long for a plain scrolling sheet.
class _SearchableChoiceSheet<T> extends StatefulWidget {
  const _SearchableChoiceSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.anyLabel,
    required this.searchHint,
  });

  final String title;
  final List<_Choice<T>> items;
  final T? selected;
  final String anyLabel;
  final String searchHint;

  @override
  State<_SearchableChoiceSheet<T>> createState() =>
      _SearchableChoiceSheetState<T>();
}

class _SearchableChoiceSheetState<T> extends State<_SearchableChoiceSheet<T>> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items
            .where((i) => i.label.toLowerCase().contains(q))
            .toList();

    return Padding(
      // Lift the sheet above the keyboard while the search box has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(TravleTokens.space16, 0,
                    TravleTokens.space16, TravleTokens.space8),
                child: Text(widget.title, style: theme.textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: TravleTokens.space16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: widget.searchHint,
                  ),
                ),
              ),
              const SizedBox(height: TravleTokens.space8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // The "Any" clear option only makes sense when not searching.
                    if (q.isEmpty)
                      ListTile(
                        title: Text(widget.anyLabel),
                        trailing: widget.selected == null
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.of(context)
                            .pop(_Choice<T>(null, widget.anyLabel)),
                      ),
                    for (final item in filtered)
                      ListTile(
                        title: Text(item.label),
                        trailing: item.value == widget.selected
                            ? Icon(Icons.check, color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(item),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(TravleTokens.space24),
                        child: Center(
                          child: Text(
                            'No matches',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
