import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class PaymentMethodsScreen extends StatefulWidget {
  static const routeName = '/payment-methods';

  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  String selectedMethod = 'card-1';
  bool quickPayEnabled = true;

  Widget _buildPaymentCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    String? balance,
    bool isDefault = false,
    Color bgColor = Colors.blue,
  }) {
    final isSelected = selectedMethod == id;
    return InkWell(
      onTap: () => setState(() => selectedMethod = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(fontSize: 10, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (balance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '₹$balance available',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected) const Icon(Icons.check, color: Colors.blue),
            Icon(Icons.more_vert, color: Colors.grey[400], size: 18),
          ],
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F8F8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.blue),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.3,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.grey,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Method'),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Saved methods
            const Text(
              'Saved Methods',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildPaymentCard(
              id: 'card-1',
              icon: LucideIcons.creditCard,
              title: 'HDFC Debit Card',
              subtitle: '**** **** **** 4521',
              isDefault: true,
              bgColor: Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildPaymentCard(
              id: 'upi-1',
              icon: LucideIcons.smartphone,
              title: 'Google Pay',
              subtitle: 'john.doe@okhdfcbank',
              bgColor: Colors.green,
            ),
            const SizedBox(height: 12),
            _buildPaymentCard(
              id: 'wallet-1',
              icon: LucideIcons.wallet,
              title: 'Workable Wallet',
              subtitle: 'Digital wallet',
              balance: '150',
              bgColor: Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildPaymentCard(
              id: 'bank-1',
              icon: LucideIcons.building2,
              title: 'HDFC Bank Account',
              subtitle: '****1234 - Savings',
              bgColor: Colors.indigo,
            ),
            const SizedBox(height: 24),

            // Preferences
            const Text(
              'Payment Preferences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildToggle(
              title: 'Quick Pay',
              subtitle: 'Skip verification for amounts under ₹500',
              value: quickPayEnabled,
              onChanged: (val) => setState(() => quickPayEnabled = val),
              icon: LucideIcons.zap,
            ),
            const SizedBox(height: 12),
            _buildToggle(
              title: 'Auto-pay for Bookings',
              subtitle: 'Automatically pay when booking is confirmed',
              value: false,
              onChanged: (val) {},
              icon: LucideIcons.settings,
            ),
            const SizedBox(height: 12),
            _buildToggle(
              title: 'Biometric Authentication',
              subtitle: 'Use fingerprint/face unlock for payments',
              value: true,
              onChanged: (val) {},
              icon: LucideIcons.shield,
            ),
            const SizedBox(height: 24),

            // Security note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.shield, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Your payments are secure',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We use bank-level encryption and never store your full card details.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment limit
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Payment Limit',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹5,000 remaining today',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Modify',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.6,
                    backgroundColor: Colors.grey[200],
                    color: Colors.blue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Add new options
            const Text(
              'Add New Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              children: [
                _buildAddMethodTile(
                  LucideIcons.creditCard,
                  'Credit/Debit Card',
                ),
                _buildAddMethodTile(LucideIcons.smartphone, 'UPI ID'),
                _buildAddMethodTile(LucideIcons.building2, 'Bank Account'),
                _buildAddMethodTile(LucideIcons.wallet, 'Digital Wallet'),
              ],
            ),
            const SizedBox(height: 24),

            // Help
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Contact support for payment issues',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMethodTile(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: Colors.grey[700]),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
