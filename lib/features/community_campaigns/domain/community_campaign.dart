import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityCampaign {
  const CommunityCampaign({
    required this.id,
    required this.name,
    required this.message,
    required this.location,
    required this.serviceCategories,
    required this.status,
    required this.discountLabel,
    required this.minimumBookings,
    required this.bookingLimit,
    required this.joinedCount,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  final String id;
  final String name;
  final String message;
  final String location;
  final List<String> serviceCategories;
  final String status;
  final String discountLabel;
  final int minimumBookings;
  final int bookingLimit;
  final int joinedCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory CommunityCampaign.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return CommunityCampaign(
      id: snapshot.id,
      name: _text(data['name'], 'Community Service Camp'),
      message: _text(data['message'], 'Local service campaign near you.'),
      location: _text(data['location'], 'Your area'),
      serviceCategories: _list(data['serviceCategories']),
      status: _text(data['status'], 'draft'),
      discountLabel: _text(data['discountLabel'], 'Group price available'),
      minimumBookings: _int(data['minimumBookings']),
      bookingLimit: _int(data['bookingLimit']),
      joinedCount: _int(data['joinedCount']),
      startDate: _date(data['startDate']),
      endDate: _date(data['endDate']),
      createdAt: _date(data['createdAt']),
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

  static List<String> _list(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
