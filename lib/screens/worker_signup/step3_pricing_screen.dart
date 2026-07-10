import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/workable_design.dart';
import '../../models/worker_onboarding_data.dart';
import '../../widgets/worker_onboarding_shell.dart';
import 'step4_schedule_screen.dart';

class Step3PricingScreen extends StatefulWidget {
  static const routeName = '/step3-pricing';
  final WorkerOnboardingData onboardingData;

  const Step3PricingScreen({super.key, required this.onboardingData});

  @override
  State<Step3PricingScreen> createState() => _Step3PricingScreenState();
}

class _Step3PricingScreenState extends State<Step3PricingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedPaymentMethod = 'Cash';
  final Map<String, TextEditingController> _rateControllers = {};
  final _upiController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();

  final Map<String, String> _averageMarketPrices = const {
    'Regular House Cleaning': 'Rs 300-500',
    'Deep Cleaning': 'Rs 800-1500',
    'Post-Renovation Cleaning': 'Rs 1000-2000',
    'Kitchen Deep Cleaning': 'Rs 400-700',
    "Men's Haircut": 'Rs 100-300',
    "Women's Haircut & Styling": 'Rs 200-500',
    'Facial & Cleanup': 'Rs 300-800',
    'Manicure & Pedicure': 'Rs 200-500',
    'Eyebrow Threading': 'Rs 50-150',
    'AC Servicing & Repair': 'Rs 300-800',
    'Washing Machine Repair': 'Rs 200-600',
    'Refrigerator Repair': 'Rs 250-700',
    'TV & Electronics Repair': 'Rs 200-1000',
    'Plumbing Services': 'Rs 200-800',
    'Electrical Work': 'Rs 200-600',
    'Painting Services': 'Rs 15-25/sq ft',
    'Carpenter Services': 'Rs 300-800',
  };

  @override
  void initState() {
    super.initState();
    for (final skill in widget.onboardingData.skills) {
      _rateControllers[skill] = TextEditingController(
        text: widget.onboardingData.wageMap[skill] ?? '',
      );
    }
    _selectedPaymentMethod = widget.onboardingData.paymentMethod.isEmpty
        ? 'Cash'
        : widget.onboardingData.paymentMethod;
    _upiController.text = widget.onboardingData.upiId ?? '';
    _accountController.text = widget.onboardingData.bankAccountNumber ?? '';
    _ifscController.text = widget.onboardingData.ifscCode ?? '';
  }

  @override
  void dispose() {
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    _upiController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  void _proceedToNextStep() {
    if (!_formKey.currentState!.validate()) return;

    final rates = <String, String>{};
    for (final entry in _rateControllers.entries) {
      rates[entry.key] = entry.value.text.trim();
    }

    final updatedData = widget.onboardingData.copyWith(
      paymentMethod: _selectedPaymentMethod,
      wageMap: rates,
      upiId: _selectedPaymentMethod == 'UPI' ? _upiController.text.trim() : '',
      bankAccountNumber: _selectedPaymentMethod == 'Bank'
          ? _accountController.text.trim()
          : '',
      ifscCode: _selectedPaymentMethod == 'Bank'
          ? _ifscController.text.trim()
          : '',
    );

    Navigator.pushNamed(
      context,
      Step4ScheduleScreen.routeName,
      arguments: updatedData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final skills = widget.onboardingData.skills;

    return WorkerOnboardingShell(
      title: 'Set fair pricing',
      subtitle:
          'Customers trust clear pricing. Add your starting rate for each service and choose how you prefer to receive payouts.',
      step: 4,
      totalSteps: 6,
      bottom: FilledButton(
        onPressed: _proceedToNextStep,
        child: const Text('Continue'),
      ),
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              WorkerOnboardingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service rates',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use your minimum visit or starting rate. Final price can still change after inspection.',
                      style: TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...skills.map(_buildRateField),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              WorkerOnboardingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payout method',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentOption('Cash', Icons.payments_outlined),
                    _buildPaymentOption('UPI', Icons.qr_code_2_outlined),
                    if (_selectedPaymentMethod == 'UPI') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _upiController,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          hintText: 'name@bank',
                          prefixIcon: Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                        ),
                        validator: (value) {
                          if (_selectedPaymentMethod != 'UPI') return null;
                          final trimmed = value?.trim() ?? '';
                          return trimmed.contains('@')
                              ? null
                              : 'Enter a valid UPI ID';
                        },
                      ),
                    ],
                    _buildPaymentOption('Bank', Icons.account_balance_outlined),
                    if (_selectedPaymentMethod == 'Bank') ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _accountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Bank account number',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                        validator: (value) {
                          if (_selectedPaymentMethod != 'Bank') return null;
                          final trimmed = value?.trim() ?? '';
                          return trimmed.length >= 9
                              ? null
                              : 'Enter a valid account number';
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ifscController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'IFSC code',
                          hintText: 'ABCD0123456',
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                        validator: (value) {
                          if (_selectedPaymentMethod != 'Bank') return null;
                          final trimmed = value?.trim().toUpperCase() ?? '';
                          return RegExp(
                                r'^[A-Z]{4}0[A-Z0-9]{6}$',
                              ).hasMatch(trimmed)
                              ? null
                              : 'Enter a valid IFSC code';
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRateField(String skill) {
    final marketPrice = _averageMarketPrices[skill];
    final controller = _rateControllers[skill]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: skill,
          hintText: 'Your starting rate',
          prefixText: 'Rs ',
          helperText: marketPrice == null ? null : 'Typical rate: $marketPrice',
        ),
        validator: (value) {
          final rate = int.tryParse(value ?? '');
          if (rate == null || rate <= 0) return 'Enter your starting rate';
          if (rate < 50) return 'Rate looks too low';
          return null;
        },
      ),
    );
  }

  Widget _buildPaymentOption(String value, IconData icon) {
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      value: value,
      groupValue: _selectedPaymentMethod,
      onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
      secondary: Icon(icon, color: WorkableDesign.accent),
      title: Text(
        value == 'Bank'
            ? 'Bank Transfer'
            : value == 'UPI'
            ? 'UPI Transfer'
            : 'Cash',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
