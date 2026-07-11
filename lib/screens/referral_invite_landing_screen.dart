import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';
import '../services/referral_link_service.dart';
import 'customer_auth_screen.dart';
import 'worker_auth_screen.dart';

class ReferralInviteLandingScreen extends StatefulWidget {
  static const routeName = '/invite';

  const ReferralInviteLandingScreen({super.key, required this.referralCode});

  final String referralCode;

  @override
  State<ReferralInviteLandingScreen> createState() =>
      _ReferralInviteLandingScreenState();
}

class _ReferralInviteLandingScreenState
    extends State<ReferralInviteLandingScreen> {
  String? _savedCode;

  @override
  void initState() {
    super.initState();
    _saveReferralCode();
  }

  Future<void> _saveReferralCode() async {
    final clean = ReferralLinkService.normalizeCode(widget.referralCode);
    if (clean.isEmpty) return;
    await ReferralLinkService.savePendingReferralCode(clean);
    if (mounted) setState(() => _savedCode = clean);
  }

  void _continueAsCustomer() {
    Navigator.pushReplacementNamed(context, CustomerAuthScreen.routeName);
  }

  void _continueAsWorker() {
    Navigator.pushReplacementNamed(context, WorkerAuthScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final code =
        _savedCode ?? ReferralLinkService.normalizeCode(widget.referralCode);

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(backgroundColor: WorkableDesign.canvas),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: WorkableDesign.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: WorkableDesign.primary.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.card_giftcard_outlined,
                  color: WorkableDesign.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'You were invited to Workable',
                style: TextStyle(
                  color: WorkableDesign.ink,
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                code.isEmpty
                    ? 'Choose how you want to continue. If you have a referral code, you can still enter it during signup.'
                    : 'Referral code $code is saved. It will be filled automatically when you create a customer or worker account.',
                style: const TextStyle(
                  color: WorkableDesign.muted,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _continueAsCustomer,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Join as customer'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _continueAsWorker,
                  icon: const Icon(Icons.engineering_outlined),
                  label: const Text('Join as worker'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
