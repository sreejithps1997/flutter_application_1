import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/star_rating.dart';
import '../widgets/workable_ui.dart';

class RatingsReviewsScreen extends StatelessWidget {
  static const routeName = '/ratings-reviews';

  const RatingsReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Ratings & Reviews')),
      body: user == null
          ? const WorkableEmptyState(
              icon: LucideIcons.star,
              title: 'Sign in to view ratings',
              message: 'Your reviews and rating summary appear here.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('workerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return WorkableEmptyState(
                    icon: LucideIcons.alertTriangle,
                    title: 'Unable to load reviews',
                    message: snapshot.error.toString(),
                  );
                }

                final reviews =
                    snapshot.data?.docs
                        .map((doc) => _ReviewModel(doc.id, doc.data()))
                        .toList() ??
                    [];

                reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (reviews.isEmpty) {
                  return const WorkableEmptyState(
                    icon: LucideIcons.star,
                    title: 'No reviews yet',
                    message:
                        'Customer feedback will appear after completed paid jobs.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(WorkableDesign.pagePadding),
                  children: [
                    const WorkablePageHeader(
                      title: 'Reputation dashboard',
                      subtitle:
                          'Track your customer rating, recent feedback, and quality signal for future bookings.',
                      icon: LucideIcons.star,
                    ),
                    const SizedBox(height: 16),
                    _RatingSummary(reviews: reviews),
                    const SizedBox(height: 16),
                    const _SectionTitle('Recent feedback'),
                    const SizedBox(height: 10),
                    ...reviews.map((review) => _ReviewCard(review: review)),
                  ],
                );
              },
            ),
    );
  }
}

class _RatingSummary extends StatelessWidget {
  const _RatingSummary({required this.reviews});

  final List<_ReviewModel> reviews;

  @override
  Widget build(BuildContext context) {
    final total = reviews.length;
    final average =
        reviews.fold<double>(0, (ratingTotal, review) {
          return ratingTotal + review.rating;
        }) /
        total;
    final counts = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
    for (final review in reviews) {
      final bucket = review.rating.round().clamp(1, 5);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }

    final excellentCount = reviews.where((review) => review.rating >= 4).length;
    final qualityScore = ((excellentCount / total) * 100).round();

    return WorkableSectionCard(
      color: WorkableDesign.ink,
      borderColor: WorkableDesign.ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StarRating(rating: average),
                    const SizedBox(height: 3),
                    Text(
                      '$total customer ${total == 1 ? 'review' : 'reviews'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WorkableStatusPill(
            label: '$qualityScore% positive quality signal',
            color: WorkableDesign.success,
            icon: LucideIcons.trendingUp,
          ),
          const SizedBox(height: 16),
          for (var star = 5; star >= 1; star--)
            _RatingBar(star: star, count: counts[star] ?? 0, total: total),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '$star star',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  WorkableDesign.warning,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final _ReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: WorkableDesign.primary.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    review.customerInitial,
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
                      Text(
                        review.customerName,
                        style: const TextStyle(
                          color: WorkableDesign.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${review.service} • ${review.dateLabel}',
                        style: const TextStyle(
                          color: WorkableDesign.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StarRating(rating: review.rating),
              ],
            ),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.text,
                style: const TextStyle(color: WorkableDesign.ink, height: 1.4),
              ),
            ],
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: review.tags
                    .map(
                      (tag) => WorkableStatusPill(
                        label: tag,
                        color: WorkableDesign.accent,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WorkableDesign.ink,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ReviewModel {
  _ReviewModel(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  double get rating => (data['rating'] as num?)?.toDouble() ?? 0;

  String get customerName =>
      _text(['customerName', 'customer', 'reviewerName'], 'Customer');

  String get customerInitial {
    final name = customerName.trim();
    if (name.isEmpty) return 'C';
    return name.characters.first.toUpperCase();
  }

  String get service =>
      _text(['service', 'serviceType', 'category'], 'Service');

  String get text => _text(['review', 'comment', 'feedback'], '');

  List<String> get tags {
    final value = data['tags'] ?? data['reviewTags'];
    if (value is! List) return [];
    return value.map((item) => item.toString()).where((item) {
      return item.trim().isNotEmpty;
    }).toList();
  }

  DateTime get createdAt {
    final value = data['timestamp'] ?? data['createdAt'] ?? data['updatedAt'];
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
    return DateTime(1970);
  }

  String get dateLabel {
    final date = createdAt;
    if (date.year <= 1970) return 'Date unavailable';
    return _dateFormat.format(date);
  }

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }
}
