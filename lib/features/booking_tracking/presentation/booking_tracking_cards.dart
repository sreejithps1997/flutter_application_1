import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../domain/booking_tracking_status.dart';
import 'booking_tracking_providers.dart';

class WorkerLiveTrackingCard extends ConsumerStatefulWidget {
  const WorkerLiveTrackingCard({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<WorkerLiveTrackingCard> createState() =>
      _WorkerLiveTrackingCardState();
}

class _WorkerLiveTrackingCardState
    extends ConsumerState<WorkerLiveTrackingCard> {
  Timer? _timer;
  bool _busy = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _share({bool showSuccess = true}) async {
    if (_busy && showSuccess) return;
    if (showSuccess) setState(() => _busy = true);
    try {
      await ref
          .read(bookingTrackingRepositoryProvider)
          .updateWorkerLiveLocation(widget.bookingId);
      if (!mounted) return;
      if (showSuccess) _showSnack('Live location shared with the customer.');
    } catch (error) {
      _timer?.cancel();
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted && showSuccess) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    await _share();
    if (!mounted) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _share(showSuccess: false);
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      await ref
          .read(bookingTrackingRepositoryProvider)
          .stopWorkerLiveLocation(widget.bookingId);
      if (!mounted) return;
      _showSnack('Live location sharing stopped.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openServiceLocation(BookingTrackingStatus tracking) async {
    try {
      await ref
          .read(bookingTrackingRepositoryProvider)
          .openServiceLocation(tracking);
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(bookingTrackingStatusProvider(widget.bookingId));
    return tracking.when(
      loading: () => const WorkableSectionCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => WorkableSectionCard(
        child: Text(
          'Unable to load tracking: $error',
          style: const TextStyle(color: WorkableDesign.danger),
        ),
      ),
      data: (status) => WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TrackingTitle(title: 'Live arrival tracking'),
            const SizedBox(height: 10),
            WorkableInfoRow(
              icon: status.isSharing
                  ? LucideIcons.navigation
                  : LucideIcons.mapPin,
              text: status.isSharing
                  ? status.isStale
                        ? 'Location sharing is active, but the last update is delayed.'
                        : 'Customer can see your latest arrival status.'
                  : 'Share your location while travelling to the customer.',
            ),
            _TrackingDetails(status: status),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: status.isSharing
                      ? OutlinedButton.icon(
                          onPressed: _busy ? null : _stop,
                          icon: const Icon(LucideIcons.mapPinOff, size: 18),
                          label: Text(_busy ? 'Updating...' : 'Stop Sharing'),
                        )
                      : FilledButton.icon(
                          onPressed: _busy ? null : _start,
                          icon: const Icon(LucideIcons.navigation, size: 18),
                          label: Text(_busy ? 'Sharing...' : 'Share Location'),
                        ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Open service location',
                  onPressed: () => _openServiceLocation(status),
                  icon: const Icon(LucideIcons.map),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? WorkableDesign.danger
            : WorkableDesign.success,
      ),
    );
  }
}

class CustomerArrivalTrackingCard extends ConsumerWidget {
  const CustomerArrivalTrackingCard({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(bookingTrackingStatusProvider(bookingId));
    return tracking.when(
      loading: () => const WorkableSectionCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) => WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: WorkableDesign.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  ),
                  child: Icon(
                    status.isSharing
                        ? LucideIcons.navigation
                        : LucideIcons.mapPin,
                    color: WorkableDesign.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.customerTitle,
                        style: const TextStyle(
                          color: WorkableDesign.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.customerMessage,
                        style: const TextStyle(
                          color: WorkableDesign.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _TrackingDetails(status: status),
            if (status.workerLocation != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref
                          .read(bookingTrackingRepositoryProvider)
                          .openWorkerLocation(status);
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_friendlyError(error)),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: WorkableDesign.danger,
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.map, size: 18),
                  label: const Text('Open in Maps'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackingTitle extends StatelessWidget {
  const _TrackingTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: WorkableDesign.ink,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TrackingDetails extends StatelessWidget {
  const _TrackingDetails({required this.status});

  final BookingTrackingStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (status.updatedAt != null)
          WorkableInfoRow(
            icon: LucideIcons.clock,
            text: 'Last update: ${_formatDateTime(status.updatedAt!)}',
          ),
        if (status.distanceToServiceMeters != null)
          WorkableInfoRow(
            icon: LucideIcons.mapPin,
            text:
                'Distance to service location: ${_formatDistance(status.distanceToServiceMeters!)}',
          ),
        if (status.accuracyMeters != null)
          WorkableInfoRow(
            icon: LucideIcons.crosshair,
            text:
                'GPS accuracy: ${status.accuracyMeters!.toStringAsFixed(0)} m',
          ),
      ],
    );
  }
}

String _formatDateTime(DateTime value) {
  final hour = value.hour > 12
      ? value.hour - 12
      : value.hour == 0
      ? 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.day}/${value.month}/${value.year} $hour:$minute $period';
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _friendlyError(Object error) {
  final text = error.toString().replaceFirst('Bad state: ', '').trim();
  return text.isEmpty ? 'Unable to update tracking.' : text;
}
