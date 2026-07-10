import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerMatchQuery {
  const WorkerMatchQuery({
    required this.searchText,
    required this.category,
    this.urgency = 'Normal',
    this.customerLocation,
    this.maxResults = 50,
  });

  final String searchText;
  final String category;
  final String urgency;
  final GeoPoint? customerLocation;
  final int maxResults;

  String get normalizedSearchText {
    return searchText.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String get normalizedCategory {
    return category.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
