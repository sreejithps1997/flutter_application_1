import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/workable_design.dart';
import '../../../screens/generic_help_request_screen.dart';
import '../../../screens/worker_list_screen.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/demand_discovery_result.dart';
import 'demand_discovery_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  static const routeName = '/search';

  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  DemandDiscoveryResult? _result;

  final List<String> _suggestions = const [
    'water leaking under sink',
    'pickup parcel from town',
    'AC not cooling',
    'deep cleaning today',
    'elder hospital support',
  ];

  Future<void> _search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await ref
          .read(demandDiscoveryRepositoryProvider)
          .discover(trimmedQuery);

      if (!mounted) return;

      if (result.hasWorkers) {
        Navigator.pushNamed(
          context,
          WorkerListScreen.routeName,
          arguments: result.workers,
        );
        setState(() => _result = result);
      } else {
        setState(() => _result = result);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to discover this service right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyDemandMessage(DemandDiscoveryResult result) async {
    final locationText = result.city == null || result.city == 'Unknown'
        ? ''
        : ' in ${result.city}';
    final message =
        'Someone needs help with "${result.query}"$locationText. Workable is looking for skilled people for ${result.guessedCategory}. If you can do this work, join Workable and add this skill to your profile.';

    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Demand message copied')));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Smart Search')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Ask for any help',
              subtitle:
                  'Search normal services, pickup, delivery, urgent help, or a new type of work. If Workable cannot find it, the demand is captured for the marketplace.',
              icon: LucideIcons.sparkles,
            ),
            const SizedBox(height: 16),
            WorkableSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: InputDecoration(
                      labelText: 'What help do you need?',
                      hintText: 'Example: pick up medicine from town',
                      prefixIcon: const Icon(LucideIcons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        icon: const Icon(LucideIcons.arrowRight),
                        onPressed: () => _search(_searchController.text),
                      ),
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions.map((suggestion) {
                      return ActionChip(
                        label: Text(suggestion),
                        avatar: const Icon(LucideIcons.plus, size: 16),
                        onPressed: () {
                          _searchController.text = suggestion;
                          _search(suggestion);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              WorkableSectionCard(
                color: WorkableDesign.danger.withValues(alpha: 0.08),
                borderColor: WorkableDesign.danger.withValues(alpha: 0.24),
                child: WorkableInfoRow(
                  icon: LucideIcons.alertCircle,
                  text: _error!,
                ),
              )
            else if (result == null)
              const _DiscoveryExplainer()
            else if (result.hasDemandSignal)
              _DemandCapturedCard(
                result: result,
                onCopy: () => _copyDemandMessage(result),
                onCreateHelpRequest: () => Navigator.pushNamed(
                  context,
                  GenericHelpRequestScreen.routeName,
                ),
              )
            else
              _MatchedWorkersCard(result: result),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryExplainer extends StatelessWidget {
  const _DiscoveryExplainer();

  @override
  Widget build(BuildContext context) {
    return const WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkableInfoRow(
            icon: LucideIcons.users,
            text:
                'If workers already match your need, Workable shows the best available profiles.',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.radar,
            text:
                'If nobody matches, Workable records real customer demand so new categories and workers can be added.',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.share2,
            text:
                'You can copy the demand message and share it to help bring the right workers into the app.',
          ),
        ],
      ),
    );
  }
}

class _MatchedWorkersCard extends StatelessWidget {
  const _MatchedWorkersCard({required this.result});

  final DemandDiscoveryResult result;

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkableStatusPill(
            label: result.guessedCategory,
            color: WorkableDesign.success,
            icon: LucideIcons.badgeCheck,
          ),
          const SizedBox(height: 12),
          Text(
            '${result.workers.length} worker match${result.workers.length == 1 ? '' : 'es'} found',
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The result list opened automatically. You can compare profiles, ratings, pricing, and service fit before booking.',
            style: TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DemandCapturedCard extends StatelessWidget {
  const _DemandCapturedCard({
    required this.result,
    required this.onCopy,
    required this.onCreateHelpRequest,
  });

  final DemandDiscoveryResult result;
  final VoidCallback onCopy;
  final VoidCallback onCreateHelpRequest;

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      color: WorkableDesign.warning.withValues(alpha: 0.08),
      borderColor: WorkableDesign.warning.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WorkableStatusPill(
            label: 'Demand captured',
            color: WorkableDesign.warning,
            icon: LucideIcons.radar,
          ),
          const SizedBox(height: 12),
          Text(
            'No worker is available for "${result.query}" yet',
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We saved this as ${result.guessedCategory}. Repeated searches can become a new category, and workers can be invited to add this skill.',
            style: const TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(LucideIcons.copy),
                label: const Text('Copy demand'),
              ),
              ElevatedButton.icon(
                onPressed: onCreateHelpRequest,
                icon: const Icon(LucideIcons.heartHandshake),
                label: const Text('Request help'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
