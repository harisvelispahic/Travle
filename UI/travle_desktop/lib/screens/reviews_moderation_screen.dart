import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';

import '../widgets/review_moderation_list.dart';

/// Admin review moderation (spec §2.4): destination and tour reviews in two tabs,
/// each filterable by minimum rating and by status (Active / All). An active review
/// can be soft-removed with a mandatory reason, which notifies the author and
/// re-rolls the destination's average. Removed reviews are shown with their audit.
class ReviewsModerationScreen extends StatelessWidget {
  const ReviewsModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Material(
            child: TabBar(
              tabs: [
                Tab(text: 'Destination reviews'),
                Tab(text: 'Tour reviews'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ReviewModerationList(
                  targetNoun: 'destination',
                  emptyMessage: 'No destination reviews in this view.',
                  fetch: (filter) async {
                    final result = await context
                        .read<DestinationReviewProvider>()
                        .get(filter: filter);
                    return SearchResult<ReviewRow>()
                      ..totalCount = result.totalCount
                      ..items =
                          result.items.map(ReviewRow.fromDestination).toList();
                  },
                  onRemove: (id, reason) => context
                      .read<DestinationReviewProvider>()
                      .adminRemove(id, reason),
                ),
                ReviewModerationList(
                  targetNoun: 'tour',
                  emptyMessage: 'No tour reviews in this view.',
                  fetch: (filter) async {
                    final result = await context
                        .read<TourReviewProvider>()
                        .get(filter: filter);
                    return SearchResult<ReviewRow>()
                      ..totalCount = result.totalCount
                      ..items = result.items.map(ReviewRow.fromTour).toList();
                  },
                  onRemove: (id, reason) =>
                      context.read<TourReviewProvider>().adminRemove(id, reason),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
