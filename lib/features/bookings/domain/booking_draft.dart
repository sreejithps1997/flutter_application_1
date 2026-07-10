class BookingDraft {
  const BookingDraft({
    required this.issue,
    required this.address,
    required this.preferredDate,
    required this.preferredTime,
    required this.scheduledAt,
    this.workerId,
    this.workerName,
    this.selectedAddress,
    this.source = 'customer_manual',
  });

  final String issue;
  final String address;
  final String preferredDate;
  final String preferredTime;
  final DateTime? scheduledAt;
  final String? workerId;
  final String? workerName;
  final Map<String, dynamic>? selectedAddress;
  final String source;
}
