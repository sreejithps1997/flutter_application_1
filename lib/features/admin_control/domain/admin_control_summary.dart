class AdminControlSummary {
  const AdminControlSummary({
    required this.paymentReviews,
    required this.payoutReviews,
    required this.verificationReviews,
    required this.disputedBookings,
    required this.workStartOverrides,
    required this.helpIssues,
    required this.openDemandSignals,
    required this.referralRewards,
    required this.activeCampaigns,
  });

  final int paymentReviews;
  final int payoutReviews;
  final int verificationReviews;
  final int disputedBookings;
  final int workStartOverrides;
  final int helpIssues;
  final int openDemandSignals;
  final int referralRewards;
  final int activeCampaigns;

  int get totalActionItems =>
      paymentReviews +
      payoutReviews +
      verificationReviews +
      disputedBookings +
      workStartOverrides +
      helpIssues +
      openDemandSignals +
      referralRewards;
}
