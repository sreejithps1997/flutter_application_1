import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:workable/core/theme/workable_design.dart';

import '../data/community_campaign_repository.dart';
import '../domain/community_campaign.dart';

class CustomerCampaignStrip extends StatelessWidget {
  const CustomerCampaignStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityCampaign>>(
      stream: CommunityCampaignRepository().watchCampaigns(activeOnly: true),
      builder: (context, snapshot) {
        final campaigns = (snapshot.data ?? const <CommunityCampaign>[])
            .take(5)
            .toList();
        if (campaigns.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 132,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkableDesign.pagePadding,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _CampaignCard(campaign: campaigns[index]),
          ),
        );
      },
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});

  final CommunityCampaign campaign;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(14),
      decoration: WorkableDesign.cardDecoration(color: WorkableDesign.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.megaphone,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  campaign.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            campaign.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${campaign.location} - ${campaign.discountLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(LucideIcons.share2, color: Colors.white, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
