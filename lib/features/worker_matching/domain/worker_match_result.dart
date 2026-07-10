class WorkerMatchResult {
  const WorkerMatchResult({
    required this.workerId,
    required this.worker,
    required this.score,
    required this.reasons,
  });

  final String workerId;
  final Map<String, dynamic> worker;
  final int score;
  final List<String> reasons;

  Map<String, dynamic> toWorkerListMap() {
    return {
      ...worker,
      'id': workerId,
      'matchScore': score,
      'matchReasons': reasons,
    };
  }
}
