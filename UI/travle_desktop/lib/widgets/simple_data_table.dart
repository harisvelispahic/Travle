import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

/// A column spec for [SimpleDataTable]: a header [label], whether its cells are
/// [numeric] (right-aligned), and its [flex] weight.
class SimpleColumn {
  const SimpleColumn(this.label, {this.numeric = false, this.flex = 1});

  final String label;
  final bool numeric;
  final int flex;
}

/// A lightweight, non-paginated table for the small aggregate report tables (rank,
/// revenue breakdowns, per-tour stats). Text-only cells, zebra striping, right-aligned
/// numeric columns, and an optional bold [footer] totals row. Styled from the theme.
class SimpleDataTable extends StatelessWidget {
  const SimpleDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
    this.boldFirstColumn = false,
  });

  final List<SimpleColumn> columns;
  final List<List<String>> rows;
  final List<String>? footer;
  final bool boldFirstColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return Column(
      children: [
        // Header row.
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(TravleTokens.radius)),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: TravleTokens.space12, vertical: TravleTokens.space8),
          child: Row(
            children: [
              for (final column in columns)
                Expanded(
                  flex: column.flex,
                  child: Text(
                    column.label,
                    textAlign: column.numeric ? TextAlign.right : TextAlign.left,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Body rows.
        for (var r = 0; r < rows.length; r++)
          Container(
            color: r.isOdd ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35) : null,
            padding: const EdgeInsets.symmetric(
                horizontal: TravleTokens.space12, vertical: TravleTokens.space8),
            child: Row(
              children: [
                for (var c = 0; c < columns.length; c++)
                  Expanded(
                    flex: columns[c].flex,
                    child: Text(
                      rows[r][c],
                      textAlign: columns[c].numeric ? TextAlign.right : TextAlign.left,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            (boldFirstColumn && c == 0) ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Optional totals footer.
        if (footer != null)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: divider)),
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: TravleTokens.space12, vertical: TravleTokens.space8),
            child: Row(
              children: [
                for (var c = 0; c < columns.length; c++)
                  Expanded(
                    flex: columns[c].flex,
                    child: Text(
                      footer![c],
                      textAlign: columns[c].numeric ? TextAlign.right : TextAlign.left,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
