import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/workable_design.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/help_request.dart';
import 'help_request_providers.dart';
import 'worker_help_request_detail_screen.dart';

class WorkerHelpRequestsScreen extends ConsumerStatefulWidget {
  const WorkerHelpRequestsScreen({super.key});

  static const routeName = '/worker/help-requests';

  @override
  ConsumerState<WorkerHelpRequestsScreen> createState() =>
      _WorkerHelpRequestsScreenState();
}

class _WorkerHelpRequestsScreenState
    extends ConsumerState<WorkerHelpRequestsScreen> {
  String? _acceptingId;

  @override
  Widget build(BuildContext context) {
    final openRequests = ref.watch(openHelpRequestsProvider);
    final myRequests = ref.watch(workerHelpRequestsProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Help Requests'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(openHelpRequestsProvider);
          ref.invalidate(workerHelpRequestsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Open local help',
              subtitle:
                  'Accept pickup, delivery, urgent and general help requests near your working area.',
              icon: Icons.volunteer_activism_outlined,
            ),
            const SizedBox(height: 18),
            _AsyncSection(
              title: 'New Help Requests',
              subtitle: 'Fast response improves customer trust.',
              value: openRequests,
              emptyTitle: 'No open help requests',
              emptyMessage:
                  'When customers ask for general help, pickup, delivery or urgent assistance, it will appear here.',
              itemBuilder: (request) => _HelpRequestCard(
                request: request,
                action: _acceptingId == request.id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openDetails(request),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Details'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _accept(request),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Accept'),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            _AsyncSection(
              title: 'My Help Jobs',
              subtitle: 'Requests you accepted and still need to complete.',
              value: myRequests,
              emptyTitle: 'No active help jobs',
              emptyMessage:
                  'Accepted help requests will stay here until the flow moves to completed or cancelled.',
              itemBuilder: (request) => _HelpRequestCard(
                request: request,
                action: OutlinedButton.icon(
                  onPressed: () => _openDetails(request),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(request.status.replaceAll('_', ' ')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _accept(HelpRequest request) async {
    setState(() => _acceptingId = request.id);
    try {
      await ref
          .read(helpRequestRepositoryProvider)
          .acceptHelpRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Help request accepted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  void _openDetails(HelpRequest request) {
    Navigator.pushNamed(
      context,
      WorkerHelpRequestDetailScreen.routeName,
      arguments: {'requestId': request.id},
    );
  }
}

class _AsyncSection extends StatelessWidget {
  const _AsyncSection({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  final String title;
  final String subtitle;
  final AsyncValue<List<HelpRequest>> value;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(HelpRequest request) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    title,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: WorkableDesign.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            value.maybeWhen(
              data: (items) => WorkableStatusPill(
                label: '${items.length}',
                color: WorkableDesign.primary,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        value.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => WorkableSectionCard(
            child: Text(
              'Unable to load requests: $error',
              style: const TextStyle(color: WorkableDesign.danger),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return WorkableEmptyState(
                icon: Icons.inbox_outlined,
                title: emptyTitle,
                message: emptyMessage,
              );
            }
            return Column(children: items.map(itemBuilder).toList());
          },
        ),
      ],
    );
  }
}

class _HelpRequestCard extends StatelessWidget {
  const _HelpRequestCard({required this.request, required this.action});

  final HelpRequest request;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _urgencyColor(request.urgency);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                      const SizedBox(height: 5),
                      Text(
                        '${request.requestType} by ${request.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  label: request.urgencyLabel,
                  color: urgencyColor,
                  icon: Icons.bolt_outlined,
                ),
              ],
            ),
            if (request.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WorkableDesign.canvas,
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                ),
                child: Text(
                  request.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            WorkableInfoRow(
              icon: Icons.schedule_outlined,
              text: request.timeLabel,
            ),
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: Icons.location_on_outlined,
              text: request.pickupAddress,
            ),
            if (request.destinationAddress.isNotEmpty) ...[
              const SizedBox(height: 8),
              WorkableInfoRow(
                icon: Icons.flag_outlined,
                text: request.destinationAddress,
              ),
            ],
            if (request.budget != null) ...[
              const SizedBox(height: 8),
              WorkableInfoRow(
                icon: Icons.currency_rupee,
                text: 'Budget: Rs ${request.budget!.toStringAsFixed(0)}',
              ),
            ],
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return WorkableDesign.danger;
      case 'today':
        return WorkableDesign.warning;
      default:
        return WorkableDesign.primary;
    }
  }
}
