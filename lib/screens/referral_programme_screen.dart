import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class ReferralProgrammeScreen extends StatefulWidget {
  static const routeName = '/referral-programme';

  const ReferralProgrammeScreen({super.key});

  @override
  State<ReferralProgrammeScreen> createState() =>
      _ReferralProgrammeScreenState();
}

class _ReferralProgrammeScreenState extends State<ReferralProgrammeScreen> {
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
    return 'https://workable.app/invite?ref=${Uri.encodeComponent(code)}';
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

    final now = FieldValue.serverTimestamp();
    final firestore = FirebaseFirestore.instance;
    final eventRef = firestore.collection('referralShareEvents').doc();
    final userRef = firestore.collection('users').doc(user.uid);

    await firestore.runTransaction((transaction) async {
      transaction.set(eventRef, {
        'referrerId': user.uid,
        'referralCode': code,
        'channel': channel,
        'inviteLink': _inviteLink(code),
        'status': 'shared',
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.set(userRef, {
        'referralShareCount': FieldValue.increment(1),
        'lastReferralShareAt': now,
        'lastReferralShareChannel': channel,
        'updatedAt': now,
      }, SetOptions(merge: true));
    });
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
                    final completed = docs
                        .where((doc) => doc.data()['status'] == 'completed')
                        .length;
                    final pending = docs.where((doc) {
                      final status = doc.data()['status']?.toString() ?? '';
                      return status == 'pending' ||
                          status == 'pending_first_paid_booking';
                    }).length;
                    final earned = docs.fold<num>(0, (total, doc) {
                      final data = doc.data();
                      final reward = data['rewardAmount'];
                      if (data['status'] == 'completed' && reward is num) {
                        return total + reward;
                      }
                      return total;
                    });

                    return ListView(
                      padding: const EdgeInsets.all(WorkableDesign.pagePadding),
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
                        _buildStats(completed, pending, earned),
                        const SizedBox(height: 16),
                        _buildHowItWorks(),
                        const SizedBox(height: 16),
                        _buildShareCard(code),
                        const SizedBox(height: 16),
                        _buildHistory(docs),
                        const SizedBox(height: 16),
                        _buildTermsNote(),
                      ],
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

  Widget _buildStats(int completed, int pending, num earned) {
    return Row(
      children: [
        _statCard(
          LucideIcons.checkCircle,
          completed.toString(),
          'Completed',
          WorkableDesign.success,
        ),
        const SizedBox(width: 10),
        _statCard(
          LucideIcons.clock,
          pending.toString(),
          'Pending',
          WorkableDesign.warning,
        ),
        const SizedBox(width: 10),
        _statCard(
          LucideIcons.wallet,
          'Rs ${earned.round()}',
          'Earned',
          WorkableDesign.primary,
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
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

  Widget _buildHistory(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) {
      return const WorkableEmptyState(
        icon: LucideIcons.users,
        title: 'No referrals yet',
        message:
            'Referral activity will appear here when friends use your code.',
      );
    }

    final sorted = docs.toList()
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
            'Recent referrals',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.take(5).map((doc) => _historyItem(doc.data())),
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
        : status.replaceAll('_', ' ');
    final name =
        data['friendName']?.toString() ??
        data['referredUserName']?.toString() ??
        'Friend';
    final reward = data['rewardAmount'] is num
        ? 'Rs ${(data['rewardAmount'] as num).round()}'
        : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: WorkableDesign.primary.withValues(alpha: 0.1),
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
                  reward,
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
