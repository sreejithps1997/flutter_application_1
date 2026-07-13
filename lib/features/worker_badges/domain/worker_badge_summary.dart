import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WorkerBadgeSummary {
  const WorkerBadgeSummary({
    required this.workerId,
    required this.level,
    required this.completedJobs,
    required this.verifiedHours,
    required this.averageRating,
    required this.reviewCount,
    required this.onTimePercent,
    required this.repeatCustomers,
  });

  final String workerId;
  final WorkerBadgeLevel level;
  final int completedJobs;
  final double verifiedHours;
  final double averageRating;
  final int reviewCount;
  final int onTimePercent;
  final int repeatCustomers;

  String get label => level.label;
  Color get color => level.color;

  static WorkerBadgeSummary fromData({
    required String workerId,
    required Map<String, dynamic> worker,
    required Iterable<Map<String, dynamic>> bookings,
  }) {
    final paidCompleted = bookings.where(_isCompletedPaid).toList();
    final completedJobs = _int(
      worker['completedJobsCount'] ?? worker['completedJobs'],
      fallback: paidCompleted.length,
    );
    final rating = _double(worker['averageRating'] ?? worker['rating']);
    final reviewCount = _int(worker['totalReviews'] ?? worker['reviewCount']);
    final verifiedHours = _verifiedHours(paidCompleted);
    final repeatCustomers = _repeatCustomers(paidCompleted);
    final onTimePercent = _onTimePercent(worker, paidCompleted);

    return WorkerBadgeSummary(
      workerId: workerId,
      level: WorkerBadgeLevel.fromMetrics(
        completedJobs: completedJobs,
        verifiedHours: verifiedHours,
        averageRating: rating,
        reviewCount: reviewCount,
        onTimePercent: onTimePercent,
      ),
      completedJobs: completedJobs,
      verifiedHours: verifiedHours,
      averageRating: rating,
      reviewCount: reviewCount,
      onTimePercent: onTimePercent,
      repeatCustomers: repeatCustomers,
    );
  }

  static bool _isCompletedPaid(Map<String, dynamic> data) {
    final status = data['status']?.toString().toLowerCase() ?? '';
    final paymentStatus = data['paymentStatus']?.toString().toLowerCase() ?? '';
    return status == 'completed' || status == 'paid' || paymentStatus == 'paid';
  }

  static double _verifiedHours(List<Map<String, dynamic>> bookings) {
    var totalMinutes = 0;
    for (final booking in bookings) {
      final start = _date(
        booking['workStartedAt'] ?? booking['timeline']?['in_progress'],
      );
      final end = _date(
        booking['completedAt'] ??
            booking['paidAt'] ??
            booking['customerConfirmedCompletionAt'] ??
            booking['timeline']?['completed'] ??
            booking['timeline']?['paid'],
      );
      if (start == null || end == null || !end.isAfter(start)) continue;
      final minutes = end.difference(start).inMinutes;
      if (minutes > 0 && minutes <= 16 * 60) {
        totalMinutes += minutes;
      }
    }
    return totalMinutes / 60;
  }

  static int _repeatCustomers(List<Map<String, dynamic>> bookings) {
    final counts = <String, int>{};
    for (final booking in bookings) {
      final customerId = booking['customerId']?.toString() ?? '';
      if (customerId.isEmpty) continue;
      counts[customerId] = (counts[customerId] ?? 0) + 1;
    }
    return counts.values.where((total) => total > 1).length;
  }

  static int _onTimePercent(
    Map<String, dynamic> worker,
    List<Map<String, dynamic>> bookings,
  ) {
    final stored = _int(worker['onTimePercent'] ?? worker['punctualityScore']);
    if (stored > 0) return stored.clamp(0, 100);
    if (bookings.length >= 5) return 90;
    return 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

enum WorkerBadgeLevel {
  verified('Verified', Color(0xFF2563EB)),
  silver('Silver', Color(0xFF64748B)),
  gold('Gold', Color(0xFFD97706)),
  diamond('Diamond', Color(0xFF0891B2)),
  platinum('Platinum', Color(0xFF4F46E5));

  const WorkerBadgeLevel(this.label, this.color);

  final String label;
  final Color color;

  static WorkerBadgeLevel fromMetrics({
    required int completedJobs,
    required double verifiedHours,
    required double averageRating,
    required int reviewCount,
    required int onTimePercent,
  }) {
    final hasRating = reviewCount >= 3 || averageRating > 0;
    final rating = hasRating ? averageRating : 4.0;

    if (completedJobs >= 250 &&
        verifiedHours >= 1200 &&
        rating >= 4.8 &&
        onTimePercent >= 95) {
      return WorkerBadgeLevel.platinum;
    }
    if (completedJobs >= 120 && verifiedHours >= 500 && rating >= 4.7) {
      return WorkerBadgeLevel.diamond;
    }
    if (completedJobs >= 50 && verifiedHours >= 150 && rating >= 4.5) {
      return WorkerBadgeLevel.gold;
    }
    if (completedJobs >= 15 && verifiedHours >= 40 && rating >= 4.2) {
      return WorkerBadgeLevel.silver;
    }
    return WorkerBadgeLevel.verified;
  }
}
