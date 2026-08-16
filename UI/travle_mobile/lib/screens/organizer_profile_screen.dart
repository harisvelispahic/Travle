import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import '../widgets/tour_card.dart';
import 'tour_details_screen.dart';

/// Public profile of a tour organizer (`GET /Users/{id}/organizer-profile`),
/// opened from a tour's "Offered by" row while a traveler is deciding whether to
/// book. Shows who runs the tour — name, home city, how long they've been on
/// Travle, a rating aggregated across all their tour reviews, and a preview of
/// their best-rated tours — without exposing any contact details.
class OrganizerProfileScreen extends StatefulWidget {
  const OrganizerProfileScreen({
    super.key,
    required this.organizerId,
    this.initialName,
  });

  final int organizerId;

  /// Shown in the app bar while the profile loads, so the title isn't blank.
  final String? initialName;

  @override
  State<OrganizerProfileScreen> createState() => _OrganizerProfileScreenState();
}

class _OrganizerProfileScreenState extends State<OrganizerProfileScreen> {
  OrganizerProfileResponse? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile =
          await context.read<UserProvider>().organizerProfile(widget.organizerId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  void _openTour(TourResponse tour) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TourDetailsScreen(tourId: tour.id, initialName: tour.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _profile?.fullName ?? widget.initialName ?? 'Organizer';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        _ProfileHeader(profile: profile),
        const SizedBox(height: TravleTokens.space24),
        _StatsStrip(profile: profile),
        const SizedBox(height: TravleTokens.space24),
        Text('Top tours', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space12),
        if (profile.topTours.isEmpty)
          const EmptyState(
            icon: Icons.tour_outlined,
            message: 'No tours yet',
            hint: 'This organizer hasn’t published any tours right now.',
          )
        else
          for (final tour in profile.topTours) ...[
            TourCard(tour: tour, onTap: () => _openTour(tour)),
            const SizedBox(height: TravleTokens.space8),
          ],
      ],
    );
  }
}

/// Avatar, name, home city, member-since, and the aggregate rating.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final OrganizerProfileResponse profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // radius == size/2 renders the square thumbnail as a circular avatar.
        ThumbnailImage(
          base64: profile.profileImageThumbnail,
          width: 88,
          height: 88,
          radius: 44,
          placeholderIcon: Icons.person_outline,
        ),
        const SizedBox(width: TravleTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.fullName, style: theme.textTheme.titleLarge),
              if (profile.cityName != null && profile.cityName!.isNotEmpty) ...[
                const SizedBox(height: TravleTokens.space4),
                _IconLine(
                  icon: Icons.place_outlined,
                  text: profile.cityName!,
                  color: muted,
                ),
              ],
              const SizedBox(height: TravleTokens.space4),
              _IconLine(
                icon: Icons.event_available_outlined,
                text: 'On Travle since ${formatDate(profile.memberSince)}',
                color: muted,
              ),
              const SizedBox(height: TravleTokens.space8),
              RatingStars(
                value: profile.averageRating,
                count: profile.reviewCount,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A two-cell strip summarizing the organizer: number of tours and the average
/// rating across their reviews.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.profile});

  final OrganizerProfileResponse profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.tour_outlined,
            value: '${profile.tourCount}',
            label: profile.tourCount == 1 ? 'Tour' : 'Tours',
          ),
        ),
        const SizedBox(width: TravleTokens.space12),
        Expanded(
          child: _StatTile(
            icon: Icons.star_rounded,
            value: profile.reviewCount > 0
                ? profile.averageRating.toStringAsFixed(1)
                : '—',
            label: profile.reviewCount == 1 ? 'review' : 'reviews',
            secondary: '${profile.reviewCount}',
          ),
        ),
      ],
    );
  }
}

/// A rounded surface tile holding one headline metric.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.secondary,
  });

  final IconData icon;
  final String value;
  final String label;

  /// Optional smaller figure shown under the label (e.g. the review count behind
  /// an average rating).
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: TravleTokens.space8),
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: TravleTokens.space4),
          Text(
            secondary != null ? '$secondary $label' : label,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// An icon followed by a single line of muted text.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: TravleTokens.space8),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: c)),
        ),
      ],
    );
  }
}
