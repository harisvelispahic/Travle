import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Submit a new destination or edit an existing one (curator/organizer). Fields:
/// name, category, description, tags, images, and location. Editing an existing
/// destination sends it back for moderation (warned up front). Coordinates are
/// entered manually for now — a map picker replaces the [_LocationSection] later.
class DestinationFormScreen extends StatefulWidget {
  const DestinationFormScreen({super.key, this.existing});

  /// The destination being edited, or null when creating a new one.
  final DestinationResponse? existing;

  bool get isEditing => existing != null;

  @override
  State<DestinationFormScreen> createState() => _DestinationFormScreenState();
}

/// One image in the form's grid: either an existing image being kept
/// ([existingId] set) or a newly picked one ([base64] + [contentType] set). Both
/// carry [previewBytes] for display (decoded once, at pick/fetch time). [key] is a
/// stable identity for the reorderable list (new images have no server id yet).
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

class _DestinationFormScreenState extends State<DestinationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _entranceFee = TextEditingController();

  List<DestinationCategoryResponse> _categories = [];
  List<CityResponse> _cities = [];
  List<TagResponse> _tags = [];

  int? _categoryId;
  int? _cityId;
  final Set<int> _selectedTagIds = {};
  final List<_ImageItem> _images = [];

  bool _loading = true;
  String? _loadError;
  bool _busy = false;
  String? _error;

  /// True only when this edit will actually change the status back to Pending —
  /// i.e. an already-approved (or rejected) destination is being edited. Editing a
  /// still-pending destination leaves it pending, so no "back for review" nudge.
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
      if (existing.entranceFee != null) {
        _entranceFee.text = existing.entranceFee!.toStringAsFixed(2);
      }
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
    _entranceFee.dispose();
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
      // Independent loads in parallel (constraint A.2).
      final results = await Future.wait([
        categoryProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
        cityProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
        tagProvider.get(filter: {'pageSize': 100, 'sortBy': 'Name'}),
      ]);

      final images = <_ImageItem>[];
      if (existing != null && existing.images.isNotEmpty) {
        // Fetch existing image bytes for preview (decoded once here, not in build).
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
    // onReorderItem already gives newIndex as the final target (adjusted for the
    // item removed at oldIndex), so no off-by-one correction is needed here.
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  String? _validateEntranceFee(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // optional — blank means free/unknown
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Entrance fee must be a number';
    if (parsed < 0 || parsed > 10000) {
      return 'Entrance fee must be between 0 and 10000 KM';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _cityId == null) return;

    // Capture context-bound handles before the confirm dialog's async gap.
    final provider = context.read<DestinationProvider>();
    final navigator = Navigator.of(context);

    final confirmed = await showConfirmDialog(
      context,
      title: widget.isEditing ? 'Save changes' : 'Submit for approval',
      message: !widget.isEditing
          ? 'Submit this destination for an admin to review?'
          : _sendsForReview
              ? 'Editing sends this destination back for moderation. Continue?'
              : 'Save changes to this destination?',
      confirmLabel: widget.isEditing ? 'Save' : 'Submit',
    );
    if (!confirmed) return;

    final latitude = double.parse(_latitude.text.trim());
    final longitude = double.parse(_longitude.text.trim());
    final feeText = _entranceFee.text.trim();
    final entranceFee = feeText.isEmpty ? null : double.parse(feeText);

    setState(() => _busy = true);
    try {
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
            entranceFee: entranceFee,
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
            entranceFee: entranceFee,
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
      if (!mounted) return;
      AppSnackbars.success(
        context,
        !widget.isEditing
            ? 'Destination submitted — an admin will review it soon.'
            : _sendsForReview
                ? 'Destination updated — it will be reviewed again.'
                : 'Destination updated.',
      );
      navigator.pop(true);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit destination' : 'New destination'),
      ),
      body: SafeArea(child: _buildBody(Theme.of(context))),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(TravleTokens.space24),
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
                      textInputAction: TextInputAction.newline,
                      validator: (v) =>
                          Validators.required(v, field: 'Description'),
                    ),
                    const SizedBox(height: TravleTokens.space16),
                    TravleTextField(
                      controller: _entranceFee,
                      label: 'Entrance fee (KM, optional)',
                      helperText:
                          'Leave blank if free. Shown to travelers as a reminder — never added to a tour price.',
                      prefixIcon: Icons.confirmation_number_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      validator: _validateEntranceFee,
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
                      enabled: !_busy,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: TravleTokens.space16),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: TravleTokens.space24),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEditing
                              ? 'Save changes'
                              : 'Submit for approval'),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      onChanged: _busy ? null : (id) => setState(() => _categoryId = id),
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
      onChanged: _busy ? null : (id) => setState(() => _cityId = id),
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
            onSelected: _busy
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
              // Drag the whole thumbnail to reorder (long-press on mobile).
              buildDefaultDragHandles: true,
              onReorderItem: (oldIndex, newIndex) {
                if (_busy) return;
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
                      onRemove: _busy ? null : () => _removeImage(i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TravleTokens.space12),
        ],
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickImages,
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

  /// The cover (first) image gets a highlighted border and a "Cover" badge.
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
/// OpenRouteService) will replace these fields with a tappable map — keeping the
/// coordinate entry isolated here makes that swap a one-widget change (07 §8).
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
