import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/workable_design.dart';

class WorkableNotification {
  const WorkableNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.type,
    required this.isRead,
    required this.requiresAction,
    required this.createdAt,
    required this.routingData,
  });

  final String id;
  final String title;
  final String message;
  final String status;
  final String type;
  final bool isRead;
  final bool requiresAction;
  final DateTime? createdAt;
  final Map<String, dynamic> routingData;

  IconData get icon {
    if (requiresAction) return LucideIcons.alertCircle;
    switch (status) {
      case 'approved':
      case 'verified':
      case 'success':
        return LucideIcons.checkCircle2;
      case 'rejected':
      case 'failed':
        return LucideIcons.xCircle;
      default:
        return LucideIcons.bell;
    }
  }

  Color get color {
    if (requiresAction) return WorkableDesign.warning;
    switch (status) {
      case 'approved':
      case 'verified':
      case 'success':
        return WorkableDesign.success;
      case 'rejected':
      case 'failed':
        return WorkableDesign.danger;
      default:
        return WorkableDesign.primary;
    }
  }

  String get statusLabel => status.replaceAll('_', ' ');
}
