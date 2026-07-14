import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/features/help_requests/data/help_request_repository.dart';
import 'package:workable/features/help_requests/domain/help_request_draft.dart';
import 'package:workable/features/help_requests/presentation/customer_help_request_detail_screen.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../data/community_campaign_repository.dart';
import '../domain/community_campaign.dart';
import '../domain/community_campaign_slot.dart';

class CustomerCampaignDetailScreen extends StatefulWidget {
  static const routeName = '/customer-campaign-detail';

  const CustomerCampaignDetailScreen({super.key});

  @override
  State<CustomerCampaignDetailScreen> createState() =>
      _CustomerCampaignDetailScreenState();
}

class _CustomerCampaignDetailScreenState
    extends State<CustomerCampaignDetailScreen> {
  final _repository = CommunityCampaignRepository();
  final _helpRequestRepository = HelpRequestRepository();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final campaign =
        ModalRoute.of(context)?.settings.arguments as CommunityCampaign?;
    if (campaign == null) {
      return const Scaffold(
        body: WorkableEmptyState(
          icon: LucideIcons.megaphone,
          title: 'Campaign not found',
          message: 'Open this page from a campaign banner.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Community Campaign')),
      body: ListView(
        padding: const EdgeInsets.all(WorkableDesign.pagePadding),
        children: [
          WorkablePageHeader(
            title: campaign.name,
            subtitle: campaign.message,
            icon: LucideIcons.megaphone,
          ),
          const SizedBox(height: 14),
          _buildProgressCard(campaign),
          const SizedBox(height: 12),
          _buildGroupSlotsCard(campaign),
          const SizedBox(height: 12),
          _buildServiceCard(campaign),
          const SizedBox(height: 12),
          _buildActions(campaign),
          const SizedBox(height: 12),
          const WorkableSectionCard(
            child: WorkableInfoRow(
              icon: LucideIcons.shieldCheck,
              text:
                  'Exact addresses are never shown to neighbours. Campaign counts show only area-level demand.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSlotsCard(CommunityCampaign campaign) {
    return StreamBuilder<List<CommunityCampaignSlot>>(
      stream: _repository.watchCampaignSlots(campaign.id),
      builder: (context, snapshot) {
        final slots = snapshot.data ?? const [];
        return WorkableSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WorkableInfoRow(
                icon: LucideIcons.calendar,
                text: 'Popular group slots',
              ),
              const SizedBox(height: 10),
              if (slots.isEmpty)
                const Text(
                  'Choose a date and slot after joining. Nearby customers selecting the same service slot will be grouped here.',
                  style: TextStyle(
                    color: WorkableDesign.muted,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                ...slots.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WorkableInfoRow(
                      icon: LucideIcons.users,
                      text:
                          '${slot.joinedCount} ${slot.joinedCount == 1 ? 'home' : 'homes'} • ${slot.label}',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressCard(CommunityCampaign campaign) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: WorkableInfoRow(
                  icon: LucideIcons.mapPin,
                  text: campaign.location,
                ),
              ),
              WorkableStatusPill(
                label: campaign.discountLabel,
                color: WorkableDesign.success,
                icon: LucideIcons.badgePercent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: campaign.progress,
              minHeight: 10,
              backgroundColor: WorkableDesign.border,
              color: WorkableDesign.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${campaign.joinedCount} homes joined near ${campaign.location}',
            style: const TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            campaign.groupProgressLabel,
            style: const TextStyle(
              color: WorkableDesign.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkableStatusPill(
                label: 'Min ${campaign.minimumBookings} homes',
                color: WorkableDesign.warning,
                icon: LucideIcons.target,
              ),
              WorkableStatusPill(
                label: '${campaign.remainingSlots} slots left',
                color: WorkableDesign.accent,
                icon: LucideIcons.ticket,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(CommunityCampaign campaign) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Included service categories',
            style: TextStyle(
              color: WorkableDesign.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: campaign.serviceCategories.isEmpty
                ? [
                    const WorkableStatusPill(
                      label: 'General local help',
                      color: WorkableDesign.primary,
                      icon: LucideIcons.sparkles,
                    ),
                  ]
                : campaign.serviceCategories
                      .map(
                        (category) => WorkableStatusPill(
                          label: category,
                          color: WorkableDesign.primary,
                          icon: LucideIcons.wrench,
                        ),
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(CommunityCampaign campaign) {
    return StreamBuilder<bool>(
      stream: _repository.watchMyJoinStatus(campaign.id),
      builder: (context, snapshot) {
        final joined = snapshot.data ?? false;
        return WorkableSectionCard(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || joined ? null : () => _join(campaign),
                  icon: Icon(joined ? LucideIcons.check : LucideIcons.users),
                  label: Text(
                    joined ? 'You joined this campaign' : 'Join Campaign',
                  ),
                ),
              ),
              if (joined) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _createCampaignHelpRequest(campaign),
                    icon: const Icon(LucideIcons.calendarClock, size: 18),
                    label: const Text('Choose Slot & Request Service'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _share(campaign, 'whatsapp'),
                      icon: const Icon(LucideIcons.messageCircle, size: 18),
                      label: const Text('WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _share(campaign, 'copy'),
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _join(CommunityCampaign campaign) async {
    setState(() => _busy = true);
    try {
      await _repository.joinCampaign(campaign);
      if (!mounted) return;
      _showSnack('Campaign joined. Choose a slot to request service.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to join campaign: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCampaignHelpRequest(CommunityCampaign campaign) async {
    final draft = await showDialog<_CampaignRequestDraft>(
      context: context,
      builder: (_) => _CampaignRequestDialog(campaign: campaign),
    );
    if (draft == null) return;

    setState(() => _busy = true);
    try {
      final requestType = draft.serviceCategory.isNotEmpty
          ? draft.serviceCategory
          : (campaign.serviceCategories.isNotEmpty
                ? campaign.serviceCategories.first
                : campaign.name);
      final slotId = CommunityCampaignRepository.buildSlotId(
        serviceCategory: requestType,
        preferredDate: draft.date,
        preferredTime: draft.time,
      );
      final helpRequestId = await _helpRequestRepository.createHelpRequest(
        HelpRequestDraft(
          requestType: requestType,
          title: campaign.name,
          description:
              '${campaign.message}\n\nCampaign: ${campaign.name}\nArea: ${campaign.location}\nOffer: ${campaign.discountLabel}',
          pickupAddress: draft.address,
          destinationAddress: '',
          urgency: 'Normal',
          preferredDate: draft.date,
          preferredTime: draft.time,
          budget: null,
          source: 'community_campaign',
          sourceMetadata: {
            'campaignId': campaign.id,
            'campaignName': campaign.name,
            'campaignLocation': campaign.location,
            'discountLabel': campaign.discountLabel,
            'joinedCountAtRequest': campaign.joinedCount,
            'campaignSlotId': slotId,
            'campaignSlotLabel': '$requestType • ${draft.date} • ${draft.time}',
          },
        ),
      );
      await _repository.linkJoinToHelpRequest(
        campaignId: campaign.id,
        helpRequestId: helpRequestId,
        preferredDate: draft.date,
        preferredTime: draft.time,
        serviceCategory: requestType,
      );
      if (!mounted) return;
      _showSnack('Service request created from campaign.');
      Navigator.pushNamed(
        context,
        CustomerHelpRequestDetailScreen.routeName,
        arguments: {'requestId': helpRequestId},
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to create request: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(CommunityCampaign campaign, String channel) async {
    final text =
        '${campaign.name} near ${campaign.location}: ${campaign.discountLabel}. Join the Workable community campaign and unlock group pricing.';
    if (channel == 'whatsapp') {
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: text));
        _showSnack('WhatsApp not available. Campaign copied instead.');
      }
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('Campaign invite copied.');
    }
    await _repository.trackCampaignShare(campaign: campaign, channel: channel);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? WorkableDesign.danger : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CampaignRequestDraft {
  const _CampaignRequestDraft({
    required this.address,
    required this.date,
    required this.time,
    required this.serviceCategory,
  });

  final String address;
  final String date;
  final String time;
  final String serviceCategory;
}

class _CampaignRequestDialog extends StatefulWidget {
  const _CampaignRequestDialog({required this.campaign});

  final CommunityCampaign campaign;

  @override
  State<_CampaignRequestDialog> createState() => _CampaignRequestDialogState();
}

class _CampaignRequestDialogState extends State<_CampaignRequestDialog> {
  final _addressController = TextEditingController();
  final _dateController = TextEditingController();
  String _time = 'Morning';
  late String _serviceCategory;

  @override
  void initState() {
    super.initState();
    _serviceCategory = widget.campaign.serviceCategories.isNotEmpty
        ? widget.campaign.serviceCategories.first
        : widget.campaign.name;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose Campaign Slot'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _serviceCategory,
              decoration: const InputDecoration(
                labelText: 'Service',
                border: OutlineInputBorder(),
              ),
              items:
                  (widget.campaign.serviceCategories.isEmpty
                          ? [widget.campaign.name]
                          : widget.campaign.serviceCategories)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _serviceCategory = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Service address',
                hintText: 'House/apartment, area, landmark',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Preferred date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(LucideIcons.calendar),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _time,
              decoration: const InputDecoration(
                labelText: 'Preferred slot',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                DropdownMenuItem(value: 'Flexible', child: Text('Flexible')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _time = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final address = _addressController.text.trim();
            final date = _dateController.text.trim();
            if (address.length < 6 || date.isEmpty) return;
            Navigator.pop(
              context,
              _CampaignRequestDraft(
                address: address,
                date: date,
                time: _time,
                serviceCategory: _serviceCategory,
              ),
            );
          },
          child: const Text('Create Request'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 45)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (selected == null) return;
    _dateController.text =
        '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
  }
}
