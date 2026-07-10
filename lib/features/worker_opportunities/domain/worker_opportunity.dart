class WorkerOpportunity {
  const WorkerOpportunity({
    required this.id,
    required this.searchPhrase,
    required this.normalizedPhrase,
    required this.guessedCategory,
    required this.city,
    required this.status,
    required this.searchCount,
    required this.claimedWorkerIds,
    this.createdAt,
    this.lastSearchedAt,
  });

  final String id;
  final String searchPhrase;
  final String normalizedPhrase;
  final String guessedCategory;
  final String city;
  final String status;
  final int searchCount;
  final List<String> claimedWorkerIds;
  final DateTime? createdAt;
  final DateTime? lastSearchedAt;

  bool isClaimedBy(String workerId) => claimedWorkerIds.contains(workerId);
}
