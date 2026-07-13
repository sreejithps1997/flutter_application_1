import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../data/community_campaign_repository.dart';
import '../domain/community_campaign.dart';

class AdminCampaignCalendarScreen extends StatefulWidget {
  static const routeName = '/admin-campaign-calendar';

  const AdminCampaignCalendarScreen({super.key});

  @override
  State<AdminCampaignCalendarScreen> createState() =>
      _AdminCampaignCalendarScreenState();
}

class _AdminCampaignCalendarScreenState
    extends State<AdminCampaignCalendarScreen> {
  final _repository = CommunityCampaignRepository();
  final _currency = NumberFormat.compact();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Campaign Calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _showCreateDialog,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Create'),
      ),
      body: StreamBuilder<List<CommunityCampaign>>(
        stream: _repository.watchCampaigns(),
        builder: (context, snapshot) {
          final campaigns = snapshot.data ?? const <CommunityCampaign>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(WorkableDesign.pagePadding),
            children: [
              const WorkablePageHeader(
                title: 'Seasonal campaigns',
                subtitle:
                    'Create location-based service camps for festivals, monsoon prep, sanitation, AC cleaning, and apartment drives.',
                icon: LucideIcons.calendarDays,
              ),
              const SizedBox(height: 14),
              if (campaigns.isEmpty)
                const WorkableEmptyState(
                  icon: LucideIcons.megaphone,
                  title: 'No campaigns yet',
                  message:
                      'Create the first campaign to show active local offers on the customer dashboard.',
                )
              else
                ...campaigns.map(_campaignCard),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _campaignCard(CommunityCampaign campaign) {
    final color = campaign.isActive
        ? WorkableDesign.success
        : WorkableDesign.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WorkableSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: const TextStyle(
                      color: WorkableDesign.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                WorkableStatusPill(
                  label: campaign.status,
                  color: color,
                  icon: campaign.isActive
                      ? LucideIcons.radio
                      : LucideIcons.fileEdit,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              campaign.message,
              style: const TextStyle(color: WorkableDesign.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WorkableStatusPill(
                  label: campaign.location,
                  color: WorkableDesign.primary,
                  icon: LucideIcons.mapPin,
                ),
                WorkableStatusPill(
                  label: campaign.discountLabel,
                  color: WorkableDesign.accent,
                  icon: LucideIcons.badgePercent,
                ),
                WorkableStatusPill(
                  label:
                      '${_currency.format(campaign.joinedCount)}/${campaign.bookingLimit} joined',
                  color: WorkableDesign.success,
                  icon: LucideIcons.users,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final name = TextEditingController();
    final message = TextEditingController();
    final location = TextEditingController();
    final categories = TextEditingController();
    final discount = TextEditingController(text: 'Group price available');
    final minBookings = TextEditingController(text: '3');
    final bookingLimit = TextEditingController(text: '25');
    String status = 'active';

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Create campaign'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(name, 'Campaign name'),
                  _field(message, 'Banner message', maxLines: 3),
                  _field(location, 'Target location'),
                  _field(categories, 'Service categories, comma separated'),
                  _field(discount, 'Discount label'),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          minBookings,
                          'Min homes',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          bookingLimit,
                          'Slot limit',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                    ],
                    onChanged: (value) {
                      setDialogState(() => status = value ?? 'active');
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (created != true) return;
    setState(() => _saving = true);
    try {
      await _repository.createCampaign(
        name: name.text,
        message: message.text,
        location: location.text,
        serviceCategories: categories.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        discountLabel: discount.text,
        minimumBookings: int.tryParse(minBookings.text) ?? 0,
        bookingLimit: int.tryParse(bookingLimit.text) ?? 0,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Campaign created.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create campaign: $error'),
          backgroundColor: WorkableDesign.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
      name.dispose();
      message.dispose();
      location.dispose();
      categories.dispose();
      discount.dispose();
      minBookings.dispose();
      bookingLimit.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
