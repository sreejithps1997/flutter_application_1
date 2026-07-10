import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';

class WorkerVisibilityStatusPanel extends StatelessWidget {
  final String workerId;
  final EdgeInsetsGeometry margin;

  const WorkerVisibilityStatusPanel({
    super.key,
    required this.workerId,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    if (workerId.trim().isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('workers')
          .doc(workerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: margin,
            child: const LinearProgressIndicator(minHeight: 3),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final status = _WorkerVisibilityStatus.from(data);

        return Container(
          margin: margin,
          padding: const EdgeInsets.all(16),
          decoration: WorkableDesign.cardDecoration(
            borderColor: status.statusColor.withValues(alpha: 0.24),
          ),
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
                      color: status.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(status.statusIcon, color: status.statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.title,
                          style: const TextStyle(
                            color: WorkableDesign.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status.subtitle,
                          style: const TextStyle(
                            color: WorkableDesign.muted,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProgressBar(
                done: status.completedChecks,
                total: status.totalChecks,
              ),
              const SizedBox(height: 14),
              _StatusChecklist(status: status),
              if (status.blockedReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BlockedReason(text: status.blockedReason),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/worker/verification-status',
                      ),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Verification'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/worker/professional-profile',
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Profile'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int done;
  final int total;

  const _ProgressBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Profile readiness',
                style: TextStyle(
                  color: WorkableDesign.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$done/$total',
              style: const TextStyle(
                color: WorkableDesign.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            color: progress == 1
                ? WorkableDesign.success
                : WorkableDesign.accent,
            backgroundColor: WorkableDesign.border,
          ),
        ),
      ],
    );
  }
}

class _StatusChecklist extends StatelessWidget {
  final _WorkerVisibilityStatus status;

  const _StatusChecklist({required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CheckRow(
          label: 'Onboarding complete',
          done: status.onboardingComplete,
          icon: Icons.flag_outlined,
        ),
        _CheckRow(
          label: 'Profile photo',
          done: status.hasProfilePhoto,
          icon: Icons.account_circle_outlined,
        ),
        _CheckRow(
          label: 'Service location',
          done: status.hasLocation,
          icon: Icons.location_on_outlined,
        ),
        _CheckRow(
          label: 'Services and pricing',
          done: status.hasServicesAndPricing,
          icon: Icons.handyman_outlined,
        ),
        _CheckRow(
          label: 'Availability',
          done: status.hasAvailability,
          icon: Icons.event_available_outlined,
        ),
        _CheckRow(
          label: 'Payout method',
          done: status.hasPayoutMethod,
          icon: Icons.account_balance_wallet_outlined,
        ),
        _CheckRow(
          label: 'Selfie verification',
          done: status.selfieVerified,
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool done;
  final IconData icon;

  const _CheckRow({
    required this.label,
    required this.done,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? WorkableDesign.success : WorkableDesign.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: WorkableDesign.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(
            done ? Icons.check_circle : Icons.error_outline,
            size: 18,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _BlockedReason extends StatelessWidget {
  final String text;

  const _BlockedReason({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(
          color: WorkableDesign.warning.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: WorkableDesign.ink,
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WorkerVisibilityStatus {
  final bool visible;
  final bool onboardingComplete;
  final bool hasProfilePhoto;
  final bool hasLocation;
  final bool hasServicesAndPricing;
  final bool hasAvailability;
  final bool hasPayoutMethod;
  final bool selfieVerified;
  final bool accountActive;
  final String verificationStatus;
  final String workerStatus;
  final String blockedReason;

  const _WorkerVisibilityStatus({
    required this.visible,
    required this.onboardingComplete,
    required this.hasProfilePhoto,
    required this.hasLocation,
    required this.hasServicesAndPricing,
    required this.hasAvailability,
    required this.hasPayoutMethod,
    required this.selfieVerified,
    required this.accountActive,
    required this.verificationStatus,
    required this.workerStatus,
    required this.blockedReason,
  });

  factory _WorkerVisibilityStatus.from(Map<String, dynamic> data) {
    final verification = Map<String, dynamic>.from(data['verification'] ?? {});
    final skills = List.from(data['skills'] ?? const []);
    final wageMap = Map<String, dynamic>.from(data['wageMap'] ?? {});
    final schedule = Map<String, dynamic>.from(data['schedule'] ?? {});
    final paymentMethod = data['paymentMethod']?.toString().trim() ?? '';

    final visible = data['visibleToUsers'] == true;
    final selfieVerified =
        verification['selfie'] == 'verified' ||
        data['verificationStatus'] == 'verified';

    return _WorkerVisibilityStatus(
      visible: visible,
      onboardingComplete: data['isOnboardingComplete'] == true,
      hasProfilePhoto:
          _hasText(data['imageUrl']) || _hasText(data['profileImageUrl']),
      hasLocation: _hasUsableLocation(data),
      hasServicesAndPricing: skills.isNotEmpty && wageMap.isNotEmpty,
      hasAvailability:
          schedule['isFlexible'] == true ||
          List.from(
            schedule['availableDays'] ?? schedule['workingDays'] ?? const [],
          ).isNotEmpty,
      hasPayoutMethod:
          paymentMethod == 'Cash' ||
          _hasText(data['upiId']) ||
          (_hasText(data['bankAccountNumber']) && _hasText(data['ifscCode'])),
      selfieVerified: selfieVerified,
      accountActive:
          data['accountDisabled'] != true &&
          data['accountStatus'] != 'disabled',
      verificationStatus: data['verificationStatus']?.toString() ?? '',
      workerStatus: data['workerStatus']?.toString() ?? '',
      blockedReason: data['visibilityBlockedReason']?.toString() ?? '',
    );
  }

  int get totalChecks => 7;

  int get completedChecks => [
    onboardingComplete,
    hasProfilePhoto,
    hasLocation,
    hasServicesAndPricing,
    hasAvailability,
    hasPayoutMethod,
    selfieVerified,
  ].where((done) => done).length;

  Color get statusColor {
    if (visible) return WorkableDesign.success;
    if (verificationStatus == 'submitted' ||
        workerStatus == 'verification_submitted') {
      return WorkableDesign.primary;
    }
    return WorkableDesign.warning;
  }

  IconData get statusIcon {
    if (visible) return Icons.visibility_outlined;
    if (verificationStatus == 'submitted' ||
        workerStatus == 'verification_submitted') {
      return Icons.hourglass_top_outlined;
    }
    return Icons.visibility_off_outlined;
  }

  String get title {
    if (visible) return 'Visible to customers';
    if (verificationStatus == 'submitted' ||
        workerStatus == 'verification_submitted') {
      return 'Verification under review';
    }
    if (verificationStatus == 'skipped' ||
        workerStatus == 'verification_pending') {
      return 'Profile hidden until verification';
    }
    return 'Profile not visible yet';
  }

  String get subtitle {
    if (visible && accountActive) {
      return 'Customers can find and book you now.';
    }
    if (verificationStatus == 'submitted' ||
        workerStatus == 'verification_submitted') {
      return 'Your profile is complete, but customer visibility starts after admin review.';
    }
    return 'Complete the checklist below to start appearing in customer search.';
  }

  static bool _hasText(dynamic value) {
    final text = value?.toString().trim();
    return text != null && text.isNotEmpty && text.toLowerCase() != 'null';
  }

  static bool _hasUsableLocation(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is GeoPoint) {
      return !(location.latitude == 0.0 && location.longitude == 0.0);
    }

    if (location is String) {
      final parts = location.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        return _isUsableCoordinate(lat, lng);
      }
    }

    final lat = _asDouble(data['latitude']);
    final lng = _asDouble(data['longitude']);
    return _isUsableCoordinate(lat, lng);
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _isUsableCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}
