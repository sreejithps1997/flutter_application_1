import 'package:cloud_firestore/cloud_firestore.dart';

import 'worker_badge_summary.dart';

class WorkerAchievement {
  const WorkerAchievement({
    required this.id,
    required this.workerId,
    required this.month,
    required this.badgeLevel,
    required this.completedJobs,
    required this.monthlyCompletedJobs,
    required this.verifiedHours,
    required this.monthlyVerifiedHours,
    required this.averageRating,
    required this.reviewCount,
    required this.repeatCustomers,
    required this.onTimePercent,
    required this.punctualityTrackedJobs,
    required this.achievementLabels,
    required this.certificateNumber,
    this.updatedAt,
  });

  final String id;
  final String workerId;
  final String month;
  final WorkerBadgeLevel badgeLevel;
  final int completedJobs;
  final int monthlyCompletedJobs;
  final double verifiedHours;
  final double monthlyVerifiedHours;
  final double averageRating;
  final int reviewCount;
  final int repeatCustomers;
  final int onTimePercent;
  final int punctualityTrackedJobs;
  final List<String> achievementLabels;
  final String certificateNumber;
  final DateTime? updatedAt;

  String get shareTitle => '${badgeLevel.label} Professional';

  String get monthLabel {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = int.tryParse(parts[1]);
    if (index == null || index < 1 || index > 12) return month;
    return '${names[index - 1]} ${parts[0]}';
  }

  String shareText(String workerName) {
    final name = workerName.trim().isEmpty
        ? 'A Workable professional'
        : workerName.trim();
    return '$name is a ${badgeLevel.label} Professional on Workable.\n'
        '$completedJobs completed jobs | ${verifiedHours.toStringAsFixed(0)} verified hours | '
        '${averageRating > 0 ? averageRating.toStringAsFixed(1) : 'New'} rating.\n'
        'Certificate: $certificateNumber';
  }

  factory WorkerAchievement.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return WorkerAchievement(
      id: snapshot.id,
      workerId: _string(data['workerId']),
      month: _string(data['month'], fallback: snapshot.id),
      badgeLevel: _level(data['badgeLevel']),
      completedJobs: _int(data['completedJobs']),
      monthlyCompletedJobs: _int(data['monthlyCompletedJobs']),
      verifiedHours: _double(data['verifiedHours']),
      monthlyVerifiedHours: _double(data['monthlyVerifiedHours']),
      averageRating: _double(data['averageRating']),
      reviewCount: _int(data['reviewCount']),
      repeatCustomers: _int(data['repeatCustomers']),
      onTimePercent: _int(data['onTimePercent']),
      punctualityTrackedJobs: _int(data['punctualityTrackedJobs']),
      achievementLabels: _list(data['achievementLabels']),
      certificateNumber: _string(data['certificateNumber']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static WorkerBadgeLevel _level(dynamic value) {
    final normalized = value?.toString().toLowerCase().trim();
    return WorkerBadgeLevel.values.firstWhere(
      (level) => level.name == normalized,
      orElse: () => WorkerBadgeLevel.verified,
    );
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _list(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}

class WorkerCertificateProfile {
  const WorkerCertificateProfile({
    required this.workerId,
    required this.name,
    required this.photoUrl,
    required this.skills,
    required this.serviceArea,
    required this.isVerified,
  });

  final String workerId;
  final String name;
  final String photoUrl;
  final List<String> skills;
  final String serviceArea;
  final bool isVerified;

  factory WorkerCertificateProfile.fromData({
    required String workerId,
    required Map<String, dynamic> data,
  }) {
    return WorkerCertificateProfile(
      workerId: workerId,
      name: _string(data['name'] ?? data['fullName'] ?? data['displayName']),
      photoUrl: _string(data['profileImageUrl'] ?? data['photoUrl']),
      skills: _list(data['serviceCategories'] ?? data['skills']),
      serviceArea: _string(
        data['serviceArea'] ?? data['city'] ?? data['location'],
      ),
      isVerified:
          data['isVerified'] == true ||
          data['verificationStatus'] == 'verified',
    );
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static List<String> _list(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
