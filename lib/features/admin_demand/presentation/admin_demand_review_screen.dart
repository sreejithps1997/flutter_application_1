import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/workable_design.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/admin_demand_signal.dart';
import 'admin_demand_providers.dart';

class AdminDemandReviewScreen extends ConsumerWidget {
  static const routeName = '/admin-demand-review';

  const AdminDemandReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSignals = ref.watch(adminDemandSignalsProvider).valueOrNull ?? [];
    final filteredSignals = ref.watch(filteredAdminDemandSignalsProvider);
    final activeFilter = ref.watch(adminDemandStatusFilterProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Demand Review')),
      body: filteredSignals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => WorkableEmptyState(
          icon: LucideIcons.alertTriangle,
          title: 'Unable to load demand',
          message: error.toString(),
        ),
        data: (signals) {
          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              WorkablePageHeader(
                title: '${_countOpen(allSignals)} open demand signals',
                subtitle:
                    'Review customer searches, approve real categories, merge similar demand, or reject unsuitable requests.',
                icon: LucideIcons.radar,
              ),
              const SizedBox(height: 16),
              _DemandStats(signals: allSignals),
              const SizedBox(height: 16),
              _StatusFilter(activeFilter: activeFilter),
              const SizedBox(height: 16),
              if (signals.isEmpty)
                WorkableEmptyState(
                  icon: LucideIcons.inbox,
                  title: 'No $activeFilter demand',
                  message:
                      'Demand signals matching this review state will appear here.',
                )
              else
                ...signals.map((signal) => _DemandSignalCard(signal: signal)),
            ],
          );
        },
      ),
    );
  }

  int _countOpen(List<AdminDemandSignal> signals) {
    return signals.where((signal) => signal.status == 'open').length;
  }
}

class _DemandStats extends StatelessWidget {
  const _DemandStats({required this.signals});

  final List<AdminDemandSignal> signals;

  @override
  Widget build(BuildContext context) {
    final totalSearches = signals.fold<int>(
      0,
      (sum, signal) => sum + signal.searchCount,
    );
    final workerInterest = signals
        .where((signal) => signal.hasWorkerInterest)
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Signals',
            value: '${signals.length}',
            icon: LucideIcons.radar,
            color: WorkableDesign.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Searches',
            value: '$totalSearches',
            icon: LucideIcons.search,
            color: WorkableDesign.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Workers',
            value: '$workerInterest',
            icon: LucideIcons.users,
            color: WorkableDesign.success,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: WorkableDesign.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends ConsumerWidget {
  const _StatusFilter({required this.activeFilter});

  final String activeFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      ('open', 'Open'),
      ('approved', 'Approved'),
      ('merged', 'Merged'),
      ('rejected', 'Rejected'),
      ('all', 'All'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = activeFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) {
                ref.read(adminDemandStatusFilterProvider.notifier).state =
                    filter.$1;
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DemandSignalCard extends ConsumerStatefulWidget {
  const _DemandSignalCard({required this.signal});

  final AdminDemandSignal signal;

  @override
  ConsumerState<_DemandSignalCard> createState() => _DemandSignalCardState();
}

class _DemandSignalCardState extends ConsumerState<_DemandSignalCard> {
  bool _busy = false;

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  Future<void> _approve() async {
    final signal = widget.signal;
    final result = await _categoryDialog(
      title: 'Approve Category',
      initialCategory: signal.guessedCategory,
      actionLabel: 'Approve',
    );
    if (result == null) return;

    await _runAction(() {
      return ref
          .read(adminDemandRepositoryProvider)
          .approveCategory(
            signal: signal,
            categoryName: result.category,
            note: result.note,
          );
    }, 'Category approved and added to skills.');
  }

  Future<void> _merge() async {
    final signal = widget.signal;
    final result = await _categoryDialog(
      title: 'Merge Demand',
      initialCategory: signal.guessedCategory,
      actionLabel: 'Merge',
      noteHint: 'Example: merged fish tank motor repair into Aquarium Services',
    );
    if (result == null) return;

    await _runAction(() {
      return ref
          .read(adminDemandRepositoryProvider)
          .mergeIntoCategory(
            signal: signal,
            categoryName: result.category,
            note: result.note,
          );
    }, 'Demand merged into category.');
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Demand?'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Why this should not become a marketplace category',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    await _runAction(() {
      return ref
          .read(adminDemandRepositoryProvider)
          .rejectSignal(signal: widget.signal, reason: reason);
    }, 'Demand rejected.');
  }

  Future<_CategoryAction?> _categoryDialog({
    required String title,
    required String initialCategory,
    required String actionLabel,
    String noteHint = 'Internal review note',
  }) async {
    final categoryController = TextEditingController(text: initialCategory);
    final noteController = TextEditingController();

    final result = await showDialog<_CategoryAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category name',
                hintText: 'Example: Aquarium Services',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note',
                hintText: noteHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                _CategoryAction(
                  category: categoryController.text,
                  note: noteController.text,
                ),
              );
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    categoryController.dispose();
    noteController.dispose();
    return result;
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Review action failed: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    final canReview = signal.status == 'open';
    final date = signal.lastSearchedAt == null
        ? 'Unknown'
        : _dateFormat.format(signal.lastSearchedAt!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(signal).withValues(alpha: 0.12),
                  child: Icon(_statusIcon(signal), color: _statusColor(signal)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        signal.searchPhrase,
                        style: const TextStyle(
                          color: WorkableDesign.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Signal ID: ${signal.id}',
                        style: const TextStyle(
                          color: WorkableDesign.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                WorkableStatusPill(
                  label: signal.status,
                  color: _statusColor(signal),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WorkableStatusPill(
                  label: signal.guessedCategory,
                  color: WorkableDesign.primary,
                  icon: LucideIcons.tags,
                ),
                if (signal.city != 'Unknown')
                  WorkableStatusPill(
                    label: signal.city,
                    color: WorkableDesign.accent,
                    icon: LucideIcons.mapPin,
                  ),
                WorkableStatusPill(
                  label: '${signal.searchCount} searches',
                  color: WorkableDesign.warning,
                  icon: LucideIcons.search,
                ),
                if (signal.claimedWorkerIds.isNotEmpty)
                  WorkableStatusPill(
                    label: '${signal.claimedWorkerIds.length} workers',
                    color: WorkableDesign.success,
                    icon: LucideIcons.users,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            WorkableInfoRow(
              icon: LucideIcons.calendar,
              text: 'Last searched: $date',
            ),
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: LucideIcons.user,
              text: '${signal.customerIds.length} interested customers',
            ),
            if (signal.approvedCategory != null) ...[
              const SizedBox(height: 8),
              WorkableInfoRow(
                icon: LucideIcons.badgeCheck,
                text: 'Reviewed category: ${signal.approvedCategory}',
              ),
            ],
            if (canReview) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _reject,
                      icon: const Icon(LucideIcons.xCircle),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _merge,
                      icon: const Icon(LucideIcons.gitMerge),
                      label: const Text('Merge'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _approve,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.checkCircle2),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(AdminDemandSignal signal) {
    switch (signal.status) {
      case 'approved':
        return WorkableDesign.success;
      case 'merged':
        return WorkableDesign.accent;
      case 'rejected':
        return WorkableDesign.danger;
      default:
        return WorkableDesign.warning;
    }
  }

  IconData _statusIcon(AdminDemandSignal signal) {
    switch (signal.status) {
      case 'approved':
        return LucideIcons.checkCircle2;
      case 'merged':
        return LucideIcons.gitMerge;
      case 'rejected':
        return LucideIcons.xCircle;
      default:
        return LucideIcons.radar;
    }
  }
}

class _CategoryAction {
  const _CategoryAction({required this.category, required this.note});

  final String category;
  final String note;
}
