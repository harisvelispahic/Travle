import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travle_ui/travle_ui.dart';

/// One column of a [SortSpec] chain: an entity property path plus a direction.
/// The chain is serialized to the backend `SortBy` (a `System.Linq.Dynamic.Core`
/// ordering expression), e.g. `Name asc, Country.Name desc`.
class SortSpec {
  const SortSpec(this.key, this.ascending);
  final String key;
  final bool ascending;
}

/// Declares one table column: how to render a cell from a row [T], and — when
/// [sortKey] is non-null — the **entity** property path the server sorts by
/// (never a flattened DTO field; the backend orders `IQueryable<TEntity>`).
class TableColumnSpec<T> {
  const TableColumnSpec({
    required this.label,
    required this.cell,
    this.sortKey,
    this.numeric = false,
    this.flex = 1,
  });

  final String label;
  final String Function(T row) cell;

  /// Entity path for `ORDER BY` (e.g. `Name`, `Country.Name`). Null = not sortable.
  final String? sortKey;

  /// Right-aligns the header and cells (for numeric columns).
  final bool numeric;

  /// Relative width weight against the other columns.
  final int flex;
}

/// Generic server-driven table: a search row (debounced) with an optional parent
/// filter slot and a New button, sortable headers supporting **multi-column
/// sort** (click = primary, Shift+click = add/toggle a secondary key, with
/// priority badges), a scrollable body, per-row Edit/Delete actions honoring a
/// disabled reason, and a pager. All data, sorting, and paging are owned by the
/// caller and driven from the server — this widget only renders and reports intent.
class PaginatedSearchTable<T> extends StatefulWidget {
  const PaginatedSearchTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.loading,
    required this.sorts,
    required this.page,
    required this.pageSize,
    required this.onSearchChanged,
    required this.onToggleSort,
    required this.onPageChanged,
    required this.onRetry,
    this.error,
    this.totalCount,
    this.initialSearch = '',
    this.searchHint = 'Search…',
    this.emptyMessage = 'Nothing here yet.',
    this.emptyHint,
    this.filter,
    this.onNew,
    this.newLabel = 'New',
    this.onEdit,
    this.onDelete,
    this.deleteDisabledReason,
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> rows;
  final bool loading;
  final String? error;

  /// Active sort chain, most-significant first. Rendered as arrows + priority badges.
  final List<SortSpec> sorts;

  final int page;
  final int pageSize;

  /// Total matching rows when known (the screen requests it); enables an exact pager.
  final int? totalCount;

  final String initialSearch;
  final String searchHint;
  final String emptyMessage;
  final String? emptyHint;

  /// Optional widget shown between the search field and the New button
  /// (e.g. a parent dropdown filter for Region-by-Country / City-by-Region).
  final Widget? filter;

  /// Shown as a "New" button when non-null (hidden for read-only entities).
  final VoidCallback? onNew;
  final String newLabel;

  final void Function(String query) onSearchChanged;

  /// [additive] is true when Shift was held — stack/toggle a secondary sort key.
  final void Function(String sortKey, bool additive) onToggleSort;

  final void Function(int page) onPageChanged;
  final VoidCallback onRetry;

  /// Per-row edit; null hides the edit action (and, with [onDelete] null too, the
  /// whole actions column — the read-only case).
  final void Function(T row)? onEdit;

  /// Per-row delete; null hides the delete action.
  final void Function(T row)? onDelete;

  /// Returns a human reason the row can't be deleted (disables + tooltips the
  /// action), or null when deletion is allowed.
  final String? Function(T row)? deleteDisabledReason;

  @override
  State<PaginatedSearchTable<T>> createState() =>
      _PaginatedSearchTableState<T>();
}

class _PaginatedSearchTableState<T> extends State<PaginatedSearchTable<T>> {
  static const _actionsWidth = 112.0;

  late final TextEditingController _searchController;
  Timer? _debounce;

  bool get _hasActions => widget.onEdit != null || widget.onDelete != null;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Rebuild so the clear (✕) affordance tracks the field's contents live.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => widget.onSearchChanged(value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          const SizedBox(height: TravleTokens.space16),
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(child: _buildBody(context)),
          const Divider(height: 1),
          _buildPager(context),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: widget.searchHint,
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                      onPressed: () {
                        _searchController.clear();
                        _debounce?.cancel();
                        widget.onSearchChanged('');
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        if (widget.filter != null) ...[
          const SizedBox(width: TravleTokens.space12),
          widget.filter!,
        ],
        const Spacer(),
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.only(right: TravleTokens.space16),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (widget.onNew != null)
          FilledButton.icon(
            onPressed: widget.onNew,
            icon: const Icon(Icons.add),
            label: Text(widget.newLabel),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TravleTokens.space12,
        horizontal: TravleTokens.space8,
      ),
      child: Row(
        children: [
          for (final col in widget.columns)
            Expanded(
              flex: col.flex,
              child: _HeaderCell(
                label: col.label,
                numeric: col.numeric,
                sortState: _sortStateFor(col),
                style: headerStyle,
                onTap: col.sortKey == null
                    ? null
                    : () => widget.onToggleSort(
                          col.sortKey!,
                          HardwareKeyboard.instance.isShiftPressed,
                        ),
              ),
            ),
          if (_hasActions)
            SizedBox(
              width: _actionsWidth,
              child: Text(
                'Actions',
                textAlign: TextAlign.right,
                style: headerStyle,
              ),
            ),
        ],
      ),
    );
  }

  /// (priority index, ascending) for a column that's part of the sort chain, else null.
  _SortState? _sortStateFor(TableColumnSpec<T> col) {
    if (col.sortKey == null) return null;
    final index = widget.sorts.indexWhere((s) => s.key == col.sortKey);
    if (index == -1) return null;
    return _SortState(
      priority: widget.sorts.length > 1 ? index + 1 : null,
      ascending: widget.sorts[index].ascending,
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: theme.colorScheme.error),
            const SizedBox(height: TravleTokens.space12),
            Text(widget.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: TravleTokens.space16),
            ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (widget.loading && widget.rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.rows.isEmpty) {
      return EmptyState(
        message: widget.emptyMessage,
        hint: widget.emptyHint,
        icon: Icons.search_off,
      );
    }

    return ListView.separated(
      itemCount: widget.rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => _DataRow<T>(
        row: widget.rows[i],
        columns: widget.columns,
        hasActions: _hasActions,
        actionsWidth: _actionsWidth,
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        deleteDisabledReason: widget.deleteDisabledReason,
      ),
    );
  }

  Widget _buildPager(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.totalCount;
    final hasPrev = widget.page > 1;
    final bool hasNext = total != null
        ? widget.page * widget.pageSize < total
        : widget.rows.length == widget.pageSize;

    String label;
    if (total != null) {
      final totalPages = total == 0 ? 1 : ((total + widget.pageSize - 1) ~/ widget.pageSize);
      label = 'Page ${widget.page} of $totalPages · $total total';
    } else {
      label = 'Page ${widget.page}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space8),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: hasPrev && !widget.loading
                ? () => widget.onPageChanged(widget.page - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext && !widget.loading
                ? () => widget.onPageChanged(widget.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _SortState {
  const _SortState({required this.priority, required this.ascending});

  /// Rank in the sort chain (1-based) when more than one key is active, else null.
  final int? priority;
  final bool ascending;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.numeric,
    required this.sortState,
    required this.style,
    required this.onTap,
  });

  final String label;
  final bool numeric;
  final _SortState? sortState;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = sortState != null;
    final children = <Widget>[
      Flexible(
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(
            color: active ? theme.colorScheme.primary : null,
          ),
        ),
      ),
      if (active) ...[
        const SizedBox(width: TravleTokens.space4),
        Icon(
          sortState!.ascending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 15,
          color: theme.colorScheme.primary,
        ),
        if (sortState!.priority != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              '${sortState!.priority}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
      ],
    ];

    final row = Row(
      mainAxisAlignment:
          numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: children,
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space8),
        child: row,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TravleTokens.radius),
      child: Tooltip(
        message: 'Click to sort · Shift+click to add a sort level',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TravleTokens.space8,
            vertical: TravleTokens.space4,
          ),
          child: row,
        ),
      ),
    );
  }
}

class _DataRow<T> extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.columns,
    required this.hasActions,
    required this.actionsWidth,
    required this.onEdit,
    required this.onDelete,
    required this.deleteDisabledReason,
  });

  final T row;
  final List<TableColumnSpec<T>> columns;
  final bool hasActions;
  final double actionsWidth;
  final void Function(T row)? onEdit;
  final void Function(T row)? onDelete;
  final String? Function(T row)? deleteDisabledReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleteReason = deleteDisabledReason?.call(row);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: TravleTokens.space12,
        horizontal: TravleTokens.space8,
      ),
      child: Row(
        children: [
          for (final col in columns)
            Expanded(
              flex: col.flex,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: TravleTokens.space8),
                child: Text(
                  col.cell(row),
                  textAlign: col.numeric ? TextAlign.right : TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          if (hasActions)
            SizedBox(
              width: actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => onEdit!(row),
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: deleteReason ?? 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: theme.colorScheme.error,
                      onPressed:
                          deleteReason != null ? null : () => onDelete!(row),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
