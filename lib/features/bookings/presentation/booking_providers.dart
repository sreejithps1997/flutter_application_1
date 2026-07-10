import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/booking_action_repository.dart';
import '../data/booking_payment_repository.dart';
import '../data/booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

final bookingActionRepositoryProvider = Provider<BookingActionRepository>((
  ref,
) {
  return BookingActionRepository();
});

final bookingPaymentRepositoryProvider = Provider<BookingPaymentRepository>((
  ref,
) {
  return BookingPaymentRepository();
});
