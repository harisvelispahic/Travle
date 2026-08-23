import 'package:flutter/widgets.dart';
import 'package:travle_core/travle_core.dart';

import '../../widgets/crud_form_dialog.dart';
import '../../widgets/paginated_search_table.dart';

/// A parent filter shown above a reference table (e.g. filter Regions by Country,
/// Cities by Region). The chosen option's value is added to the list query under
/// [queryKey].
class ReferenceFilter {
  const ReferenceFilter({
    required this.queryKey,
    required this.label,
    required this.optionsLoader,
    this.grandparent,
  });

  /// Query parameter the selected value is sent as (e.g. `countryId`).
  final String queryKey;

  /// Label for the "All …" dropdown (e.g. `Country`).
  final String label;

  /// Loads the selectable parent options, narrowed by the [grandparent]'s current
  /// selection when there is one (null = unnarrowed).
  final Future<List<CrudOption>> Function(Object? grandparentValue) optionsLoader;

  /// Optional level above this one, rendered to its left. Picking it reloads this
  /// filter's options and clears its selection; its own value is never sent to the
  /// API — it exists only to keep this list short (Cities: Country ⇒ Region).
  final ReferenceFilterLevel? grandparent;
}

/// The narrowing-only level above a [ReferenceFilter].
class ReferenceFilterLevel {
  const ReferenceFilterLevel({required this.label, required this.optionsLoader});

  final String label;
  final Future<List<CrudOption>> Function() optionsLoader;
}

/// Everything the generic [ReferenceCrudScreen] needs to render and manage one
/// reference entity: its provider, table columns, search/filter behaviour, and
/// (when [writable]) its create/edit form and delete rules. Keeping this as a
/// per-entity descriptor is what lets one screen serve all eight tables.
class ReferenceEntityConfig<T> {
  const ReferenceEntityConfig({
    required this.title,
    required this.columns,
    required this.rowTitle,
    required this.idOf,
    required this.providerFactory,
    this.writable = true,
    this.searchHint = 'Search by name…',
    this.emptyMessage = 'No records yet.',
    this.emptyHint,
    this.buildSearchQuery,
    this.filter,
    this.formFields = const [],
    this.formValues,
    this.toBody,
    this.deleteBlockedReason,
  });

  final String title;
  final List<TableColumnSpec<T>> columns;

  /// A human label for a row, used in confirmation/snackbar copy (never an id).
  final String Function(T row) rowTitle;

  /// The row's primary key — used for update/delete calls, never shown.
  final int Function(T row) idOf;

  /// Builds a fresh data-access provider for this entity.
  final BaseProvider<T> Function() providerFactory;

  /// When false the table is view-only (no New/Edit/Delete) — e.g. Booking Statuses.
  final bool writable;

  final String searchHint;
  final String emptyMessage;
  final String? emptyHint;

  /// Maps the search box text to query params. Defaults to a `name` contains
  /// filter; entities without a name (e.g. tiers) override it.
  final Map<String, dynamic> Function(String search)? buildSearchQuery;

  /// Optional parent dropdown filter shown beside the search box.
  final ReferenceFilter? filter;

  /// Fields for the create/edit form (empty when [writable] is false).
  final List<CrudField> formFields;

  /// Seeds the form when editing an existing [row] (field id → current value).
  final Map<String, Object?> Function(T row)? formValues;

  /// Builds the API request body from the form's collected [values].
  final Map<String, dynamic> Function(Map<String, Object?> values)? toBody;

  /// Why a given row cannot be deleted (null = it can). Supplied by the API as
  /// `deleteBlockedReason`, so Delete renders *disabled with the reason* instead
  /// of only failing on click (course §6: unavailable actions explain themselves).
  final String? Function(T row)? deleteBlockedReason;

  Map<String, dynamic> searchQueryFor(String search) =>
      (buildSearchQuery ?? _defaultNameSearch)(search);
}

Map<String, dynamic> _defaultNameSearch(String search) =>
    search.isEmpty ? const {} : {'name': search};

/// A nav-facing entry for a reference module: the sidebar label/icon plus the
/// screen it opens. Non-generic so the ordered registry can hold every entity in
/// one list regardless of its row type.
class ReferenceModule {
  const ReferenceModule({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}
