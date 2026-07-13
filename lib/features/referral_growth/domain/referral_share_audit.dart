import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralShareAudit {
  const ReferralShareAudit({
    required this.totalShares,
    required this.whatsAppShares,
    required this.smsShares,
    required this.copyInviteShares,
    required this.copyCodeShares,
    required this.lastShareAt,
  });

  final int totalShares;
  final int whatsAppShares;
  final int smsShares;
  final int copyInviteShares;
  final int copyCodeShares;
  final DateTime? lastShareAt;

  bool get hasShares => totalShares > 0;

  factory ReferralShareAudit.fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var whatsApp = 0;
    var sms = 0;
    var copyInvite = 0;
    var copyCode = 0;
    DateTime? latest;

    for (final doc in docs) {
      final data = doc.data();
      final channel = data['channel']?.toString() ?? '';
      if (channel == 'whatsapp') {
        whatsApp++;
      } else if (channel == 'sms') {
        sms++;
      } else if (channel == 'copy_invite') {
        copyInvite++;
      } else if (channel == 'copy_code') {
        copyCode++;
      }
      final date = _date(data['createdAt']);
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }

    return ReferralShareAudit(
      totalShares: docs.length,
      whatsAppShares: whatsApp,
      smsShares: sms,
      copyInviteShares: copyInvite,
      copyCodeShares: copyCode,
      lastShareAt: latest,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '');
  }
}
