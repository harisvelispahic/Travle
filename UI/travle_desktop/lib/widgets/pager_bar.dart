import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

/// The standard server-paging footer: "Page 2 of 7 · 63 total" plus prev/next.
///
/// Extracted from [PaginatedSearchTable] so the card-based lists (the booking
/// management screens) page exactly the way the reference tables do. The caller
/// owns page state and refetches — this only renders and reports intent.
///
/// [totalCount] comes from the API's `includeTotalCount`; without it the bar falls
/// back to "there is probably a next page if this one came back full".
class PagerBar extends StatelessWidget {
  const PagerBar({
    super.key,
    required this.page,
    required this.pageSize,
    required this.itemCount,
    required this.onPageChanged,
    this.totalCount,
    this.loading = false,
  });

  /// 1-based current page.
  final int page;
  final int pageSize;

  /// How many rows the current page actually returned.
  final int itemCount;

  /// Total matching rows when the screen asked for the count.
  final int? totalCount;

  final bool loading;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totalCount;
    final hasPrev = page > 1;
    final hasNext =
        total != null ? page * pageSize < total : itemCount == pageSize;

    final String label;
    if (total != null) {
      final totalPages = total == 0 ? 1 : ((total + pageSize - 1) ~/ pageSize);
      label = 'Page $page of $totalPages · $total total';
    } else {
      label = 'Page $page';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space8),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed:
                hasPrev && !loading ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed:
                hasNext && !loading ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
