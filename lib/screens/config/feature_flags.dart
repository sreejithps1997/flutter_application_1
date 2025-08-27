class FeatureFlags {
  static const Map<String, List<String>> features = {
    'booking_history': ['customer'],
    'job_history': ['worker'],
    'earnings_analytics': ['worker'],
    'favorite_workers': ['customer'],
    'portfolio': ['worker'],
    'payout_methods': ['worker'],
    'wallet_credits': ['customer'],
  };

  static bool isFeatureEnabled(String feature, String userType) {
    return features[feature]?.contains(userType) ?? false;
  }
}
