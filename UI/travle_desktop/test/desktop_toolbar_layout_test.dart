import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';
import 'package:travle_desktop/screens/reference/reference_crud_screen.dart';
import 'package:travle_desktop/screens/reference/reference_entity_config.dart';
import 'package:travle_desktop/widgets/crud_form_dialog.dart';
import 'package:travle_desktop/widgets/paginated_search_table.dart';
import 'package:travle_desktop/widgets/review_moderation_list.dart';

/// The management screens have to survive the smallest window the app allows
/// (`windowManager.setMinimumSize(1200, 720)` in main.dart), i.e. a content area of
/// 1200 − 248 (side nav) = 952 px. The two worst-case toolbars are pumped at exactly
/// that width here, and any render overflow fails the test:
///
/// * Cities — search field + Country + Region dropdowns + a New button;
/// * review moderation — Active/All + search field + rating filter + refresh.
///
/// The review test also covers the ordering contract: picking a minimum rating sorts
/// from that rating upwards, so the list visibly reacts to the filter.
void main() {
  const contentWidth = 952.0; // the shell's content area at the minimum width

  Future<void> pumpCities(WidgetTester tester,
      {required bool loading, double width = contentWidth}) async {
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTravleTheme(compact: true),
        home: Scaffold(
          body: ReferenceCrudScreen<CityResponse>(config: _cityConfig(loading)),
        ),
      ),
    );
    // One frame with the fetch still in flight (the spinner is on screen, which is
    // the widest the toolbar ever gets), then let the futures settle.
    await tester.pump();
    if (!loading) {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Cities toolbar fits the minimum window width while loading',
      (tester) async {
    await pumpCities(tester, loading: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cities toolbar fits the minimum window width once loaded',
      (tester) async {
    await pumpCities(tester, loading: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a roomy window keeps the preferred widths and a right-pinned New',
      (tester) async {
    const wide = 1400.0;
    await pumpCities(tester, loading: false, width: wide);
    expect(tester.takeException(), isNull);

    // The search field stops growing at its preferred width...
    expect(tester.getSize(find.byType(TextField)).width, 320);
    // ...and the leftover room does not push the New button off the right edge
    // (16 px is the table's own padding).
    expect(
      tester.getBottomRight(find.widgetWithText(FilledButton, 'New City')).dx,
      wide - 16,
    );
  });

  group('review moderation list', () {
    Future<List<Map<String, dynamic>>> pumpReviews(WidgetTester tester) async {
      final queries = <Map<String, dynamic>>[];
      tester.view.physicalSize = const Size(contentWidth, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTravleTheme(compact: true),
          home: Scaffold(
            body: ReviewModerationList(
              targetNoun: 'destination',
              onRemove: (_, _) async {},
              fetch: (filter) async {
                queries.add(filter);
                return SearchResult<ReviewRow>()
                  ..totalCount = 1
                  ..items = [
                    ReviewRow(
                      id: 1,
                      targetName: 'Stari most',
                      authorName: 'Amina Hodzic',
                      username: 'amina',
                      rating: 2,
                      comment: 'Crowded at noon.',
                      isRemoved: false,
                      createdAt: DateTime.utc(2026, 5, 1),
                    ),
                  ];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return queries;
    }

    testWidgets('toolbar fits the minimum window width', (tester) async {
      await pumpReviews(tester);
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(TextField, 'Search destinations or authors…'),
          findsOneWidget);
    });

    testWidgets('a minimum rating orders from that rating upwards',
        (tester) async {
      final queries = await pumpReviews(tester);
      // Unfiltered, the newest review still leads.
      expect(queries.single['sortBy'], 'CreatedAt desc');

      await tester.tap(find.text('Any rating'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2+ stars').last);
      await tester.pumpAndSettle();

      expect(queries.last['minRating'], 2);
      expect(queries.last['sortBy'], 'Rating asc, CreatedAt desc');
      expect(tester.takeException(), isNull);
    });
  });
}

/// A stand-in for the real Cities descriptor (see `reference_registry.dart`): same
/// title, columns, filter labels and delete rule, but served by a fake provider so
/// the test never touches the network.
ReferenceEntityConfig<CityResponse> _cityConfig(bool loading) =>
    ReferenceEntityConfig<CityResponse>(
      title: 'City',
      providerFactory: () => _FakeCityProvider(neverCompletes: loading),
      idOf: (c) => c.id,
      rowTitle: (c) => c.name,
      emptyMessage: 'No cities yet.',
      deleteBlockedReason: (c) => c.deleteBlockedReason,
      columns: [
        TableColumnSpec(label: 'Name', sortKey: 'Name', flex: 3, cell: (c) => c.name),
        TableColumnSpec(
            label: 'Region',
            sortKey: 'Region.Name',
            flex: 3,
            cell: (c) => c.regionName ?? '—'),
        TableColumnSpec(label: 'Time zone', flex: 3, cell: (c) => c.timeZoneId),
        TableColumnSpec(
            label: 'In use', flex: 1, numeric: true, cell: (c) => '${c.usageCount}'),
        TableColumnSpec(
            label: 'Added', sortKey: 'CreatedAt', flex: 2, cell: (c) => 'today'),
      ],
      filter: ReferenceFilter(
        queryKey: 'regionId',
        label: 'Region',
        optionsLoader: (_) async => const [
          CrudOption(1, 'Hercegovacko-neretvanski kanton'),
          CrudOption(2, 'Tuzlanski kanton'),
        ],
        grandparent: ReferenceFilterLevel(
          label: 'Country',
          optionsLoader: () async => const [
            CrudOption(1, 'Bosnia and Herzegovina'),
            CrudOption(2, 'Croatia'),
          ],
        ),
      ),
    );

class _FakeCityProvider extends BaseProvider<CityResponse> {
  _FakeCityProvider({required this.neverCompletes}) : super('Cities');

  /// Keeps the screen in its loading state, so the toolbar renders its spinner.
  final bool neverCompletes;

  @override
  CityResponse fromJson(Map<String, dynamic> json) =>
      CityResponse.fromJson(json);

  @override
  Future<SearchResult<CityResponse>> get({dynamic filter}) async {
    if (neverCompletes) {
      return Completer<SearchResult<CityResponse>>().future;
    }
    return SearchResult<CityResponse>()
      ..totalCount = 2
      ..items = [
        CityResponse(
          id: 1,
          name: 'Mostar',
          regionId: 1,
          regionName: 'Hercegovacko-neretvanski kanton',
          timeZoneId: 'Europe/Sarajevo',
          usageCount: 12,
          deleteBlockedReason: 'Cannot delete city: it is still referenced.',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        CityResponse(
          id: 2,
          name: 'Sarajevo',
          regionId: 1,
          regionName: 'Kanton Sarajevo',
          timeZoneId: 'Europe/Sarajevo',
          usageCount: 0,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];
  }
}
