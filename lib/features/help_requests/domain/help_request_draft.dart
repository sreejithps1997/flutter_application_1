import 'package:cloud_firestore/cloud_firestore.dart';

class HelpRequestDraft {
  const HelpRequestDraft({
    required this.requestType,
    required this.title,
    required this.description,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.urgency,
    required this.preferredDate,
    required this.preferredTime,
    required this.budget,
    this.pickupLocation,
    this.selectedAddress,
    this.source = 'customer_manual',
    this.sourceMetadata = const {},
  });

  final String requestType;
  final String title;
  final String description;
  final String pickupAddress;
  final String destinationAddress;
  final String urgency;
  final String preferredDate;
  final String preferredTime;
  final double? budget;
  final GeoPoint? pickupLocation;
  final Map<String, dynamic>? selectedAddress;
  final String source;
  final Map<String, dynamic> sourceMetadata;
}
