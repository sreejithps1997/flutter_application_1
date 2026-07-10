import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';

class BookingStatusTimeline extends StatelessWidget {
  const BookingStatusTimeline({
    super.key,
    required this.status,
    this.compact = false,
  });

  final String status;
  final bool compact;

  static const _steps = [
    _TimelineStep('pending', 'Requested', Icons.assignment_outlined),
    _TimelineStep('confirmed', 'Accepted', Icons.verified_outlined),
    _TimelineStep('in_progress', 'In Progress', Icons.build_outlined),
    _TimelineStep(
      'completion_requested',
      'Completion',
      Icons.task_alt_outlined,
    ),
    _TimelineStep('payment_due', 'Payment', Icons.payments_outlined),
    _TimelineStep('completed', 'Completed', Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final activeIndex = _activeIndex(normalized);

    if (compact) {
      return _CompactTimeline(activeIndex: activeIndex, status: normalized);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: WorkableDesign.border),
        boxShadow: [
          BoxShadow(
            color: WorkableDesign.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...List.generate(_steps.length, (index) {
            final step = _steps[index];
            final isDone = index < activeIndex;
            final isActive = index == activeIndex;
            final isLast = index == _steps.length - 1;
            return _TimelineRow(
              step: step,
              isDone: isDone,
              isActive: isActive,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  int _activeIndex(String value) {
    if (value == 'paid') return _steps.length - 1;
    if (value == 'payment_initiated' ||
        value == 'payment_under_review' ||
        value == 'customer_reported_paid' ||
        value == 'cash_pending_confirmation' ||
        value == 'payment_rejected') {
      return 4;
    }
    if (value == 'completion_disputed') return 3;
    if (value == 'cancelled') return 0;

    final index = _steps.indexWhere((step) => step.status == value);
    return index < 0 ? 0 : index;
  }
}

class _CompactTimeline extends StatelessWidget {
  const _CompactTimeline({required this.activeIndex, required this.status});

  final int activeIndex;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(BookingStatusTimeline._steps.length, (index) {
        final done = index <= activeIndex;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(
              right: index == BookingStatusTimeline._steps.length - 1 ? 0 : 4,
            ),
            decoration: BoxDecoration(
              color: done ? _colorFor(status) : WorkableDesign.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }

  Color _colorFor(String value) {
    if (value == 'cancelled' || value == 'completion_disputed') {
      return WorkableDesign.danger;
    }
    if (value.contains('payment')) return WorkableDesign.primary;
    if (value == 'completed' || value == 'paid') return WorkableDesign.success;
    return WorkableDesign.accent;
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  final _TimelineStep step;
  final bool isDone;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isDone || isActive
        ? WorkableDesign.primary
        : Colors.grey.shade400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDone || isActive
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                  border: Border.all(color: color),
                ),
                child: Icon(
                  isDone ? Icons.check : step.icon,
                  size: 16,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone
                        ? WorkableDesign.primary
                        : WorkableDesign.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isDone || isActive
                          ? WorkableDesign.ink
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (isActive)
                    Text(
                      'Current stage',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  const _TimelineStep(this.status, this.label, this.icon);

  final String status;
  final String label;
  final IconData icon;
}
