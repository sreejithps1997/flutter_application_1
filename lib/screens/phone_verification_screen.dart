import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';

class PhoneVerificationScreen extends StatefulWidget {
  static const routeName = '/phone-verification';

  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  String _step = 'enter';
  String _phoneNumber = '';
  String _verificationId = '';
  int _timer = 30;
  int _attempts = 0;
  bool _canResend = false;
  bool _isLoading = false;
  String _error = '';
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _timer = 30;
      _canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_timer > 1) {
        setState(() => _timer--);
      } else {
        setState(() {
          _timer = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    final digitsOnly = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _phoneNumber = digitsOnly;
      if (isResend) {
        for (final controller in _otpControllers) {
          controller.clear();
        }
      }
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$digitsOnly',
        timeout: const Duration(seconds: 60),
        verificationCompleted: _authenticateWithCredential,
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _error = e.message ?? 'Phone verification failed.';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _step = 'verify';
            _verificationId = verificationId;
          });
          _startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not send OTP. Please try again.';
      });
    }
  }

  Future<void> _authenticateWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        await currentUser.updatePhoneNumber(credential);
      } else {
        await _auth.signInWithCredential(credential);
      }

      await _markPhoneVerified();

      if (!mounted) return;
      setState(() {
        _step = 'success';
        _isLoading = false;
        _error = '';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _attempts++;
        _error = _firebasePhoneError(e);
        _clearOtp();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Phone verification failed. Please try again.';
        _clearOtp();
      });
    }
  }

  Future<void> _markPhoneVerified() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final phone = '+91$_phoneNumber';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc('phone')
        .set({
          'status': 'verified',
          'phone': phone,
          'verifiedAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'phoneNumber': phone,
      'phoneVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _firebasePhoneError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check the code and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new code.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before trying again.';
      default:
        return e.message ?? 'Phone verification failed.';
    }
  }

  void _clearOtp() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
  }

  void _handleOtpChange(int index, String value) {
    final digit = value.replaceAll(RegExp(r'\D'), '');
    if (digit != value) {
      _otpControllers[index].text = digit;
      _otpControllers[index].selection = TextSelection.collapsed(
        offset: digit.length,
      );
    }

    if (digit.isNotEmpty && index < 5) {
      FocusScope.of(context).nextFocus();
    }

    final code = _otpControllers.map((controller) => controller.text).join();
    if (code.length == 6 && !_isLoading) {
      _verifyOtp(code);
    }
  }

  Future<void> _verifyOtp(String code) async {
    if (_verificationId.isEmpty) {
      setState(() => _error = 'OTP session expired. Please resend the code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: code,
    );
    await _authenticateWithCredential(credential);
  }

  String _formatTimer(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Phone Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (_step == 'enter') {
              Navigator.pop(context);
            } else {
              setState(() => _step = 'enter');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          child: Column(
            children: [
              const WorkablePageHeader(
                title: 'Secure phone access',
                subtitle:
                    'Verify your mobile number so booking calls, alerts, and account recovery stay trusted.',
                icon: LucideIcons.phone,
              ),
              const SizedBox(height: 16),
              _buildStepIndicator(),
              const SizedBox(height: 16),
              WorkableSectionCard(
                child: _step == 'enter'
                    ? _buildEnterPhone()
                    : _step == 'verify'
                    ? _buildVerifyOtp()
                    : _buildSuccess(),
              ),
              const SizedBox(height: 16),
              _buildSupportCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['enter', 'verify', 'success'];
    final labels = ['Phone', 'OTP', 'Done'];
    final currentIndex = steps.indexOf(_step);

    return WorkableSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: List.generate(3, (index) {
          final isCompleted = index < currentIndex;
          final isActive = index == currentIndex;
          final color = isCompleted || isActive
              ? WorkableDesign.primary
              : WorkableDesign.border;

          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            LucideIcons.check,
                            size: 15,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : WorkableDesign.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: isActive || isCompleted
                          ? WorkableDesign.ink
                          : WorkableDesign.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEnterPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconTitle(
          icon: LucideIcons.smartphone,
          title: 'Verify your mobile number',
          subtitle: 'We will send a real Firebase SMS OTP to this number.',
        ),
        const SizedBox(height: 20),
        const Text(
          'Mobile number',
          style: TextStyle(
            color: WorkableDesign.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            prefixText: '+91 ',
            hintText: 'Enter 10-digit mobile number',
            counterText: '',
          ),
          onChanged: (_) => setState(() => _error = ''),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildErrorText(_error),
        ],
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: LucideIcons.info,
          title: 'Why this matters',
          points: const [
            'Workers and customers can coordinate safely.',
            'You receive critical booking and payment updates.',
            'Your account recovery becomes more secure.',
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _isLoading ? null : () => _sendOtp(),
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(LucideIcons.send),
          label: Text(_isLoading ? 'Sending OTP...' : 'Send SMS OTP'),
        ),
      ],
    );
  }

  Widget _buildVerifyOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIconTitle(
          icon: LucideIcons.messageSquare,
          title: 'Enter OTP',
          subtitle: 'Code sent to +91 $_phoneNumber',
        ),
        TextButton(
          onPressed: _isLoading ? null : () => setState(() => _step = 'enter'),
          child: const Text('Edit phone number'),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44,
              child: TextField(
                controller: _otpControllers[index],
                maxLength: 1,
                enabled: !_isLoading,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (value) => _handleOtpChange(index, value),
              ),
            );
          }),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildErrorText(_attempts >= 3 ? '$_error Try again later.' : _error),
        ],
        const SizedBox(height: 16),
        if (_isLoading)
          const CircularProgressIndicator()
        else if (_canResend)
          TextButton.icon(
            onPressed: () => _sendOtp(isResend: true),
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Resend OTP'),
          )
        else
          Text(
            'Resend OTP in ${_formatTimer(_timer)}',
            style: const TextStyle(color: WorkableDesign.muted),
          ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        _buildIconTitle(
          icon: LucideIcons.checkCircle,
          title: 'Phone verified',
          subtitle: '+91 $_phoneNumber is now linked to your account.',
          color: WorkableDesign.success,
        ),
        const SizedBox(height: 18),
        _buildInfoCard(
          icon: LucideIcons.shieldCheck,
          title: 'Account trust improved',
          points: const [
            'Booking coordination is easier.',
            'Important payment alerts can reach you.',
            'Your verification profile is stronger.',
          ],
          color: WorkableDesign.success,
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Back to Verification'),
        ),
      ],
    );
  }

  Widget _buildIconTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = WorkableDesign.primary,
  }) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(WorkableDesign.radius),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: WorkableDesign.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: WorkableDesign.muted, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<String> points,
    Color color = WorkableDesign.primary,
  }) {
    return Container(
      decoration: WorkableDesign.cardDecoration(
        color: color.withValues(alpha: 0.06),
        borderColor: color.withValues(alpha: 0.18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: WorkableInfoRow(icon: LucideIcons.check, text: point),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorText(String message) {
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

  Widget _buildSupportCard() {
    return const WorkableSectionCard(
      child: Row(
        children: [
          Icon(LucideIcons.helpCircle, color: WorkableDesign.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'If OTP delivery fails repeatedly, wait a few minutes and try again from an active mobile network.',
              style: TextStyle(color: WorkableDesign.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
