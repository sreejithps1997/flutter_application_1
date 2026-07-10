import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/workable_design.dart';
import '../../help_requests/domain/help_request_prefill.dart';
import '../../../screens/generic_help_request_screen.dart';
import '../../../screens/worker_list_screen.dart';
import '../../../widgets/workable_ui.dart';
import '../domain/smart_booking_ai_diagnosis.dart';
import '../domain/smart_booking_assessment.dart';
import '../domain/smart_help_quota.dart';
import 'smart_booking_providers.dart';

class SmartBookingAssistantScreen extends ConsumerStatefulWidget {
  const SmartBookingAssistantScreen({super.key});

  static const routeName = '/customer/smart-booking';

  @override
  ConsumerState<SmartBookingAssistantScreen> createState() =>
      _SmartBookingAssistantScreenState();
}

class _SmartBookingAssistantScreenState
    extends ConsumerState<SmartBookingAssistantScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _aiLoading = false;
  String? _error;
  String? _aiError;
  SmartBookingAssessment? _assessment;
  SmartBookingAiDiagnosis? _aiDiagnosis;

  final _examples = const [
    'water leaking under sink',
    'pick up medicine from town today',
    'AC not cooling',
    'elder hospital support urgent',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _assess(String value) async {
    final query = value.trim();
    if (query.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _aiError = null;
      _assessment = null;
      _aiDiagnosis = null;
    });

    try {
      final result = await ref
          .read(smartBookingAssistantRepositoryProvider)
          .assess(query);
      await ref
          .read(smartHelpQuotaRepositoryProvider)
          .recordLocalAssessment(
            query: result.query,
            category: result.category,
            urgency: result.urgency,
            recommendedPath: result.recommendedPath,
            foundWorkers: result.hasWorkers,
          );
      if (!mounted) return;
      setState(() => _assessment = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runDeeperDiagnosis() async {
    final query = (_assessment?.query ?? _controller.text).trim();
    if (query.isEmpty || _aiLoading) return;

    setState(() {
      _aiLoading = true;
      _aiError = null;
    });

    try {
      final result = await ref
          .read(smartBookingAssistantRepositoryProvider)
          .runBackendDiagnosis(query);
      if (!mounted) return;
      setState(() => _aiDiagnosis = result);
      ref.invalidate(smartHelpQuotaProvider);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _aiError = error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    final quota = ref.watch(smartHelpQuotaProvider);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Smart Booking'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Tell Workable what you need',
              subtitle:
                  'This first version uses local intelligence: category detection, urgency check, worker matching and help-request routing. Real AI can plug in later.',
              icon: LucideIcons.sparkles,
            ),
            const SizedBox(height: 16),
            quota.when(
              data: (value) => _SmartHelpQuotaCard(quota: value),
              loading: () => const _SmartHelpQuotaSkeleton(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            WorkableSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 5,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'What help do you need?',
                      hintText:
                          'Example: I need someone to pick up a parcel from town today',
                      prefixIcon: Icon(LucideIcons.messageCircle),
                    ),
                    onSubmitted: _assess,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _assess(_controller.text),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.wand2),
                      label: Text(_loading ? 'Thinking...' : 'Understand Need'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _examples.map((example) {
                      return ActionChip(
                        label: Text(example),
                        avatar: const Icon(LucideIcons.plus, size: 16),
                        onPressed: () {
                          _controller.text = example;
                          _assess(example);
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
            else if (assessment == null)
              const _AssistantExplainer()
            else
              _AssessmentResultCard(
                assessment: assessment,
                aiDiagnosis: _aiDiagnosis,
                aiError: _aiError,
                aiLoading: _aiLoading,
                onRunDeeperDiagnosis: _runDeeperDiagnosis,
                onViewWorkers: assessment.hasWorkers
                    ? () => Navigator.pushNamed(
                        context,
                        WorkerListScreen.routeName,
                        arguments: assessment.workers,
                      )
                    : null,
                onCreateHelpRequest: () => Navigator.pushNamed(
                  context,
                  GenericHelpRequestScreen.routeName,
                  arguments: HelpRequestPrefill(
                    query: assessment.query,
                    category: _aiDiagnosis?.category ?? assessment.category,
                    urgency: _aiDiagnosis?.urgency ?? assessment.urgency,
                    demandSignalId: assessment.demandSignalId,
                    city: assessment.city,
                    aiDiagnosis: _aiDiagnosis?.toMetadata(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssistantExplainer extends StatelessWidget {
  const _AssistantExplainer();

  @override
  Widget build(BuildContext context) {
    return const WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkableInfoRow(
            icon: LucideIcons.brain,
            text:
                'The assistant first uses free local rules, so there is no AI API cost in this phase.',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.users,
            text:
                'If workers match the need, it sends you to ranked worker profiles.',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.heartHandshake,
            text:
                'If the need is pickup, delivery, urgent support, or no worker exists, it guides you toward a Help Request.',
          ),
        ],
      ),
    );
  }
}

class _SmartHelpQuotaCard extends StatelessWidget {
  const _SmartHelpQuotaCard({required this.quota});

  final SmartHelpQuota quota;

  @override
  Widget build(BuildContext context) {
    final remaining = quota.remainingAiCalls;
    final color = remaining == 0
        ? WorkableDesign.warning
        : WorkableDesign.success;

    return WorkableSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(WorkableDesign.radius),
            ),
            child: Icon(Icons.speed_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$remaining Smart Helps left today',
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Local matching stays free. These Smart Helps are reserved for future AI diagnosis when the app really needs deeper understanding.',
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WorkableStatusPill(
                      label: '${quota.localAssessments} free checks',
                      color: WorkableDesign.primary,
                      icon: LucideIcons.search,
                    ),
                    WorkableStatusPill(
                      label: '${quota.aiCallsUsed}/${quota.dailyAllowance} AI',
                      color: color,
                      icon: LucideIcons.sparkles,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartHelpQuotaSkeleton extends StatelessWidget {
  const _SmartHelpQuotaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const WorkableSectionCard(
      child: WorkableInfoRow(
        icon: Icons.speed_outlined,
        text: 'Checking today\'s Smart Help allowance...',
      ),
    );
  }
}

class _AssessmentResultCard extends StatelessWidget {
  const _AssessmentResultCard({
    required this.assessment,
    required this.aiDiagnosis,
    required this.aiError,
    required this.aiLoading,
    required this.onRunDeeperDiagnosis,
    required this.onViewWorkers,
    required this.onCreateHelpRequest,
  });

  final SmartBookingAssessment assessment;
  final SmartBookingAiDiagnosis? aiDiagnosis;
  final String? aiError;
  final bool aiLoading;
  final VoidCallback onRunDeeperDiagnosis;
  final VoidCallback? onViewWorkers;
  final VoidCallback onCreateHelpRequest;

  @override
  Widget build(BuildContext context) {
    final effectivePath =
        aiDiagnosis?.recommendedPath ?? assessment.recommendedPath;
    final isEmergency = effectivePath == 'emergency';
    final preferWorkers = effectivePath == 'worker_booking';
    final preferHelpRequest =
        effectivePath == 'help_request' || isEmergency || onViewWorkers == null;
    final helpRequestAction = isEmergency
        ? () => _confirmEmergencyHelpRequest(context)
        : onCreateHelpRequest;

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkableStatusPill(
                label: assessment.category,
                color: WorkableDesign.primary,
                icon: LucideIcons.tags,
              ),
              WorkableStatusPill(
                label: assessment.urgency,
                color: assessment.isUrgent
                    ? WorkableDesign.danger
                    : WorkableDesign.success,
                icon: Icons.flash_on_outlined,
              ),
              WorkableStatusPill(
                label: assessment.hasWorkers
                    ? '${assessment.workers.length} matches'
                    : 'Demand captured',
                color: assessment.hasWorkers
                    ? WorkableDesign.success
                    : WorkableDesign.warning,
                icon: assessment.hasWorkers
                    ? LucideIcons.users
                    : LucideIcons.radar,
              ),
              if (isEmergency)
                WorkableStatusPill(
                  label: 'Safety first',
                  color: WorkableDesign.danger,
                  icon: LucideIcons.shield,
                ),
            ],
          ),
          if (isEmergency) ...[
            const SizedBox(height: 12),
            _EmergencyGuidanceCard(safetyNote: aiDiagnosis?.safetyNote),
          ],
          const SizedBox(height: 14),
          Text(
            assessment.summary,
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Before booking, confirm:',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...assessment.questions.map((question) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WorkableInfoRow(
                icon: LucideIcons.checkCircle2,
                text: question,
              ),
            );
          }),
          if (aiDiagnosis != null || aiError != null) ...[
            const SizedBox(height: 8),
            _BackendDiagnosisPanel(diagnosis: aiDiagnosis, error: aiError),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: aiLoading ? null : onRunDeeperDiagnosis,
                icon: aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles),
                label: Text(aiLoading ? 'Checking...' : 'Deeper Diagnosis'),
              ),
              if (preferHelpRequest)
                FilledButton.icon(
                  onPressed: helpRequestAction,
                  icon: Icon(
                    isEmergency
                        ? Icons.warning_amber_outlined
                        : LucideIcons.heartHandshake,
                  ),
                  label: Text(
                    isEmergency ? 'Request Urgent Help' : 'Create Help Request',
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: helpRequestAction,
                  icon: const Icon(LucideIcons.heartHandshake),
                  label: const Text('Create Help Request'),
                ),
              if (onViewWorkers != null && preferWorkers)
                FilledButton.icon(
                  onPressed: onViewWorkers,
                  icon: const Icon(LucideIcons.users),
                  label: const Text('View Workers'),
                )
              else if (onViewWorkers != null)
                OutlinedButton.icon(
                  onPressed: onViewWorkers,
                  icon: const Icon(LucideIcons.users),
                  label: const Text('View Workers'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEmergencyHelpRequest(BuildContext context) async {
    final note = aiDiagnosis?.safetyNote.trim();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Safety first'),
          content: Text(
            note != null && note.isNotEmpty
                ? '$note\n\nIf there is immediate danger, contact local emergency services first. Workable can still help you create an urgent request.'
                : 'If there is immediate danger, contact local emergency services first. Workable can still help you create an urgent request.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (proceed == true) {
      onCreateHelpRequest();
    }
  }
}

class _EmergencyGuidanceCard extends StatelessWidget {
  const _EmergencyGuidanceCard({required this.safetyNote});

  final String? safetyNote;

  @override
  Widget build(BuildContext context) {
    final note = safetyNote?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: WorkableDesign.cardDecoration(
        color: WorkableDesign.danger.withValues(alpha: 0.08),
        borderColor: WorkableDesign.danger.withValues(alpha: 0.24),
      ),
      child: WorkableInfoRow(
        icon: Icons.warning_amber_outlined,
        text: note == null || note.isEmpty
            ? 'If there is immediate danger, contact local emergency services first.'
            : note,
      ),
    );
  }
}

class _BackendDiagnosisPanel extends StatelessWidget {
  const _BackendDiagnosisPanel({required this.diagnosis, required this.error});

  final SmartBookingAiDiagnosis? diagnosis;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: WorkableDesign.cardDecoration(
          color: WorkableDesign.danger.withValues(alpha: 0.08),
          borderColor: WorkableDesign.danger.withValues(alpha: 0.24),
        ),
        child: WorkableInfoRow(icon: LucideIcons.alertCircle, text: error!),
      );
    }

    final value = diagnosis;
    if (value == null) return const SizedBox.shrink();
    final confidence = _confidenceDisplay(value.confidence);
    final path = _pathDisplay(value.recommendedPath);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: WorkableDesign.cardDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.06),
        borderColor: WorkableDesign.primary.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkableStatusPill(
                label: value.cached
                    ? 'Cached AI'
                    : value.aiUsed
                    ? 'AI used'
                    : 'Backend fallback',
                color: value.aiUsed
                    ? WorkableDesign.success
                    : WorkableDesign.warning,
                icon: LucideIcons.sparkles,
              ),
              if (value.cached)
                WorkableStatusPill(
                  label: 'No quota used',
                  color: WorkableDesign.success,
                  icon: Icons.repeat,
                ),
              if (value.remainingSmartHelps != null)
                WorkableStatusPill(
                  label: '${value.remainingSmartHelps} left',
                  color: WorkableDesign.primary,
                  icon: Icons.speed_outlined,
                ),
              WorkableStatusPill(
                label: confidence.label,
                color: confidence.color,
                icon: Icons.fact_check_outlined,
              ),
              WorkableStatusPill(
                label: path.label,
                color: path.color,
                icon: path.icon,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value.summary,
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Backend category: ${value.category} - ${value.urgency}',
            style: const TextStyle(color: WorkableDesign.muted),
          ),
          if (value.priceRange.isNotEmpty &&
              value.priceRange.toLowerCase() != 'unknown') ...[
            const SizedBox(height: 8),
            WorkableInfoRow(
              icon: Icons.currency_rupee,
              text: 'Estimated range: ${value.priceRange}',
            ),
          ],
          if (value.safetyNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            WorkableInfoRow(icon: LucideIcons.shield, text: value.safetyNote),
          ],
          const SizedBox(height: 10),
          ...value.questions.take(3).map((question) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: WorkableInfoRow(
                icon: LucideIcons.checkCircle2,
                text: question,
              ),
            );
          }),
        ],
      ),
    );
  }

  _PillDisplay _confidenceDisplay(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
        return const _PillDisplay(
          label: 'High confidence',
          color: WorkableDesign.success,
          icon: Icons.fact_check_outlined,
        );
      case 'low':
        return const _PillDisplay(
          label: 'Needs details',
          color: WorkableDesign.warning,
          icon: Icons.help_outline,
        );
      default:
        return const _PillDisplay(
          label: 'Medium confidence',
          color: WorkableDesign.primary,
          icon: Icons.fact_check_outlined,
        );
    }
  }

  _PillDisplay _pathDisplay(String recommendedPath) {
    switch (recommendedPath) {
      case 'worker_booking':
        return const _PillDisplay(
          label: 'Best: compare workers',
          color: WorkableDesign.primary,
          icon: LucideIcons.users,
        );
      case 'emergency':
        return const _PillDisplay(
          label: 'Best: urgent help',
          color: WorkableDesign.danger,
          icon: Icons.warning_amber_outlined,
        );
      default:
        return const _PillDisplay(
          label: 'Best: help request',
          color: WorkableDesign.success,
          icon: LucideIcons.heartHandshake,
        );
    }
  }
}

class _PillDisplay {
  const _PillDisplay({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}
