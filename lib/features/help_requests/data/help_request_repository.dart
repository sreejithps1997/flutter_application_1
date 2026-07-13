import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/help_request.dart';
import '../domain/help_request_draft.dart';

class HelpRequestRepository {
  HelpRequestRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const timelineStages = {
    'open': null,
    'accepted': null,
    'in_progress': null,
    'completion_requested': null,
    'payment_due': null,
    'completed': null,
    'cancelled': null,
  };

  Future<String> createHelpRequest(HelpRequestDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again to create a help request.');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final requestRef = _firestore.collection('helpRequests').doc();
    final now = FieldValue.serverTimestamp();

    await requestRef.set({
      'id': requestRef.id,
      'requestKind': 'generic_help',
      'requestType': draft.requestType,
      'title': draft.title,
      'description': draft.description,
      'customerId': user.uid,
      'customerName':
          userData['name'] ??
          userData['fullName'] ??
          user.displayName ??
          'Customer',
      'customerPhone':
          userData['phone'] ?? userData['phoneNumber'] ?? user.phoneNumber,
      'pickupAddress': draft.pickupAddress,
      'destinationAddress': draft.destinationAddress,
      if (draft.pickupLocation != null) 'pickupLocation': draft.pickupLocation,
      if (draft.selectedAddress != null)
        'selectedAddress': draft.selectedAddress,
      'urgency': draft.urgency,
      'preferredDate': draft.preferredDate,
      'preferredTime': draft.preferredTime,
      if (draft.budget != null) 'budget': draft.budget,
      if (draft.budget != null) 'estimatedPrice': draft.budget,
      'source': draft.source,
      if (draft.sourceMetadata.isNotEmpty)
        'sourceMetadata': draft.sourceMetadata,
      'status': 'open',
      'paymentStatus': 'not_started',
      'timeline': {...timelineStages, 'open': now},
      'createdAt': now,
      'updatedAt': now,
    });

    return requestRef.id;
  }

  Stream<List<HelpRequest>> watchOpenHelpRequests({int limit = 50}) {
    return _firestore
        .collection('helpRequests')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => HelpRequest(id: doc.id, data: doc.data()))
              .toList();
        });
  }

  Stream<List<HelpRequest>> watchWorkerHelpRequests({int limit = 50}) {
    final workerId = _auth.currentUser?.uid;
    if (workerId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('helpRequests')
        .where('workerId', isEqualTo: workerId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => HelpRequest(id: doc.id, data: doc.data()))
              .where((request) => !request.isClosed)
              .toList();
          requests.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return requests;
        });
  }

  Stream<List<HelpRequest>> watchCustomerHelpRequests({int limit = 80}) {
    final customerId = _auth.currentUser?.uid;
    if (customerId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('helpRequests')
        .where('customerId', isEqualTo: customerId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => HelpRequest(id: doc.id, data: doc.data()))
              .toList();
          requests.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return requests;
        });
  }

  Stream<HelpRequest?> watchHelpRequest(String requestId) {
    if (requestId.trim().isEmpty) {
      return Stream.value(null);
    }

    return _firestore.collection('helpRequests').doc(requestId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        return HelpRequest(id: snapshot.id, data: data);
      },
    );
  }

  Future<void> acceptHelpRequest(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please log in again to accept this request.');
    }

    final requestRef = _firestore.collection('helpRequests').doc(requestId);
    final workerRef = _firestore.collection('workers').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw StateError('This help request is no longer available.');
      }

      final requestData = requestSnapshot.data() ?? {};
      final status = (requestData['status'] ?? '').toString().toLowerCase();
      if (status != 'open') {
        throw StateError('Another worker has already accepted this request.');
      }
      final customerId = requestData['customerId']?.toString() ?? '';
      final bookingRef = _firestore.collection('bookings').doc();

      final workerSnapshot = await transaction.get(workerRef);
      final userSnapshot = await transaction.get(userRef);
      final workerData = workerSnapshot.data() ?? {};
      final userData = userSnapshot.data() ?? {};
      final workerName =
          workerData['fullName'] ??
          workerData['name'] ??
          userData['name'] ??
          userData['fullName'] ??
          user.displayName ??
          'Worker';
      final workerPhone =
          workerData['phone'] ??
          workerData['phoneNumber'] ??
          userData['phone'] ??
          userData['phoneNumber'] ??
          user.phoneNumber;

      transaction.update(requestRef, {
        'status': 'accepted',
        'workerId': user.uid,
        'acceptedWorkerId': user.uid,
        'workerName': workerName,
        if (workerPhone != null) 'workerPhone': workerPhone,
        'convertedToBooking': true,
        'linkedBookingId': bookingRef.id,
        'linkedBookingCreatedAt': now,
        'acceptedAt': now,
        'updatedAt': now,
        'timeline.accepted': now,
      });

      transaction.set(bookingRef, {
        'id': bookingRef.id,
        'source': 'help_request',
        'sourceHelpRequestId': requestId,
        'requestKind': requestData['requestKind'] ?? 'generic_help',
        'customerId': customerId,
        'customerName': requestData['customerName'] ?? 'Customer',
        'customerPhone': requestData['customerPhone'],
        'workerId': user.uid,
        'workerName': workerName,
        if (workerPhone != null) 'workerPhone': workerPhone,
        'service': requestData['requestType'] ?? 'General Help',
        'serviceType': requestData['requestType'] ?? 'General Help',
        'issue': requestData['description'] ?? requestData['title'] ?? 'Help',
        'issueDescription':
            requestData['description'] ?? requestData['title'] ?? 'Help',
        'address': requestData['pickupAddress'] ?? '',
        'destinationAddress': requestData['destinationAddress'],
        'preferredDate': requestData['preferredDate'] ?? '',
        'preferredTime': requestData['preferredTime'] ?? '',
        if (requestData['pickupLocation'] != null)
          'addressLocation': requestData['pickupLocation'],
        if (requestData['selectedAddress'] != null)
          'selectedAddress': requestData['selectedAddress'],
        if (requestData['budget'] != null) 'price': requestData['budget'],
        if (requestData['estimatedPrice'] != null)
          'estimatedPrice': requestData['estimatedPrice'],
        'payment': 'Cash',
        'paymentMethod': 'Cash',
        'paymentStatus': 'not_started',
        'rating': null,
        'status': 'confirmed',
        'createdAt': now,
        'updatedAt': now,
        'acceptedAt': now,
        'timeline': {
          'requested': requestData['createdAt'],
          'accepted': now,
          'in_progress': null,
          'completion_requested': null,
          'payment_due': null,
          'paid': null,
          'completed': null,
          'cancelled': null,
        },
      });

      if (workerSnapshot.exists) {
        transaction.update(workerRef, {
          'activeHelpRequestIds': FieldValue.arrayUnion([requestId]),
          'activeBookingIds': FieldValue.arrayUnion([bookingRef.id]),
          'lastAcceptedHelpRequestAt': now,
          'updatedAt': now,
        });
      }

      // Cloud Function notifyOnHelpRequestAccepted creates the customer
      // notification from this accepted state change.
    });
  }

  Future<void> startHelpRequest(String requestId) {
    return _updateHelpRequest(requestId, {
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
      'timeline.in_progress': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestCompletion(String requestId) {
    return _updateHelpRequest(requestId, {
      'status': 'completion_requested',
      'paymentStatus': 'not_started',
      'workCompletedAt': FieldValue.serverTimestamp(),
      'completionRequestedAt': FieldValue.serverTimestamp(),
      'timeline.work_completed': FieldValue.serverTimestamp(),
      'timeline.completion_requested': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmCompletion(String requestId) {
    return _updateHelpRequest(requestId, {
      'status': 'payment_due',
      'paymentStatus': 'payment_due',
      'customerConfirmedCompletionAt': FieldValue.serverTimestamp(),
      'timeline.payment_due': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelHelpRequest(String requestId, {String by = 'customer'}) {
    return _updateHelpRequest(requestId, {
      'status': 'cancelled',
      'cancelledBy': by,
      'cancelledAt': FieldValue.serverTimestamp(),
      'timeline.cancelled': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markCashPending(String requestId) {
    return _updateHelpRequest(requestId, {
      'status': 'payment_under_review',
      'paymentMethod': 'Cash',
      'paymentStatus': 'cash_pending_confirmation',
      'cashReportedAt': FieldValue.serverTimestamp(),
      'timeline.cash_pending_confirmation': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmCashReceived(String requestId) {
    return _updateHelpRequest(requestId, {
      'status': 'completed',
      'paymentStatus': 'paid',
      'paymentReviewStatus': 'approved',
      'paidAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'timeline.paid': FieldValue.serverTimestamp(),
      'timeline.completed': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateHelpRequest(String requestId, Map<String, dynamic> data) {
    if (requestId.trim().isEmpty) {
      throw StateError('Help request id is required.');
    }
    return _firestore.collection('helpRequests').doc(requestId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
