import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/workable_design.dart';
import '../features/referral_growth/data/referral_growth_repository.dart';
import '../features/referral_growth/domain/referral_share_audit.dart';
import '../services/referral_link_service.dart';
import '../widgets/workable_ui.dart';

class ReferralProgrammeScreen extends StatefulWidget {
  static const routeName = '/referral-programme';

  const ReferralProgrammeScreen({super.key});

  @override
  State<ReferralProgrammeScreen> createState() =>
      _ReferralProgrammeScreenState();
}

class _ReferralProgrammeScreenState extends State<ReferralProgrammeScreen> {
  final _growthRepository = ReferralGrowthRepository();
  bool _copied = false;

  String _fallbackCode(User user) {
    final source = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? user.uid;
    final clean = source
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase()
        .padRight(4, 'X');
    return '${clean.substring(0, clean.length.clamp(0, 6))}${user.uid.substring(0, 4).toUpperCase()}';
  }

  _ReferralAudit _auditFrom(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return _ReferralAudit.fromDocs(docs);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _referralsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('referrals')
        .where('referrerId', isEqualTo: uid)
        .snapshots();
  }

  Future<String> _ensureReferralCode(User user) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snapshot = await userRef.get();
    final existing = snapshot.data()?['referralCode']?.toString();
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final code = _fallbackCode(user);
    await userRef.set({
      'referralCode': code,
      'referralCodeCreatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return code;
  }

  Future<void> _copyInviteText(String code) async {
    await Clipboard.setData(ClipboardData(text: _inviteText(code)));
    await _trackShare(code: code, channel: 'copy_invite');
    if (!mounted) return;
    setState(() => _copied = true);
    _showSnack('Invite text copied');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _inviteText(String code) {
    return 'Use my Workable referral code $code to book trusted local help faster: ${_inviteLink(code)}';
  }

  String _inviteLink(String code) {
    return ReferralLinkService.inviteLink(code);
  }

  Future<void> _copyReferralCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    await _trackShare(code: code, channel: 'copy_code');
    if (mounted) _showSnack('Referral code copied');
  }

  Future<void> _shareViaWhatsApp(String code) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_inviteText(code))}',
    );
    await _launchShareUri(uri, code: code, channel: 'whatsapp');
  }

  Future<void> _shareViaSms(String code) async {
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {'body': _inviteText(code)},
    );
    await _launchShareUri(uri, code: code, channel: 'sms');
  }

  Future<void> _launchShareUri(
    Uri uri, {
    required String code,
    required String channel,
  }) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) {
      await _trackShare(code: code, channel: channel);
      return;
    }

    await _copyInviteText(code);
    if (mounted) _showSnack('Share app not available. Invite copied instead.');
  }

  Future<void> _trackShare({
    required String code,
    required String channel,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _growthRepository.trackShare(
      uid: user.uid,
      code: code,
      channel: channel,
      inviteLink: _inviteLink(code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Referral Programme'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? const WorkableEmptyState(
              icon: LucideIcons.gift,
              title: 'Sign in required',
              message: 'Please sign in to access your referral programme.',
            )
          : FutureBuilder<String>(
              future: _ensureReferralCode(user),
              builder: (context, codeSnapshot) {
                if (codeSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final code = codeSnapshot.data ?? _fallbackCode(user);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _referralsStream(user.uid),
                  builder: (context, referralSnapshot) {
                    final docs = referralSnapshot.data?.docs ?? [];
                    final audit = _auditFrom(docs);

                    return StreamBuilder<ReferralShareAudit>(
                      stream: _growthRepository.watchShareAudit(user.uid),
                      builder: (context, shareSnapshot) {
                        final shareAudit =
                            shareSnapshot.data ??
                            const ReferralShareAudit(
                              totalShares: 0,
                              whatsAppShares: 0,
                              smsShares: 0,
                              copyInviteShares: 0,
                              copyCodeShares: 0,
                              lastShareAt: null,
                            );

                        return ListView(
                          padding: const EdgeInsets.all(
                            WorkableDesign.pagePadding,
                          ),
                          children: [
                            const WorkablePageHeader(
                              title: 'Invite trusted people',
                              subtitle:
                                  'Share Workable when someone needs help. They get a smoother first booking, you grow the community.',
                              icon: LucideIcons.gift,
                            ),
                            const SizedBox(height: 16),
                            _buildCodeCard(code),
                            const SizedBox(height: 16),
                            _buildStats(audit),
                            const SizedBox(height: 16),
                            _buildShareAudit(shareAudit),
                            const SizedBox(height: 16),
                            _buildCommunityImpact(audit),
                            const SizedBox(height: 16),
                            _buildRewardSummary(audit),
                            const SizedBox(height: 16),
                            _buildPeopleSummary(audit),
                            const SizedBox(height: 16),
                            _buildHowItWorks(),
                            const SizedBox(height: 16),
                            _buildShareCard(code),
                            const SizedBox(height: 16),
                            _buildHistory(audit),
                            const SizedBox(height: 16),
                            _buildTermsNote(),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildCodeCard(String code) {
    return WorkableSectionCard(
      color: WorkableDesign.ink,
      borderColor: WorkableDesign.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your referral code',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _copyInviteText(code),
                icon: Icon(_copied ? LucideIcons.check : LucideIcons.copy),
                label: Text(_copied ? 'Copied' : 'Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(_ReferralAudit audit) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _statCard(
          LucideIcons.users,
          '${audit.totalJoined}',
          'Total joined',
          WorkableDesign.primary,
        ),
        _statCard(
          LucideIcons.user,
          '${audit.customerJoined}',
          'Customers',
          WorkableDesign.success,
        ),
        _statCard(
          LucideIcons.hardHat,
          '${audit.workerJoined}',
          'Workers',
          WorkableDesign.accent,
        ),
        _statCard(
          LucideIcons.clock,
          '${audit.pending}',
          'Pending',
          WorkableDesign.warning,
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 52) / 2,
      child: WorkableSectionCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: WorkableDesign.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityImpact(_ReferralAudit audit) {
    final badge = _impactBadge(audit);
    final nextTarget = _nextImpactTarget(audit);

    return WorkableSectionCard(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(badge.icon, color: badge.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Community Impact',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      badge.label,
                      style: TextStyle(
                        color: badge.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _impactMessage(audit),
            style: const TextStyle(
              color: WorkableDesign.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _impactMetric(
                  LucideIcons.hardHat,
                  '${audit.workerJoined}',
                  'Workers added',
                  WorkableDesign.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _impactMetric(
                  LucideIcons.userPlus,
                  '${audit.customerJoined}',
                  'Customers helped',
                  WorkableDesign.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WorkableInfoRow(icon: LucideIcons.target, text: nextTarget),
        ],
      ),
    );
  }

  Widget _buildShareAudit(ReferralShareAudit audit) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share audit',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _rewardMetric(
                  'Total shares',
                  '${audit.totalShares}',
                  WorkableDesign.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rewardMetric(
                  'WhatsApp',
                  '${audit.whatsAppShares}',
                  WorkableDesign.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _rewardMetric(
                  'SMS',
                  '${audit.smsShares}',
                  WorkableDesign.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rewardMetric(
                  'Copied',
                  '${audit.copyInviteShares + audit.copyCodeShares}',
                  WorkableDesign.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WorkableInfoRow(
            icon: LucideIcons.share2,
            text: audit.hasShares
                ? 'Every share is recorded so future campaigns can reward genuine growth.'
                : 'Share your invite to start building your referral audit.',
          ),
        ],
      ),
    );
  }

  Widget _impactMetric(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ImpactBadge _impactBadge(_ReferralAudit audit) {
    if (audit.totalJoined >= 25 || audit.workerJoined >= 10) {
      return const _ImpactBadge(
        label: 'Local Growth Partner',
        icon: LucideIcons.trophy,
        color: WorkableDesign.success,
      );
    }
    if (audit.totalJoined >= 10 || audit.workerJoined >= 3) {
      return const _ImpactBadge(
        label: 'Trusted Connector',
        icon: LucideIcons.badgeCheck,
        color: WorkableDesign.primary,
      );
    }
    if (audit.totalJoined >= 1) {
      return const _ImpactBadge(
        label: 'Community Builder',
        icon: LucideIcons.users,
        color: WorkableDesign.accent,
      );
    }
    return const _ImpactBadge(
      label: 'Start your help circle',
      icon: LucideIcons.sparkles,
      color: WorkableDesign.warning,
    );
  }

  String _impactMessage(_ReferralAudit audit) {
    if (audit.totalJoined == 0) {
      return 'Invite people you trust. Every customer or worker who joins through you strengthens your local help circle.';
    }
    if (audit.workerJoined > 0) {
      return 'You helped add ${audit.workerJoined} worker${audit.workerJoined == 1 ? '' : 's'} and ${audit.customerJoined} customer${audit.customerJoined == 1 ? '' : 's'} to Workable.';
    }
    return 'You helped ${audit.customerJoined} customer${audit.customerJoined == 1 ? '' : 's'} discover Workable. Add trusted workers next to make help faster nearby.';
  }

  String _nextImpactTarget(_ReferralAudit audit) {
    if (audit.totalJoined >= 25 || audit.workerJoined >= 10) {
      return 'Top tier reached. Future admin rewards can use this badge for special campaigns.';
    }
    if (audit.totalJoined >= 10 || audit.workerJoined >= 3) {
      final remaining = (25 - audit.totalJoined).clamp(0, 25);
      return 'Next badge: Local Growth Partner. Add $remaining more people or reach 10 workers.';
    }
    if (audit.totalJoined >= 1) {
      final remaining = (10 - audit.totalJoined).clamp(0, 10);
      return 'Next badge: Trusted Connector. Add $remaining more people or refer 3 workers.';
    }
    return 'First milestone: invite 1 customer or worker to become a Community Builder.';
  }

  Widget _buildRewardSummary(_ReferralAudit audit) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reward audit',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _rewardMetric(
                  'Ready for review',
                  'Rs ${audit.readyAmount.round()}',
                  WorkableDesign.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _rewardMetric(
                  'Credited history',
                  'Rs ${audit.paidAmount.round()}',
                  WorkableDesign.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          WorkableInfoRow(
            icon: LucideIcons.shieldCheck,
            text:
                '${audit.readyCount} reward${audit.readyCount == 1 ? '' : 's'} waiting for admin credit. Credited rewards stay in history so you can audit them later.',
          ),
        ],
      ),
    );
  }

  Widget _rewardMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: WorkableDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleSummary(_ReferralAudit audit) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People joined through you',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _smallCountRow('Customers joined', audit.customerJoined),
          _smallCountRow('Workers joined', audit.workerJoined),
          _smallCountRow('Rewards waiting', audit.readyCount),
          _smallCountRow('Rewards credited', audit.paidCount),
        ],
      ),
    );
  }

  Widget _smallCountRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: WorkableDesign.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    const steps = [
      ('Share your code', 'Send your referral code to a friend.'),
      ('Friend books help', 'They sign up and complete their first booking.'),
      ('Rewards unlock', 'Credits are added after successful completion.'),
    ];

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: WorkableDesign.primary.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: WorkableDesign.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$1,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          step.$2,
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
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShareCard(String code) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share invite',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Send a ready invite through WhatsApp, SMS, or copy it for any social app.',
            style: TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WorkableDesign.canvas,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: WorkableDesign.border),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.link,
                  color: WorkableDesign.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _inviteLink(code),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _shareViaWhatsApp(code),
                  icon: const Icon(LucideIcons.messageCircle),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareViaSms(code),
                  icon: const Icon(LucideIcons.messageSquare),
                  label: const Text('SMS'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyInviteText(code),
                  icon: const Icon(LucideIcons.copy),
                  label: const Text('Copy invite'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _copyReferralCode(code),
                  icon: const Icon(LucideIcons.badgePercent),
                  label: const Text('Copy code'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(_ReferralAudit audit) {
    if (audit.docs.isEmpty) {
      return const WorkableEmptyState(
        icon: LucideIcons.users,
        title: 'No referrals yet',
        message:
            'Referral activity will appear here when friends use your code.',
      );
    }

    final sorted = audit.docs.toList()
      ..sort((a, b) {
        final ad = _dateFrom(a.data()['createdAt']);
        final bd = _dateFrom(b.data()['createdAt']);
        return bd.compareTo(ad);
      });

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referral history',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((doc) => _historyItem(doc.data())),
        ],
      ),
    );
  }

  Widget _historyItem(Map<String, dynamic> data) {
    final status = data['status']?.toString() ?? 'pending';
    final color = status == 'completed'
        ? WorkableDesign.success
        : status == 'rejected'
        ? WorkableDesign.danger
        : WorkableDesign.warning;
    final label = status == 'pending_first_paid_booking'
        ? 'first booking pending'
        : status == 'pending_worker_onboarding'
        ? 'worker onboarding pending'
        : status.replaceAll('_', ' ');
    final name =
        data['friendName']?.toString() ??
        data['referredUserName']?.toString() ??
        'Friend';
    final reward = data['rewardAmount'] is num
        ? 'Rs ${(data['rewardAmount'] as num).round()}'
        : 'Pending';
    final rewardStatus = data['rewardStatus']?.toString() ?? 'locked';
    final role = data['referredUserRole']?.toString() ?? 'customer';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                (role == 'worker'
                        ? WorkableDesign.accent
                        : WorkableDesign.primary)
                    .withValues(alpha: 0.1),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: WorkableDesign.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  '$role - $reward - ${rewardStatus.replaceAll('_', ' ')}',
                  style: const TextStyle(color: WorkableDesign.muted),
                ),
              ],
            ),
          ),
          WorkableStatusPill(label: label, color: color),
        ],
      ),
    );
  }

  Widget _buildTermsNote() {
    return const WorkableSectionCard(
      child: WorkableInfoRow(
        icon: LucideIcons.info,
        text:
            'Referral rewards should be credited only after a valid first booking is completed and payment is confirmed.',
      ),
    );
  }

  DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'F';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ReferralAudit {
  const _ReferralAudit({
    required this.docs,
    required this.totalJoined,
    required this.customerJoined,
    required this.workerJoined,
    required this.pending,
    required this.readyCount,
    required this.readyAmount,
    required this.paidCount,
    required this.paidAmount,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final int totalJoined;
  final int customerJoined;
  final int workerJoined;
  final int pending;
  final int readyCount;
  final num readyAmount;
  final int paidCount;
  final num paidAmount;

  factory _ReferralAudit.fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var customerJoined = 0;
    var workerJoined = 0;
    var pending = 0;
    var readyCount = 0;
    num readyAmount = 0;
    var paidCount = 0;
    num paidAmount = 0;

    for (final doc in docs) {
      final data = doc.data();
      final role = data['referredUserRole']?.toString() ?? 'customer';
      final status = data['status']?.toString() ?? '';
      final rewardStatus = data['rewardStatus']?.toString() ?? 'locked';
      final reward = data['rewardAmount'] is num
          ? data['rewardAmount'] as num
          : 0;

      if (role == 'worker') {
        workerJoined++;
      } else {
        customerJoined++;
      }

      if (status == 'pending' ||
          status == 'pending_first_paid_booking' ||
          status == 'pending_worker_onboarding') {
        pending++;
      }

      if (rewardStatus == 'ready_for_credit') {
        readyCount++;
        readyAmount += reward;
      }

      if (rewardStatus == 'credited' ||
          rewardStatus == 'paid' ||
          rewardStatus == 'reward_paid') {
        paidCount++;
        paidAmount += reward;
      }
    }

    return _ReferralAudit(
      docs: docs,
      totalJoined: docs.length,
      customerJoined: customerJoined,
      workerJoined: workerJoined,
      pending: pending,
      readyCount: readyCount,
      readyAmount: readyAmount,
      paidCount: paidCount,
      paidAmount: paidAmount,
    );
  }
}

class _ImpactBadge {
  const _ImpactBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
