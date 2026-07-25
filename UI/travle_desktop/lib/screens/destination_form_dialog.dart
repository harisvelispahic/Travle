import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Opens the destination submit/edit dialog. Resolves to `true` when the
/// destination was saved (the caller refreshes and shows a snackbar), or null on
/// cancel. Editing an existing destination sends it back for moderation.
Future<bool?> showDestinationFormDialog(
  BuildContext context, {
  DestinationResponse? existing,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DestinationFormDialog(existing: existing),
  );
}

/// One image in the form's grid: an existing image being kept ([existingId] set)
/// or a newly picked one ([base64] + [contentType] set). Both carry
/// [previewBytes] for display (decoded once, at pick/fetch time). [key] is a
/// stable identity for the reorderable list.
class _ImageItem {
  _ImageItem({
    this.existingId,
    this.base64,
    this.contentType,
    required this.previewBytes,
  }) : key = UniqueKey();

  final Key key;
  final int? existingId;
  final String? base64;
  final String? contentType;
  final Uint8List previewBytes;

  bool get isExisting => existingId != null;
}

class DestinationFormDialog extends StatefulWidget {
  const DestinationFormDialog({super.key, this.existing});

  final DestinationResponse? existing;

  bool get isEditing => existing != null;

  @override
  State<DestinationFormDialog> createState() => _DestinationFormDialogState();
}

class _DestinationFormDialogState extends State<DestinationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  List<DestinationCategoryResponse> _categories = [];
  List<CityResponse> _cities = [];
  List<TagResponse> _tags = [];

  int? _categoryId;
  int? _cityId;
  final Set<int> _selectedTagIds = {};
  final List<_ImageItem> _images = [];

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _submitError;

  /// True only when this edit will actually change the status back to Pending —
  /// i.e. an already-approved (or rejected) destination is being edited.
  bool get _sendsForReview =>
      widget.existing != null && !widget.existing!.isPending;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _name.text = existing.name;
      _description.text = existing.description;
      _latitude.text = existing.latitude.toString();
      _longitude.text = existing.longitude.toString();
      _categoryId = existing.categoryId;
      _cityId = existing.cityId;
      _selectedTagIds.addAll(existing.tags.map((t) => t.id));
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final categoryProvider = context.read<DestinationCategoryProvider>();
    final cityProvider = context.read<CityProvider>();
    final tagProvider = context.read<TagProvider>();
    final destinationProvider = context.read<DestinationProvider>();
    final existing = widget.existing;
    try {
      final results = await Future.wait([
        categoryProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
        cityProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
        tagProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
      ]);

      final images = <_ImageItem>[];
      if (existing != null && existing.images.isNotEmpty) {
        final ordered = [...existing.images]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final bytes = await Future.wait(
          ordered.map((img) => destinationProvider.imageBytes(existing.id, img.id)),
        );
        for (var i = 0; i < ordered.length; i++) {
          images.add(_ImageItem(existingId: ordered[i].id, previewBytes: bytes[i]));
        }
      }

      if (!mounted) return;
      setState(() {
        _categories =
            (results[0] as SearchResult<DestinationCategoryResponse>).items;
        _cities = (results[1] as SearchResult<CityResponse>).items;
        _tags = (results[2] as SearchResult<TagResponse>).items;
        _images
          ..clear()
          ..addAll(images);
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

  Future<void> _pickImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;

    final added = <_ImageItem>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final contentType = ImageCodec.sniffContentType(bytes);
      if (contentType == null) {
        if (mounted) {
          AppSnackbars.error(context, 'Skipped "${file.name}" — only JPEG or PNG images are allowed.');
        }
        continue;
      }
      if (bytes.length > ImageCodec.maxImageBytes) {
        if (mounted) {
          AppSnackbars.error(context, 'Skipped "${file.name}" — images must be 5 MB or smaller.');
        }
        continue;
      }
      added.add(_ImageItem(
        base64: ImageCodec.encode(bytes),
        contentType: contentType,
        previewBytes: bytes,
      ));
    }

    if (added.isEmpty || !mounted) return;
    setState(() => _images.addAll(added));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  void _reorderImages(int oldIndex, int newIndex) {
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _cityId == null) return;

    final provider = context.read<DestinationProvider>();
    final navigator = Navigator.of(context);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final latitude = double.parse(_latitude.text.trim());
      final longitude = double.parse(_longitude.text.trim());
      if (widget.isEditing) {
        await provider.edit(
          widget.existing!.id,
          DestinationUpdateRequest(
            name: _name.text.trim(),
            description: _description.text.trim(),
            categoryId: _categoryId!,
            cityId: _cityId!,
            latitude: latitude,
            longitude: longitude,
            tagIds: _selectedTagIds.toList(),
            images: [
              for (var i = 0; i < _images.length; i++)
                if (_images[i].isExisting)
                  DestinationImageEditItem(id: _images[i].existingId, sortOrder: i)
                else
                  DestinationImageEditItem(
                    data: _images[i].base64,
                    contentType: _images[i].contentType,
                    sortOrder: i,
                  ),
            ],
          ),
        );
      } else {
        await provider.submit(
          DestinationInsertRequest(
            name: _name.text.trim(),
            description: _description.text.trim(),
            categoryId: _categoryId!,
            cityId: _cityId!,
            latitude: latitude,
            longitude: longitude,
            tagIds: _selectedTagIds.toList(),
            images: [
              for (var i = 0; i < _images.length; i++)
                DestinationImageRequest(
                  data: _images[i].base64!,
                  contentType: _images[i].contentType!,
                  sortOrder: i,
                ),
            ],
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
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
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
                      widget.isEditing ? 'Edit destination' : 'New destination',
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
                        : Text(widget.isEditing
                            ? 'Save changes'
                            : 'Submit for approval'),
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
            if (_sendsForReview) ...[
              _EditWarningBanner(),
              const SizedBox(height: TravleTokens.space16),
            ],
            TravleTextField(
              controller: _name,
              label: 'Name',
              prefixIcon: Icons.place_outlined,
              textInputAction: TextInputAction.next,
              maxLength: 200,
              validator: (v) => Validators.required(v, field: 'Name'),
            ),
            const SizedBox(height: TravleTokens.space16),
            _buildCategoryDropdown(),
            const SizedBox(height: TravleTokens.space16),
            _buildCityDropdown(),
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
            _SectionLabel('Tags'),
            const SizedBox(height: TravleTokens.space8),
            _buildTagChips(theme),
            const SizedBox(height: TravleTokens.space24),
            _SectionLabel('Photos'),
            const SizedBox(height: TravleTokens.space8),
            _buildImageGrid(theme),
            const SizedBox(height: TravleTokens.space24),
            _LocationSection(
              latitude: _latitude,
              longitude: _longitude,
              enabled: !_submitting,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _categoryId,
      decoration: const InputDecoration(
        labelText: 'Category',
        hintText: 'Select a category',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        for (final c in _categories)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
      ],
      onChanged: _submitting ? null : (id) => setState(() => _categoryId = id),
      validator: (v) => v == null ? 'Please select a category' : null,
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: _cityId,
      decoration: const InputDecoration(
        labelText: 'City',
        hintText: 'Select a city',
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      items: [
        for (final c in _cities)
          DropdownMenuItem(
            value: c.id,
            child: Text(c.regionName == null ? c.name : '${c.name} — ${c.regionName}'),
          ),
      ],
      onChanged: _submitting ? null : (id) => setState(() => _cityId = id),
      validator: (v) => v == null ? 'Please select a city' : null,
    );
  }

  Widget _buildTagChips(ThemeData theme) {
    if (_tags.isEmpty) {
      return Text(
        'No tags available.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: TravleTokens.space8,
      runSpacing: TravleTokens.space8,
      children: [
        for (final tag in _tags)
          FilterChip(
            label: Text(tag.name),
            selected: _selectedTagIds.contains(tag.id),
            onSelected: _submitting
                ? null
                : (selected) => setState(() {
                      if (selected) {
                        _selectedTagIds.add(tag.id);
                      } else {
                        _selectedTagIds.remove(tag.id);
                      }
                    }),
          ),
      ],
    );
  }

  Widget _buildImageGrid(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_images.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ReorderableListView(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              onReorderItem: (oldIndex, newIndex) {
                if (_submitting) return;
                _reorderImages(oldIndex, newIndex);
              },
              children: [
                for (var i = 0; i < _images.length; i++)
                  Padding(
                    key: _images[i].key,
                    padding: const EdgeInsets.only(right: TravleTokens.space8),
                    child: _ImageThumb(
                      bytes: _images[i].previewBytes,
                      isCover: i == 0,
                      onRemove: _submitting ? null : () => _removeImage(i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TravleTokens.space12),
        ],
        OutlinedButton.icon(
          onPressed: _submitting ? null : _pickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_images.isEmpty ? 'Add photos' : 'Add more photos'),
        ),
        const SizedBox(height: TravleTokens.space4),
        Text(
          'JPEG or PNG, up to 5 MB each. Drag to reorder — the first photo is used as the cover.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);
}

class _EditWarningBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Text(
              'Editing sends this destination back for moderation.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.bytes, this.isCover = false, this.onRemove});

  final Uint8List bytes;
  final bool isCover;
  final VoidCallback? onRemove;

  static const double _size = 84;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Container(
          width: _size,
          height: _size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TravleTokens.radius),
            border: Border.all(
              color: isCover
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isCover ? 3 : 1,
            ),
          ),
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
        if (isCover)
          Positioned(
            left: TravleTokens.space4,
            bottom: TravleTokens.space4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
              ),
              child: Text(
                'Cover',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Manual latitude/longitude entry. Interim: a map picker (Leaflet /
/// OpenRouteService) will replace these fields later — keeping the coordinate
/// entry isolated here makes that swap a one-widget change.
class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.latitude,
    required this.longitude,
    required this.enabled,
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final bool enabled;

  static final _coordinateFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'));

  String? _validate(String? value, String field, double min, double max) {
    final required = Validators.required(value, field: field);
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) return '$field must be a number';
    if (parsed < min || parsed > max) {
      return '$field must be between $min and $max';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space4),
        Text(
          'Enter the coordinates for now — a map picker is coming soon.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: TravleTokens.space16),
        Row(
          children: [
            Expanded(
              child: TravleTextField(
                controller: latitude,
                label: 'Latitude',
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [_coordinateFormatter],
                textInputAction: TextInputAction.next,
                validator: (v) => _validate(v, 'Latitude', -90, 90),
              ),
            ),
            const SizedBox(width: TravleTokens.space16),
            Expanded(
              child: TravleTextField(
                controller: longitude,
                label: 'Longitude',
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [_coordinateFormatter],
                textInputAction: TextInputAction.done,
                validator: (v) => _validate(v, 'Longitude', -180, 180),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Inline banner for a server-side submit error, shown inside the form so the
/// user's input is preserved.
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
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
