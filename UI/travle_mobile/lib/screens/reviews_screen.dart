import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../widgets/review_card.dart';

/// One row of [ReviewsScreen], flattened from either review DTO so the screen can
/// serve destinations and tours alike (the two responses carry the same fields
/// under different types).
class ReviewListEntry {
  const ReviewListEntry({
    required this.userId,
    required this.authorName,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final int userId;
  final String authorName;
  final int rating;
  final DateTime createdAt;
  final String? comment;
}

/// One page of reviews plus the total, as returned by a [ReviewsScreen] fetcher.
typedef ReviewPage = ({List<ReviewListEntry> items, int? totalCount});

/// The full, infinitely-scrolled review list behind a detail page's "Show all
/// reviews" button.
///
/// A detail page shows only the newest handful inline — a long review list buried
/// in the middle of a destination's page pushes everything below it out of reach —
/// so the rest live here, on their own screen, where scrolling them is the point.
/// Read-only: writing or editing your own review stays on the detail page, next to
/// the rating it belongs to.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.title, required this.fetch});

  final String title;

  /// Fetches one page (1-based) of `pageSize` reviews, newest first.
  final Future<ReviewPage> Function(int page, int pageSize) fetch;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();

  final List<ReviewListEntry> _items = [];
  int _page = 1;
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetch(1, _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _totalCount = result.totalCount ?? result.items.length;
        _page = 1;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_items.length >= _totalCount) return;

    setState(() => _loadingMore = true);
    try {
      final result = await widget.fetch(_page + 1, _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _totalCount = result.totalCount ?? _totalCount;
        _page += 1;
        _loadingMore = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackbars.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _totalCount > 0 ? '${widget.title} ($_totalCount)' : widget.title,
        ),
      ),
      body: SafeArea(child: _buildBody(Theme.of(context))),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.rate_review_outlined,
        message: 'No reviews yet',
      );
    }

    final currentUserId = context.read<AuthProvider>().userId;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(TravleTokens.space16),
        // One trailing slot for the next-page spinner.
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(TravleTokens.space16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final review = _items[i];
          return ReviewCard(
            authorName: review.authorName,
            rating: review.rating,
            createdAt: review.createdAt,
            comment: review.comment,
            isMine: review.userId == currentUserId,
          );
        },
      ),
    );
  }
}
