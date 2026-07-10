import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/workable_design.dart';
import '../features/bookings/data/booking_payment_repository.dart';
import 'customer_booking_confirmation_screen.dart';

class CustomerPaymentScreen extends StatefulWidget {
  static const routeName = '/customer-payment';

  final String bookingId;

  const CustomerPaymentScreen({super.key, required this.bookingId});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  static const _fallbackMerchantUpiId = 'workable@upi';
  static const _merchantName = 'Workable';

  final _promoCodeController = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');

  String _selectedMethod = 'phonepe';
  bool _isProcessing = false;
  bool _promoApplied = false;
  String? _promoMessage;

  final List<_CheckoutMethod> _paymentMethods = const [
    _CheckoutMethod(
      id: 'phonepe',
      title: 'PhonePe',
      subtitle: 'Open PhonePe with amount pre-filled',
      icon: LucideIcons.smartphone,
      color: Color(0xFF5F259F),
      launchScheme: 'phonepe',
      launchHost: 'pay',
    ),
    _CheckoutMethod(
      id: 'gpay',
      title: 'Google Pay',
      subtitle: 'Open GPay and approve with UPI PIN',
      icon: LucideIcons.badgeCheck,
      color: Color(0xFF1A73E8),
      launchScheme: 'tez',
      launchHost: 'upi/pay',
    ),
    _CheckoutMethod(
      id: 'paytm',
      title: 'Paytm',
      subtitle: 'Open Paytm with secure UPI checkout',
      icon: LucideIcons.wallet,
      color: Color(0xFF00BAF2),
      launchScheme: 'paytmmp',
      launchHost: 'pay',
    ),
    _CheckoutMethod(
      id: 'upi',
      title: 'Other UPI app',
      subtitle: 'BHIM, banking apps, WhatsApp UPI and more',
      icon: LucideIcons.smartphone,
      color: Color(0xFF16A34A),
      launchScheme: 'upi',
      launchHost: 'pay',
    ),
    _CheckoutMethod(
      id: 'Credit Card',
      title: 'Credit Card',
      subtitle: 'Coming with payment gateway integration',
      icon: LucideIcons.creditCard,
      color: Color(0xFF2563EB),
      enabled: false,
    ),
    _CheckoutMethod(
      id: 'Debit Card',
      title: 'Debit Card',
      subtitle: 'Coming with payment gateway integration',
      icon: Icons.credit_card,
      color: Color(0xFF7C3AED),
      enabled: false,
    ),
    _CheckoutMethod(
      id: 'Cash on Delivery',
      title: 'Pay after service',
      subtitle: 'Cash payment after work completion',
      icon: LucideIcons.banknote,
      color: Color(0xFFEA580C),
    ),
  ];

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _bookingRef =>
      FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId);

  double _asAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double _bookingAmount(Map<String, dynamic> booking) {
    final amount = _asAmount(
      booking['totalAmount'] ?? booking['amount'] ?? booking['price'],
    );
    return amount > 0 ? amount : 499;
  }

  double _platformFee(double subtotal) {
    if (_selectedMethod == 'Cash on Delivery') return 0;
    return (subtotal * 0.03).clamp(15, 49).toDouble();
  }

  double _discount(double subtotal) {
    if (!_promoApplied) return 0;
    return (subtotal * 0.10).clamp(0, 100).toDouble();
  }

  double _payableTotal(Map<String, dynamic> booking) {
    final subtotal = _bookingAmount(booking);
    return subtotal + _platformFee(subtotal) - _discount(subtotal);
  }

  void _applyPromo(Map<String, dynamic> booking) {
    final code = _promoCodeController.text.trim().toUpperCase();
    setState(() {
      if (code == 'WORKABLE10') {
        _promoApplied = true;
        _promoMessage =
            'WORKABLE10 applied. You saved ${_currency.format(_discount(_bookingAmount(booking)))}.';
      } else if (code.isEmpty) {
        _promoApplied = false;
        _promoMessage = 'Enter WORKABLE10 to apply a 10% launch discount.';
      } else {
        _promoApplied = false;
        _promoMessage = 'Promo code is not valid for this booking.';
      }
    });
  }

  Future<void> _submitPayment(Map<String, dynamic> booking) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please log in again to complete payment.', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    final subtotal = _bookingAmount(booking);
    final platformFee = _platformFee(subtotal);
    final discount = _discount(subtotal);
    final total = subtotal + platformFee - discount;
    final isCash = _selectedMethod == 'Cash on Delivery';
    final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
    final breakdown = _paymentBreakdown(
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      total: total,
    );

    try {
      if (!isCash) {
        await _startUpiPayment(
          booking: booking,
          userId: user.uid,
          transactionId: transactionId,
          subtotal: subtotal,
          platformFee: platformFee,
          discount: discount,
          total: total,
        );
        return;
      }

      await BookingPaymentRepository().recordCashPending(
        bookingId: widget.bookingId,
        customerId: user.uid,
        transactionId: transactionId,
        paymentMethod: _selectedMethod,
        breakdown: breakdown,
      );

      if (!mounted) return;
      _showSnack(
        isCash
            ? 'Cash payment recorded for verification.'
            : 'Payment successful via $_selectedMethod.',
      );
      Navigator.pushReplacementNamed(
        context,
        CustomerBookingConfirmationScreen.routeName,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Payment failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _merchantUpiId(Map<String, dynamic> booking) {
    final configuredUpi =
        booking['merchantUpiId'] ??
        booking['businessUpiId'] ??
        booking['workerUpiId'] ??
        booking['upiId'];
    final upi = configuredUpi?.toString().trim();
    return upi != null && upi.isNotEmpty ? upi : _fallbackMerchantUpiId;
  }

  Future<void> _startUpiPayment({
    required Map<String, dynamic> booking,
    required String userId,
    required String transactionId,
    required double subtotal,
    required double platformFee,
    required double discount,
    required double total,
  }) async {
    final method = _paymentMethods.firstWhere((m) => m.id == _selectedMethod);
    final upiId = _merchantUpiId(booking);

    if (upiId == _fallbackMerchantUpiId) {
      _showSnack(
        'Online UPI is not available for this booking yet. Please choose cash or contact support.',
        isError: true,
      );
      return;
    }

    await _recordPaymentAttempt(
      booking: booking,
      userId: userId,
      transactionId: transactionId,
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      total: total,
      upiId: upiId,
      status: 'initiated',
    );

    final params = {
      'pa': upiId,
      'pn': _merchantName,
      'am': total.toStringAsFixed(2),
      'cu': 'INR',
      'tn': 'Workable booking ${widget.bookingId}',
      'tr': transactionId,
    };

    final preferredUri = _buildUpiUri(
      scheme: method.launchScheme,
      hostPath: method.launchHost,
      queryParameters: params,
    );
    final genericUri = Uri(scheme: 'upi', host: 'pay', queryParameters: params);

    final launched =
        await _launchPaymentUri(preferredUri) ||
        await _launchPaymentUri(genericUri);

    if (!mounted) return;

    if (!launched) {
      await _recordPaymentAttempt(
        booking: booking,
        userId: userId,
        transactionId: transactionId,
        subtotal: subtotal,
        platformFee: platformFee,
        discount: discount,
        total: total,
        upiId: upiId,
        status: 'launch_failed',
      );
      _showSnack(
        'No supported UPI app was found on this device.',
        isError: true,
      );
      return;
    }

    await _showUpiFollowUpSheet(
      booking: booking,
      userId: userId,
      transactionId: transactionId,
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      total: total,
      upiId: upiId,
    );
  }

  Uri _buildUpiUri({
    required String scheme,
    required String hostPath,
    required Map<String, String> queryParameters,
  }) {
    final parts = hostPath.split('/');
    return Uri(
      scheme: scheme,
      host: parts.first,
      path: parts.length > 1 ? parts.skip(1).join('/') : '',
      queryParameters: queryParameters,
    );
  }

  Future<bool> _launchPaymentUri(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _recordPaymentAttempt({
    required Map<String, dynamic> booking,
    required String userId,
    required String transactionId,
    required double subtotal,
    required double platformFee,
    required double discount,
    required double total,
    required String upiId,
    required String status,
  }) async {
    await BookingPaymentRepository().recordUpiAttempt(
      bookingId: widget.bookingId,
      customerId: userId,
      transactionId: transactionId,
      paymentMethod: _selectedMethod,
      breakdown: _paymentBreakdown(
        subtotal: subtotal,
        platformFee: platformFee,
        discount: discount,
        total: total,
      ),
      upiId: upiId,
      status: status,
    );
  }

  BookingPaymentBreakdown _paymentBreakdown({
    required double subtotal,
    required double platformFee,
    required double discount,
    required double total,
  }) {
    return BookingPaymentBreakdown(
      subtotal: subtotal,
      platformFee: platformFee,
      discount: discount,
      total: total,
      promoCode: _promoApplied ? _promoCodeController.text.trim() : null,
    );
  }

  Future<void> _showUpiFollowUpSheet({
    required Map<String, dynamic> booking,
    required String userId,
    required String transactionId,
    required double subtotal,
    required double platformFee,
    required double discount,
    required double total,
    required String upiId,
  }) async {
    final completed = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Did you complete the UPI payment?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'We opened your UPI app with ${_currency.format(total)}. Once you confirm, this booking will be marked for payment verification.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('I completed the payment'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not paid yet'),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (completed == true) {
      await _recordPaymentAttempt(
        booking: booking,
        userId: userId,
        transactionId: transactionId,
        subtotal: subtotal,
        platformFee: platformFee,
        discount: discount,
        total: total,
        upiId: upiId,
        status: 'customer_reported_paid',
      );
      if (!mounted) return;
      _showSnack('Payment submitted for verification.');
      Navigator.pushReplacementNamed(
        context,
        CustomerBookingConfirmationScreen.routeName,
      );
    } else {
      _showSnack('Payment is still pending.');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(
        title: const Text('Secure Checkout'),
        backgroundColor: WorkableDesign.surface,
        foregroundColor: WorkableDesign.ink,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _bookingRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildEmptyState();
          }

          final booking = snapshot.data!.data()!;
          final subtotal = _bookingAmount(booking);
          final fee = _platformFee(subtotal);
          final discount = _discount(subtotal);
          final total = _payableTotal(booking);
          final paymentState = _PaymentState.from(booking);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(booking, total),
              const SizedBox(height: 16),
              _buildPaymentStateCard(paymentState),
              const SizedBox(height: 16),
              if (!paymentState.isLocked) ...[
                _buildPaymentMethods(),
                const SizedBox(height: 16),
                _buildPromoCard(booking),
                const SizedBox(height: 16),
              ],
              _buildSummaryCard(
                subtotal: subtotal,
                platformFee: fee,
                discount: discount,
                total: total,
              ),
              const SizedBox(height: 16),
              _buildTrustCard(),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
      bottomNavigationBar:
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _bookingRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }
              final booking = snapshot.data!.data()!;
              final total = _payableTotal(booking);
              final paymentState = _PaymentState.from(booking);
              return SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: WorkableDesign.surface,
                    border: Border(
                      top: BorderSide(color: WorkableDesign.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payable now',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _currency.format(total),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isProcessing || paymentState.isLocked
                            ? null
                            : () => _submitPayment(booking),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.lock),
                        label: Text(
                          paymentState.isLocked
                              ? paymentState.actionLabel
                              : _selectedMethod == 'Cash on Delivery'
                              ? 'Confirm'
                              : 'Pay now',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt, size: 44, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            const Text(
              'Booking not found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'We could not load this checkout. Please open it again from your bookings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> booking, double total) {
    final workerName = booking['workerName']?.toString().trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: WorkableDesign.cardDecoration(color: WorkableDesign.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Workable protected checkout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            booking['issue']?.toString().trim().isNotEmpty == true
                ? booking['issue'].toString()
                : 'Service booking',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            workerName != null && workerName.isNotEmpty
                ? 'Professional: $workerName'
                : 'Professional will be assigned shortly',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
              ),
              Text(
                _currency.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return _buildPanel(
      title: 'Payment method',
      child: Column(
        children: _paymentMethods
            .map(
              (method) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPaymentMethodTile(method),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPaymentMethodTile(_CheckoutMethod method) {
    final selected = method.id == _selectedMethod;
    final enabled = method.enabled;
    return InkWell(
      onTap: enabled ? () => setState(() => _selectedMethod = method.id) : null,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? method.color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? method.color : Colors.grey.shade200,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: method.color.withValues(alpha: enabled ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                method.icon,
                color: enabled ? method.color : Colors.grey,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: TextStyle(
                      color: enabled ? Colors.black : Colors.grey,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    method.subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: method.id,
              groupValue: _selectedMethod,
              onChanged: enabled
                  ? (value) => setState(() => _selectedMethod = value!)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCard(Map<String, dynamic> booking) {
    return _buildPanel(
      title: 'Offers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Try WORKABLE10',
                    prefixIcon: const Icon(Icons.local_offer_outlined),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _applyPromo(booking),
                child: const Text('Apply'),
              ),
            ],
          ),
          if (_promoMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _promoMessage!,
              style: TextStyle(
                color: _promoApplied ? Colors.green.shade700 : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required double subtotal,
    required double platformFee,
    required double discount,
    required double total,
  }) {
    return _buildPanel(
      title: 'Bill summary',
      child: Column(
        children: [
          _buildSummaryRow('Service charge', subtotal),
          _buildSummaryRow('Platform protection fee', platformFee),
          if (discount > 0) _buildSummaryRow('Offer discount', -discount),
          Divider(height: 24, color: Colors.grey.shade200),
          _buildSummaryRow('Total payable', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value, {bool isTotal = false}) {
    final isDiscount = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.grey.shade700,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}${_currency.format(value.abs())}',
            style: TextStyle(
              color: isDiscount ? Colors.green.shade700 : Colors.black,
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lock, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedMethod == 'Cash on Delivery'
                  ? 'Your booking will be confirmed now. The worker collects cash only after the service is complete.'
                  : 'This checkout records a secure payment reference and protects the booking in your transaction history.',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStateCard(_PaymentState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: state.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: state.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(state.icon, color: state.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.message,
                  style: const TextStyle(
                    color: WorkableDesign.ink,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CheckoutMethod {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String launchScheme;
  final String launchHost;
  final bool enabled;

  const _CheckoutMethod({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.launchScheme = 'upi',
    this.launchHost = 'pay',
    this.enabled = true,
  });
}

class _PaymentState {
  const _PaymentState({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.actionLabel,
    required this.isLocked,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final String actionLabel;
  final bool isLocked;

  factory _PaymentState.from(Map<String, dynamic> booking) {
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final paymentStatus = (booking['paymentStatus'] ?? '')
        .toString()
        .toLowerCase();

    if (status == 'completed' || status == 'paid' || paymentStatus == 'paid') {
      return const _PaymentState(
        title: 'Payment completed',
        message:
            'This booking is marked paid and completed. You can review the worker from booking details.',
        color: WorkableDesign.success,
        icon: LucideIcons.checkCircle,
        actionLabel: 'Paid',
        isLocked: true,
      );
    }

    if (paymentStatus == 'payment_rejected') {
      final reason = booking['paymentRejectionReason']?.toString().trim();
      return _PaymentState(
        title: 'Payment needs attention',
        message: reason == null || reason.isEmpty
            ? 'The previous payment report was rejected. Please pay again or choose cash.'
            : 'The previous payment report was rejected: $reason',
        color: WorkableDesign.danger,
        icon: LucideIcons.alertTriangle,
        actionLabel: 'Pay again',
        isLocked: false,
      );
    }

    if (paymentStatus == 'cash_pending_confirmation') {
      return const _PaymentState(
        title: 'Cash confirmation pending',
        message:
            'Cash payment is recorded. The worker must confirm receiving cash before this booking is completed.',
        color: WorkableDesign.warning,
        icon: LucideIcons.banknote,
        actionLabel: 'Waiting',
        isLocked: true,
      );
    }

    if (status == 'payment_under_review' ||
        paymentStatus == 'customer_reported_paid' ||
        paymentStatus == 'payment_under_review') {
      return const _PaymentState(
        title: 'Payment under review',
        message:
            'Your payment report was submitted. Workable/admin review will confirm it before the booking is marked completed.',
        color: WorkableDesign.primary,
        icon: LucideIcons.hourglass,
        actionLabel: 'Under review',
        isLocked: true,
      );
    }

    if (status == 'payment_initiated' || paymentStatus == 'initiated') {
      return const _PaymentState(
        title: 'Payment started',
        message:
            'If you completed UPI payment, return to this screen and submit it for verification. Otherwise choose a payment method below.',
        color: WorkableDesign.primary,
        icon: LucideIcons.smartphone,
        actionLabel: 'Continue',
        isLocked: false,
      );
    }

    return const _PaymentState(
      title: 'Payment due',
      message:
          'Choose UPI or cash. UPI is reviewed after you report it paid; cash is completed after the worker confirms receipt.',
      color: WorkableDesign.accent,
      icon: LucideIcons.shieldCheck,
      actionLabel: 'Pay now',
      isLocked: false,
    );
  }
}
