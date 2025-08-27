import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneVerificationScreen extends StatefulWidget {
  static const routeName = '/phone-verification';

  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  String step = 'enter'; // enter, verify, success
  String phoneNumber = '';
  List<String> otp = List.filled(6, '');
  int timer = 30;
  bool canResend = false;
  String verificationMethod = 'sms'; // sms or call
  int attempts = 0;
  String error = '';
  bool isLoading = false;
  Timer? countdownTimer;

  String _verificationId = '';
  FirebaseAuth auth = FirebaseAuth.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  void startTimer() {
    setState(() {
      timer = 30;
      canResend = false;
    });
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timer > 1) {
        setState(() => timer--);
      } else {
        setState(() {
          timer = 0;
          canResend = true;
        });
        countdownTimer?.cancel();
      }
    });
  }

  // void handlePhoneSubmit() {
  //   if (phoneNumber.length == 10) {
  //     setState(() {
  //       isLoading = true;
  //       error = '';
  //     });
  //     Future.delayed(const Duration(seconds: 2), () {
  //       setState(() {
  //         isLoading = false;
  //         step = 'verify';
  //         otp = List.filled(6, '');
  //         startTimer();
  //       });
  //     });
  //   } else {
  //     setState(() {
  //       error = 'Please enter a valid 10-digit phone number';
  //     });
  //   }
  // }

  void handlePhoneSubmit() async {
    if (phoneNumber.length == 10) {
      setState(() {
        isLoading = true;
        error = '';
      });

      try {
        await auth.verifyPhoneNumber(
          phoneNumber: '+91$phoneNumber',
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-retrieval or instant verification
            await auth.signInWithCredential(credential);
            onVerificationSuccess();
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() {
              isLoading = false;
              error = e.message ?? 'Verification failed';
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              isLoading = false;
              step = 'verify';
              _verificationId = verificationId;
              startTimer();
            });
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      } catch (e) {
        setState(() {
          isLoading = false;
          error = 'Something went wrong: $e';
        });
      }
    } else {
      setState(() {
        error = 'Please enter a valid 10-digit phone number';
      });
    }
  }

  void handleOtpChange(int index, String value) {
    if (value.length == 1 && RegExp(r'\d').hasMatch(value)) {
      setState(() {
        otp[index] = value;
      });

      if (index < 5) FocusScope.of(context).nextFocus();

      if (otp.every((d) => d.isNotEmpty)) {
        handleOtpVerify(otp.join());
      }
    }
  }

  // void handleOtpVerify(String enteredOtp) {
  //   setState(() {
  //     isLoading = true;
  //     error = '';
  //   });
  //   Future.delayed(const Duration(seconds: 2), () {
  //     setState(() {
  //       isLoading = false;
  //       if (enteredOtp == '123456') {
  //         step = 'success';
  //       } else {
  //         attempts++;
  //         error = attempts >= 3
  //             ? 'Too many failed attempts. Please try again later.'
  //             : 'Invalid OTP. Please try again.';
  //         otp = List.filled(6, '');
  //       }
  //     });
  //   });
  // }

  Future<void> onVerificationSuccess() async {
    final uid = currentUser?.uid;

    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('identityVerification')
          .doc('phone')
          .set({
            'status': 'verified',
            'verifiedAt': Timestamp.now(),
            'phone': '+91$phoneNumber',
          });
    }

    setState(() {
      step = 'success';
      isLoading = false;
    });
  }

  void handleOtpVerify(String enteredOtp) async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: enteredOtp,
      );

      await auth.signInWithCredential(credential);
      await onVerificationSuccess();
    } catch (e) {
      setState(() {
        isLoading = false;
        attempts++;
        error = attempts >= 3
            ? 'Too many failed attempts. Please try again later.'
            : 'Invalid OTP. Please try again.';
        otp = List.filled(6, '');
      });
    }
  }

  void handleResendOtp() {
    setState(() {
      isLoading = true;
      error = '';
      otp = List.filled(6, '');
    });
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
        startTimer();
      });
    });
  }

  String formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Phone Verification'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (step == 'enter') {
              Navigator.pop(context);
            } else {
              setState(() => step = 'enter');
            }
          },
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(LucideIcons.helpCircle, color: Colors.grey),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStepIndicator(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: step == 'enter'
                  ? _buildEnterPhone()
                  : step == 'verify'
                  ? _buildVerifyOtp()
                  : _buildSuccess(),
            ),
            const SizedBox(height: 16),
            _buildSupportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['enter', 'verify', 'success'];
    final labels = ['Enter Phone', 'Verify OTP', 'Complete'];
    final currentIndex = steps.indexOf(step);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isCompleted = index < currentIndex;
        final isActive = index == currentIndex;

        return Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isCompleted || isActive
                  ? Colors.blue
                  : Colors.grey.shade300,
              child: isCompleted
                  ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
            ),
            if (index < 2)
              Container(
                width: 24,
                height: 2,
                color: isCompleted ? Colors.blue : Colors.grey.shade300,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildEnterPhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(LucideIcons.phone, color: Colors.blue, size: 28),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verify Your Phone Number',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "We'll send you a code to confirm your number",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Phone Number',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('🇮🇳 +91', style: TextStyle(fontSize: 16)),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: 'Enter 10-digit mobile number',
            counterText: '',
          ),
          onChanged: (value) {
            final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
            if (digitsOnly.length <= 10) {
              setState(() {
                phoneNumber = digitsOnly;
                error = '';
              });
            }
          },
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  error,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _buildWhyWeNeedCard(),
        const SizedBox(height: 16),
        const Text(
          'Verification Method:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMethodButton(
                'sms',
                LucideIcons.messageSquare,
                'SMS',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMethodButton('call', LucideIcons.phoneCall, 'Call'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: phoneNumber.length == 10 && !isLoading
              ? handlePhoneSubmit
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: Colors.blue,
          ),
          child: isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text("Sending Code..."),
                  ],
                )
              : const Text('Send Verification Code'),
        ),
      ],
    );
  }

  Widget _buildMethodButton(String method, IconData icon, String label) {
    final isSelected = verificationMethod == method;
    return GestureDetector(
      onTap: () => setState(() => verificationMethod = method),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey.shade700,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhyWeNeedCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Why we need your phone number:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text('• Direct communication with service providers'),
                Text('• Account security and verification'),
                Text('• Important booking updates and alerts'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: Color(0xFFEFFDF5),
          child: Icon(LucideIcons.messageSquare, color: Colors.green, size: 28),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Code sent to +91 $phoneNumber',
          style: const TextStyle(color: Colors.grey),
        ),
        TextButton(
          onPressed: () => setState(() => step = 'enter'),
          child: const Text('Edit Phone'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 45,
              child: TextField(
                maxLength: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(counterText: ''),
                onChanged: (val) => handleOtpChange(index, val),
              ),
            );
          }),
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 12),
        if (!canResend)
          Text(
            "Resend code in ${formatTimer(timer)}",
            style: const TextStyle(color: Colors.grey),
          ),
        if (canResend)
          TextButton(
            onPressed: isLoading ? null : handleResendOtp,
            child: const Text('Resend Code'),
          ),
        TextButton(
          onPressed: () {
            setState(() {
              verificationMethod = verificationMethod == 'sms' ? 'call' : 'sms';
            });
          },
          child: Text(
            verificationMethod == 'sms'
                ? 'Use Call instead'
                : 'Use SMS instead',
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 36,
          backgroundColor: Color(0xFFEFFDF5),
          child: Icon(LucideIcons.check, color: Colors.green, size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'Phone Verified Successfully!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('Your phone number +91 $phoneNumber has been verified'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'What\'s next?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text('• Receive booking notifications'),
              Text('• Talk to workers directly'),
              Text('• Enhanced account security'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          //onPressed: () => Navigator.pop(context),
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Continue to Identity Verification'),
        ),
      ],
    );
  }

  Widget _buildSupportCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: const [
          CircleAvatar(
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(LucideIcons.helpCircle, color: Colors.blue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need Help?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Contact support for verification issues',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: Colors.grey),
        ],
      ),
    );
  }
}
