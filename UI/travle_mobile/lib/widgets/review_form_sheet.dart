import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

/// What the review form produced: a required 1–5 rating and an optional comment.
class ReviewDraft {
  const ReviewDraft(this.rating, this.comment);

  final int rating;
  final String? comment;
}

/// Bottom sheet to write or edit a review — a required 1–5 star rating and an
/// optional comment (≤1000 chars). Returns a [ReviewDraft] on submit, or null when
/// dismissed. The caller performs the API call so it can show meaningful feedback.
class ReviewFormSheet extends StatefulWidget {
  const ReviewFormSheet({
    super.key,
    required this.title,
    this.initialRating = 0,
    this.initialComment,
    this.submitLabel = 'Submit review',
  });

  final String title;
  final int initialRating;
  final String? initialComment;
  final String submitLabel;

  /// Opens the sheet and resolves to the composed [ReviewDraft] (or null).
  static Future<ReviewDraft?> show(
    BuildContext context, {
    required String title,
    int initialRating = 0,
    String? initialComment,
    String submitLabel = 'Submit review',
  }) {
    return showModalBottomSheet<ReviewDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReviewFormSheet(
        title: title,
        initialRating: initialRating,
        initialComment: initialComment,
        submitLabel: submitLabel,
      ),
    );
  }

  @override
  State<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<ReviewFormSheet> {
  late int _rating = widget.initialRating;
  late final TextEditingController _comment =
      TextEditingController(text: widget.initialComment ?? '');
  bool _submitted = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    if (_rating < 1) return; // rating is required
    final text = _comment.text.trim();
    Navigator.of(context).pop(ReviewDraft(_rating, text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratingError = _submitted && _rating < 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: TravleTokens.space24,
          right: TravleTokens.space24,
          top: TravleTokens.space8,
          bottom:
              MediaQuery.of(context).viewInsets.bottom + TravleTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: TravleTokens.space16),
            Text('Your rating', style: theme.textTheme.titleSmall),
            const SizedBox(height: TravleTokens.space4),
            RatingInput(
              value: _rating,
              onChanged: (v) => setState(() => _rating = v),
            ),
            // Validation message under the control (never inside it) — course §4.
            if (ratingError) ...[
              const SizedBox(height: TravleTokens.space4),
              Text(
                'Please select a rating from 1 to 5 stars.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: TravleTokens.space16),
            TravleTextField(
              controller: _comment,
              label: 'Comment (optional)',
              hint: 'Share what you liked…',
              minLines: 3,
              maxLines: 4,
              maxLength: 1000,
            ),
            const SizedBox(height: TravleTokens.space8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(widget.submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
