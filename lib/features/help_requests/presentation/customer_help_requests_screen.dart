import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/workable_design.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/help_request.dart';
import 'customer_help_request_detail_screen.dart';
import 'generic_help_request_screen.dart';
import 'help_request_providers.dart';

class CustomerHelpRequestsScreen extends ConsumerStatefulWidget {
  const CustomerHelpRequestsScreen({super.key});

  static const routeName = '/customer/help-requests';

  @override
  ConsumerState<CustomerHelpRequestsScreen> createState() =>
      _CustomerHelpRequestsScreenState();
}

class _CustomerHelpRequestsScreenState
    extends ConsumerState<CustomerHelpRequestsScreen> {
  String _filter = 'active';

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(customerHelpRequestsProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('My Help Requests'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            Navigator.pushNamed(context, GenericHelpRequestScreen.routeName),
        icon: const Icon(Icons.add),
        label: const Text('Request help'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customerHelpRequestsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Your helping hand board',
              subtitle:
                  'Track pickup, delivery, urgent, elder support and general help requests from one place.',
              icon: Icons.handshake_outlined,
            ),
            const SizedBox(height: 16),
            _FilterBar(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 16),
            requests.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => WorkableSectionCard(
                child: Text(
                  'Unable to load help requests: $error',
                  style: const TextStyle(color: WorkableDesign.danger),
                ),
              ),
              data: (items) {
                final filtered = items.where(_matchesFilter).toList();
                if (filtered.isEmpty) {
                  return WorkableEmptyState(
                    icon: Icons.volunteer_activism_outlined,
                    title: _emptyTitle,
                    message: _emptyMessage,
                    actionLabel: 'Create help request',
                    onAction: () => Navigator.pushNamed(
                      context,
                      GenericHelpRequestScreen.routeName,
                    ),
                  );
                }
                return Column(
                  children: filtered
                      .map(
                        (request) => _HelpRequestListCard(
                          request: request,
                          onTap: () => _openDetails(request),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(HelpRequest request) {
    if (_filter == 'all') return true;
    if (_filter == 'history') return request.isClosed;
    return !request.isClosed;
  }

  String get _emptyTitle {
    switch (_filter) {
      case 'history':
        return 'No completed help requests';
      case 'all':
        return 'No help requests yet';
      default:
        return 'No active help requests';
    }
  }

  String get _emptyMessage {
    switch (_filter) {
      case 'history':
        return 'Completed and cancelled help requests will appear here.';
      case 'all':
        return 'Create a pickup, delivery, urgent or general help request when you need support.';
      default:
        return 'Active help requests will appear here after you create one.';
    }
  }

  void _openDetails(HelpRequest request) {
    Navigator.pushNamed(
      context,
      CustomerHelpRequestDetailScreen.routeName,
      arguments: {'requestId': request.id},
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = const [
      ('active', 'Active'),
      ('all', 'All'),
      ('history', 'History'),
    ];

    return WorkableSectionCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: filters.map((filter) {
          final isSelected = selected == filter.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(WorkableDesign.radius),
                onTap: () => onChanged(filter.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? WorkableDesign.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  ),
                  child: Text(
                    filter.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : WorkableDesign.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HelpRequestListCard extends StatelessWidget {
  const _HelpRequestListCard({required this.request, required this.onTap});

  final HelpRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        onTap: onTap,
        child: WorkableSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WorkableDesign.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request.requestType,
                          style: const TextStyle(
                            color: WorkableDesign.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  WorkableStatusPill(
                    label: _label(request.status),
                    color: _statusColor(request.status),
                  ),
                ],
              ),
              if (request.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  request.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              WorkableInfoRow(
                icon: Icons.schedule_outlined,
                text: request.timeLabel,
              ),
              const SizedBox(height: 7),
              WorkableInfoRow(
                icon: Icons.location_on_outlined,
                text: request.pickupAddress,
              ),
              const SizedBox(height: 7),
              WorkableInfoRow(
                icon: Icons.person_outline,
                text: request.workerId.isEmpty
                    ? 'Waiting for a worker'
                    : 'Worker: ${request.workerName}',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: WorkableStatusPill(
                      label: _label(request.paymentStatus),
                      color: _paymentColor(request.paymentStatus),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: WorkableDesign.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(String value) {
    if (value.trim().isEmpty) return 'Not Started';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'in_progress':
        return WorkableDesign.success;
      case 'completion_requested':
      case 'payment_due':
      case 'payment_under_review':
        return WorkableDesign.primary;
      case 'cancelled':
      case 'rejected':
        return WorkableDesign.danger;
      case 'completed':
      case 'paid':
        return WorkableDesign.success;
      default:
        return WorkableDesign.warning;
    }
  }

  Color _paymentColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'paid':
        return WorkableDesign.success;
      case 'cash_pending_confirmation':
      case 'payment_under_review':
      case 'customer_reported_paid':
        return WorkableDesign.warning;
      case 'payment_rejected':
        return WorkableDesign.danger;
      default:
        return WorkableDesign.primary;
    }
  }
}
