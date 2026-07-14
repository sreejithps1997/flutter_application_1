import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../signup_referral/data/signup_referral_repository.dart';

class CustomerSignupRepository {
  CustomerSignupRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    SignupReferralRepository? referralRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _referralRepository = referralRepository ?? SignupReferralRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final SignupReferralRepository _referralRepository;

  Future<String> completePhoneSignup({
    required String phone,
    required String name,
    required String email,
    required String address,
    required String? referralCode,
    Position? position,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Phone verification expired. Please verify OTP again.');
    }

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);
    final existing = await userRef.get();
    final cleanName = name.trim();
    final cleanEmail = email.trim();
    final cleanAddress = address.trim();
    final cleanPhone = _normalizePhone(phone);
    final referral = _referralRepository.attributionFromInput(
      referralCode,
      source: 'customer_phone_signup',
    );

    await userRef.set({
      'uid': uid,
      'userType': 'customer',
      'name': cleanName.isEmpty ? 'Customer' : cleanName,
      if (cleanEmail.isNotEmpty) 'email': cleanEmail,
      'phone': cleanPhone,
      'phoneNumber': cleanPhone,
      'phoneVerified': true,
      'authProvider': 'phone',
      'signupMode': 'phone_only',
      'onboardingStatus': 'active',
      if (cleanAddress.isNotEmpty) 'address': cleanAddress,
      if (position != null)
        'location': GeoPoint(position.latitude, position.longitude),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'signupCompletedAt': FieldValue.serverTimestamp(),
      ...referral.toUserFields(),
    }, SetOptions(merge: true));

    await userRef.collection('identityVerification').doc('phone').set({
      'number': cleanPhone,
      'status': 'verified',
      'verifiedAt': FieldValue.serverTimestamp(),
      'verificationMethod': 'signup_otp',
    }, SetOptions(merge: true));

    if (referral.hasCode) {
      await _referralRepository.consumePendingCodeIfMatches(referral.code);
    }

    return uid;
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('91') && digits.length == 12) return '+$digits';
    if (digits.length == 10) return '+91$digits';
    if (phone.startsWith('+')) return phone;
    return '+$digits';
  }
}
