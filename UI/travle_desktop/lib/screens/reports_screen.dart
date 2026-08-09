import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import '../util/report_download.dart';
import '../widgets/simple_data_table.dart';

/// The admin reporting module (course §2.2/§2.4): two downloadable/printable PDF
/// reports, each with an on-screen preview and its own filters (the period/category
/// filters are the "search parameters" every list view must have). A segmented
/// control switches between them.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TravleTokens.space16,
            TravleTokens.space16,
            TravleTokens.space16,
            TravleTokens.space12,
          ),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Popular destinations'),
                icon: Icon(Icons.trending_up),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Revenue'),
                icon: Icon(Icons.pie_chart_outline),
              ),
            ],
            selected: {_index},
            onSelectionChanged: (s) => setState(() => _index = s.first),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [_PopularDestinationsView(), _RevenueView()],
          ),
        ),
      ],
    );
  }
}

/// Builds a KM period caption for a report header.
String _periodLabel(DateTime? from, DateTime? to) {
  if (from == null && to == null) return 'All time';
  if (from != null && to != null) {
    return '${formatDate(from.toLocal())} – ${formatDate(to.subtract(const Duration(days: 1)).toLocal())}';
  }
  if (from != null) return 'From ${formatDate(from.toLocal())}';
  return 'Up to ${formatDate(to!.subtract(const Duration(days: 1)).toLocal())}';
}

/// A discriminative PDF file name reflecting the selected period, e.g.
/// `travle-revenue-2026-01-01_to_2026-07-31.pdf` or `travle-revenue-all-time.pdf`.
/// [toExclusive] is the exclusive upper bound the UI holds (picked end date + 1 day),
/// so the inclusive end date is echoed back in the name.
String reportFileName(String base, DateTime? from, DateTime? toExclusive) {
  String isoDate(DateTime value) => value.toIso8601String().split('T').first;
  final to = toExclusive?.subtract(const Duration(days: 1));
  final String suffix;
  if (from == null && to == null) {
    suffix = 'all-time';
  } else if (from != null && to != null) {
    suffix = '${isoDate(from)}_to_${isoDate(to)}';
  } else if (from != null) {
    suffix = 'from_${isoDate(from)}';
  } else {
    suffix = 'until_${isoDate(to!)}';
  }
  return 'travle-$base-$suffix.pdf';
}

/// A date filter as a button showing the picked date (or "Any"), with a clear button.
class _DateFilterField extends StatelessWidget {
  const _DateFilterField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value; // UTC date-midnight, or null for "any"
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: TravleTokens.space4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(value == null ? 'Any' : formatDate(value!.toLocal())),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value?.toLocal() ?? now,
                  firstDate: DateTime(now.year - 3),
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null) {
                  onChanged(
                    DateTime.utc(picked.year, picked.month, picked.day),
                  );
                }
              },
            ),
            if (value != null)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Popular

class _PopularDestinationsView extends StatefulWidget {
  const _PopularDestinationsView();

  @override
  State<_PopularDestinationsView> createState() =>
      _PopularDestinationsViewState();
}

class _PopularDestinationsViewState extends State<_PopularDestinationsView> {
  final ReportProvider _provider = ReportProvider();
  final DestinationCategoryProvider _categoryProvider =
      DestinationCategoryProvider();

  PopularDestinationsReport? _report;
  List<DestinationCategoryResponse> _categories = [];
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  DateTime? _fromDate;
  DateTime?
  _toDate; // exclusive upper bound (start of day after the picked date)
  int? _categoryId;
  int _top = 10;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  Future<void> _loadCategories() async {
    try {
      final page = await _categoryProvider.get(
        filter: {'pageSize': 100, 'sortBy': 'Name'},
      );
      if (!mounted) return;
      setState(() => _categories = page.items);
    } on ApiClientException {
      // Non-fatal: the report still works without the category filter.
    }
  }

  Map<String, dynamic> _filter() {
    final q = <String, dynamic>{'Top': _top};
    if (_fromDate != null) q['FromDate'] = _fromDate;
    if (_toDate != null) q['ToDate'] = _toDate;
    if (_categoryId != null) q['CategoryId'] = _categoryId;
    return q;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _provider.getPopularDestinations(filter: _filter());
      if (!mounted) return;
      setState(() {
        _report = report;
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

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes = await _provider.popularDestinationsPdf(filter: _filter());
      if (!mounted) return;
      await saveReportPdf(
        context,
        bytes,
        reportFileName('popular-destinations', _fromDate, _toDate),
      );
    } on ApiClientException catch (e) {
      if (mounted) AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _setToDate(DateTime? date) {
    // Make the picked end date inclusive: send the start of the following day.
    setState(() => _toDate = date?.add(const Duration(days: 1)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        _filters(theme),
        const SizedBox(height: TravleTokens.space16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TravleTokens.space32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorBlock(_error!, _load)
        else
          _preview(theme),
      ],
    );
  }

  Widget _filters(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Wrap(
          spacing: TravleTokens.space16,
          runSpacing: TravleTokens.space12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _DateFilterField(
              label: 'From',
              value: _fromDate,
              onChanged: (d) {
                setState(() => _fromDate = d);
                _load();
              },
            ),
            _DateFilterField(
              label: 'To',
              // Show the inclusive date back to the user (undo the +1 day).
              value: _toDate?.subtract(const Duration(days: 1)),
              onChanged: _setToDate,
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Category',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All categories'),
                  ),
                  for (final c in _categories)
                    DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) {
                  setState(() => _categoryId = value);
                  _load();
                },
              ),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: _top,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Show top',
                ),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('Top 5')),
                  DropdownMenuItem(value: 10, child: Text('Top 10')),
                  DropdownMenuItem(value: 20, child: Text('Top 20')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _top = value);
                  _load();
                },
              ),
            ),
            FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: const Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    final report = _report!;
    final period = _periodLabel(report.fromDate, report.toDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most popular destinations',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              report.categoryName == null
                  ? 'Period: $period'
                  : 'Period: $period · Category: ${report.categoryName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TravleTokens.space16),
            if (report.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TravleTokens.space16,
                ),
                child: Text(
                  'No bookings in the selected period.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              SimpleDataTable(
                boldFirstColumn: false,
                columns: const [
                  SimpleColumn('#', flex: 1),
                  SimpleColumn('Destination', flex: 4),
                  SimpleColumn('Category', flex: 3),
                  SimpleColumn('Region', flex: 3),
                  SimpleColumn('Bookings', numeric: true, flex: 2),
                  SimpleColumn('Travelers', numeric: true, flex: 2),
                  SimpleColumn('Views', numeric: true, flex: 2),
                  SimpleColumn('Favorites', numeric: true, flex: 2),
                ],
                rows: [
                  for (final row in report.rows)
                    [
                      row.rank.toString(),
                      row.destinationName,
                      row.categoryName,
                      row.regionName,
                      row.bookings.toString(),
                      row.travelers.toString(),
                      row.views.toString(),
                      row.favorites.toString(),
                    ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Revenue

class _RevenueView extends StatefulWidget {
  const _RevenueView();

  @override
  State<_RevenueView> createState() => _RevenueViewState();
}

class _RevenueViewState extends State<_RevenueView> {
  final ReportProvider _provider = ReportProvider();

  RevenueReport? _report;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  DateTime? _fromDate;
  DateTime? _toDate; // exclusive upper bound

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _filter() {
    final q = <String, dynamic>{};
    if (_fromDate != null) q['FromDate'] = _fromDate;
    if (_toDate != null) q['ToDate'] = _toDate;
    return q;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _provider.getRevenue(filter: _filter());
      if (!mounted) return;
      setState(() {
        _report = report;
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

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes = await _provider.revenuePdf(filter: _filter());
      if (!mounted) return;
      await saveReportPdf(
        context,
        bytes,
        reportFileName('revenue', _fromDate, _toDate),
      );
    } on ApiClientException catch (e) {
      if (mounted) AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _setToDate(DateTime? date) {
    setState(() => _toDate = date?.add(const Duration(days: 1)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        _filters(),
        const SizedBox(height: TravleTokens.space16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: TravleTokens.space32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _errorBlock(_error!, _load)
        else
          ..._preview(theme),
      ],
    );
  }

  Widget _filters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Wrap(
          spacing: TravleTokens.space16,
          runSpacing: TravleTokens.space12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _DateFilterField(
              label: 'From',
              value: _fromDate,
              onChanged: (d) {
                setState(() => _fromDate = d);
                _load();
              },
            ),
            _DateFilterField(
              label: 'To',
              value: _toDate?.subtract(const Duration(days: 1)),
              onChanged: _setToDate,
            ),
            FilledButton.icon(
              onPressed: _downloading ? null : _download,
              icon: _downloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: const Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _preview(ThemeData theme) {
    final report = _report!;
    return [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StatTile(
                label: 'Net revenue',
                value: formatPrice(report.totalNet),
                icon: Icons.account_balance_wallet_outlined,
                emphasize: true,
              ),
            ),
            const SizedBox(width: TravleTokens.space12),
            Expanded(
              child: StatTile(
                label: 'Gross captured',
                value: formatPrice(report.totalGross),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: TravleTokens.space12),
            Expanded(
              child: StatTile(
                label: 'Refunded',
                value: formatPrice(report.totalRefunded),
                icon: Icons.undo_outlined,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: TravleTokens.space8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: TravleTokens.space4),
        child: Text(
          'Period: ${_periodLabel(report.fromDate, report.toDate)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: TravleTokens.space16),
      _sectionCard(theme, 'By category', 'Category', report.byCategory),
      const SizedBox(height: TravleTokens.space16),
      _sectionCard(theme, 'By region', 'Region', report.byRegion),
    ];
  }

  Widget _sectionCard(
    ThemeData theme,
    String heading,
    String groupLabel,
    List<RevenueGroupRow> rows,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: TravleTokens.space12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TravleTokens.space8,
                ),
                child: Text(
                  'No revenue in the selected period.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              SimpleDataTable(
                boldFirstColumn: true,
                columns: [
                  SimpleColumn(groupLabel, flex: 3),
                  const SimpleColumn('Bookings', numeric: true, flex: 2),
                  const SimpleColumn('Gross', numeric: true, flex: 2),
                  const SimpleColumn('Refunded', numeric: true, flex: 2),
                  const SimpleColumn('Net', numeric: true, flex: 2),
                ],
                rows: [
                  for (final row in rows)
                    [
                      row.groupName,
                      row.bookings.toString(),
                      formatPrice(row.grossRevenue),
                      formatPrice(row.refunded),
                      formatPrice(row.netRevenue),
                    ],
                ],
                footer: [
                  'Total',
                  rows.fold<int>(0, (s, r) => s + r.bookings).toString(),
                  formatPrice(
                    rows.fold<double>(0, (s, r) => s + r.grossRevenue),
                  ),
                  formatPrice(rows.fold<double>(0, (s, r) => s + r.refunded)),
                  formatPrice(rows.fold<double>(0, (s, r) => s + r.netRevenue)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Shared error block for the report views.
Widget _errorBlock(String message, VoidCallback onRetry) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: TravleTokens.space32),
    child: EmptyState(
      icon: Icons.error_outline,
      message: 'Could not load the report',
      hint: message,
      action: FilledButton.tonalIcon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    ),
  );
}
