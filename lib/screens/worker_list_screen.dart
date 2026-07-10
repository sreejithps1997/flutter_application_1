import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/star_rating.dart';
import '../widgets/workable_ui.dart';
import 'worker_profile_screen.dart';

class WorkerListScreen extends StatelessWidget {
  static const routeName = '/worker-list';

  final List<Map<String, dynamic>> results;

  const WorkerListScreen({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Available Workers')),
      body: SafeArea(
        child: results.isEmpty
            ? const WorkableEmptyState(
                icon: LucideIcons.users,
                title: 'No workers found',
                message:
                    'Try a different service keyword or adjust your filters.',
              )
            : ListView(
                padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                children: [
                  WorkablePageHeader(
                    title:
                        '${results.length} worker match${results.length == 1 ? '' : 'es'}',
                    subtitle:
                        'Compare rating, service fit, pricing and completed work before opening a profile.',
                    icon: LucideIcons.users,
                  ),
                  const SizedBox(height: 16),
                  ...results.map((worker) => _WorkerSearchCard(worker: worker)),
                ],
              ),
      ),
    );
  }
}

class _WorkerSearchCard extends StatelessWidget {
  const _WorkerSearchCard({required this.worker});

  final Map<String, dynamic> worker;

  @override
  Widget build(BuildContext context) {
    final name = _text(['name', 'fullName'], 'Worker');
    final service = _serviceText();
    final rating = _rating();
    final imageUrl = _text(['imageUrl', 'profileImageUrl', 'photoUrl'], '');
    final jobs = _int(['completedJobsCount', 'completedJobs', 'totalJobs']);
    final location = _text(['location', 'city', 'address'], '');
    final price = _priceText();
    final workerId = _text(['id', 'workerId', 'uid'], '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: InkWell(
          onTap: workerId.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          WorkerProfileScreen(workerId: workerId, name: name),
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: WorkableDesign.primary.withValues(
                    alpha: 0.1,
                  ),
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : null,
                  child: imageUrl.isEmpty
                      ? Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: WorkableDesign.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: WorkableDesign.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: WorkableDesign.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (service.isNotEmpty)
                        Text(
                          service,
                          style: const TextStyle(
                            color: WorkableDesign.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          WorkableStatusPill(
                            label: rating > 0
                                ? rating.toStringAsFixed(1)
                                : 'New',
                            color: WorkableDesign.warning,
                            icon: LucideIcons.star,
                          ),
                          if (jobs > 0)
                            WorkableStatusPill(
                              label: '$jobs jobs',
                              color: WorkableDesign.accent,
                              icon: LucideIcons.checkCircle,
                            ),
                          if (price.isNotEmpty)
                            WorkableStatusPill(
                              label: price,
                              color: WorkableDesign.primary,
                              icon: LucideIcons.wallet,
                            ),
                        ],
                      ),
                      if (rating > 0) ...[
                        const SizedBox(height: 10),
                        StarRating(rating: rating),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        WorkableInfoRow(
                          icon: LucideIcons.mapPin,
                          text: location,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _serviceText() {
    final services = worker['services'] ?? worker['skills'];
    if (services is List) {
      return services.map((item) => item.toString()).join(', ');
    }
    return _text(['service', 'serviceType', 'category'], '');
  }

  double _rating() {
    final value = worker['averageRating'] ?? worker['rating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _int(List<String> keys) {
    for (final key in keys) {
      final value = worker[key];
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _priceText() {
    final value =
        worker['pricing'] ?? worker['startingPrice'] ?? worker['rate'];
    if (value is num) return 'From Rs ${value.toInt()}';
    if (value is Map && value.isNotEmpty) {
      final prices = value.values
          .map(
            (item) => item is num ? item.toDouble() : double.tryParse('$item'),
          )
          .whereType<double>()
          .where((item) => item > 0)
          .toList();
      if (prices.isNotEmpty) {
        prices.sort();
        return 'From Rs ${prices.first.toInt()}';
      }
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    return text.toLowerCase().contains('rs') ? text : 'Rs $text';
  }

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = worker[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }
}
