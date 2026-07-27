import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import '../widgets/paginated_search_table.dart';

/// Admin's read-only payments oversight: revenue / commission / refund totals on
/// top, and the filterable, sortable, paginated payments list below (`GET /Payments`
/// + `/Payments/summary`). Financial records are never edited here.
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

// (label, PaymentStatus int) — mirrors the backend enum values.
const List<(String, int)> _statusFilters = [
  ('Succeeded', 1),
  ('Refunded', 3),
  ('Partially refunded', 4),
  ('Failed', 2),
  ('Pending', 0),
];

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  static const int _pageSize = 20;

  final PaymentProvider _provider = PaymentProvider();

  List<PaymentResponse> _rows = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int? _totalCount;
  List<SortSpec> _sorts = const [];
  String _search = '';
  int? _statusId; // null = all
  int? _periodDays; // null = all time
  PaymentSummaryResponse? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _query({bool withPaging = true}) {
    final q = <String, dynamic>{};
    if (withPaging) {
      q['page'] = _page;
      q['pageSize'] = _pageSize;
      q['includeTotalCount'] = true;
      final sortBy = _sortBy();
      if (sortBy != null) q['sortBy'] = sortBy;
    }
    if (_search.isNotEmpty) q['text'] = _search;
    if (_statusId != null) q['status'] = _statusId;
    if (_periodDays != null) {
      q['fromDate'] =
          DateTime.now().toUtc().subtract(Duration(days: _periodDays!));
    }
    return q;
  }

  String? _sortBy() => _sorts.isEmpty
      ? null
      : _sorts.map((s) => '${s.key} ${s.ascending ? 'asc' : 'desc'}').join(', ');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _provider.get(filter: _query());
      final summary = await _provider.summary(filter: _query(withPaging: false));
      if (!mounted) return;
      setState(() {
        _rows = page.items;
        _totalCount = page.totalCount;
        _summary = summary;
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

  void _onToggleSort(String key, bool additive) {
    setState(() {
      _sorts = _nextSorts(_sorts, key, additive);
      _page = 1;
    });
    _load();
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _load();
  }

  void _onStatusChanged(int? value) {
    setState(() {
      _statusId = value;
      _page = 1;
    });
    _load();
  }

  void _onPeriodChanged(int? value) {
    setState(() {
      _periodDays = value;
      _page = 1;
    });
    _load();
  }

  // Plain click cycles the primary key asc → desc → cleared; Shift+click adds/flips
  // a secondary key (same behaviour as the reference tables).
  static List<SortSpec> _nextSorts(
      List<SortSpec> current, String key, bool additive) {
    final index = current.indexWhere((s) => s.key == key);
    if (additive) {
      if (index == -1) return [...current, SortSpec(key, true)];
      final updated = [...current];
      updated[index] = SortSpec(key, !current[index].ascending);
      return updated;
    }
    if (current.length == 1 && current.first.key == key) {
      return current.first.ascending ? [SortSpec(key, false)] : const [];
    }
    return [SortSpec(key, true)];
  }

  List<TableColumnSpec<PaymentResponse>> _columns() => [
        TableColumnSpec(
          label: 'Traveler',
          flex: 2,
          sortKey: 'Booking.User.Username',
          cell: (r) => r.travelerName,
        ),
        TableColumnSpec(
          label: 'Tour',
          flex: 2,
          sortKey: 'Booking.TourSchedule.Tour.Name',
          cell: (r) => r.tourName,
        ),
        TableColumnSpec(
          label: 'Amount',
          numeric: true,
          sortKey: 'Amount',
          cell: (r) => formatPrice(r.amount),
        ),
        TableColumnSpec(
          label: 'Commission',
          numeric: true,
          sortKey: 'PlatformFeeAmount',
          cell: (r) => formatPrice(r.platformFeeAmount),
        ),
        TableColumnSpec(
          label: 'Refunded',
          numeric: true,
          cell: (r) => r.refundedAmount > 0 ? formatPrice(r.refundedAmount) : '—',
        ),
        TableColumnSpec(
          label: 'Status',
          sortKey: 'Status',
          cell: (r) => _statusLabel(r.status),
        ),
        TableColumnSpec(
          label: 'Date',
          sortKey: 'CreatedAt',
          cell: (r) => formatDate(r.createdAt),
        ),
      ];

  static String _statusLabel(String status) =>
      status == 'PartiallyRefunded' ? 'Partially refunded' : status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TotalsBar(summary: _summary),
        Expanded(
          child: PaginatedSearchTable<PaymentResponse>(
            columns: _columns(),
            rows: _rows,
            loading: _loading,
            error: _error,
            sorts: _sorts,
            page: _page,
            pageSize: _pageSize,
            totalCount: _totalCount,
            searchHint: 'Search traveler or tour…',
            emptyMessage: 'No payments yet',
            emptyHint: 'Payments appear here as travelers pay for bookings.',
            onSearchChanged: _onSearchChanged,
            onToggleSort: _onToggleSort,
            onPageChanged: _onPageChanged,
            onRetry: _load,
            filter: _buildFilters(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int?>(
            initialValue: _statusId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, labelText: 'Status'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All statuses')),
              for (final (label, id) in _statusFilters)
                DropdownMenuItem<int?>(value: id, child: Text(label)),
            ],
            onChanged: _loading ? null : _onStatusChanged,
          ),
        ),
        const SizedBox(width: TravleTokens.space12),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int?>(
            initialValue: _periodDays,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, labelText: 'Period'),
            items: const [
              DropdownMenuItem<int?>(value: null, child: Text('All time')),
              DropdownMenuItem<int?>(value: 7, child: Text('Last 7 days')),
              DropdownMenuItem<int?>(value: 30, child: Text('Last 30 days')),
              DropdownMenuItem<int?>(value: 365, child: Text('Last 12 months')),
            ],
            onChanged: _loading ? null : _onPeriodChanged,
          ),
        ),
      ],
    );
  }
}

/// Revenue / commission / refund totals row above the payments table.
class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.summary});

  final PaymentSummaryResponse? summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    String money(double? v) => v == null ? '—' : formatPrice(v);

    return Padding(
      padding: const EdgeInsets.fromLTRB(TravleTokens.space16, TravleTokens.space16,
          TravleTokens.space16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Net revenue',
              value: money(s?.netRevenue),
              icon: Icons.account_balance_wallet_outlined,
              emphasize: true,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: _StatCard(
              label: 'Captured',
              value: money(s?.grossRevenue),
              sub: s == null
                  ? null
                  : '${s.capturedCount} ${s.capturedCount == 1 ? 'payment' : 'payments'}',
              icon: Icons.payments_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: _StatCard(
              label: 'Commission',
              value: money(s?.platformCommission),
              icon: Icons.percent_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: _StatCard(
              label: 'Refunded',
              value: money(s?.totalRefunded),
              sub: s == null
                  ? null
                  : '${s.refundCount} ${s.refundCount == 1 ? 'refund' : 'refunds'}',
              icon: Icons.undo_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? sub;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: TravleTokens.space8),
                Text(label,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted)),
              ],
            ),
            const SizedBox(height: TravleTokens.space8),
            Text(
              value,
              style: (emphasize
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: emphasize ? theme.colorScheme.primary : null,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: TravleTokens.space4),
              Text(sub!, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ],
        ),
      ),
    );
  }
}
