class AdminDemandSignal {
  const AdminDemandSignal({
    required this.id,
    required this.searchPhrase,
    required this.normalizedPhrase,
    required this.guessedCategory,
    required this.city,
    required this.status,
    required this.searchCount,
    required this.customerIds,
    required this.claimedWorkerIds,
    this.adminAction,
    this.approvedCategory,
    this.createdAt,
    this.lastSearchedAt,
    this.updatedAt,
  });

  final String id;
  final String searchPhrase;
  final String normalizedPhrase;
  final String guessedCategory;
  final String city;
  final String status;
  final int searchCount;
  final List<String> customerIds;
  final List<String> claimedWorkerIds;
  final String? adminAction;
  final String? approvedCategory;
  final DateTime? createdAt;
  final DateTime? lastSearchedAt;
  final DateTime? updatedAt;

  bool get isOpen => status == 'open';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get hasWorkerInterest => claimedWorkerIds.isNotEmpty;
}
