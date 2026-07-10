import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class EmailVerificationScreen extends StatefulWidget {
  static const routeName = '/email-verification';

  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();

  String _emailStatus = 'unverified';
  String _currentEmail = '';
  String? _pendingEmail;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _actionBusy = false;
  bool _showSentSuccess = false;
  String _error = '';
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _loadEmailStatus();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadEmailStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please sign in again to verify your email.';
      });
      return;
    }

    try {
      await user.reload();
      final refreshedUser = _auth.currentUser;
      final uid = refreshedUser?.uid;

      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .doc('email')
          .get();

      final data = snapshot.data();
      final statusFromFirestore = data?['status'] as String?;
      final pendingEmail = data?['pendingEmail'] as String?;
      final isVerified = refreshedUser?.emailVerified ?? false;

      setState(() {
        _currentEmail = refreshedUser?.email ?? '';
        _emailController.text = _currentEmail;
        _pendingEmail = pendingEmail;
        _emailStatus = isVerified
            ? 'verified'
            : statusFromFirestore ?? 'pending';
        _isLoading = false;
      });

      if (isVerified && statusFromFirestore != 'verified') {
        await _markEmailVerified();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load email verification status.';
      });
    }
  }

  Future<void> _markEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('identityVerification')
        .doc('email')
        .set({
          'status': 'verified',
          'email': user.email,
          'verifiedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'emailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Please sign in again to verify your email.');
      return;
    }

    setState(() {
      _actionBusy = true;
      _error = '';
      _showSentSuccess = false;
    });

    try {
      await user.sendEmailVerification();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('identityVerification')
          .doc('email')
          .set({
            'status': 'pending',
            'email': user.email,
            'sentAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _emailStatus = 'pending';
        _showSentSuccess = true;
      });
      _startCooldown();
      _hideSentSuccessLater();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _firebaseEmailError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not send verification email.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _requestEmailChange() async {
    final user = _auth.currentUser;
    final nextEmail = _emailController.text.trim();

    if (user == null) {
      setState(() => _error = 'Please sign in again to update your email.');
      return;
    }
    if (!_isValidEmail(nextEmail)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (nextEmail == user.email) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() {
      _actionBusy = true;
      _error = '';
      _showSentSuccess = false;
    });

    try {
      await user.verifyBeforeUpdateEmail(nextEmail);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('identityVerification')
          .doc('email')
          .set({
            'status': 'pending',
            'email': user.email,
            'pendingEmail': nextEmail,
            'sentAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _pendingEmail = nextEmail;
        _emailStatus = 'pending';
        _isEditing = false;
        _showSentSuccess = true;
      });
      _startCooldown();
      _hideSentSuccessLater();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _firebaseEmailError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not start email update verification.');
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _refreshVerificationStatus() async {
    setState(() {
      _actionBusy = true;
      _error = '';
    });

    final user = _auth.currentUser;
    try {
      await user?.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser != null && refreshedUser.emailVerified) {
        await _markEmailVerified();
        if (!mounted) return;
        setState(() {
          _currentEmail = refreshedUser.email ?? _currentEmail;
          _pendingEmail = null;
          _emailStatus = 'verified';
          _isEditing = false;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email is not verified yet. Check your inbox.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        setState(() => _cooldown = 0);
        timer.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _hideSentSuccessLater() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showSentSuccess = false);
    });
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _firebaseEmailError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'For security, please log in again before changing email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-already-in-use':
        return 'This email is already used by another account.';
      case 'too-many-requests':
        return 'Too many requests. Please wait before trying again.';
      default:
        return e.message ?? 'Email verification failed.';
    }
  }

  _EmailStatusConfig _statusConfig() {
    switch (_emailStatus) {
      case 'verified':
        return const _EmailStatusConfig(
          title: 'Email verified',
          subtitle: 'Your email is trusted for account recovery and alerts.',
          color: WorkableDesign.success,
          icon: LucideIcons.checkCircle,
        );
      case 'pending':
        return const _EmailStatusConfig(
          title: 'Verification pending',
          subtitle: 'Open the verification link from your email inbox.',
          color: WorkableDesign.warning,
          icon: LucideIcons.clock,
        );
      case 'failed':
        return const _EmailStatusConfig(
          title: 'Verification failed',
          subtitle: 'The verification link expired. Send a new link.',
          color: WorkableDesign.danger,
          icon: LucideIcons.xCircle,
        );
      default:
        return const _EmailStatusConfig(
          title: 'Email not verified',
          subtitle: 'Verify your email to secure this account.',
          color: WorkableDesign.primary,
          icon: LucideIcons.mail,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusConfig();

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Email Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context, _emailStatus == 'verified'),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                child: Column(
                  children: [
                    const WorkablePageHeader(
                      title: 'Secure email access',
                      subtitle:
                          'Use a verified email for account recovery, booking receipts, and important trust updates.',
                      icon: LucideIcons.mailCheck,
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(status),
                    const SizedBox(height: 16),
                    _buildCurrentEmailCard(),
                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      _buildEditEmailCard(),
                    ],
                    if (_emailStatus != 'verified') ...[
                      const SizedBox(height: 16),
                      _buildActionsCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildInstructionsCard(),
                    const SizedBox(height: 16),
                    _buildSupportCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard(_EmailStatusConfig status) {
    return WorkableSectionCard(
      color: status.color.withValues(alpha: 0.06),
      borderColor: status.color.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, color: status.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.title,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.subtitle,
                  style: const TextStyle(
                    color: WorkableDesign.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentEmailCard() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current email',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          WorkableInfoRow(
            icon: LucideIcons.mail,
            text: _currentEmail.isEmpty ? 'No email linked' : _currentEmail,
          ),
          if (_pendingEmail != null && _pendingEmail!.isNotEmpty) ...[
            const SizedBox(height: 10),
            WorkableStatusPill(
              label: 'Pending change: $_pendingEmail',
              color: WorkableDesign.warning,
              icon: LucideIcons.clock,
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _actionBusy
                ? null
                : () {
                    setState(() {
                      _isEditing = !_isEditing;
                      _emailController.text = _currentEmail;
                      _error = '';
                    });
                  },
            icon: const Icon(LucideIcons.edit3),
            label: Text(_isEditing ? 'Close editor' : 'Change email'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditEmailCard() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update email address',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Firebase will send a secure verification link to the new email. The change completes only after the link is opened.',
            style: TextStyle(color: WorkableDesign.muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'name@example.com'),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildError(_error),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _actionBusy ? null : _requestEmailChange,
                  child: Text(_actionBusy ? 'Sending...' : 'Send link'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _actionBusy
                      ? null
                      : () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification actions',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _actionBusy || _cooldown > 0
                ? null
                : _sendVerificationEmail,
            icon: const Icon(LucideIcons.send),
            label: Text(
              _cooldown > 0
                  ? 'Resend in ${_cooldown}s'
                  : 'Send verification link',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _actionBusy ? null : _refreshVerificationStatus,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('I clicked the link'),
          ),
          if (_showSentSuccess) ...[
            const SizedBox(height: 12),
            const WorkableStatusPill(
              label: 'Verification email sent',
              color: WorkableDesign.success,
              icon: LucideIcons.checkCircle,
            ),
          ],
          if (_error.isNotEmpty && !_isEditing) ...[
            const SizedBox(height: 12),
            _buildError(_error),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return const WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How verification works',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 12),
          WorkableInfoRow(
            icon: LucideIcons.inbox,
            text: 'Check your inbox and spam folder for the secure link.',
          ),
          SizedBox(height: 8),
          WorkableInfoRow(
            icon: LucideIcons.mousePointerClick,
            text: 'Open the link on this device, then return here.',
          ),
          SizedBox(height: 8),
          WorkableInfoRow(
            icon: LucideIcons.refreshCw,
            text: 'Tap "I clicked the link" to refresh your status.',
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard() {
    return const WorkableSectionCard(
      child: Row(
        children: [
          Icon(LucideIcons.helpCircle, color: WorkableDesign.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'If the link expires, send a new one. If email change is blocked, sign in again for security.',
              style: TextStyle(color: WorkableDesign.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(LucideIcons.alertCircle, color: WorkableDesign.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: WorkableDesign.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmailStatusConfig {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _EmailStatusConfig({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });
}
