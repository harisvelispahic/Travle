import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import 'destination_details_screen.dart';

/// Traveler-facing tour details. Fetches `GET /Tours/{id}`, showing the tour
/// header (cover, type, price per person, duration), the ordered itinerary (each
/// stop opens its destination details), and the upcoming departures with live
/// free-seat counts. Booking is added in Phase 5, so there is no pay/book action
/// here yet.
class TourDetailsScreen extends StatefulWidget {
  const TourDetailsScreen({
    super.key,
    required this.tourId,
    this.initialName,
  });

  final int tourId;

  /// Shown in the app bar while the detail loads, so the title isn't blank.
  final String? initialName;

  @override
  State<TourDetailsScreen> createState() => _TourDetailsScreenState();
}

class _TourDetailsScreenState extends State<TourDetailsScreen> {
  TourResponse? _tour;
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
      final tour = await context.read<TourProvider>().getDetail(widget.tourId);
      if (!mounted) return;
      setState(() {
        _tour = tour;
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

  void _openStop(TourDestinationRef stop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DestinationDetailsScreen(
          destinationId: stop.destinationId,
          initialName: stop.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _tour?.name ?? widget.initialName ?? 'Tour';
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

    final tour = _tour!;
    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        _Header(tour: tour),
        const SizedBox(height: TravleTokens.space24),
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        Text(tour.description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: TravleTokens.space24),
        Text('Itinerary', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        _Itinerary(stops: tour.destinations, onTapStop: _openStop),
        const SizedBox(height: TravleTokens.space24),
        Text('Upcoming departures',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: TravleTokens.space8),
        _Departures(schedules: tour.schedules ?? const []),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tour});

  final TourResponse tour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThumbnailImage(
          base64: tour.primaryThumbnail,
          width: 104,
          height: 104,
          placeholderIcon: Icons.tour_outlined,
        ),
        const SizedBox(width: TravleTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tour.name, style: theme.textTheme.titleLarge),
              if (tour.tourTypeName != null) ...[
                const SizedBox(height: TravleTokens.space4),
                Text(
                  tour.tourTypeName!,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
              const SizedBox(height: TravleTokens.space12),
              _IconLine(
                icon: Icons.payments_outlined,
                text: '${formatPrice(tour.pricePerPerson)} per person',
              ),
              const SizedBox(height: TravleTokens.space4),
              _IconLine(
                icon: Icons.schedule_outlined,
                text: formatDuration(tour.durationMinutes),
              ),
              const SizedBox(height: TravleTokens.space4),
              _IconLine(
                icon: Icons.place_outlined,
                text:
                    '${tour.destinationCount} ${tour.destinationCount == 1 ? 'stop' : 'stops'}',
                color: muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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

class _Itinerary extends StatelessWidget {
  const _Itinerary({required this.stops, required this.onTapStop});

  final List<TourDestinationRef> stops;
  final void Function(TourDestinationRef stop) onTapStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stops.isEmpty) {
      return Text('No stops listed.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    final ordered = [...stops]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      children: [
        for (var i = 0; i < ordered.length; i++)
          Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: TravleTokens.space8),
            child: InkWell(
              onTap: () => onTapStop(ordered[i]),
              child: Padding(
                padding: const EdgeInsets.all(TravleTokens.space12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                    ),
                    const SizedBox(width: TravleTokens.space12),
                    ThumbnailImage(
                      base64: ordered[i].thumbnail,
                      width: 52,
                      height: 52,
                      placeholderIcon: Icons.photo_outlined,
                    ),
                    const SizedBox(width: TravleTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ordered[i].name,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (ordered[i].cityName != null &&
                              ordered[i].cityName!.isNotEmpty) ...[
                            const SizedBox(height: TravleTokens.space4),
                            Text(
                              ordered[i].cityName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Departures extends StatelessWidget {
  const _Departures({required this.schedules});

  final List<TourScheduleResponse> schedules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (schedules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(TravleTokens.space16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(TravleTokens.radius),
        ),
        child: Text(
          'No upcoming departures for this tour yet.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      children: [
        for (final s in schedules)
          Card(
            margin: const EdgeInsets.only(bottom: TravleTokens.space8),
            child: Padding(
              padding: const EdgeInsets.all(TravleTokens.space16),
              child: Row(
                children: [
                  Icon(Icons.event_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: TravleTokens.space12),
                  Expanded(
                    child: Text(
                      formatScheduleRange(s.startsAt, s.endsAt),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  _SeatsPill(freeSeats: s.freeSeats, capacity: s.capacity),
                ],
              ),
            ),
          ),
        const SizedBox(height: TravleTokens.space4),
        Row(
          children: [
            Icon(Icons.info_outline,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: TravleTokens.space8),
            Expanded(
              child: Text(
                'Booking will be available soon.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SeatsPill extends StatelessWidget {
  const _SeatsPill({required this.freeSeats, required this.capacity});

  final int freeSeats;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    if (freeSeats <= 0) {
      return const StatusPill(label: 'Sold out', tone: StatusTone.danger);
    }
    return StatusPill(
      label: '$freeSeats of $capacity free',
      tone: freeSeats <= 3 ? StatusTone.warning : StatusTone.success,
    );
  }
}
