import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Opens the tour create/edit dialog. Resolves to `true` when the tour was saved
/// (the caller refreshes and shows a snackbar), or null on cancel.
Future<bool?> showTourFormDialog(
  BuildContext context, {
  TourResponse? existing,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TourFormDialog(existing: existing),
  );
}

/// One selected itinerary stop in the form (an approved destination). [key] is a
/// stable identity for the reorderable list.
class _Stop {
  _Stop({
    required this.destinationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.thumbnail,
  }) : key = UniqueKey();

  final Key key;
  final int destinationId;
  final String name;
  final double latitude;
  final double longitude;
  final String? cityName;
  final String? thumbnail;
}

class TourFormDialog extends StatefulWidget {
  const TourFormDialog({super.key, this.existing});

  final TourResponse? existing;

  bool get isEditing => existing != null;

  @override
  State<TourFormDialog> createState() => _TourFormDialogState();
}

class _TourFormDialogState extends State<TourFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _duration = TextEditingController();
  final _price = TextEditingController();
  final _capacity = TextEditingController();

  List<TourTypeResponse> _tourTypes = [];
  int? _tourTypeId;
  final List<_Stop> _stops = [];

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _submitError;
  // Set once the stops fail their own (non-form-field) validation on submit.
  bool _stopsError = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _description.text = existing.description;
      _duration.text = existing.durationMinutes.toString();
      _price.text = existing.pricePerPerson.toStringAsFixed(2);
      _capacity.text = existing.capacity.toString();
      _tourTypeId = existing.tourTypeId;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _price.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final tourTypeProvider = context.read<TourTypeProvider>();
    final tourProvider = context.read<TourProvider>();
    final existing = widget.existing;
    try {
      final results = await Future.wait([
        tourTypeProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
        // Editing: the list row carries no itinerary, so pull the detail for its
        // ordered stops.
        if (existing != null)
          tourProvider.getDetail(existing.id)
        else
          Future<TourResponse?>.value(null),
      ]);

      final stops = <_Stop>[];
      final detail = results[1] as TourResponse?;
      if (detail != null) {
        final ordered = [...detail.destinations]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        for (final d in ordered) {
          stops.add(_Stop(
            destinationId: d.destinationId,
            name: d.name,
            latitude: d.latitude,
            longitude: d.longitude,
            cityName: d.cityName,
            thumbnail: d.thumbnail,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _tourTypes = (results[0] as SearchResult<TourTypeResponse>).items;
        _stops
          ..clear()
          ..addAll(stops);
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _addDestinations() async {
    final added = await showDialog<List<DestinationResponse>>(
      context: context,
      builder: (_) => _DestinationPickerDialog(
        excludeIds: _stops.map((s) => s.destinationId).toSet(),
      ),
    );
    if (added == null || added.isEmpty || !mounted) return;
    setState(() {
      for (final d in added) {
        _stops.add(_Stop(
          destinationId: d.id,
          name: d.name,
          latitude: d.latitude,
          longitude: d.longitude,
          cityName: d.cityName,
          thumbnail: d.primaryThumbnail,
        ));
      }
      _stopsError = false;
    });
  }

  void _removeStop(int index) => setState(() => _stops.removeAt(index));

  // Paired with ReorderableListView.onReorderItem, which already adjusts newIndex
  // for the item removed at oldIndex — so this is a straight remove/insert.
  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final formOk = _formKey.currentState!.validate();
    final stopsOk = _stops.isNotEmpty;
    if (!stopsOk) setState(() => _stopsError = true);
    if (!formOk || !stopsOk || _tourTypeId == null) return;

    final provider = context.read<TourProvider>();
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final durationMinutes = int.parse(_duration.text.trim());
      final pricePerPerson = double.parse(_price.text.trim());
      final capacity = int.parse(_capacity.text.trim());
      final destinationIds = _stops.map((s) => s.destinationId).toList();

      if (widget.isEditing) {
        await provider.edit(
          widget.existing!.id,
          TourUpdateRequest(
            name: _name.text.trim(),
            description: _description.text.trim(),
            durationMinutes: durationMinutes,
            pricePerPerson: pricePerPerson,
            capacity: capacity,
            tourTypeId: _tourTypeId!,
            destinationIds: destinationIds,
          ),
        );
      } else {
        await provider.create(
          TourInsertRequest(
            name: _name.text.trim(),
            description: _description.text.trim(),
            durationMinutes: durationMinutes,
            pricePerPerson: pricePerPerson,
            capacity: capacity,
            tourTypeId: _tourTypeId!,
            destinationIds: destinationIds,
          ),
        );
      }
      navigator.pop(true);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isEditing ? 'Edit tour' : 'New tour',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: TravleTokens.space16),
              Flexible(child: _buildContent(theme)),
              if (_submitError != null) ...[
                const SizedBox(height: TravleTokens.space16),
                _ErrorBanner(message: _submitError!),
              ],
              const SizedBox(height: TravleTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  FilledButton(
                    onPressed: (_loading || _submitting) ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isEditing ? 'Save changes' : 'Create tour'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUnfocus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TravleTextField(
              controller: _name,
              label: 'Name',
              prefixIcon: Icons.tour_outlined,
              textInputAction: TextInputAction.next,
              maxLength: 200,
              validator: (v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: TravleTokens.space16),
            _buildTourTypeDropdown(),
            const SizedBox(height: TravleTokens.space16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TravleTextField(
                    controller: _duration,
                    label: 'Duration (minutes)',
                    prefixIcon: Icons.schedule_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateInt(v, 'Duration', 1, 10080),
                  ),
                ),
                const SizedBox(width: TravleTokens.space16),
                Expanded(
                  child: TravleTextField(
                    controller: _price,
                    label: 'Price / person (KM)',
                    prefixIcon: Icons.payments_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: _validatePrice,
                  ),
                ),
                const SizedBox(width: TravleTokens.space16),
                Expanded(
                  child: TravleTextField(
                    controller: _capacity,
                    label: 'Capacity',
                    prefixIcon: Icons.groups_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateInt(v, 'Capacity', 1, 1000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space8),
            Text(
              'Capacity is the default group size for new schedules — each date can override it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: TravleTokens.space16),
            TravleTextField(
              controller: _description,
              label: 'Description',
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              keyboardType: TextInputType.multiline,
              validator: (v) => Validators.required(v, field: 'Description'),
            ),
            const SizedBox(height: TravleTokens.space24),
            _buildItinerary(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTourTypeDropdown() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _tourTypeId,
      decoration: const InputDecoration(
        labelText: 'Tour type',
        hintText: 'Select a tour type',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        for (final t in _tourTypes)
          DropdownMenuItem(value: t.id, child: Text(t.name)),
      ],
      onChanged: _submitting ? null : (id) => setState(() => _tourTypeId = id),
      validator: (v) => v == null ? 'Please select a tour type' : null,
    );
  }

  Widget _buildItinerary(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Itinerary', style: theme.textTheme.titleMedium),
            ),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _addDestinations,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add destinations'),
            ),
          ],
        ),
        const SizedBox(height: TravleTokens.space4),
        Text(
          'Approved destinations the tour visits, in order. Drag to reorder.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: TravleTokens.space8),
        if (_stops.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TravleTokens.space16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(TravleTokens.radius),
              border: _stopsError
                  ? Border.all(color: theme.colorScheme.error)
                  : null,
            ),
            child: Text(
              'Add at least one destination.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _stopsError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          Builder(
            builder: (context) {
              final points = [
                for (final stop in _stops)
                  MapPoint(
                    latitude: stop.latitude,
                    longitude: stop.longitude,
                    label: stop.name,
                  ),
              ];
              return TravleMapView(
                points: points,
                height: 220,
                numbered: true,
                connect: true,
                onTap: () => showTravleMap(
                  context,
                  points: points,
                  title: 'Itinerary',
                  numbered: true,
                  connect: true,
                ),
              );
            },
          ),
          const SizedBox(height: TravleTokens.space12),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            onReorderItem: (oldIndex, newIndex) {
              if (_submitting) return;
              _reorderStops(oldIndex, newIndex);
            },
            children: [
              for (var i = 0; i < _stops.length; i++)
                _StopTile(
                  key: _stops[i].key,
                  index: i,
                  stop: _stops[i],
                  onRemove: _submitting ? null : () => _removeStop(i),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String? _validateInt(String? value, String field, int min, int max) {
    final required = Validators.required(value, field: field);
    if (required != null) return required;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return '$field must be a whole number';
    if (parsed < min || parsed > max) {
      return '$field must be between $min and $max';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final required = Validators.required(value, field: 'Price');
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) return 'Price must be a number';
    if (parsed <= 0) return 'Price must be greater than 0';
    if (parsed > 100000) return 'Price cannot exceed 100000 KM';
    return null;
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    super.key,
    required this.index,
    required this.stop,
    required this.onRemove,
  });

  final int index;
  final _Stop stop;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: TravleTokens.space8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TravleTokens.space12,
          vertical: TravleTokens.space8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(TravleTokens.radius),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
            const SizedBox(width: TravleTokens.space12),
            ThumbnailImage(base64: stop.thumbnail, width: 40, height: 40),
            const SizedBox(width: TravleTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(stop.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis),
                  if (stop.cityName != null && stop.cityName!.isNotEmpty)
                    Text(
                      stop.cityName!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close, size: 20),
                onPressed: onRemove,
              ),
            const SizedBox(width: TravleTokens.space4),
            Icon(Icons.drag_handle, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// A searchable multi-select of approved destinations to add to a tour's
/// itinerary. Returns the chosen destinations (or null on cancel).
class _DestinationPickerDialog extends StatefulWidget {
  const _DestinationPickerDialog({required this.excludeIds});

  final Set<int> excludeIds;

  @override
  State<_DestinationPickerDialog> createState() =>
      _DestinationPickerDialogState();
}

class _DestinationPickerDialogState extends State<_DestinationPickerDialog> {
  String _search = '';
  bool _loading = true;
  String? _error;
  List<DestinationResponse> _items = [];
  // Selections persist across searches by holding the full row, not just the id.
  final Map<int, DestinationResponse> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<DestinationProvider>().get(
        filter: {
          'pageSize': 50,
          'sortBy': 'Name',
          if (_search.isNotEmpty) 'text': _search,
        },
      );
      if (!mounted) return;
      setState(() {
        _items = result.items
            .where((d) => !widget.excludeIds.contains(d.id))
            .toList();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Add destinations',
                        style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: TravleTokens.space16),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search approved destinations…',
                ),
                onSubmitted: (v) {
                  _search = v.trim();
                  _load();
                },
              ),
              const SizedBox(height: TravleTokens.space16),
              Flexible(child: _buildList(theme)),
              const SizedBox(height: TravleTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context)
                            .pop(_selected.values.toList()),
                    child: Text(_selected.isEmpty
                        ? 'Add'
                        : 'Add ${_selected.length}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.travel_explore_outlined,
        message: 'No approved destinations to add.',
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final d = _items[i];
        final selected = _selected.containsKey(d.id);
        return CheckboxListTile(
          value: selected,
          onChanged: (checked) => setState(() {
            if (checked == true) {
              _selected[d.id] = d;
            } else {
              _selected.remove(d.id);
            }
          }),
          secondary:
              ThumbnailImage(base64: d.primaryThumbnail, width: 44, height: 44),
          title: Text(d.name),
          subtitle: Text(
            [d.cityName, d.regionName]
                .where((p) => p != null && p.isNotEmpty)
                .join(', '),
          ),
        );
      },
    );
  }
}

/// Inline banner for a server-side submit error (keeps the user's input).
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: TravleTokens.space8),
          Expanded(
            child:
                Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
