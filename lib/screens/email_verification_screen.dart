import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailVerificationScreen extends StatefulWidget {
  static const routeName = '/email-verification';

  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  String emailStatus =
      'pending'; // 'verified', 'pending', 'failed', 'unverified'
  String currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

  String newEmail = '';
  bool isEditing = false;
  bool showResendSuccess = false;
  int resendCooldown = 0;
  List<String> verificationCode = List.filled(6, '');

  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void startResendCooldown() {
    setState(() => resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => resendCooldown--);
      }
    });
  }

  // void handleResendEmail() {
  //   setState(() {
  //     showResendSuccess = true;
  //   });
  //   startResendCooldown();
  //   Future.delayed(const Duration(seconds: 3), () {
  //     setState(() {
  //       showResendSuccess = false;
  //     });
  //   });
  // }

  void handleEmailUpdate() {
    setState(() {
      currentEmail = newEmail;
      emailStatus = 'pending';
      isEditing = false;
      newEmail = '';
    });
  }

  void handleCodeChange(int index, String value) {
    if (value.length <= 1) {
      setState(() {
        verificationCode[index] = value;
      });
      if (value.isNotEmpty && index < 5) {
        FocusScope.of(context).nextFocus();
      }
    }
  }

  void _sendEmailVerificationLink() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.sendEmailVerification();

    // Set Firestore status to pending
    final uid = user?.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc('email')
        .set({'status': 'pending'});
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    if (user != null && user.emailVerified) {
      final uid = user.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .doc('email')
          .set({'status': 'verified'});

      setState(() {
        emailStatus = 'verified';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email not verified yet. Try again.")),
      );
    }
  }

  void handleResendEmail() {
    _sendEmailVerificationLink();
    setState(() => showResendSuccess = true);
    startResendCooldown();
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => showResendSuccess = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadEmailStatus();
  }

  Future<void> _loadEmailStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('identityVerification')
        .doc('email')
        .get();

    if (snapshot.exists) {
      setState(() {
        emailStatus = snapshot.data()?['status'] ?? 'unverified';
      });
    }
  }

  Map<String, dynamic> getStatusConfig() {
    switch (emailStatus) {
      case 'verified':
        return {
          'color': Colors.green.shade600,
          'bgColor': Colors.green.shade50,
          'icon': LucideIcons.checkCircle,
          'title': 'Email Verified',
          'subtitle': 'Your email address has been successfully verified',
        };
      case 'pending':
        return {
          'color': Colors.orange.shade600,
          'bgColor': Colors.orange.shade50,
          'icon': LucideIcons.clock,
          'title': 'Verification Pending',
          'subtitle': 'Check your email and click the verification link',
        };
      case 'failed':
        return {
          'color': Colors.red.shade600,
          'bgColor': Colors.red.shade50,
          'icon': LucideIcons.xCircle,
          'title': 'Verification Failed',
          'subtitle': 'The verification link has expired or is invalid',
        };
      default:
        return {
          'color': Colors.grey.shade600,
          'bgColor': Colors.grey.shade100,
          'icon': LucideIcons.mail,
          'title': 'Email Not Verified',
          'subtitle': 'Please verify your email address to continue',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = getStatusConfig();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Email Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          //onPressed: () => Navigator.pop(context),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(LucideIcons.helpCircle),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusConfig['bgColor'],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      statusConfig['icon'],
                      color: statusConfig['color'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusConfig['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusConfig['subtitle'],
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Current Email
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Email Address',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mail,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(currentEmail)),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.edit3,
                          size: 18,
                          color: Colors.blue,
                        ),
                        onPressed: () => setState(() => isEditing = true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Email Address',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Enter new email',
                      ),
                      onChanged: (value) => setState(() => newEmail = value),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: handleEmailUpdate,
                            child: const Text('Update Email'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => isEditing = false),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (emailStatus != 'verified') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Actions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: resendCooldown > 0 ? null : handleResendEmail,
                      icon: const Icon(LucideIcons.send),
                      label: Text(
                        resendCooldown > 0
                            ? 'Resend in ${resendCooldown}s'
                            : 'Resend Verification Email',
                      ),
                    ),
                    if (showResendSuccess)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: const [
                            Icon(
                              LucideIcons.checkCircle,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Verification email sent successfully!',
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (emailStatus == 'pending') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Verification Code',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text('Enter the 6-digit code sent to your email'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 45,
                          child: TextField(
                            maxLength: 1,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(counterText: ''),
                            onChanged: (value) =>
                                handleCodeChange(index, value),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Verify logic
                      },
                      child: const Text('Verify Code'),
                    ),

                    TextButton.icon(
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text("Refresh Status"),
                      onPressed: _checkEmailVerified,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Instruction steps
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'How to Verify Your Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  ListTile(
                    leading: CircleAvatar(
                      child: Text('1'),
                      backgroundColor: Colors.blue,
                    ),
                    title: Text(
                      'Check your email inbox for a verification message',
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      child: Text('2'),
                      backgroundColor: Colors.blue,
                    ),
                    title: Text(
                      'Click the verification link or enter the code',
                    ),
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      child: Text('3'),
                      backgroundColor: Colors.blue,
                    ),
                    title: Text(
                      'Your email will be marked as verified automatically',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Troubleshooting
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Didn\'t Receive the Email?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  ListTile(
                    leading: Icon(LucideIcons.alertCircle, color: Colors.amber),
                    title: Text('Check your spam/junk folder'),
                  ),
                  ListTile(
                    leading: Icon(LucideIcons.alertCircle, color: Colors.amber),
                    title: Text('Make sure your email address is correct'),
                  ),
                  ListTile(
                    leading: Icon(LucideIcons.alertCircle, color: Colors.amber),
                    title: Text('Wait a few minutes, emails can be delayed'),
                  ),
                  ListTile(
                    leading: Icon(LucideIcons.alertCircle, color: Colors.amber),
                    title: Text('Try resending the verification email'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Why verify
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEDF4FF), Color(0xFFEDEBFF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.shield, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        'Why Verify Your Email?',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(LucideIcons.check, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Secure account recovery'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(LucideIcons.check, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Receive important notifications'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(LucideIcons.check, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Build trust on platform'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(LucideIcons.check, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Access all features'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Support
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(LucideIcons.helpCircle, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still Having Issues?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Our support team is here to help',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Help navigation
                    },
                    child: const Text('Get Help'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
