import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/community_campaign.dart';
import '../domain/community_campaign_slot.dart';

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

  Stream<bool> watchMyJoinStatus(String campaignId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<bool>.value(false);
    return _firestore
        .collection('communityCampaigns')
        .doc(campaignId)
        .collection('joins')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<List<CommunityCampaignSlot>> watchCampaignSlots(String campaignId) {
    return _firestore
        .collection('communityCampaigns')
        .doc(campaignId)
        .collection('slots')
        .orderBy('joinedCount', descending: true)
        .limit(8)
        .snapshots()
        .map((snapshot) {
          final slots = snapshot.docs
              .map(CommunityCampaignSlot.fromSnapshot)
              .toList();
          slots.sort((a, b) {
            final count = b.joinedCount.compareTo(a.joinedCount);
            if (count != 0) return count;
            return a.label.compareTo(b.label);
          });
          return slots;
        });
  }

  Future<void> joinCampaign(CommunityCampaign campaign) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in required.');
    if (!campaign.isActive) throw StateError('Campaign is not active.');

    final campaignRef = _firestore
        .collection('communityCampaigns')
        .doc(campaign.id);
    final joinRef = campaignRef.collection('joins').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final joinSnap = await transaction.get(joinRef);
      if (joinSnap.exists) return;
      transaction.set(joinRef, {
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'Customer',
        'userPhone': user.phoneNumber ?? '',
        'campaignId': campaign.id,
        'campaignName': campaign.name,
        'status': 'interested',
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.update(campaignRef, {
        'joinedCount': FieldValue.increment(1),
        'updatedAt': now,
      });
    });
  }

  Future<void> trackCampaignShare({
    required CommunityCampaign campaign,
    required String channel,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = FieldValue.serverTimestamp();
    await _firestore.collection('communityCampaignShares').add({
      'campaignId': campaign.id,
      'campaignName': campaign.name,
      'sharedBy': user.uid,
      'channel': channel,
      'status': 'shared',
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> linkJoinToHelpRequest({
    required String campaignId,
    required String helpRequestId,
    required String preferredDate,
    required String preferredTime,
    required String serviceCategory,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in required.');
    final campaignRef = _firestore
        .collection('communityCampaigns')
        .doc(campaignId);
    final joinRef = campaignRef.collection('joins').doc(user.uid);
    final slotId = buildSlotId(
      serviceCategory: serviceCategory,
      preferredDate: preferredDate,
      preferredTime: preferredTime,
    );
    final slotRef = campaignRef.collection('slots').doc(slotId);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final joinSnap = await transaction.get(joinRef);
      final previousSlotId = joinSnap.data()?['slotId']?.toString();
      final alreadyInSlot = previousSlotId == slotId;
      if (previousSlotId != null &&
          previousSlotId.isNotEmpty &&
          !alreadyInSlot) {
        throw StateError(
          'You already selected a slot for this campaign. Contact support to change it.',
        );
      }

      transaction.set(joinRef, {
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'Customer',
        'userPhone': user.phoneNumber ?? '',
        'campaignId': campaignId,
        'status': 'help_request_created',
        'helpRequestId': helpRequestId,
        'slotId': slotId,
        'preferredDate': preferredDate,
        'preferredTime': preferredTime,
        'serviceCategory': serviceCategory,
        'updatedAt': now,
        if (!joinSnap.exists) 'createdAt': now,
      }, SetOptions(merge: true));

      transaction.set(slotRef, {
        'campaignId': campaignId,
        'slotId': slotId,
        'serviceCategory': serviceCategory,
        'preferredDate': preferredDate,
        'preferredTime': preferredTime,
        'joinedCount': alreadyInSlot
            ? FieldValue.increment(0)
            : FieldValue.increment(1),
        'updatedAt': now,
        if (!alreadyInSlot) 'createdAt': now,
      }, SetOptions(merge: true));
    });
  }

  static String buildSlotId({
    required String serviceCategory,
    required String preferredDate,
    required String preferredTime,
  }) {
    final raw =
        '${serviceCategory.trim()}_${preferredDate.trim()}_${preferredTime.trim()}'
            .toLowerCase();
    return raw
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
