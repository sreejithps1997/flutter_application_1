import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminDisputeType { booking, helpRequest }

class AdminDisputeItem {
  const AdminDisputeItem({
    required this.id,
    required this.type,
    required this.status,
    required this.paymentStatus,
    required this.customerName,
    required this.workerName,
    required this.service,
    required this.issue,
    required this.amount,
    required this.adminNote,
    required this.evidenceStatus,
    required this.evidenceRequestedFrom,
    required this.evidenceRequestNote,
    required this.evidenceSubmissionNote,
    required this.evidenceProofLinks,
    required this.resolutionStatus,
    required this.riskFlags,
    required this.updatedAt,
    required this.data,
  });

  final String id;
  final AdminDisputeType type;
  final String status;
  final String paymentStatus;
  final String customerName;
  final String workerName;
  final String service;
  final String issue;
  final double amount;
  final String adminNote;
  final String evidenceStatus;
  final String evidenceRequestedFrom;
  final String evidenceRequestNote;
  final String evidenceSubmissionNote;
  final List<String> evidenceProofLinks;
  final String resolutionStatus;
  final List<String> riskFlags;
  final DateTime? updatedAt;
  final Map<String, dynamic> data;

  bool get isHelpRequest => type == AdminDisputeType.helpRequest;
  String get typeLabel => isHelpRequest ? 'Help Request' : 'Booking';
  String get displayStatus {
    final value = status.isNotEmpty ? status : paymentStatus;
    return value.replaceAll('_', ' ');
  }

  factory AdminDisputeItem.booking(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AdminDisputeItem(
      id: snapshot.id,
      type: AdminDisputeType.booking,
      status: _text(data, ['status'], ''),
      paymentStatus: _text(data, ['paymentStatus'], ''),
      customerName: _text(data, ['customerName', 'name'], 'Customer'),
      workerName: _text(data, ['workerName'], 'Worker'),
      service: _text(data, ['service', 'serviceType'], 'Service'),
      issue: _text(data, [
        'completionDisputeReason',
        'paymentReviewNote',
        'issueDescription',
        'issue',
      ], ''),
      amount: _amount(data),
      adminNote: _text(data, ['adminDisputeNote', 'adminNote'], ''),
      evidenceStatus: _text(data, ['evidenceStatus'], ''),
      evidenceRequestedFrom: _text(data, ['evidenceRequestedFrom'], ''),
      evidenceRequestNote: _text(data, ['evidenceRequestNote'], ''),
      evidenceSubmissionNote: _text(data, ['evidenceSubmissionNote'], ''),
      evidenceProofLinks: _list(data['evidenceProofLinks']),
      resolutionStatus: _text(data, ['resolutionStatus'], ''),
      riskFlags: _list(data['riskFlags']),
      updatedAt: _date(data['updatedAt'] ?? data['createdAt']),
      data: data,
    );
  }

  factory AdminDisputeItem.helpRequest(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AdminDisputeItem(
      id: snapshot.id,
      type: AdminDisputeType.helpRequest,
      status: _text(data, ['status'], ''),
      paymentStatus: _text(data, ['paymentStatus'], ''),
      customerName: _text(data, ['customerName'], 'Customer'),
      workerName: _text(data, ['workerName'], 'Worker'),
      service: _text(data, ['title', 'requestType'], 'Help request'),
      issue: _text(data, ['completionDisputeReason', 'description'], ''),
      amount: _amount(data),
      adminNote: _text(data, ['adminDisputeNote', 'adminNote'], ''),
      evidenceStatus: _text(data, ['evidenceStatus'], ''),
      evidenceRequestedFrom: _text(data, ['evidenceRequestedFrom'], ''),
      evidenceRequestNote: _text(data, ['evidenceRequestNote'], ''),
      evidenceSubmissionNote: _text(data, ['evidenceSubmissionNote'], ''),
      evidenceProofLinks: _list(data['evidenceProofLinks']),
      resolutionStatus: _text(data, ['resolutionStatus'], ''),
      riskFlags: _list(data['riskFlags']),
      updatedAt: _date(data['updatedAt'] ?? data['createdAt']),
      data: data,
    );
  }

  static String _text(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  static double _amount(Map<String, dynamic> data) {
    for (final key in [
      'totalAmount',
      'amount',
      'budget',
      'price',
      'estimatedPrice',
      'servicePrice',
    ]) {
      final value = data[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '');
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
}
