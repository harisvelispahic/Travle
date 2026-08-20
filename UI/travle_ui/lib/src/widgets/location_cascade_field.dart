import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';

import '../theme/tokens.dart';

/// How deep the [LocationCascadeField] chain goes.
enum LocationDepth {
  /// Country → Region. The selected value is a region id.
  region,

  /// Country → Region → City. The selected value is a city id.
  city,
}

/// The Country → Region (→ City) picker used wherever a screen needs a place from
/// the reference tables.
///
/// A flat "pick a city" dropdown cannot work here: the seeded geography holds
/// ~200 countries and 600+ cities, so a single page of options both buries the
/// city the user wants and leaves most of them unreachable altogether. Narrowing
/// by parent keeps every list short enough to page in one request and makes the
/// choice obvious.
///
/// Each level is a real [DropdownButtonFormField], so it takes part in the
/// enclosing [Form] and renders its validation message under its own control
/// (course UI rules). Children are disabled-with-reason until their parent is
/// chosen. Options come from the API — never a hardcoded list.
///
/// Owns its own providers rather than reading them from the widget tree, so the
/// design system stays free of a `provider` dependency (same approach as the
/// desktop reference registry's option loaders).
class LocationCascadeField extends StatefulWidget {
  const LocationCascadeField({
    super.key,
    this.depth = LocationDepth.city,
    this.initialCityId,
    this.initialRegionId,
    required this.onChanged,
    this.enabled = true,
    this.isRequired = true,
    this.countryLabel = 'Country',
    this.regionLabel = 'Region',
    this.cityLabel = 'City',
  });

  final LocationDepth depth;

  /// Prefill for [LocationDepth.city]: resolved up its region/country chain so all
  /// three dropdowns open on the saved values.
  final int? initialCityId;

  /// Prefill for [LocationDepth.region] (ignored when [depth] is
  /// [LocationDepth.city], which derives the region from [initialCityId]).
  final int? initialRegionId;

  /// Fires with the id of the deepest level whenever it changes — a city id for
  /// [LocationDepth.city], a region id for [LocationDepth.region] — and with null
  /// when a parent change clears it.
  final ValueChanged<int?> onChanged;

  final bool enabled;

  /// Whether the deepest level must be chosen for the form to validate.
  final bool isRequired;

  final String countryLabel;
  final String regionLabel;
  final String cityLabel;

  @override
  State<LocationCascadeField> createState() => _LocationCascadeFieldState();
}

class _LocationCascadeFieldState extends State<LocationCascadeField> {
  final _countryProvider = CountryProvider();
  final _regionProvider = RegionProvider();
  final _cityProvider = CityProvider();

  List<CountryResponse> _countries = [];
  List<RegionResponse> _regions = [];
  List<CityResponse> _cities = [];

  int? _countryId;
  int? _regionId;
  int? _cityId;

  bool _loading = true;
  bool _loadingRegions = false;
  bool _loadingCities = false;
  String? _loadError;

  bool get _wantsCity => widget.depth == LocationDepth.city;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _countryProvider.dispose();
    _regionProvider.dispose();
    _cityProvider.dispose();
    super.dispose();
  }

  /// Loads the countries and, when editing, walks the saved place back up its
  /// chain so every level opens on the stored value.
  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      int? countryId;
      int? regionId;
      int? cityId;
      var regions = <RegionResponse>[];
      var cities = <CityResponse>[];

      CityResponse? city;
      RegionResponse? region;

      if (_wantsCity && widget.initialCityId != null) {
        city = await _cityProvider.getById(widget.initialCityId!);
        region = await _regionProvider.getById(city.regionId);
        countryId = region.countryId;
        regionId = region.id;
        cityId = city.id;
      } else if (!_wantsCity && widget.initialRegionId != null) {
        region = await _regionProvider.getById(widget.initialRegionId!);
        countryId = region.countryId;
        regionId = region.id;
      }

      // Countries need every page (see CountryProvider.getAll); a region's cities
      // and a country's regions always fit one.
      final countries = await _countryProvider.getAll();
      if (countryId != null) {
        regions = (await _regionProvider.get(
          filter: {..._page(), 'countryId': countryId},
        )).items;
      }
      if (_wantsCity && regionId != null) {
        cities = (await _cityProvider.get(
          filter: {..._page(), 'regionId': regionId},
        )).items;
      }

      // Belt and braces: a prefilled value that somehow isn't in its list would
      // trip DropdownButton's "exactly one item with this value" assertion and take
      // the whole form down. We already hold the resolved rows, so splice them in.
      if (region != null && !regions.any((r) => r.id == region!.id)) {
        regions = [...regions, region];
      }
      if (city != null && !cities.any((c) => c.id == city!.id)) {
        cities = [...cities, city];
      }

      if (!mounted) return;
      setState(() {
        _countries = countries;
        _regions = regions;
        _cities = cities;
        _countryId =
            countries.any((c) => c.id == countryId) ? countryId : null;
        _regionId = regionId;
        _cityId = cityId;
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

  /// One page of alphabetically ordered options — enough for any single parent's
  /// children, which is exactly why the chain exists. (The country level is the
  /// exception and pages through everything; see [CountryProvider.getAll].)
  Map<String, dynamic> _page() =>
      {'pageSize': 100, 'sortBy': 'Name', 'includeTotalCount': false};

  Future<void> _onCountryChanged(int? id) async {
    setState(() {
      _countryId = id;
      _regionId = null;
      _cityId = null;
      _regions = [];
      _cities = [];
      _loadingRegions = id != null;
    });
    widget.onChanged(null);
    if (id == null) return;

    try {
      final regions =
          await _regionProvider.get(filter: {..._page(), 'countryId': id});
      if (!mounted) return;
      setState(() {
        _regions = regions.items;
        _loadingRegions = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRegions = false;
        _loadError = e.message;
      });
    }
  }

  Future<void> _onRegionChanged(int? id) async {
    setState(() {
      _regionId = id;
      _cityId = null;
      _cities = [];
      _loadingCities = _wantsCity && id != null;
    });
    widget.onChanged(_wantsCity ? null : id);
    if (!_wantsCity || id == null) return;

    try {
      final cities =
          await _cityProvider.get(filter: {..._page(), 'regionId': id});
      if (!mounted) return;
      setState(() {
        _cities = cities.items;
        _loadingCities = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCities = false;
        _loadError = e.message;
      });
    }
  }

  void _onCityChanged(int? id) {
    setState(() => _cityId = id);
    widget.onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: TravleTokens.space24),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_loadError != null && _countries.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: TravleTokens.space8),
          OutlinedButton.icon(
            onPressed: _bootstrap,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdown(
          label: widget.countryLabel,
          hint: 'Select a country',
          icon: Icons.public_outlined,
          value: _countryId,
          items: [for (final c in _countries) (c.id, c.name)],
          enabled: widget.enabled,
          onChanged: _onCountryChanged,
          // Not itself submitted — it only narrows what follows.
          validator: null,
        ),
        const SizedBox(height: TravleTokens.space16),
        _dropdown(
          // Re-keyed per country so the field is rebuilt from scratch when its
          // parent changes: a FormField only reads initialValue once, so without
          // this it would keep a selection that the reloaded items no longer
          // contain — which DropdownButton asserts on.
          key: ValueKey('region-$_countryId'),
          label: widget.regionLabel,
          hint: 'Select a region',
          icon: Icons.map_outlined,
          value: _regionId,
          items: [for (final r in _regions) (r.id, r.name)],
          enabled: widget.enabled && _countryId != null && !_loadingRegions,
          loading: _loadingRegions,
          helperText: _countryId == null ? 'Choose a country first' : null,
          onChanged: _onRegionChanged,
          validator: (widget.isRequired && !_wantsCity)
              ? (v) => v == null ? 'Please select a region' : null
              : null,
        ),
        if (_wantsCity) ...[
          const SizedBox(height: TravleTokens.space16),
          _dropdown(
            key: ValueKey('city-$_regionId'),
            label: widget.cityLabel,
            hint: 'Select a city',
            icon: Icons.location_city_outlined,
            value: _cityId,
            items: [for (final c in _cities) (c.id, c.name)],
            enabled: widget.enabled && _regionId != null && !_loadingCities,
            loading: _loadingCities,
            helperText: _regionId == null ? 'Choose a region first' : null,
            onChanged: _onCityChanged,
            validator: widget.isRequired
                ? (v) => v == null ? 'Please select a city' : null
                : null,
          ),
        ],
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String hint,
    required IconData icon,
    required int? value,
    required List<(int, String)> items,
    required bool enabled,
    required ValueChanged<int?> onChanged,
    required FormFieldValidator<int>? validator,
    Key? key,
    bool loading = false,
    String? helperText,
  }) {
    return DropdownButtonFormField<int>(
      key: key,
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon),
        suffixIcon: loading
            ? const Padding(
                padding: EdgeInsets.all(TravleTokens.space12),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      items: [
        for (final (id, name) in items)
          DropdownMenuItem(value: id, child: Text(name)),
      ],
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}
