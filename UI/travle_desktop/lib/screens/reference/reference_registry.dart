import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';

import '../../widgets/crud_form_dialog.dart';
import '../../widgets/paginated_search_table.dart';
import 'reference_crud_screen.dart';
import 'reference_entity_config.dart';

/// The ordered set of reference tables shown under the sidebar's "Reference
/// Data" group. Each module pairs a nav label/icon with the screen it opens —
/// one generic [ReferenceCrudScreen] specialised by a per-entity config below.
/// Kept in one file so every entity's wiring is scannable together.
List<ReferenceModule> buildReferenceModules() => [
      ReferenceModule(
        title: 'Countries',
        icon: Icons.public,
        builder: (_) => ReferenceCrudScreen<CountryResponse>(config: _country()),
      ),
      ReferenceModule(
        title: 'Regions',
        icon: Icons.map_outlined,
        builder: (_) => ReferenceCrudScreen<RegionResponse>(config: _region()),
      ),
      ReferenceModule(
        title: 'Cities',
        icon: Icons.location_city_outlined,
        builder: (_) => ReferenceCrudScreen<CityResponse>(config: _city()),
      ),
      ReferenceModule(
        title: 'Categories',
        icon: Icons.category_outlined,
        builder: (_) =>
            ReferenceCrudScreen<DestinationCategoryResponse>(config: _category()),
      ),
      ReferenceModule(
        title: 'Tour Types',
        icon: Icons.tour_outlined,
        builder: (_) => ReferenceCrudScreen<TourTypeResponse>(config: _tourType()),
      ),
      ReferenceModule(
        title: 'Tags',
        icon: Icons.sell_outlined,
        builder: (_) => ReferenceCrudScreen<TagResponse>(config: _tag()),
      ),
      ReferenceModule(
        title: 'Refund Tiers',
        icon: Icons.percent_outlined,
        builder: (_) =>
            ReferenceCrudScreen<RefundPolicyTierResponse>(config: _refundTier()),
      ),
      ReferenceModule(
        title: 'Booking Statuses',
        icon: Icons.flag_outlined,
        builder: (_) =>
            ReferenceCrudScreen<BookingStatusResponse>(config: _bookingStatus()),
      ),
    ];

// ── Shared helpers ──────────────────────────────────────────────────────────

/// Local calendar date (UTC → local, display only) for the "Added" column.
String _date(DateTime utc) {
  final d = utc.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Human description of a refund tier's cancellation window (no raw fields shown).
String _tierWindow(int min, int? max) {
  if (max == null) return '$min h or more before';
  if (min == 0) return 'Under $max h before';
  return '$min–$max h before';
}

Future<List<CrudOption>> _loadCountries() async {
  final result = await CountryProvider().get(
    filter: {'pageSize': 100, 'sortBy': 'Name', 'includeTotalCount': false},
  );
  return [for (final c in result.items) CrudOption(c.id, c.name)];
}

Future<List<CrudOption>> _loadRegions({int? countryId}) async {
  final filter = <String, dynamic>{
    'pageSize': 100,
    'sortBy': 'Name',
    'includeTotalCount': false,
  };
  if (countryId != null) filter['countryId'] = countryId;
  final result = await RegionProvider().get(filter: filter);
  return [
    for (final r in result.items)
      CrudOption(
        r.id,
        r.countryName == null ? r.name : '${r.name} · ${r.countryName}',
      ),
  ];
}

// ── Per-entity configs ──────────────────────────────────────────────────────

ReferenceEntityConfig<CountryResponse> _country() =>
    ReferenceEntityConfig<CountryResponse>(
      title: 'Country',
      providerFactory: CountryProvider.new,
      idOf: (c) => c.id,
      rowTitle: (c) => c.name,
      emptyMessage: 'No countries yet.',
      columns: [
        TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: (c) => c.name),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (c) => _date(c.createdAt)),
      ],
      formFields: const [
        CrudField(id: 'name', label: 'Name', kind: CrudFieldKind.text, maxLength: 100),
      ],
      formValues: (c) => {'name': c.name},
      toBody: (v) => {'name': v['name']},
    );

ReferenceEntityConfig<RegionResponse> _region() =>
    ReferenceEntityConfig<RegionResponse>(
      title: 'Region',
      providerFactory: RegionProvider.new,
      idOf: (r) => r.id,
      rowTitle: (r) => r.name,
      emptyMessage: 'No regions yet.',
      columns: [
        TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: (r) => r.name),
        TableColumnSpec(
            label: 'Country',
            sortKey: 'Country.Name',
            flex: 3,
            cell: (r) => r.countryName ?? '—'),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (r) => _date(r.createdAt)),
      ],
      filter: ReferenceFilter(
        queryKey: 'countryId',
        label: 'Country',
        optionsLoader: _loadCountries,
      ),
      formFields: [
        const CrudField(
            id: 'name', label: 'Name', kind: CrudFieldKind.text, maxLength: 100),
        CrudField(
          id: 'countryId',
          label: 'Country',
          kind: CrudFieldKind.dropdown,
          optionsLoader: (_) => _loadCountries(),
        ),
      ],
      formValues: (r) => {'name': r.name, 'countryId': r.countryId},
      toBody: (v) => {'name': v['name'], 'countryId': v['countryId']},
    );

ReferenceEntityConfig<CityResponse> _city() => ReferenceEntityConfig<CityResponse>(
      title: 'City',
      providerFactory: CityProvider.new,
      idOf: (c) => c.id,
      rowTitle: (c) => c.name,
      emptyMessage: 'No cities yet.',
      columns: [
        TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: (c) => c.name),
        TableColumnSpec(
            label: 'Region',
            sortKey: 'Region.Name',
            flex: 3,
            cell: (c) => c.regionName ?? '—'),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (c) => _date(c.createdAt)),
      ],
      filter: ReferenceFilter(
        queryKey: 'regionId',
        label: 'Region',
        optionsLoader: () => _loadRegions(),
      ),
      formFields: [
        const CrudField(
            id: 'name', label: 'Name', kind: CrudFieldKind.text, maxLength: 100),
        // A helper (not sent): narrows the Region list below via Country→Region chaining.
        CrudField(
          id: 'country',
          label: 'Country',
          kind: CrudFieldKind.dropdown,
          required: false,
          hint: 'Optional — narrows the region list',
          optionsLoader: (_) => _loadCountries(),
        ),
        CrudField(
          id: 'regionId',
          label: 'Region',
          kind: CrudFieldKind.dropdown,
          dependsOn: 'country',
          optionsLoader: (current) =>
              _loadRegions(countryId: current['country'] as int?),
        ),
      ],
      formValues: (c) => {'name': c.name, 'regionId': c.regionId},
      toBody: (v) => {'name': v['name'], 'regionId': v['regionId']},
    );

ReferenceEntityConfig<DestinationCategoryResponse> _category() =>
    ReferenceEntityConfig<DestinationCategoryResponse>(
      title: 'Category',
      providerFactory: DestinationCategoryProvider.new,
      idOf: (c) => c.id,
      rowTitle: (c) => c.name,
      emptyMessage: 'No categories yet.',
      columns: [
        TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: (c) => c.name),
        TableColumnSpec(
            label: 'Description',
            sortKey: 'Description',
            flex: 5,
            cell: (c) => c.description ?? '—'),
        TableColumnSpec(
            label: 'Image', flex: 1, cell: (c) => c.imageThumbnail == null ? '—' : 'Set'),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (c) => _date(c.createdAt)),
      ],
      formFields: const [
        CrudField(id: 'name', label: 'Name', kind: CrudFieldKind.text, maxLength: 100),
        CrudField(
          id: 'description',
          label: 'Description',
          kind: CrudFieldKind.multiline,
          required: false,
          maxLength: 150,
          maxLines: 3,
          helperText: 'Shown on the onboarding category card.',
        ),
        CrudField(
          id: 'image',
          label: 'Image',
          kind: CrudFieldKind.image,
          required: false,
          helperText: 'JPEG or PNG, up to 5 MB. A square illustration looks best.',
        ),
      ],
      formValues: (c) => {
        'name': c.name,
        'description': c.description,
        'image': c.imageThumbnail,
      },
      toBody: (v) {
        final body = <String, dynamic>{
          'name': v['name'],
          'description': v['description'],
        };
        final image = v['image'];
        if (image is CrudImageValue) {
          body['image'] = image.base64;
          body['imageContentType'] = image.contentType;
        }
        return body;
      },
    );

ReferenceEntityConfig<TourTypeResponse> _tourType() =>
    _simpleNamed<TourTypeResponse>(
      title: 'Tour Type',
      providerFactory: TourTypeProvider.new,
      idOf: (t) => t.id,
      name: (t) => t.name,
      createdAt: (t) => t.createdAt,
      emptyMessage: 'No tour types yet.',
    );

ReferenceEntityConfig<TagResponse> _tag() => _simpleNamed<TagResponse>(
      title: 'Tag',
      providerFactory: TagProvider.new,
      idOf: (t) => t.id,
      name: (t) => t.name,
      createdAt: (t) => t.createdAt,
      emptyMessage: 'No tags yet.',
    );

ReferenceEntityConfig<RefundPolicyTierResponse> _refundTier() =>
    ReferenceEntityConfig<RefundPolicyTierResponse>(
      title: 'Refund Tier',
      providerFactory: RefundPolicyTierProvider.new,
      idOf: (t) => t.id,
      rowTitle: (t) =>
          '${_tierWindow(t.hoursBeforeMin, t.hoursBeforeMax)} → ${t.percentage}%',
      searchHint: 'Filter by refund %…',
      emptyMessage: 'No refund tiers yet.',
      buildSearchQuery: (s) {
        final n = int.tryParse(s.trim());
        return n == null ? const {} : {'percentage': n};
      },
      columns: [
        TableColumnSpec(
            label: 'Cancellation window',
            sortKey: 'HoursBeforeMin',
            flex: 4,
            cell: (t) => _tierWindow(t.hoursBeforeMin, t.hoursBeforeMax)),
        TableColumnSpec(
            label: 'Refund',
            sortKey: 'Percentage',
            flex: 2,
            numeric: true,
            cell: (t) => '${t.percentage}%'),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (t) => _date(t.createdAt)),
      ],
      formFields: const [
        CrudField(
          id: 'hoursBeforeMin',
          label: 'From (hours)',
          kind: CrudFieldKind.integer,
          min: 0,
          helperText: 'Hours before the slot this tier starts at',
        ),
        CrudField(
          id: 'hoursBeforeMax',
          label: 'To (hours)',
          kind: CrudFieldKind.integer,
          required: false,
          min: 0,
          helperText: 'Leave blank for the open-ended top tier',
        ),
        CrudField(
          id: 'percentage',
          label: 'Refund %',
          kind: CrudFieldKind.integer,
          min: 0,
          max: 100,
        ),
      ],
      formValues: (t) => {
        'hoursBeforeMin': t.hoursBeforeMin,
        'hoursBeforeMax': t.hoursBeforeMax,
        'percentage': t.percentage,
      },
      toBody: (v) => {
        'hoursBeforeMin': v['hoursBeforeMin'],
        'hoursBeforeMax': v['hoursBeforeMax'],
        'percentage': v['percentage'],
      },
    );

ReferenceEntityConfig<BookingStatusResponse> _bookingStatus() =>
    ReferenceEntityConfig<BookingStatusResponse>(
      title: 'Booking Status',
      providerFactory: BookingStatusProvider.new,
      idOf: (b) => b.id,
      rowTitle: (b) => b.name,
      writable: false,
      emptyMessage: 'No booking statuses.',
      columns: [
        TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: (b) => b.name),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (b) => _date(b.createdAt)),
      ],
    );

/// Builds the common "just a Name" config shared by Categories, Tour Types, Tags.
ReferenceEntityConfig<T> _simpleNamed<T>({
  required String title,
  required BaseProvider<T> Function() providerFactory,
  required int Function(T) idOf,
  required String Function(T) name,
  required DateTime Function(T) createdAt,
  required String emptyMessage,
}) {
  return ReferenceEntityConfig<T>(
    title: title,
    providerFactory: providerFactory,
    idOf: idOf,
    rowTitle: name,
    emptyMessage: emptyMessage,
    columns: [
      TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: name),
      TableColumnSpec(
          label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (row) => _date(createdAt(row))),
    ],
    formFields: const [
      CrudField(id: 'name', label: 'Name', kind: CrudFieldKind.text, maxLength: 100),
    ],
    formValues: (row) => {'name': name(row)},
    toBody: (v) => {'name': v['name']},
  );
}
