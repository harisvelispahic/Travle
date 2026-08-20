import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One selectable row in a [showMultiSelectSheet]: the id sent to the API paired
/// with the label the traveler reads. Never renders the id.
class MultiSelectOption {
  const MultiSelectOption(this.value, this.label);

  final int value;
  final String label;
}

/// A bottom sheet for picking **any number** of reference rows — the multi-select
/// counterpart of the single-choice filter sheets.
///
/// Resolves to the chosen set on Apply, or **null** when dismissed, so a dismissal
/// leaves the caller's filter untouched instead of silently clearing it. Shared by
/// every mobile filter that reads as "show me these kinds of thing" (destination
/// search, map browse), so the two surfaces stay identical.
Future<Set<int>?> showMultiSelectSheet(
  BuildContext context, {
  required String title,
  required List<MultiSelectOption> options,
  required Set<int> selected,
  String clearLabel = 'Clear',
  String applyLabel = 'Apply',
}) {
  final theme = Theme.of(context);
  final working = {...selected};

  return showModalBottomSheet<Set<int>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  TravleTokens.space16, 0, TravleTokens.space8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed:
                        working.isEmpty ? null : () => setSheet(working.clear),
                    child: Text(clearLabel),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    CheckboxListTile(
                      value: working.contains(option.value),
                      title: Text(option.label),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (checked) => setSheet(() {
                        if (checked ?? false) {
                          working.add(option.value);
                        } else {
                          working.remove(option.value);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(TravleTokens.space16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(working),
                  child: Text(applyLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The label a multi-select filter chip should show: the bare filter name when
/// nothing is picked, the single pick's own label when exactly one is, and a count
/// beyond that. Keeps the search and map chips reading the same.
String multiSelectChipLabel({
  required String emptyLabel,
  required Set<int> selected,
  required List<MultiSelectOption> options,
  required String pluralNoun,
}) {
  if (selected.isEmpty) return emptyLabel;
  if (selected.length == 1) {
    for (final option in options) {
      if (option.value == selected.first) return option.label;
    }
  }
  return '${selected.length} $pluralNoun';
}
