import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';

class WorkerOnboardingShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final int step;
  final int totalSteps;
  final List<Widget> children;
  final Widget? bottom;

  const WorkerOnboardingShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
    required this.children,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(backgroundColor: WorkableDesign.canvas),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  WorkerOnboardingHeader(
                    title: title,
                    subtitle: subtitle,
                    step: step,
                    totalSteps: totalSteps,
                  ),
                  const SizedBox(height: 22),
                  ...children,
                ],
              ),
            ),
            if (bottom != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  color: WorkableDesign.surface,
                  border: Border(top: BorderSide(color: WorkableDesign.border)),
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class WorkerOnboardingHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int step;
  final int totalSteps;

  const WorkerOnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (step / totalSteps).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: WorkableDesign.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.engineering_outlined,
                color: WorkableDesign.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Step $step of $totalSteps',
                style: const TextStyle(
                  color: WorkableDesign.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            color: WorkableDesign.accent,
            backgroundColor: WorkableDesign.border,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: const TextStyle(
            color: WorkableDesign.ink,
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            color: WorkableDesign.muted,
            fontSize: 14.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class WorkerOnboardingCard extends StatelessWidget {
  final Widget child;

  const WorkerOnboardingCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: child,
    );
  }
}
