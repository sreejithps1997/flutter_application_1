import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/community_campaign.dart';

class CommunityCampaignRepository {
  CommunityCampaignRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<CommunityCampaign>> watchCampaigns({bool activeOnly = false}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('communityCampaigns')
        .limit(100);
    if (activeOnly) {
      query = query.where('status', isEqualTo: 'active');
    }
    return query.snapshots().map((snapshot) {
      final items = snapshot.docs.map(CommunityCampaign.fromSnapshot).toList();
      items.sort((a, b) {
        final aDate = a.startDate ?? a.createdAt ?? DateTime(1970);
        final bDate = b.startDate ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
      return items;
    });
  }

  Future<void> createCampaign({
    required String name,
    required String message,
    required String location,
    required List<String> serviceCategories,
    required String discountLabel,
    required int minimumBookings,
    required int bookingLimit,
    required String status,
  }) async {
    final adminId = _auth.currentUser?.uid ?? 'admin';
    final now = FieldValue.serverTimestamp();
    await _firestore.collection('communityCampaigns').add({
      'name': name.trim(),
      'message': message.trim(),
      'location': location.trim(),
      'serviceCategories': serviceCategories,
      'discountLabel': discountLabel.trim(),
      'minimumBookings': minimumBookings,
      'bookingLimit': bookingLimit,
      'joinedCount': 0,
      'status': status,
      'createdBy': adminId,
      'createdAt': now,
      'updatedAt': now,
      'source': 'admin_campaign_calendar',
    });
  }
}
