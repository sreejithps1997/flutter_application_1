import 'package:flutter/material.dart';

import '../core/theme/workable_design.dart';
import 'worker_login_screen.dart';
import 'worker_signup_screen.dart';

class WorkerAuthScreen extends StatelessWidget {
  static const routeName = '/worker-auth';

  const WorkerAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(backgroundColor: WorkableDesign.canvas),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              _buildIdentityMark(),
              const SizedBox(height: 28),
              const Text(
                'Turn your skill into a trusted local business.',
                style: TextStyle(
                  color: WorkableDesign.ink,
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Log in to manage jobs and earnings, or create your worker profile to start receiving nearby requests.',
                style: TextStyle(
                  color: WorkableDesign.muted,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              _buildFeatureRow(Icons.badge_outlined, 'Verified profile'),
              _buildFeatureRow(Icons.work_history_outlined, 'Active job flow'),
              _buildFeatureRow(
                Icons.account_balance_wallet_outlined,
                'Earnings and payout tracking',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(context, WorkerLoginScreen.routeName);
                  },
                  child: const Text('Log In'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, WorkerSignupScreen.routeName);
                  },
                  child: const Text('Create Worker Account'),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'By continuing, you agree to our Terms and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: WorkableDesign.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityMark() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: WorkableDesign.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WorkableDesign.accent.withValues(alpha: 0.12),
        ),
      ),
      child: const Icon(
        Icons.engineering_outlined,
        color: WorkableDesign.accent,
        size: 38,
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: WorkableDesign.accent, size: 19),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
