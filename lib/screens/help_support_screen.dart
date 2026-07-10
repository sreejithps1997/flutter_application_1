import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/workable_design.dart';
import '../widgets/workable_ui.dart';
import 'report_issue_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  static const routeName = '/help-support';

  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  final List<String> _categories = const [
    'Booking help',
    'Payment issue',
    'Worker concern',
    'Account or login',
    'Safety concern',
    'App feedback',
  ];

  String _selectedCategory = 'Booking help';
  String _searchQuery = '';
  bool _isSubmitting = false;

  static const List<_FaqItem> _faqItems = [
    _FaqItem(
      category: 'Booking',
      question: 'How do I know my booking is confirmed?',
      answer:
          'A booking becomes confirmed after the worker accepts it. You can track the full status from your bookings page.',
    ),
    _FaqItem(
      category: 'Payment',
      question: 'What should I do if I already paid?',
      answer:
          'Open the booking payment page and use the reported payment flow. Admin review keeps UPI payments from being marked paid without verification.',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'How do I report a worker or unsafe situation?',
      answer:
          'Use Report Issue and choose safety concern. Those requests are marked high priority for review.',
    ),
    _FaqItem(
      category: 'Account',
      question: 'Can I change my saved address or profile details?',
      answer:
          'Yes. Open Account settings to update profile, addresses, security, language, and app preferences.',
    ),
    _FaqItem(
      category: 'Repeat',
      question: 'Can I book the same worker again?',
      answer:
          'Use Repeat Booking to reopen completed services with the same worker or the same service details.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filteredFaqItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _faqItems;

    return _faqItems.where((item) {
      return item.category.toLowerCase().contains(query) ||
          item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _submitSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please login again to contact support.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final isSafety = _selectedCategory == 'Safety concern';
      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': user.uid,
        'userEmail': user.email,
        'category': _selectedCategory,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'open',
        'priority': isSafety ? 'high' : 'normal',
        'source': 'customer_help_support',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _subjectController.clear();
      _messageController.clear();
      if (!mounted) return;
      _showSnack('Support request submitted.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not submit support request: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? WorkableDesign.danger
            : WorkableDesign.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Help & Support'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const WorkablePageHeader(
              title: 'Get help without waiting',
              subtitle:
                  'Search common answers, report urgent issues, or send a support request with clear priority.',
              icon: LucideIcons.helpCircle,
            ),
            const SizedBox(height: 16),
            _buildServiceStatus(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildFaqSection(),
            const SizedBox(height: 16),
            _buildSupportForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatus() {
    return const WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkableInfoRow(
            icon: LucideIcons.checkCircle,
            text:
                'Support is active for booking, payment, account and safety requests.',
          ),
          SizedBox(height: 10),
          WorkableInfoRow(
            icon: LucideIcons.clock,
            text: 'Safety and payment issues are treated as higher priority.',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Quick actions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: LucideIcons.alertTriangle,
                  title: 'Report issue',
                  subtitle: 'Booking, worker or safety',
                  onTap: () =>
                      Navigator.pushNamed(context, ReportIssueScreen.routeName),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: LucideIcons.repeat,
                  title: 'Repeat service',
                  subtitle: 'Book trusted help again',
                  onTap: () => Navigator.pushNamed(context, '/repeat-booking'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    final filteredItems = _filteredFaqItems;

    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Help topics'),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              labelText: 'Search help',
              hintText: 'Payment, booking, safety...',
            ),
          ),
          const SizedBox(height: 14),
          if (filteredItems.isEmpty)
            const WorkableEmptyState(
              icon: LucideIcons.search,
              title: 'No matching help topic',
              message: 'Send a support request and the team can review it.',
            )
          else
            ...filteredItems.map((item) => _FaqTile(item: item)),
        ],
      ),
    );
  }

  Widget _buildSupportForm() {
    return WorkableSectionCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Contact support'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(LucideIcons.list),
              ),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Subject',
                prefixIcon: Icon(LucideIcons.fileText),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 4) {
                  return 'Enter a clear subject';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'What do you need help with?',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().length < 15) {
                  return 'Add at least 15 characters so support can help faster';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitSupportRequest,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.send),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WorkableDesign.radius),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WorkableDesign.canvas,
          borderRadius: BorderRadius.circular(WorkableDesign.radius),
          border: Border.all(color: WorkableDesign.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: WorkableDesign.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: WorkableDesign.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: WorkableDesign.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: WorkableDesign.ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});

  final _FaqItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: WorkableDesign.canvas,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: WorkableDesign.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: const Icon(
          LucideIcons.messageCircle,
          color: WorkableDesign.primary,
        ),
        title: Text(
          item.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: WorkableDesign.ink,
          ),
        ),
        subtitle: Text(
          item.category,
          style: const TextStyle(fontSize: 12, color: WorkableDesign.muted),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.answer,
              style: const TextStyle(height: 1.45, color: WorkableDesign.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}
