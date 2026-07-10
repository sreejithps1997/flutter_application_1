import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'customer_booking_detail_screen.dart';

class OngoingServicesScreen extends StatefulWidget {
  static const routeName = '/ongoing-services';

  const OngoingServicesScreen({super.key});

  @override
  State<OngoingServicesScreen> createState() => _OngoingServicesScreenState();
}

class _OngoingServicesScreenState extends State<OngoingServicesScreen> {
  String _activeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Ongoing Services')),
      body: currentUserId == null
          ? const WorkableEmptyState(
              icon: LucideIcons.userX,
              title: 'Sign in required',
              message: 'Login again to view active services.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return WorkableEmptyState(
                    icon: LucideIcons.alertTriangle,
                    title: 'Unable to load services',
                    message: snapshot.error.toString(),
                  );
                }

                final bookings =
                    (snapshot.data?.docs ?? [])
                        .map((doc) => _OngoingBooking(doc.id, doc.data()))
                        .where((booking) => booking.isActive)
                        .toList()
                      ..sort((a, b) => a.sortDate.compareTo(b.sortDate));

                final visibleBookings = bookings.where(_matchesFilter).toList();

                return ListView(
                  padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                  children: [
                    const WorkablePageHeader(
                      title: 'Track live services',
                      subtitle:
                          'Follow accepted, in-progress, completion and payment-stage bookings.',
                      icon: LucideIcons.activity,
                    ),
                    const SizedBox(height: 16),
                    _buildStats(bookings),
                    const SizedBox(height: 16),
                    _buildFilters(),
                    const SizedBox(height: 12),
                    if (visibleBookings.isEmpty)
                      WorkableEmptyState(
                        icon: LucideIcons.briefcase,
                        title: bookings.isEmpty
                            ? 'No ongoing services'
                            : 'No services in this filter',
                        message:
                            'Active bookings will appear here after a worker accepts your request.',
                        actionLabel: 'Book a Service',
                        onAction: () =>
                            Navigator.pushNamed(context, '/book-service'),
                      )
                    else
                      ...visibleBookings.map(_buildBookingCard),
                  ],
                );
              },
            ),
    );
  }

  bool _matchesFilter(_OngoingBooking booking) {
    switch (_activeFilter) {
      case 'Today':
        final today = DateTime.now();
        final date = booking.sortDate;
        return date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
      case 'Action':
        return booking.needsAction;
      default:
        return true;
    }
  }

  Widget _buildStats(List<_OngoingBooking> bookings) {
    final inProgress = bookings.where((booking) {
      return booking.status == 'in_progress';
    }).length;
    final actionNeeded = bookings
        .where((booking) => booking.needsAction)
        .length;

    return Row(
      children: [
        _StatCard(
          value: bookings.length.toString(),
          label: 'Active',
          color: WorkableDesign.primary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: inProgress.toString(),
          label: 'In Progress',
          color: WorkableDesign.accent,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: actionNeeded.toString(),
          label: 'Need Action',
          color: WorkableDesign.warning,
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Today', 'Action'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final selected = _activeFilter == filter;
        return FilterChip(
          label: Text(filter),
          selected: selected,
          onSelected: (_) => setState(() => _activeFilter = filter),
          selectedColor: WorkableDesign.primary.withValues(alpha: 0.12),
          checkmarkColor: WorkableDesign.primary,
          labelStyle: TextStyle(
            color: selected ? WorkableDesign.primary : WorkableDesign.muted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBookingCard(_OngoingBooking booking) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.service,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                WorkableStatusPill(
                  label: booking.statusLabel,
                  color: booking.statusColor,
                  icon: booking.statusIcon,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: booking.progress,
              minHeight: 7,
              backgroundColor: WorkableDesign.border,
              valueColor: AlwaysStoppedAnimation<Color>(booking.statusColor),
            ),
            const SizedBox(height: 12),
            WorkableInfoRow(
              icon: LucideIcons.user,
              text: 'Worker: ${booking.workerName}',
            ),
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: LucideIcons.clock,
              text: '${booking.preferredDate} ${booking.preferredTime}'.trim(),
            ),
            const SizedBox(height: 8),
            WorkableInfoRow(icon: LucideIcons.mapPin, text: booking.address),
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: LucideIcons.wallet,
              text: 'Payment: ${booking.paymentStatusLabel}',
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerBookingDetailScreen(
                        booking: {'id': booking.id, ...booking.data},
                      ),
                    ),
                  );
                },
                icon: const Icon(LucideIcons.externalLink),
                label: const Text('Open Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: WorkableSectionCard(
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: WorkableDesign.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OngoingBooking {
  const _OngoingBooking(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  String get status => _text(['status'], 'pending').toLowerCase();
  String get paymentStatus => _text(['paymentStatus'], '').toLowerCase();
  String get service => _text(['service', 'serviceType', 'issue'], 'Service');
  String get workerName => _text(['workerName'], 'Worker');
  String get address => _text(['address'], 'Address not available');
  String get preferredDate => _text(['preferredDate'], '');
  String get preferredTime => _text(['preferredTime'], '');

  bool get isActive {
    const active = {
      'accepted',
      'confirmed',
      'in_progress',
      'completion_requested',
      'payment_due',
      'payment_initiated',
      'payment_under_review',
      'reschedule_requested',
    };
    return active.contains(status) ||
        paymentStatus == 'cash_pending_confirmation' ||
        paymentStatus == 'customer_reported_paid';
  }

  bool get needsAction {
    return status == 'completion_requested' ||
        status == 'payment_due' ||
        paymentStatus == 'rejected' ||
        paymentStatus == 'payment_rejected';
  }

  double get progress {
    switch (status) {
      case 'accepted':
      case 'confirmed':
        return 0.28;
      case 'in_progress':
        return 0.48;
      case 'completion_requested':
        return 0.68;
      case 'payment_due':
      case 'payment_initiated':
      case 'payment_under_review':
        return 0.84;
      case 'completed':
      case 'paid':
        return 1;
      default:
        return 0.18;
    }
  }

  String get statusLabel => _label(status);
  String get paymentStatusLabel {
    if (paymentStatus.isEmpty) return 'Not started';
    return _label(paymentStatus);
  }

  Color get statusColor {
    switch (status) {
      case 'confirmed':
      case 'accepted':
        return WorkableDesign.primary;
      case 'in_progress':
        return WorkableDesign.accent;
      case 'completion_requested':
      case 'reschedule_requested':
      case 'payment_due':
      case 'payment_under_review':
        return WorkableDesign.warning;
      default:
        return WorkableDesign.muted;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'in_progress':
        return LucideIcons.activity;
      case 'completion_requested':
      case 'reschedule_requested':
        return LucideIcons.clock;
      case 'payment_due':
      case 'payment_under_review':
        return LucideIcons.wallet;
      default:
        return LucideIcons.briefcase;
    }
  }

  DateTime get sortDate {
    final value = data['preferredDate'];
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      final parsedIso = DateTime.tryParse(value);
      if (parsedIso != null) return parsedIso;
      final parts = value.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return DateTime(2100);
  }

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  String _label(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
