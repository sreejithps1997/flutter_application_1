import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/workable_design.dart';
import '../../../screens/worker_professional_profile_screen.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/worker_opportunity.dart';
import 'worker_opportunity_providers.dart';

class WorkerOpportunityFeedScreen extends ConsumerWidget {
  static const routeName = '/worker/opportunities';

  const WorkerOpportunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunities = ref.watch(workerOpportunitiesProvider);
    final workerId = ref.watch(currentWorkerIdProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Opportunities')),
      body: opportunities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const WorkableEmptyState(
          icon: LucideIcons.radar,
          title: 'Unable to load opportunities',
          message:
              'Customer demand signals could not be loaded right now. Please try again shortly.',
        ),
        data: (items) {
          if (items.isEmpty) {
            return WorkableEmptyState(
              icon: LucideIcons.radar,
              title: 'No open demand yet',
              message:
                  'When customers search for services that are not available, those opportunities will appear here.',
              actionLabel: 'Improve profile',
              onAction: () => Navigator.pushNamed(
                context,
                WorkerProfessionalProfileScreen.routeName,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              WorkablePageHeader(
                title: 'Customer demand near the market',
                subtitle:
                    'Add services customers are actively searching for. Only claim work you can confidently accept.',
                icon: LucideIcons.radar,
                trailing: WorkableStatusPill(
                  label: '${items.length} open',
                  color: WorkableDesign.accent,
                ),
              ),
              const SizedBox(height: 16),
              const WorkableSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WorkableInfoRow(
                      icon: LucideIcons.shieldCheck,
                      text:
                          'Claiming an opportunity adds the suggested category to your worker profile.',
                    ),
                    SizedBox(height: 10),
                    WorkableInfoRow(
                      icon: LucideIcons.badgeCheck,
                      text:
                          'Profile visibility rules still apply. Verification, availability, and pricing remain important.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) =>
                    _OpportunityCard(opportunity: item, workerId: workerId),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OpportunityCard extends ConsumerStatefulWidget {
  const _OpportunityCard({required this.opportunity, required this.workerId});

  final WorkerOpportunity opportunity;
  final String? workerId;

  @override
  ConsumerState<_OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends ConsumerState<_OpportunityCard> {
  bool _isClaiming = false;

  static final DateFormat _dateFormat = DateFormat('dd MMM');

  Future<void> _claim() async {
    if (_isClaiming) return;

    setState(() => _isClaiming = true);
    try {
      await ref
          .read(workerOpportunityRepositoryProvider)
          .claimOpportunity(widget.opportunity);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.opportunity.guessedCategory} added to your profile',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to claim opportunity: $error')),
      );
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opportunity = widget.opportunity;
    final workerId = widget.workerId;
    final alreadyClaimed =
        workerId != null && opportunity.isClaimedBy(workerId);
    final lastSeen = opportunity.lastSearchedAt == null
        ? 'recently'
        : _dateFormat.format(opportunity.lastSearchedAt!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: WorkableDesign.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(WorkableDesign.radius),
                  ),
                  child: const Icon(
                    LucideIcons.radar,
                    color: WorkableDesign.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.searchPhrase,
                        style: const TextStyle(
                          color: WorkableDesign.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${opportunity.searchCount} customer search${opportunity.searchCount == 1 ? '' : 'es'} • last seen $lastSeen',
                        style: const TextStyle(
                          color: WorkableDesign.muted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WorkableStatusPill(
                  label: opportunity.guessedCategory,
                  color: WorkableDesign.primary,
                  icon: LucideIcons.tags,
                ),
                if (opportunity.city != 'Unknown')
                  WorkableStatusPill(
                    label: opportunity.city,
                    color: WorkableDesign.accent,
                    icon: LucideIcons.mapPin,
                  ),
                if (alreadyClaimed)
                  const WorkableStatusPill(
                    label: 'in your profile',
                    color: WorkableDesign.success,
                    icon: LucideIcons.checkCircle2,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      WorkerProfessionalProfileScreen.routeName,
                    ),
                    icon: const Icon(LucideIcons.userCog),
                    label: const Text('Edit profile'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: alreadyClaimed || _isClaiming ? null : _claim,
                    icon: _isClaiming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            alreadyClaimed
                                ? LucideIcons.checkCircle2
                                : LucideIcons.plus,
                          ),
                    label: Text(alreadyClaimed ? 'Added' : 'I can do this'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
