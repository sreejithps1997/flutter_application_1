import 'package:cloud_firestore/cloud_firestore.dart';

class HelpRequest {
  const HelpRequest({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => _text(['status'], 'open').toLowerCase();
  String get requestType => _text(['requestType'], 'General help');
  String get title => _text(['title'], requestType);
  String get description => _text(['description'], '');
  String get customerId => _text(['customerId'], '');
  String get customerName => _text(['customerName'], 'Customer');
  String get customerPhone => _text(['customerPhone'], '');
  String get pickupAddress => _text(['pickupAddress'], 'Address not shared');
  String get destinationAddress => _text(['destinationAddress'], '');
  String get urgency => _text(['urgency'], 'Normal');
  String get preferredDate => _text(['preferredDate'], 'Date flexible');
  String get preferredTime => _text(['preferredTime'], 'Time flexible');
  String get workerId => _text(['workerId', 'acceptedWorkerId'], '');
  String get workerName => _text(['workerName'], 'Not assigned yet');
  String get workerPhone => _text(['workerPhone'], '');
  String get linkedBookingId => _text(['linkedBookingId'], '');
  String get paymentStatus => _text(['paymentStatus'], 'not_started');
  DateTime? get createdAt => _date(data['createdAt']);

  double? get budget {
    for (final key in ['budget', 'estimatedPrice', 'amount']) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  bool get isOpen => status == 'open';
  bool get isAccepted => status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isClosed {
    return {'completed', 'cancelled', 'rejected', 'paid'}.contains(status);
  }

  String get urgencyLabel {
    final value = urgency.trim();
    if (value.isEmpty) return 'Normal';
    return value[0].toUpperCase() + value.substring(1);
  }

  String get timeLabel {
    final parts = [
      if (preferredDate.trim().isNotEmpty) preferredDate,
      if (preferredTime.trim().isNotEmpty) preferredTime,
    ];
    return parts.isEmpty ? 'Flexible timing' : parts.join(' at ');
  }

  String _text(List<String> keys, String fallback) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
