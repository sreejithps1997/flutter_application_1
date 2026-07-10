import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/workable_design.dart';

class WorkerPayoutMethodsScreen extends StatefulWidget {
  const WorkerPayoutMethodsScreen({super.key});

  static const routeName = '/worker/payout-methods';

  @override
  State<WorkerPayoutMethodsScreen> createState() =>
      _WorkerPayoutMethodsScreenState();
}

class _WorkerPayoutMethodsScreenState extends State<WorkerPayoutMethodsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _defaultMethod = 'upi';

  @override
  void initState() {
    super.initState();
    _loadPayout();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _loadPayout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    final payout = Map<String, dynamic>.from(data['payout'] ?? {});
    final topLevelMethod = data['paymentMethod']?.toString().toLowerCase();

    if (!mounted) return;
    setState(() {
      _upiController.text =
          payout['upiId']?.toString() ?? data['upiId']?.toString() ?? '';
      _accountNameController.text =
          payout['bankAccountName']?.toString() ??
          data['bankAccountName']?.toString() ??
          '';
      _accountNumberController.text =
          payout['bankAccountNumber']?.toString() ??
          data['bankAccountNumber']?.toString() ??
          '';
      _ifscController.text =
          payout['ifsc']?.toString() ?? data['ifscCode']?.toString() ?? '';
      _defaultMethod =
          payout['defaultMethod']?.toString() == 'bank' ||
              topLevelMethod == 'bank'
          ? 'bank'
          : 'upi';
      _loading = false;
    });
  }

  Future<void> _savePayout() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final upiId = _upiController.text.trim();
    final accountName = _accountNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim().toUpperCase();

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('workers').doc(uid).set({
        'paymentMethod': _defaultMethod == 'bank' ? 'Bank' : 'UPI',
        'upiId': upiId,
        'bankAccountName': accountName,
        'bankAccountNumber': accountNumber,
        'ifscCode': ifsc,
        'payout': {
          'upiId': upiId,
          'bankAccountName': accountName,
          'bankAccountNumber': accountNumber,
          'ifsc': ifsc,
          'defaultMethod': _defaultMethod,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'payoutMethodUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payout methods saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save payout methods: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Payout Methods')),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: WorkableDesign.surface,
                  border: Border(top: BorderSide(color: WorkableDesign.border)),
                ),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _savePayout,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Payout Method'),
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _HeaderCard(
                    defaultMethod: _defaultMethod,
                    hasUpi: _isValidUpi(_upiController.text),
                    hasBank: _isValidBank(),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Default Payout',
                    subtitle:
                        'Choose where eligible completed-job earnings should be sent.',
                    icon: Icons.account_balance_wallet_outlined,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'upi',
                          icon: Icon(Icons.qr_code_2_outlined),
                          label: Text('UPI'),
                        ),
                        ButtonSegment(
                          value: 'bank',
                          icon: Icon(Icons.account_balance_outlined),
                          label: Text('Bank'),
                        ),
                      ],
                      selected: {_defaultMethod},
                      onSelectionChanged: (value) {
                        setState(() => _defaultMethod = value.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'UPI Details',
                    subtitle:
                        'Recommended for fast settlement. Example: name@bank',
                    icon: Icons.qr_code_scanner_outlined,
                    child: TextFormField(
                      controller: _upiController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        hintText: 'name@bank',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (_defaultMethod != 'upi') return null;
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'UPI ID is required';
                        if (!_isValidUpi(text)) return 'Enter a valid UPI ID';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Bank Account',
                    subtitle:
                        'Use the exact account holder name, account number, and IFSC code.',
                    icon: Icons.account_balance_outlined,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _accountNameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Account holder name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (_defaultMethod != 'bank') return null;
                            final text = value?.trim() ?? '';
                            if (text.length < 3) {
                              return 'Enter account holder name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Account number',
                            prefixIcon: Icon(Icons.numbers_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (_defaultMethod != 'bank') return null;
                            final text = value?.trim() ?? '';
                            if (text.length < 9 || text.length > 18) {
                              return 'Enter a valid account number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _ifscController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(11),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'IFSC code',
                            hintText: 'ABCD0123456',
                            prefixIcon: Icon(Icons.account_tree_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (_defaultMethod != 'bank') return null;
                            final text = value?.trim().toUpperCase() ?? '';
                            if (!RegExp(
                              r'^[A-Z]{4}0[A-Z0-9]{6}$',
                            ).hasMatch(text)) {
                              return 'Enter a valid IFSC code';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SecurityNote(),
                ],
              ),
            ),
    );
  }

  bool _isValidUpi(String value) {
    return RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$').hasMatch(value.trim());
  }

  bool _isValidBank() {
    return _accountNameController.text.trim().length >= 3 &&
        _accountNumberController.text.trim().length >= 9 &&
        RegExp(
          r'^[A-Z]{4}0[A-Z0-9]{6}$',
        ).hasMatch(_ifscController.text.trim().toUpperCase());
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.defaultMethod,
    required this.hasUpi,
    required this.hasBank,
  });

  final String defaultMethod;
  final bool hasUpi;
  final bool hasBank;

  @override
  Widget build(BuildContext context) {
    final label = defaultMethod == 'bank' ? 'Bank transfer' : 'UPI';
    final ready = defaultMethod == 'bank' ? hasBank : hasUpi;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WorkableDesign.ink,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default payout: $label',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'Ready for payout requests after completed paid jobs.'
                      : 'Complete the selected payout details to request payouts.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _ReadyPill(ready: ready),
        ],
      ),
    );
  }
}

class _ReadyPill extends StatelessWidget {
  const _ReadyPill({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? WorkableDesign.success : WorkableDesign.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        ready ? 'Ready' : 'Setup',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorkableDesign.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: WorkableDesign.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: WorkableDesign.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(
          color: WorkableDesign.primary.withValues(alpha: 0.14),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: WorkableDesign.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'These details are used only for worker payout settlement and admin payout review.',
              style: TextStyle(
                color: WorkableDesign.ink,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
