class DemandDiscoveryResult {
  const DemandDiscoveryResult({
    required this.query,
    required this.normalizedQuery,
    required this.guessedCategory,
    required this.workers,
    this.demandSignalId,
    this.city,
  });

  final String query;
  final String normalizedQuery;
  final String guessedCategory;
  final List<Map<String, dynamic>> workers;
  final String? demandSignalId;
  final String? city;

  bool get hasWorkers => workers.isNotEmpty;
  bool get hasDemandSignal => demandSignalId != null;
}
