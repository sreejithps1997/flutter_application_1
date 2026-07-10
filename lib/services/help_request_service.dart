import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/help_requests/data/help_request_repository.dart';
import '../features/help_requests/domain/help_request_draft.dart';

class HelpRequestService {
  HelpRequestService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _repository = HelpRequestRepository(firestore: firestore, auth: auth);

  final HelpRequestRepository _repository;

  Future<String> createHelpRequest({
    required String requestType,
    required String title,
    required String description,
    required String pickupAddress,
    required String destinationAddress,
    required String urgency,
    required String preferredDate,
    required String preferredTime,
    required double? budget,
    GeoPoint? pickupLocation,
    Map<String, dynamic>? selectedAddress,
  }) {
    return _repository.createHelpRequest(
      HelpRequestDraft(
        requestType: requestType,
        title: title,
        description: description,
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        urgency: urgency,
        preferredDate: preferredDate,
        preferredTime: preferredTime,
        budget: budget,
        pickupLocation: pickupLocation,
        selectedAddress: selectedAddress,
      ),
    );
  }
}
