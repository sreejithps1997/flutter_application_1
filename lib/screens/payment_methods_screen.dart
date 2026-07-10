import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../services/app_preferences_service.dart';
import '../widgets/workable_ui.dart';

class PaymentMethodsScreen extends StatefulWidget {
  static const routeName = '/payment-methods';

  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  bool quickPayEnabled = true;
  bool autoPayEnabled = false;
  bool biometricPayments = true;

  @override
  void initState() {
    super.initState();
    quickPayEnabled = AppPreferencesService.quickPay;
    autoPayEnabled = AppPreferencesService.autoPay;
    biometricPayments = AppPreferencesService.biometricPayments;
  }

  CollectionReference<Map<String, dynamic>> _methodsRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('paymentMethods');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _methodsStream(String uid) {
    return _methodsRef(uid).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> _addUpiMethod(String uid) async {
    final labelController = TextEditingController(text: 'UPI');
    final upiController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add UPI ID',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  hintText: 'Google Pay, PhonePe, Paytm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'UPI ID',
                  hintText: 'name@bank',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final upi = upiController.text.trim();
                    if (!_isValidUpi(upi)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid UPI ID like name@bank'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'label': labelController.text.trim().isEmpty
                          ? 'UPI'
                          : labelController.text.trim(),
                      'upiId': upi,
                    });
                  },
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Save UPI ID'),
                ),
              ),
            ],
          ),
        );
      },
    );

    labelController.dispose();
    upiController.dispose();

    if (result == null) return;

    final existing = await _methodsRef(uid).limit(1).get();
    await _methodsRef(uid).add({
      'type': 'upi',
      'label': result['label'],
      'upiId': result['upiId'],
      'isDefault': existing.docs.isEmpty,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _showSnack('UPI ID saved');
  }

  bool _isValidUpi(String value) {
    return RegExp(r'^[a-zA-Z0-9.\-_]{2,}@[a-zA-Z]{2,}$').hasMatch(value);
  }

  Future<void> _setDefault(String uid, String methodId) async {
    final batch = FirebaseFirestore.instance.batch();
    final methods = await _methodsRef(uid).get();
    for (final method in methods.docs) {
      batch.update(method.reference, {
        'isDefault': method.id == methodId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    if (!mounted) return;
    _showSnack('Default payment method updated');
  }

  Future<void> _deleteMethod(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> method,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment method?'),
        content: Text(
          'Remove ${method.data()['label'] ?? 'this method'} from your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final wasDefault = method.data()['isDefault'] == true;
    await method.reference.delete();

    if (wasDefault) {
      final next = await _methodsRef(uid).limit(1).get();
      if (next.docs.isNotEmpty) {
        await next.docs.first.reference.update({
          'isDefault': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    if (!mounted) return;
    _showSnack('Payment method removed');
  }

  Future<void> _toggleQuickPay(bool value) async {
    setState(() => quickPayEnabled = value);
    await AppPreferencesService.setQuickPay(value);
  }

  Future<void> _toggleAutoPay(bool value) async {
    setState(() => autoPayEnabled = value);
    await AppPreferencesService.setAutoPay(value);
  }

  Future<void> _toggleBiometricPayments(bool value) async {
    setState(() => biometricPayments = value);
    await AppPreferencesService.setBiometricPayments(value);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Payment Methods'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? _emptyState('Sign in to manage payment methods')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _methodsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _emptyState('Unable to load payment methods');
                }

                final methods = snapshot.data!.docs;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const WorkablePageHeader(
                      title: 'Payment readiness',
                      subtitle:
                          'Save trusted UPI aliases and choose how fast checkout should feel.',
                      icon: LucideIcons.creditCard,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _addUpiMethod(user.uid),
                            icon: const Icon(Icons.add),
                            label: const Text('Add UPI ID'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.outlined(
                          icon: const Icon(Icons.settings),
                          onPressed: () =>
                              _showSnack('Payment preferences saved locally'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Saved Methods',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (methods.isEmpty)
                      _emptyState('No saved payment methods yet')
                    else
                      ...methods.map(
                        (method) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPaymentCard(user.uid, method),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _buildUnavailableMethods(),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment Preferences',
                      style: TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildToggle(
                      title: 'Quick Pay',
                      subtitle: 'Skip extra confirmation under Rs. 500',
                      value: quickPayEnabled,
                      onChanged: _toggleQuickPay,
                      icon: LucideIcons.zap,
                    ),
                    const SizedBox(height: 12),
                    _buildToggle(
                      title: 'Auto-pay for Bookings',
                      subtitle: 'Use your default method when available',
                      value: autoPayEnabled,
                      onChanged: _toggleAutoPay,
                      icon: LucideIcons.settings,
                    ),
                    const SizedBox(height: 12),
                    _buildToggle(
                      title: 'Biometric Payment Lock',
                      subtitle: 'Require device unlock before payment',
                      value: biometricPayments,
                      onChanged: _toggleBiometricPayments,
                      icon: LucideIcons.shield,
                    ),
                    const SizedBox(height: 24),
                    _buildSecurityNote(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPaymentCard(
    String uid,
    QueryDocumentSnapshot<Map<String, dynamic>> method,
  ) {
    final data = method.data();
    final isDefault = data['isDefault'] == true;

    return InkWell(
      onTap: () => _setDefault(uid, method.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: WorkableDesign.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDefault ? WorkableDesign.primary : WorkableDesign.border,
            width: isDefault ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: WorkableDesign.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                LucideIcons.smartphone,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data['label']?.toString() ?? 'UPI',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        _defaultPill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data['upiId']?.toString() ?? '',
                    style: TextStyle(color: WorkableDesign.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'default') _setDefault(uid, method.id);
                if (value == 'delete') _deleteMethod(uid, method);
              },
              itemBuilder: (context) => [
                if (!isDefault)
                  const PopupMenuItem(
                    value: 'default',
                    child: Text('Set as default'),
                  ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: WorkableDesign.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'Default',
        style: TextStyle(fontSize: 10, color: WorkableDesign.success),
      ),
    );
  }

  Widget _buildUnavailableMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Coming with Gateway Integration',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _disabledMethod(LucideIcons.creditCard, 'Cards')),
            const SizedBox(width: 10),
            Expanded(
              child: _disabledMethod(LucideIcons.building2, 'Bank Account'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _disabledMethod(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: WorkableDesign.muted),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: WorkableDesign.muted)),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WorkableDesign.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: WorkableDesign.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: WorkableDesign.muted),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WorkableDesign.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: WorkableDesign.primary.withValues(alpha: 0.18),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.shield, size: 20, color: WorkableDesign.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Only UPI aliases are saved here. Card and bank storage will be added with a certified payment gateway.',
              style: TextStyle(color: WorkableDesign.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.creditCard,
              color: WorkableDesign.muted,
              size: 38,
            ),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
