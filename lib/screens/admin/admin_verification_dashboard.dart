import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/features/admin_demand/presentation/admin_demand_review_screen.dart';
import 'package:workable/features/admin_referrals/presentation/admin_referral_reward_screen.dart';
import 'package:workable/screens/admin/admin_payout_review_screen.dart';
import 'package:workable/screens/admin/admin_payment_review_screen.dart';
import 'package:workable/screens/admin/verification_review_screen.dart';
import 'package:workable/widgets/workable_ui.dart';

class AdminVerificationDashboard extends StatefulWidget {
  static const routeName = '/admin-verification-dashboard';

  const AdminVerificationDashboard({super.key});

  @override
  State<AdminVerificationDashboard> createState() =>
      _AdminVerificationDashboardState();
}

class _AdminVerificationDashboardState
    extends State<AdminVerificationDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  Future<List<Map<String, dynamic>>> _loadPendingRequests() async {
    final snapshot = await _firestore
        .collection('adminVerificationQueue')
        .where('status', isEqualTo: 'pending')
        .orderBy('submittedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return {'requestId': doc.id, ...doc.data()};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Verification Queue'),
        actions: [
          IconButton(
            tooltip: 'Payment review',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.pushNamed(context, AdminPaymentReviewScreen.routeName);
            },
          ),
          IconButton(
            tooltip: 'Payout review',
            icon: const Icon(LucideIcons.wallet),
            onPressed: () {
              Navigator.pushNamed(context, AdminPayoutReviewScreen.routeName);
            },
          ),
          IconButton(
            tooltip: 'Demand review',
            icon: const Icon(LucideIcons.radar),
            onPressed: () {
              Navigator.pushNamed(context, AdminDemandReviewScreen.routeName);
            },
          ),
          IconButton(
            tooltip: 'Referral rewards',
            icon: const Icon(LucideIcons.badgePercent),
            onPressed: () {
              Navigator.pushNamed(context, AdminReferralRewardScreen.routeName);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return WorkableEmptyState(
              icon: LucideIcons.alertTriangle,
              title: 'Unable to load queue',
              message: snapshot.error.toString(),
            );
          }

          final requests = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              WorkablePageHeader(
                title:
                    '${requests.length} pending request${requests.length == 1 ? '' : 's'}',
                subtitle:
                    'Review worker/customer identity submissions before marketplace visibility changes.',
                icon: LucideIcons.shieldCheck,
              ),
              const SizedBox(height: 16),
              if (requests.isEmpty)
                const WorkableEmptyState(
                  icon: LucideIcons.inbox,
                  title: 'No pending requests',
                  message:
                      'New verification submissions will appear here for admin review.',
                )
              else
                ...requests.map(_buildRequestCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final documentData = request['documentData'] is Map
        ? Map<String, dynamic>.from(request['documentData'])
        : <String, dynamic>{};
    final submittedAt = _dateLabel(
      documentData['submittedAt'] ?? request['submittedAt'],
    );
    final profileImageUrl = request['profileImageUrl']?.toString() ?? '';
    final userName = request['userName']?.toString() ?? 'Unknown user';
    final uid = request['uid']?.toString() ?? '';
    final documentId = request['documentId']?.toString() ?? 'document';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
          onTap: uid.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerificationReviewScreen(uid: uid),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: WorkableDesign.primary.withValues(
                        alpha: 0.1,
                      ),
                      backgroundImage: profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: profileImageUrl.isEmpty
                          ? Text(
                              userName.characters.first.toUpperCase(),
                              style: const TextStyle(
                                color: WorkableDesign.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              color: WorkableDesign.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            request['email']?.toString() ?? '',
                            style: const TextStyle(color: WorkableDesign.muted),
                          ),
                        ],
                      ),
                    ),
                    WorkableStatusPill(
                      label: 'Pending',
                      color: WorkableDesign.warning,
                      icon: LucideIcons.clock,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WorkableStatusPill(
                      label: documentId.toUpperCase(),
                      color: WorkableDesign.primary,
                      icon: LucideIcons.fileText,
                    ),
                    if ((request['phoneNumber']?.toString() ?? '').isNotEmpty)
                      WorkableStatusPill(
                        label: request['phoneNumber'].toString(),
                        color: WorkableDesign.accent,
                        icon: LucideIcons.phone,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                WorkableInfoRow(
                  icon: LucideIcons.user,
                  text: 'Document name: ${documentData['name'] ?? '-'}',
                ),
                const SizedBox(height: 8),
                WorkableInfoRow(
                  icon: LucideIcons.hash,
                  text: 'Document number: ${documentData['number'] ?? '-'}',
                ),
                const SizedBox(height: 8),
                WorkableInfoRow(
                  icon: LucideIcons.calendar,
                  text: 'Submitted: $submittedAt',
                ),
                if ((documentData['imageUrl']?.toString() ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(WorkableDesign.radius),
                    child: Image.network(
                      documentData['imageUrl'].toString(),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(dynamic value) {
    if (value is Timestamp) return _dateFormat.format(value.toDate());
    if (value is String && value.trim().isNotEmpty) return value;
    return 'Unknown';
  }
}
