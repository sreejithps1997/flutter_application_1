import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/workable_design.dart';
import '../../../widgets/workable_ui.dart';
import '../data/neighbourhood_deal_repository.dart';
import '../domain/neighbourhood_deal.dart';

class NeighbourhoodDealCard extends StatefulWidget {
  const NeighbourhoodDealCard({
    super.key,
    this.bookingId = '',
    this.service = '',
    this.area = '',
  });

  final String bookingId;
  final String service;
  final String area;

  @override
  State<NeighbourhoodDealCard> createState() => _NeighbourhoodDealCardState();
}

class _NeighbourhoodDealCardState extends State<NeighbourhoodDealCard> {
  final _repository = NeighbourhoodDealRepository();
  final _deal = NeighbourhoodDeal.defaultDeal;
  bool _busy = false;

  Future<void> _share(String channel) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await _repository.ensureReferralCode();
      final text = _repository.shareText(
        code: code,
        service: widget.service,
        area: widget.area,
      );
      await _repository.trackShare(
        channel: channel,
        bookingId: widget.bookingId,
        service: widget.service,
        area: widget.area,
      );

      if (channel == 'whatsapp') {
        final uri = Uri.parse(
          'https://wa.me/?text=${Uri.encodeComponent(text)}',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await Clipboard.setData(ClipboardData(text: text));
          _showSnack('Deal message copied.');
        }
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        _showSnack('Deal message copied.');
      }
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return WorkableSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: WorkableDesign.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(WorkableDesign.radius),
                ),
                child: const Icon(
                  LucideIcons.users,
                  color: WorkableDesign.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deal.title,
                      style: const TextStyle(
                        color: WorkableDesign.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _deal.subtitle,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _deal.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            color: WorkableDesign.success,
            backgroundColor: WorkableDesign.success.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkableStatusPill(
                label: _deal.joinedLabel,
                color: WorkableDesign.success,
                icon: LucideIcons.home,
              ),
              WorkableStatusPill(
                label: '${_deal.remainingSlots} slots left',
                color: WorkableDesign.primary,
                icon: LucideIcons.calendarClock,
              ),
              WorkableStatusPill(
                label: widget.area.trim().isEmpty
                    ? _deal.coverageArea
                    : widget.area.trim(),
                color: WorkableDesign.warning,
                icon: LucideIcons.mapPin,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._deal.tiers.map((tier) {
            final unlocked = _deal.joinedHomes >= tier.homes;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    unlocked ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    size: 18,
                    color: unlocked
                        ? WorkableDesign.success
                        : WorkableDesign.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tier.homes} home${tier.homes == 1 ? '' : 's'} - ${tier.label} (${tier.capLabel})',
                      style: TextStyle(
                        color: unlocked
                            ? WorkableDesign.ink
                            : WorkableDesign.muted,
                        fontWeight: unlocked
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          WorkableInfoRow(
            icon: LucideIcons.shieldCheck,
            text:
                'Rewards are approved by admin after checking referred users, completed paid bookings, spend, and net profit.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _share('whatsapp'),
                  icon: const Icon(LucideIcons.messageCircle),
                  label: const Text('WhatsApp'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _share('copy'),
                  icon: const Icon(LucideIcons.copy),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
