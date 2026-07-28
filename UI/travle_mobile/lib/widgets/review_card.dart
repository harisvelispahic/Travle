import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';

/// One review in a list (destination or tour): author, rating, date, and comment.
/// When [isMine] is true it is labelled "Your review" and, if callbacks are given,
/// offers Edit / Remove actions under the comment.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.authorName,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.isMine = false,
    this.onEdit,
    this.onRemove,
  });

  final String authorName;
  final int rating;
  final DateTime createdAt;
  final String? comment;
  final bool isMine;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasComment = comment != null && comment!.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: TravleTokens.space8),
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isMine ? 'Your review' : authorName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formatDate(createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space4),
            RatingStars(value: rating.toDouble(), size: 16, showValue: false),
            if (hasComment) ...[
              const SizedBox(height: TravleTokens.space8),
              Text(comment!.trim(), style: theme.textTheme.bodyMedium),
            ],
            if (isMine && (onEdit != null || onRemove != null)) ...[
              const SizedBox(height: TravleTokens.space4),
              Row(
                children: [
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  if (onRemove != null)
                    TextButton.icon(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
