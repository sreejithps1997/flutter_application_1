import 'package:cloud_firestore/cloud_firestore.dart';

class DisputeEvidenceCase {
  const DisputeEvidenceCase({
    required this.id,
    required this.collection,
    required this.service,
    required this.status,
    required this.customerId,
    required this.workerId,
    required this.requestedFrom,
    required this.requestNote,
    required this.evidenceStatus,
    required this.submissionNote,
    required this.proofLinks,
  });

  final String id;
  final String collection;
  final String service;
  final String status;
  final String customerId;
  final String workerId;
  final String requestedFrom;
  final String requestNote;
  final String evidenceStatus;
  final String submissionNote;
  final List<String> proofLinks;

  bool get isBooking => collection == 'bookings';

  factory DisputeEvidenceCase.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String collection,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return DisputeEvidenceCase(
      id: snapshot.id,
      collection: collection,
      service: _text(data, ['service', 'serviceType', 'title'], 'Service'),
      status: _text(data, ['status'], ''),
      customerId: _text(data, ['customerId'], ''),
      workerId: _text(data, ['workerId', 'acceptedWorkerId'], ''),
      requestedFrom: _text(data, ['evidenceRequestedFrom'], ''),
      requestNote: _text(data, ['evidenceRequestNote'], ''),
      evidenceStatus: _text(data, ['evidenceStatus'], ''),
      submissionNote: _text(data, ['evidenceSubmissionNote'], ''),
      proofLinks: _list(data['evidenceProofLinks']),
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
