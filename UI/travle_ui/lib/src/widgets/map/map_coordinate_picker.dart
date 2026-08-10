import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/tokens.dart';
import 'map_basemap.dart';
import 'map_pin.dart';
import 'map_types.dart';
import 'travle_map_view.dart';

/// Default map centre when nothing is pre-selected — Sarajevo, the natural focus
/// for a Bosnia-and-Herzegovina destination catalogue.
const LatLng _defaultCenter = LatLng(43.8563, 18.4131);

/// Opens the full-screen map picker and resolves to the chosen [MapCoordinate],
/// or null if the user backs out. [initial] pre-drops the pin when editing.
Future<MapCoordinate?> showMapCoordinatePicker(
  BuildContext context, {
  MapCoordinate? initial,
}) {
  return Navigator.of(context).push<MapCoordinate>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MapCoordinatePickerScreen(initial: initial),
    ),
  );
}

/// Full-screen tap-to-place map picker (doc 08 §5 `MapCoordinatePicker`). Tapping
/// the map drops/moves the pin; street ⇄ satellite toggle top-right; a bottom bar
/// shows the chosen coordinates, the tile attribution, and Cancel / confirm.
class MapCoordinatePickerScreen extends StatefulWidget {
  const MapCoordinatePickerScreen({super.key, this.initial});

  final MapCoordinate? initial;

  @override
  State<MapCoordinatePickerScreen> createState() =>
      _MapCoordinatePickerScreenState();
}

class _MapCoordinatePickerScreenState extends State<MapCoordinatePickerScreen> {
  late MapCoordinate? _selected = widget.initial;
  TravleBasemap _basemap = TravleBasemap.street;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Pick location')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: selected?.toLatLng() ?? _defaultCenter,
              initialZoom: selected != null ? 14 : 7,
              interactionOptions: const InteractionOptions(
                flags: kTravleMapInteractiveFlags,
              ),
              minZoom: 3,
              maxZoom: kMaxMapZoom,
              onTap: (_, point) => setState(
                () => _selected = MapCoordinate(point.latitude, point.longitude),
              ),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            children: [
              TileLayer(
                urlTemplate: _basemap.urlTemplate,
                userAgentPackageName: kTravleMapUserAgent,
                maxZoom: 19,
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selected.toLatLng(),
                      width: MapPin.width,
                      height: MapPin.height,
                      alignment: Alignment.topCenter,
                      child: const MapPin(),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: TravleTokens.space8,
            right: TravleTokens.space8,
            child: BasemapToggle(
              value: _basemap,
              onChanged: (b) => setState(() => _basemap = b),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomBar(
              selected: selected,
              attribution: _basemap.attribution,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: selected == null
                  ? null
                  : () => Navigator.of(context).pop(selected),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selected,
    required this.attribution,
    required this.onCancel,
    required this.onConfirm,
  });

  final MapCoordinate? selected;
  final String attribution;
  final VoidCallback onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                selected == null
                    ? 'Tap the map to drop a pin on the exact spot.'
                    : 'Selected: $selected',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: TravleTokens.space4),
              Text(
                attribution,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TravleTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      child: const Text('Use this location'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Form control that replaces raw latitude/longitude textboxes (constraint K). It
/// shows a read-only preview of the chosen point (or an empty placeholder), the
/// coordinate read-back, and a button that opens [showMapCoordinatePicker]. As a
/// [FormField] it participates in `Form.validate()` and renders its error inline.
class MapLocationField extends FormField<MapCoordinate> {
  MapLocationField({
    super.key,
    super.initialValue,
    required ValueChanged<MapCoordinate> onChanged,
    bool enabled = true,
    super.validator,
  }) : super(
          builder: (state) =>
              _build(state, onChanged: onChanged, enabled: enabled),
        );

  static Widget _build(
    FormFieldState<MapCoordinate> state, {
    required ValueChanged<MapCoordinate> onChanged,
    required bool enabled,
  }) {
    final context = state.context;
    final theme = Theme.of(context);
    final value = state.value;

    Future<void> pick() async {
      final result = await showMapCoordinatePicker(context, initial: value);
      if (result != null) {
        state.didChange(result);
        onChanged(result);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: theme.textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space4),
        Text(
          value == null
              ? 'Choose the exact spot on the map.'
              : 'Adjust the pin any time with “Change location”.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: TravleTokens.space16),
        if (value != null)
          TravleMapView(
            points: [MapPoint(latitude: value.latitude, longitude: value.longitude)],
            height: 170,
            showBasemapToggle: false,
          )
        else
          _Placeholder(hasError: state.hasError),
        if (value != null) ...[
          const SizedBox(height: TravleTokens.space8),
          Text(
            value.toString(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: TravleTokens.space12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: enabled ? pick : null,
            icon: Icon(value == null
                ? Icons.add_location_alt_outlined
                : Icons.edit_location_alt_outlined),
            label: Text(value == null ? 'Pick location on map' : 'Change location'),
          ),
        ),
        if (state.hasError) ...[
          const SizedBox(height: TravleTokens.space8),
          Text(
            state.errorText!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.hasError});

  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor =
        hasError ? theme.colorScheme.error : theme.colorScheme.outlineVariant;
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TravleTokens.radius),
        border: Border.all(color: borderColor),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: TravleTokens.space8),
            Text(
              'No location selected',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
