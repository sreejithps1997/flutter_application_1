import 'package:flutter/material.dart';

import 'customer_booking_detail_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  static const routeName = '/booking-detail';

  final Map<String, dynamic> booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return CustomerBookingDetailScreen(booking: booking);
  }
}
