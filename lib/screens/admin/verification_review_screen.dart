import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:workable/core/theme/workable_design.dart';
import 'package:workable/widgets/workable_ui.dart';

class VerificationReviewScreen extends StatefulWidget {
  final String uid;

  const VerificationReviewScreen({super.key, required this.uid});

  @override
  State<VerificationReviewScreen> createState() =>
      _VerificationReviewScreenState();
}

class _VerificationReviewScreenState extends State<VerificationReviewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> requiredDocuments = [
    'pan',
    'aadhaar',
    'voterId',
    'drivingLicense',
  ];

  Future<void> _approveVerification(String documentId) async {
    await _firestore
        .collection('users')
        .doc(widget.uid)
        .collection('identityVerification')
        .doc(documentId)
        .update({
          'status': 'verified',
          'verifiedAt': FieldValue.serverTimestamp(),

          // Clear old rejection data
          'rejectionReason': FieldValue.delete(),
          'reviewedAt': FieldValue.serverTimestamp(),
        });

    await _firestore
        .collection('adminVerificationQueue')
        .doc('${widget.uid}_$documentId')
        .update({
          'status': 'verified',
          'reviewedAt': FieldValue.serverTimestamp(),

          // Clear old rejection data
          'rejectionReason': FieldValue.delete(),
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification approved'),
          backgroundColor: Colors.green,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _rejectVerification(
    String documentId,
    String rejectionReason,
  ) async {
    await _firestore
        .collection('users')
        .doc(widget.uid)
        .collection('identityVerification')
        .doc(documentId)
        .update({
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': rejectionReason,
        });

    await _firestore
        .collection('adminVerificationQueue')
        .doc('${widget.uid}_$documentId')
        .update({
          'status': 'rejected',
          'reviewedAt': FieldValue.serverTimestamp(),
          'rejectionReason': rejectionReason,
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification rejected'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _showRejectDialog(String documentId) async {
    final TextEditingController customReasonController =
        TextEditingController();

    String? selectedReason;

    final List<String> rejectionReasons = [
      'Blurred image',
      'Name mismatch',
      'Document cropped',
      'Low image quality',
      'Expired document',
      'Invalid document',
      'Other',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Reject Verification'),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,

                    decoration: const InputDecoration(
                      labelText: 'Select rejection reason',
                      border: OutlineInputBorder(),
                    ),

                    items: rejectionReasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason,
                        child: Text(reason),
                      );
                    }).toList(),

                    onChanged: (value) {
                      setModalState(() {
                        selectedReason = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  if (selectedReason == 'Other')
                    TextField(
                      controller: customReasonController,
                      maxLines: 3,

                      decoration: const InputDecoration(
                        hintText: 'Enter custom rejection reason...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (selectedReason == null) return;

                    String finalReason;

                    if (selectedReason == 'Other') {
                      finalReason = customReasonController.text.trim();

                      if (finalReason.isEmpty) return;
                    } else {
                      finalReason = selectedReason!;
                    }

                    Navigator.pop(context);

                    await _rejectVerification(documentId, finalReason);
                  },
                  child: const Text('Reject'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,

      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,

          insetPadding: const EdgeInsets.all(12),

          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 5,

                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),

              Positioned(
                top: 10,
                right: 10,

                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },

                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      appBar: AppBar(title: const Text('Verification Review')),

      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('users').doc(widget.uid).get(),

        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const WorkableEmptyState(
              icon: Icons.person_off,
              title: 'User not found',
              message: 'This verification request no longer has a user record.',
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;

          return StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('users')
                .doc(widget.uid)
                .collection('identityVerification')
                .orderBy('submittedAt', descending: true)
                .snapshots(),

            builder: (context, verificationSnapshot) {
              if (verificationSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = verificationSnapshot.data?.docs ?? [];

              final uploadedDocuments = <String>[];

              final pendingDocuments = <String>[];

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;

                final status = data['status'] ?? 'pending';

                // VERIFIED OR PENDING
                if (status == 'verified' || status == 'pending') {
                  uploadedDocuments.add(doc.id);
                }
                // REJECTED
                else if (status == 'rejected') {
                  pendingDocuments.add(doc.id);
                }
              }

              // ADD NON-UPLOADED DOCUMENTS
              for (final requiredDoc in requiredDocuments) {
                final exists = docs.any((doc) => doc.id == requiredDoc);

                if (!exists) {
                  pendingDocuments.add(requiredDoc);
                }
              }

              final Map<String, String> verificationStatuses = {};

              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;

                verificationStatuses[doc.id] = data['status'] ?? 'pending';
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // USER HEADER
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(16),

                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage:
                                  userData['profileImageUrl'] != null &&
                                      userData['profileImageUrl'] != ''
                                  ? NetworkImage(userData['profileImageUrl'])
                                  : null,
                            ),

                            const SizedBox(width: 16),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  Text(
                                    userData['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(userData['email'] ?? ''),

                                  Text(userData['phoneNumber'] ?? ''),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // VERIFICATION CENTER
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(16),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'Verification Center',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // STATUS CHIPS
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,

                              children: requiredDocuments.map((documentType) {
                                final status =
                                    verificationStatuses[documentType] ??
                                    'missing';

                                Color color;
                                IconData icon;
                                String label;

                                if (status == 'verified') {
                                  color = Colors.green;
                                  icon = Icons.check_circle;
                                  label = 'VERIFIED';
                                } else if (status == 'pending') {
                                  color = Colors.orange;
                                  icon = Icons.pending;
                                  label = 'PENDING';
                                } else {
                                  return const SizedBox.shrink();
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),

                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                    ),
                                  ),

                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,

                                    children: [
                                      Icon(icon, color: color, size: 20),

                                      const SizedBox(width: 8),

                                      Text(
                                        '${documentType.toUpperCase()} • $label',

                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),

                            // ACTION REQUIRED
                            if (pendingDocuments.isNotEmpty) ...[
                              const SizedBox(height: 24),

                              Container(
                                width: double.infinity,

                                padding: const EdgeInsets.all(14),

                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),

                                  borderRadius: BorderRadius.circular(14),

                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                  ),
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                        ),

                                        SizedBox(width: 8),

                                        Text(
                                          'Action Required',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    ...pendingDocuments.map((doc) {
                                      final status =
                                          verificationStatuses[doc] ??
                                          'missing';

                                      String message;

                                      if (status == 'rejected') {
                                        message =
                                            '${doc.toUpperCase()} rejected — reupload needed';
                                      } else {
                                        message =
                                            '${doc.toUpperCase()} not uploaded';
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),

                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,

                                          children: [
                                            const Text(
                                              '• ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            Expanded(child: Text(message)),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // DOCUMENT OVERVIEW
                    // Card(
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(16),
                    //   ),

                    //   child: Padding(
                    //     padding: const EdgeInsets.all(16),

                    //     child: Column(
                    //       crossAxisAlignment: CrossAxisAlignment.start,

                    //       children: [
                    //         const Text(
                    //           'Document Overview',
                    //           style: TextStyle(
                    //             fontSize: 18,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),

                    //         const SizedBox(height: 20),

                    //         // UPLOADED
                    //         const Text(
                    //           'Uploaded Documents',
                    //           style: TextStyle(
                    //             fontWeight: FontWeight.bold,
                    //             fontSize: 16,
                    //           ),
                    //         ),

                    //         const SizedBox(height: 10),

                    //         Wrap(
                    //           spacing: 10,
                    //           runSpacing: 10,

                    //           children: uploadedDocuments.map((doc) {
                    //             return Container(
                    //               padding: const EdgeInsets.symmetric(
                    //                 horizontal: 12,
                    //                 vertical: 8,
                    //               ),

                    //               decoration: BoxDecoration(
                    //                 color: Colors.green.withOpacity(0.1),

                    //                 borderRadius: BorderRadius.circular(20),

                    //                 border: Border.all(
                    //                   color: Colors.green.withOpacity(0.3),
                    //                 ),
                    //               ),

                    //               child: Row(
                    //                 mainAxisSize: MainAxisSize.min,

                    //                 children: [
                    //                   const Icon(
                    //                     Icons.check_circle,
                    //                     color: Colors.green,
                    //                     size: 18,
                    //                   ),

                    //                   const SizedBox(width: 6),

                    //                   Text(
                    //                     doc.toUpperCase(),
                    //                     style: const TextStyle(
                    //                       fontWeight: FontWeight.bold,
                    //                       color: Colors.green,
                    //                     ),
                    //                   ),
                    //                 ],
                    //               ),
                    //             );
                    //           }).toList(),
                    //         ),

                    //         const SizedBox(height: 24),

                    //         // PENDING
                    //         const Text(
                    //           'Pending Documents',
                    //           style: TextStyle(
                    //             fontWeight: FontWeight.bold,
                    //             fontSize: 16,
                    //           ),
                    //         ),

                    //         const SizedBox(height: 10),

                    //         if (pendingDocuments.isEmpty)
                    //           Container(
                    //             padding: const EdgeInsets.all(12),

                    //             decoration: BoxDecoration(
                    //               color: Colors.green.withOpacity(0.08),

                    //               borderRadius: BorderRadius.circular(12),
                    //             ),

                    //             child: const Text(
                    //               'All required documents uploaded',
                    //               style: TextStyle(
                    //                 color: Colors.green,
                    //                 fontWeight: FontWeight.bold,
                    //               ),
                    //             ),
                    //           )
                    //         else
                    //           Wrap(
                    //             spacing: 10,
                    //             runSpacing: 10,

                    //             children: pendingDocuments.map((doc) {
                    //               return Container(
                    //                 padding: const EdgeInsets.symmetric(
                    //                   horizontal: 12,
                    //                   vertical: 8,
                    //                 ),

                    //                 decoration: BoxDecoration(
                    //                   color: Colors.orange.withOpacity(0.1),

                    //                   borderRadius: BorderRadius.circular(20),

                    //                   border: Border.all(
                    //                     color: Colors.orange.withOpacity(0.3),
                    //                   ),
                    //                 ),

                    //                 child: Row(
                    //                   mainAxisSize: MainAxisSize.min,

                    //                   children: [
                    //                     const Icon(
                    //                       Icons.pending,
                    //                       color: Colors.orange,
                    //                       size: 18,
                    //                     ),

                    //                     const SizedBox(width: 6),

                    //                     Text(
                    //                       doc.toUpperCase(),
                    //                       style: const TextStyle(
                    //                         fontWeight: FontWeight.bold,
                    //                         color: Colors.orange,
                    //                       ),
                    //                     ),
                    //                   ],
                    //                 ),
                    //               );
                    //             }).toList(),
                    //           ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 24),

                    const Text(
                      'Uploaded Documents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // DOCUMENTS
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      final submittedAt = data['submittedAt'] != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(
                              (data['submittedAt'] as Timestamp).toDate(),
                            )
                          : 'Unknown';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),

                        child: Padding(
                          padding: const EdgeInsets.all(16),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              // DOCUMENT TYPE
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),

                                decoration: BoxDecoration(
                                  color: WorkableDesign.primary.withValues(
                                    alpha: 0.1,
                                  ),

                                  borderRadius: BorderRadius.circular(20),
                                ),

                                child: Text(
                                  doc.id.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Text('Name: ${data['name'] ?? ''}'),

                              const SizedBox(height: 6),

                              Text('Number: ${data['number'] ?? ''}'),

                              const SizedBox(height: 6),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),

                                decoration: BoxDecoration(
                                  color: data['status'] == 'verified'
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : data['status'] == 'rejected'
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : Colors.orange.withValues(alpha: 0.15),

                                  borderRadius: BorderRadius.circular(20),
                                ),

                                child: Text(
                                  (data['status'] ?? '').toUpperCase(),

                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,

                                    color: data['status'] == 'verified'
                                        ? Colors.green
                                        : data['status'] == 'rejected'
                                        ? Colors.red
                                        : Colors.orange,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text('Submitted: $submittedAt'),

                              if (data['status'] == 'rejected' &&
                                  data['rejectionReason'] != null &&
                                  data['rejectionReason']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 10),

                                Container(
                                  width: double.infinity,

                                  padding: const EdgeInsets.all(12),

                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),

                                    borderRadius: BorderRadius.circular(12),

                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),

                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      const Text(
                                        'Rejection Reason',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        data['rejectionReason'],
                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              if (data['imageUrl'] != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),

                                  child: GestureDetector(
                                    onTap: () =>
                                        _showFullImage(data['imageUrl']),

                                    child: Hero(
                                      tag: data['imageUrl'],

                                      child: Image.network(
                                        data['imageUrl'],
                                        height: 220,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),

                              if (data['status'] == 'pending')
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _approveVerification(doc.id),

                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),

                                        icon: const Icon(Icons.check),

                                        label: const Text('Approve'),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _showRejectDialog(doc.id),

                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),

                                        icon: const Icon(Icons.close),

                                        label: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
