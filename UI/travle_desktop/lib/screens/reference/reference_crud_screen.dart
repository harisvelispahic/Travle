import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../../widgets/crud_form_dialog.dart';
import '../../widgets/paginated_search_table.dart';
import 'reference_entity_config.dart';

/// One screen serving every reference table. Given a [ReferenceEntityConfig] it
/// owns the fetch/search/sort/paging state, renders a [PaginatedSearchTable], and
/// (when the entity is writable) drives create/edit via [CrudFormDialog] and
/// delete via a confirmation — surfacing the backend's friendly conflict message
/// verbatim when a referenced row can't be removed.
class ReferenceCrudScreen<T> extends StatefulWidget {
  const ReferenceCrudScreen({super.key, required this.config});

  final ReferenceEntityConfig<T> config;

  @override
  State<ReferenceCrudScreen<T>> createState() => _ReferenceCrudScreenState<T>();
}

class _ReferenceCrudScreenState<T> extends State<ReferenceCrudScreen<T>> {
  static const int _pageSize = 20;

  late final BaseProvider<T> _provider = widget.config.providerFactory();

  List<T> _rows = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int? _totalCount;
  List<SortSpec> _sorts = const [];
  String _search = '';

  // Optional parent filter (Regions-by-Country, Cities-by-Region) and, above it,
  // the narrowing-only grandparent that keeps its option list short (Cities get a
  // Country picker so the Region list isn't every region on earth).
  Object? _filterValue;
  List<CrudOption>? _filterOptions;
  Object? _grandparentValue;
  List<CrudOption>? _grandparentOptions;

  ReferenceEntityConfig<T> get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFilterOptions();
    _loadGrandparentOptions();
  }

  Future<void> _loadFilterOptions() async {
    final filter = _config.filter;
    if (filter == null) return;
    try {
      final options = await filter.optionsLoader(_grandparentValue);
      if (!mounted) return;
      setState(() => _filterOptions = options);
    } catch (_) {
      // A failed filter load just leaves the dropdown empty; the table still works.
    }
  }

  Future<void> _loadGrandparentOptions() async {
    final level = _config.filter?.grandparent;
    if (level == null) return;
    try {
      final options = await level.optionsLoader();
      if (!mounted) return;
      setState(() => _grandparentOptions = options);
    } catch (_) {
      // As above — the table stays usable without the narrowing dropdown.
    }
  }

  Map<String, dynamic> _query() {
    final query = <String, dynamic>{
      'page': _page,
      'pageSize': _pageSize,
      'includeTotalCount': true,
    };
    final sortBy = _sortBy();
    if (sortBy != null) query['sortBy'] = sortBy;
    query.addAll(_config.searchQueryFor(_search));
    final filter = _config.filter;
    if (filter != null && _filterValue != null) {
      query[filter.queryKey] = _filterValue;
    }
    return query;
  }

  String? _sortBy() {
    if (_sorts.isEmpty) return null;
    return _sorts
        .map((s) => '${s.key} ${s.ascending ? 'asc' : 'desc'}')
        .join(', ');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _provider.get(filter: _query());
      if (!mounted) return;
      setState(() {
        _rows = result.items;
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
    _search = value;
    _page = 1;
    _load();
  }

  void _onFilterChanged(Object? value) {
    setState(() {
      _filterValue = value;
      _page = 1;
    });
    _load();
  }

  /// Picking (or clearing) the narrowing level drops the parent selection — it may
  /// no longer be in the reloaded list — and reloads the table unfiltered.
  void _onGrandparentChanged(Object? value) {
    setState(() {
      _grandparentValue = value;
      _filterValue = null;
      _filterOptions = null;
      _page = 1;
    });
    _loadFilterOptions();
    _load();
  }

  void _onToggleSort(String key, bool additive) {
    setState(() {
      _sorts = _nextSorts(_sorts, key, additive);
      _page = 1;
    });
    _load();
  }

  /// Multi-column sort transition. Plain click cycles the primary key
  /// asc → desc → cleared; Shift+click adds a key (or flips a present one),
  /// preserving the existing chain order.
  static List<SortSpec> _nextSorts(
      List<SortSpec> current, String key, bool additive) {
    final index = current.indexWhere((s) => s.key == key);
    if (additive) {
      if (index == -1) {
        return [...current, SortSpec(key, true)];
      }
      final updated = [...current];
      updated[index] = SortSpec(key, !current[index].ascending);
      return updated;
    }
    if (current.length == 1 && current.first.key == key) {
      return current.first.ascending ? [SortSpec(key, false)] : const [];
    }
    return [SortSpec(key, true)];
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _load();
  }

  Future<void> _create() async {
    final saved = await showCrudFormDialog(
      context,
      title: 'New ${_config.title}',
      fields: _config.formFields,
      saveLabel: 'Create',
      onSubmit: (values) => _write(() => _provider.insert(_config.toBody!(values))),
    );
    if (saved == true && mounted) {
      AppSnackbars.success(context, '${_config.title} created.');
      _page = 1;
      await _load();
    }
  }

  Future<void> _edit(T row) async {
    final saved = await showCrudFormDialog(
      context,
      title: 'Edit ${_config.title}',
      fields: _config.formFields,
      saveLabel: 'Save changes',
      initialValues: _config.formValues!(row),
      onSubmit: (values) =>
          _write(() => _provider.update(_config.idOf(row), _config.toBody!(values))),
    );
    if (saved == true && mounted) {
      AppSnackbars.success(context, '${_config.title} updated.');
      await _load();
    }
  }

  /// Runs a create/update call, translating an [ApiClientException] into the
  /// inline error string the form dialog expects (null = success).
  Future<String?> _write(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on ApiClientException catch (e) {
      return e.message;
    }
  }

  Future<void> _delete(T row) async {
    final label = _config.rowTitle(row);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${_config.title}',
      message: 'Delete "$label"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await _provider.remove(_config.idOf(row));
      if (!mounted) return;
      AppSnackbars.success(context, 'Deleted "$label".');
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      // In-use deletes come back as the backend's human conflict message.
      AppSnackbars.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final writable = _config.writable;
    return PaginatedSearchTable<T>(
      columns: _config.columns,
      rows: _rows,
      loading: _loading,
      error: _error,
      sorts: _sorts,
      page: _page,
      pageSize: _pageSize,
      totalCount: _totalCount,
      searchHint: _config.searchHint,
      emptyMessage: _search.isEmpty && _filterValue == null
          ? _config.emptyMessage
          : 'No matches for the current search/filter.',
      emptyHint: _config.emptyHint,
      onSearchChanged: _onSearchChanged,
      onToggleSort: _onToggleSort,
      onPageChanged: _onPageChanged,
      onRetry: _load,
      filter: _buildFilter(),
      onNew: writable ? _create : null,
      newLabel: 'New ${_config.title}',
      onEdit: writable ? _edit : null,
      onDelete: writable ? _delete : null,
    );
  }

  Widget? _buildFilter() {
    final filter = _config.filter;
    if (filter == null) return null;

    final parent = _filterDropdown(
      // Re-keyed per grandparent so the field is rebuilt from scratch when the
      // level above changes: a FormField only reads initialValue once, so without
      // this it would keep a selection the reloaded options no longer contain —
      // which DropdownButton asserts on.
      key: ValueKey('filter-$_grandparentValue'),
      label: filter.label,
      value: _filterValue,
      options: _filterOptions,
      onChanged: _onFilterChanged,
    );

    final level = filter.grandparent;
    if (level == null) return parent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _filterDropdown(
          label: level.label,
          value: _grandparentValue,
          options: _grandparentOptions,
          onChanged: _onGrandparentChanged,
        ),
        const SizedBox(width: TravleTokens.space12),
        parent,
      ],
    );
  }

  Widget _filterDropdown({
    required String label,
    required Object? value,
    required List<CrudOption>? options,
    required ValueChanged<Object?> onChanged,
    Key? key,
  }) {
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<Object?>(
        key: key,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
        ),
        items: [
          DropdownMenuItem<Object?>(
            value: null,
            child: Text('All ${_pluralOf(label.toLowerCase())}'),
          ),
          for (final option in options ?? const <CrudOption>[])
            DropdownMenuItem<Object?>(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// English plural of a filter's label, for the "All …" option: naively appending
/// an "s" turned Country into "All countrys". Covers the labels this screen can
/// be given (Country ⇒ countries, Region ⇒ regions, Category ⇒ categories).
String _pluralOf(String noun) {
  const vowels = 'aeiou';
  if (noun.length > 1 &&
      noun.endsWith('y') &&
      !vowels.contains(noun[noun.length - 2])) {
    return '${noun.substring(0, noun.length - 1)}ies';
  }
  if (noun.endsWith('s') ||
      noun.endsWith('x') ||
      noun.endsWith('z') ||
      noun.endsWith('ch') ||
      noun.endsWith('sh')) {
    return '${noun}es';
  }
  return '${noun}s';
}
