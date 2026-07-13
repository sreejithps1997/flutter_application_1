import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/booking_tracking_repository.dart';
import '../domain/booking_tracking_status.dart';

final bookingTrackingRepositoryProvider = Provider<BookingTrackingRepository>((
  ref,
) {
  return BookingTrackingRepository();
});

final bookingTrackingStatusProvider =
    StreamProvider.family<BookingTrackingStatus, String>((ref, bookingId) {
      return ref
          .watch(bookingTrackingRepositoryProvider)
          .watchTrackingStatus(bookingId);
    });
