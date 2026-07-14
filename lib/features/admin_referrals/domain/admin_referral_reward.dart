import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReferralReward {
  const AdminReferralReward({
    required this.id,
    required this.referrerId,
    required this.referrerName,
    required this.referralCode,
    required this.referredUserId,
    required this.referredUserName,
    required this.referredUserRole,
    required this.status,
    required this.rewardStatus,
    required this.rewardAmount,
    required this.rewardCurrency,
    required this.firstPaidBookingAmount,
    required this.referredCustomerSpend,
    required this.referredCustomerPaidBookingCount,
    required this.referrerTotalJoinedSnapshot,
    required this.referrerCompletedCountSnapshot,
    required this.referrerAttributedSpendSnapshot,
    this.referredUserEmail,
    this.referredUserPhone,
    this.firstPaidBookingId,
    this.adminNote,
    this.createdAt,
    this.completedAt,
    this.reviewedAt,
    this.creditedAt,
    this.updatedAt,
  });

  final String id;
  final String referrerId;
  final String referrerName;
  final String referralCode;
  final String referredUserId;
  final String referredUserName;
  final String referredUserRole;
  final String status;
  final String rewardStatus;
  final num rewardAmount;
  final String rewardCurrency;
  final num firstPaidBookingAmount;
  final num referredCustomerSpend;
  final int referredCustomerPaidBookingCount;
  final int referrerTotalJoinedSnapshot;
  final int referrerCompletedCountSnapshot;
  final num referrerAttributedSpendSnapshot;
  final String? referredUserEmail;
  final String? referredUserPhone;
  final String? firstPaidBookingId;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final DateTime? reviewedAt;
  final DateTime? creditedAt;
  final DateTime? updatedAt;

  bool get isRewardReady {
    return rewardStatus == 'ready_for_credit' || rewardStatus == 'approved';
  }

  bool get isCredited => rewardStatus == 'credited';

  bool get isRejected => rewardStatus == 'rejected';

  bool get isWorkerOnboarding => status == 'pending_worker_onboarding';

  factory AdminReferralReward.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return AdminReferralReward(
      id: snapshot.id,
      referrerId: _text(data, 'referrerId', 'unknown'),
      referrerName: _text(data, 'referrerName', 'Workable user'),
      referralCode: _text(data, 'referralCode', ''),
      referredUserId: _text(data, 'referredUserId', 'unknown'),
      referredUserName: _text(data, 'referredUserName', 'New user'),
      referredUserRole: _text(data, 'referredUserRole', 'customer'),
      status: _text(data, 'status', 'tracked'),
      rewardStatus: _text(data, 'rewardStatus', 'locked'),
      rewardAmount: data['rewardAmount'] is num
          ? data['rewardAmount'] as num
          : num.tryParse(data['rewardAmount']?.toString() ?? '') ?? 0,
      rewardCurrency: _text(data, 'rewardCurrency', 'INR'),
      firstPaidBookingAmount: _num(data['firstPaidBookingAmount']),
      referredCustomerSpend: _num(data['referredCustomerSpend']),
      referredCustomerPaidBookingCount: _num(
        data['referredCustomerPaidBookingCount'],
      ).round(),
      referrerTotalJoinedSnapshot: _num(
        data['referrerTotalJoinedSnapshot'],
      ).round(),
      referrerCompletedCountSnapshot: _num(
        data['referrerCompletedCountSnapshot'],
      ).round(),
      referrerAttributedSpendSnapshot: _num(
        data['referrerAttributedSpendSnapshot'],
      ),
      referredUserEmail: _optionalText(data['referredUserEmail']),
      referredUserPhone: _optionalText(data['referredUserPhone']),
      firstPaidBookingId: _optionalText(data['firstPaidBookingId']),
      adminNote: _optionalText(data['adminNote']),
      createdAt: _date(data['createdAt']),
      completedAt: _date(data['completedAt']),
      reviewedAt: _date(data['reviewedAt']),
      creditedAt: _date(data['creditedAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static String _text(Map<String, dynamic> data, String key, String fallback) {
    final value = data[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return fallback;
    }
    return value;
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static num _num(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
