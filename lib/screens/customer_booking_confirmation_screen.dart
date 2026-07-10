import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'customer_dashboard_screen.dart';

class CustomerBookingConfirmationScreen extends StatelessWidget {
  static const routeName = '/customer-booking-confirmation';

  const CustomerBookingConfirmationScreen({super.key});

  void _goToHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      CustomerDashboardScreen.routeName,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Booking Submitted'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(WorkableDesign.pagePadding),
          children: [
            const WorkablePageHeader(
              title: 'Request sent',
              subtitle:
                  'Your booking is now waiting for worker confirmation. You can track updates from bookings.',
              icon: LucideIcons.checkCircle,
            ),
            const SizedBox(height: 16),
            const WorkableSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkableInfoRow(
                    icon: LucideIcons.bell,
                    text:
                        'You will receive a notification after the worker accepts or responds.',
                  ),
                  SizedBox(height: 10),
                  WorkableInfoRow(
                    icon: LucideIcons.listChecks,
                    text:
                        'Booking progress, payment, completion and reviews stay connected in your bookings page.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/customer-bookings',
                (route) => false,
              ),
              icon: const Icon(LucideIcons.listChecks),
              label: const Text('View My Bookings'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _goToHome(context),
              icon: const Icon(LucideIcons.home),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
