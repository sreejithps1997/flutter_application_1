class NeighbourhoodDealTier {
  const NeighbourhoodDealTier({
    required this.homes,
    required this.label,
    required this.capLabel,
  });

  final int homes;
  final String label;
  final String capLabel;
}

class NeighbourhoodDeal {
  const NeighbourhoodDeal({
    required this.title,
    required this.subtitle,
    required this.joinedHomes,
    required this.targetHomes,
    required this.remainingSlots,
    required this.coverageArea,
    required this.approximateSlot,
    required this.tiers,
  });

  final String title;
  final String subtitle;
  final int joinedHomes;
  final int targetHomes;
  final int remainingSlots;
  final String coverageArea;
  final String approximateSlot;
  final List<NeighbourhoodDealTier> tiers;

  double get progress {
    if (targetHomes <= 0) return 0;
    return (joinedHomes / targetHomes).clamp(0, 1).toDouble();
  }

  String get joinedLabel => '$joinedHomes of $targetHomes homes joined';

  NeighbourhoodDealTier get activeTier {
    var active = tiers.first;
    for (final tier in tiers) {
      if (joinedHomes >= tier.homes) active = tier;
    }
    return active;
  }

  static const defaultDeal = NeighbourhoodDeal(
    title: 'Workable Neighbourhood Deal',
    subtitle:
        'Invite nearby homes. If enough neighbours join, everyone can unlock a better community rate after admin review.',
    joinedHomes: 1,
    targetHomes: 4,
    remainingSlots: 9,
    coverageArea: 'your nearby area',
    approximateSlot: 'next available community slot',
    tiers: [
      NeighbourhoodDealTier(
        homes: 1,
        label: 'Normal price',
        capLabel: 'No group benefit yet',
      ),
      NeighbourhoodDealTier(
        homes: 3,
        label: '10% discount',
        capLabel: 'up to Rs 100',
      ),
      NeighbourhoodDealTier(
        homes: 5,
        label: '15% discount',
        capLabel: 'up to Rs 150',
      ),
      NeighbourhoodDealTier(
        homes: 10,
        label: 'Special community rate',
        capLabel: 'admin calculated',
      ),
    ],
  );
}
