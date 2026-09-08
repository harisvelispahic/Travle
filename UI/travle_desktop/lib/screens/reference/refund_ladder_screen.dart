import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// The refund policy, edited as one ladder instead of a row at a time.
///
/// The tiers only mean anything together: they must cover every hour before
/// departure exactly once, exactly one of them is open-ended, and refunds have
/// to rise as notice grows. A per-row CRUD screen cannot express that — adding
/// a row always overlaps a neighbour and removing one always leaves a gap, so
/// every single-row edit to a valid ladder is rejected. Here the boundaries are
/// *shared* between adjacent tiers, so a gap or an overlap is not something the
/// admin can type: moving a boundary moves both sides of it at once.
///
/// That leaves two structural operations, both of which preserve coverage by
/// construction: **split** a tier at a new boundary, and **merge** a tier into
/// the one below it. Percentages are edited in place. Everything is validated
/// live and saved in one request; the server re-validates the same rules.
class RefundLadderScreen extends StatefulWidget {
  const RefundLadderScreen({super.key});

  @override
  State<RefundLadderScreen> createState() => _RefundLadderScreenState();
}

/// One rung while it is being edited. [upperBound] is null for the open-ended
/// top tier; the lower bound is always the previous rung's upper bound (or 0),
/// which is what makes gaps and overlaps unrepresentable.
class _Rung {
  _Rung({required this.upperBound, required this.percentage});

  int? upperBound;
  int percentage;
}

class _RefundLadderScreenState extends State<RefundLadderScreen> {
  final RefundPolicyTierProvider _provider = RefundPolicyTierProvider();

  /// Ordered from the departure upwards: index 0 starts at 0 hours before.
  List<_Rung> _rungs = [];

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _saveError = null;
    });
    try {
      final result = await _provider.get(filter: {'page': 1, 'pageSize': 100});
      // The API returns the ladder in no particular order; rebuild it bottom-up
      // so each rung's lower bound is simply the one below it.
      final tiers = [...result.items]
        ..sort((a, b) => a.hoursBeforeMin.compareTo(b.hoursBeforeMin));
      if (!mounted) return;
      setState(() {
        _rungs = [
          for (final t in tiers)
            _Rung(upperBound: t.hoursBeforeMax, percentage: t.percentage),
        ];
        _loading = false;
        _dirty = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  // ── Derived state ─────────────────────────────────────────────────────────

  /// The lower bound of rung [i]: 0 for the first, else the rung below's upper.
  int _lowerBound(int i) => i == 0 ? 0 : (_rungs[i - 1].upperBound ?? 0);

  /// The first problem with the ladder as it currently stands, or null when it
  /// is valid. Mirrors the server's rules so the admin never has to submit to
  /// find out.
  String? get _validationError {
    if (_rungs.isEmpty) {
      return 'The policy must have at least one tier.';
    }
    for (var i = 0; i < _rungs.length; i++) {
      final isLast = i == _rungs.length - 1;
      final upper = _rungs[i].upperBound;

      if (isLast && upper != null) {
        return 'The highest tier must be open-ended.';
      }
      if (!isLast && upper == null) {
        return 'Only the highest tier may be open-ended.';
      }
      if (!isLast && upper! <= _lowerBound(i)) {
        return 'Tier ${i + 1} ends at ${upper}h, which is not after its start '
            'of ${_lowerBound(i)}h.';
      }
      if (i > 0 && _rungs[i].percentage <= _rungs[i - 1].percentage) {
        return 'Refunds must increase with notice: tier ${i + 1} pays '
            '${_rungs[i].percentage}%, which is not more than the '
            '${_rungs[i - 1].percentage}% below it.';
      }
    }
    return null;
  }

  bool get _canSave => _dirty && _validationError == null && !_saving;

  // ── Structural edits (each preserves full coverage by construction) ───────

  /// Splits rung [i] in two at a boundary inside it, so the range stays covered.
  void _split(int i) {
    final lower = _lowerBound(i);
    final upper = _rungs[i].upperBound;
    // Halfway for a bounded tier; a sensible step above the floor for the open
    // top one, which has no midpoint.
    final boundary = upper == null ? lower + 24 : lower + ((upper - lower) ~/ 2);
    if (upper != null && (boundary <= lower || boundary >= upper)) {
      AppSnackbars.error(context, 'This tier is too narrow to split.');
      return;
    }

    setState(() {
      final below = _Rung(upperBound: boundary, percentage: _rungs[i].percentage);
      // The new upper half keeps the original's ceiling; nudge its percentage up
      // so the ladder stays strictly increasing without further typing.
      final above = _Rung(
        upperBound: upper,
        percentage: (_rungs[i].percentage + 5).clamp(0, 100),
      );
      _rungs
        ..removeAt(i)
        ..insertAll(i, [below, above]);
      _dirty = true;
    });
  }

  /// Removes the boundary below rung [i], merging it into its lower neighbour.
  void _mergeDown(int i) {
    setState(() {
      // The lower rung absorbs this one's ceiling; this one's percentage wins,
      // since the wider window now reaches further out.
      _rungs[i - 1].upperBound = _rungs[i].upperBound;
      _rungs[i - 1].percentage = _rungs[i].percentage;
      _rungs.removeAt(i);
      _dirty = true;
    });
  }

  void _setBoundary(int i, int? value) {
    setState(() {
      _rungs[i].upperBound = value;
      _dirty = true;
    });
  }

  void _setPercentage(int i, int value) {
    setState(() {
      _rungs[i].percentage = value;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      // Rebuild absolute windows from the shared boundaries.
      final payload = <RefundPolicyTierResponse>[
        for (var i = 0; i < _rungs.length; i++)
          RefundPolicyTierResponse(
            id: 0,
            hoursBeforeMin: _lowerBound(i),
            hoursBeforeMax: _rungs[i].upperBound,
            percentage: _rungs[i].percentage,
            createdAt: DateTime.now(),
          ),
      ];
      await _provider.replaceLadder(payload);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      AppSnackbars.success(context, 'Refund policy saved.');
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e.message;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: TravleTokens.space16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final error = _validationError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(TravleTokens.space16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Refund policy', style: theme.textTheme.titleLarge),
                    const SizedBox(height: TravleTokens.space4),
                    Text(
                      'How much a traveler gets back when they cancel, by how long before '
                      'departure. The tiers meet exactly, so every cancellation matches one '
                      'rule — split a tier to add a step, merge it to remove one.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TravleTokens.space16),
              if (_dirty)
                TextButton(
                  onPressed: _saving ? null : _load,
                  child: const Text('Discard'),
                ),
              const SizedBox(width: TravleTokens.space8),
              FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save policy'),
              ),
            ],
          ),
        ),
        if (error != null || _saveError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(TravleTokens.space16, 0,
                TravleTokens.space16, TravleTokens.space12),
            child: _Banner(message: _saveError ?? error!),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(TravleTokens.space16),
            itemCount: _rungs.length,
            separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space8),
            itemBuilder: (context, i) => _RungRow(
              index: i,
              total: _rungs.length,
              lowerBound: _lowerBound(i),
              rung: _rungs[i],
              onBoundaryChanged: (v) => _setBoundary(i, v),
              onPercentageChanged: (v) => _setPercentage(i, v),
              onSplit: () => _split(i),
              onMergeDown: i == 0 ? null : () => _mergeDown(i),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: TravleTokens.space8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// One rung: its window (lower bound read-only, because it belongs to the rung
/// below), its refund percentage, and the two structural actions.
class _RungRow extends StatelessWidget {
  const _RungRow({
    required this.index,
    required this.total,
    required this.lowerBound,
    required this.rung,
    required this.onBoundaryChanged,
    required this.onPercentageChanged,
    required this.onSplit,
    required this.onMergeDown,
  });

  final int index;
  final int total;
  final int lowerBound;
  final _Rung rung;
  final ValueChanged<int?> onBoundaryChanged;
  final ValueChanged<int> onPercentageChanged;
  final VoidCallback onSplit;
  final VoidCallback? onMergeDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = index == total - 1;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                'From ${lowerBound}h',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            SizedBox(
              width: 150,
              child: isLast
                  ? Text(
                      'and earlier',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    )
                  : _NumberField(
                      label: 'up to (h)',
                      value: rung.upperBound,
                      onChanged: onBoundaryChanged,
                    ),
            ),
            const SizedBox(width: TravleTokens.space16),
            SizedBox(
              width: 130,
              child: _NumberField(
                label: 'refund %',
                value: rung.percentage,
                onChanged: (v) => onPercentageChanged(v ?? 0),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onSplit,
              icon: const Icon(Icons.call_split, size: 18),
              label: const Text('Split'),
            ),
            const SizedBox(width: TravleTokens.space8),
            Tooltip(
              message: onMergeDown == null
                  ? 'The lowest tier has no boundary below it to remove'
                  : 'Remove the boundary below and merge into that tier',
              child: TextButton.icon(
                onPressed: onMergeDown,
                icon: const Icon(Icons.merge, size: 18),
                label: const Text('Merge down'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void didUpdateWidget(covariant _NumberField old) {
    super.didUpdateWidget(old);
    // Structural edits (split/merge) renumber the rows, so a row can be handed a
    // different value than the one its controller holds. Only overwrite when it
    // actually differs, or typing would fight the rebuild.
    final incoming = widget.value?.toString() ?? '';
    if (incoming != _controller.text) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (raw) => widget.onChanged(int.tryParse(raw.trim())),
      );
}
