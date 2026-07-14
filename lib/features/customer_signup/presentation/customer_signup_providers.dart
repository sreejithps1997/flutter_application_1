import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/customer_signup_repository.dart';
import '../domain/customer_signup_state.dart';

final customerSignupRepositoryProvider = Provider<CustomerSignupRepository>((
  ref,
) {
  return CustomerSignupRepository();
});

final customerSignupControllerProvider =
    StateNotifierProvider<CustomerSignupController, CustomerSignupState>((ref) {
      return CustomerSignupController(
        ref.watch(customerSignupRepositoryProvider),
      );
    });

class CustomerSignupController extends StateNotifier<CustomerSignupState> {
  CustomerSignupController(this._repository)
    : super(const CustomerSignupState());

  final CustomerSignupRepository _repository;

  Future<void> sendOtp(String rawPhone) async {
    final phone = _formatIndianPhone(rawPhone);
    if (phone == null) {
      state = state.copyWith(
        error: 'Enter a valid 10-digit phone number.',
        clearMessage: true,
      );
      return;
    }

    state = state.copyWith(
      otpSent: true,
      isOtpSending: true,
      isPhoneVerified: false,
      verifiedPhone: phone,
      clearError: true,
      clearMessage: true,
    );

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await _verifyWithCredential(credential, phone, automatic: true);
        },
        verificationFailed: (error) {
          state = state.copyWith(
            otpSent: false,
            isOtpSending: false,
            error: error.message ?? 'OTP verification failed.',
            clearMessage: true,
          );
        },
        codeSent: (verificationId, resendToken) {
          state = state.copyWith(
            verificationId: verificationId,
            isOtpSending: false,
            message: 'OTP sent to $phone.',
            clearError: true,
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          state = state.copyWith(verificationId: verificationId);
        },
      );
    } catch (error) {
      state = state.copyWith(
        otpSent: false,
        isOtpSending: false,
        error: error.toString(),
        clearMessage: true,
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6) {
      state = state.copyWith(
        error: 'Enter the 6-digit OTP.',
        clearMessage: true,
      );
      return;
    }
    if (state.verificationId.isEmpty) {
      state = state.copyWith(
        error: 'OTP session expired. Please resend OTP.',
        clearMessage: true,
      );
      return;
    }

    state = state.copyWith(isVerifyingOtp: true, clearError: true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: state.verificationId,
        smsCode: cleanOtp,
      );
      await _verifyWithCredential(credential, state.verifiedPhone);
    } on FirebaseAuthException catch (error) {
      state = state.copyWith(
        isVerifyingOtp: false,
        error: error.code == 'invalid-verification-code'
            ? 'Invalid OTP. Please check and try again.'
            : error.message ?? 'Invalid OTP.',
        clearMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        isVerifyingOtp: false,
        error: 'Invalid OTP. Please try again.',
        clearMessage: true,
      );
    }
  }

  Future<String> completePhoneSignup({
    required String phone,
    required String name,
    required String email,
    required String address,
    required String? referralCode,
    Position? position,
  }) async {
    if (!state.isPhoneVerified) {
      throw StateError('Please verify your phone number first.');
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final uid = await _repository.completePhoneSignup(
        phone: phone,
        name: name,
        email: email,
        address: address,
        referralCode: referralCode,
        position: position,
      );
      state = state.copyWith(
        isSubmitting: false,
        message: 'Account created.',
        clearError: true,
      );
      return uid;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: error.toString().replaceFirst('Bad state: ', ''),
        clearMessage: true,
      );
      rethrow;
    }
  }

  void clearTransientMessages() {
    state = state.copyWith(clearError: true, clearMessage: true);
  }

  Future<void> _verifyWithCredential(
    PhoneAuthCredential credential,
    String phone, {
    bool automatic = false,
  }) async {
    await FirebaseAuth.instance.signInWithCredential(credential);
    state = state.copyWith(
      otpSent: false,
      isOtpSending: false,
      isVerifyingOtp: false,
      isPhoneVerified: true,
      verifiedPhone: phone,
      message: automatic
          ? 'Phone verified automatically.'
          : 'Phone verified successfully.',
      clearError: true,
    );
  }

  String? _formatIndianPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.startsWith('91') && digits.length == 12) return '+$digits';
    return null;
  }
}
