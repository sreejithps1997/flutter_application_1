import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

import '../data/community_campaign_repository.dart';
import '../domain/community_campaign.dart';

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
      _showSnack('Campaign joined. We will notify you when slots open.');
    } catch (error) {
      if (!mounted) return;
      _showSnack('Unable to join campaign: $error', isError: true);
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
