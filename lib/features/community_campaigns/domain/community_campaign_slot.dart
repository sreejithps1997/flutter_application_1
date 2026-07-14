import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityCampaignSlot {
  const CommunityCampaignSlot({
    required this.id,
    required this.campaignId,
    required this.serviceCategory,
    required this.preferredDate,
    required this.preferredTime,
    required this.joinedCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String campaignId;
  final String serviceCategory;
  final String preferredDate;
  final String preferredTime;
  final int joinedCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get label => '$serviceCategory • $preferredDate • $preferredTime';

  factory CommunityCampaignSlot.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return CommunityCampaignSlot(
      id: snapshot.id,
      campaignId: _text(data['campaignId'], ''),
      serviceCategory: _text(data['serviceCategory'], 'General service'),
      preferredDate: _text(data['preferredDate'], 'Flexible date'),
      preferredTime: _text(data['preferredTime'], 'Flexible'),
      joinedCount: _int(data['joinedCount']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static String _text(dynamic value, String fallback) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
