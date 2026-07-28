import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';

import '../widgets/review_moderation_list.dart';

/// The organizer's read-only view of the reviews across their own tours
/// (spec §2.3, `GET /TourReviews/my-tours`). Filterable by minimum rating; no
/// moderation actions (removal is admin-only) and only active reviews are shown.
class OrganizerReviewsScreen extends StatelessWidget {
  const OrganizerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReviewModerationList(
      targetNoun: 'tour',
      showStatusFilter: false,
      emptyMessage: 'No reviews on your tours yet.',
      fetch: (filter) async {
        final result =
            await context.read<TourReviewProvider>().forMyTours(filter: filter);
        return SearchResult<ReviewRow>()
          ..totalCount = result.totalCount
          ..items = result.items.map(ReviewRow.fromTour).toList();
      },
    );
  }
}
