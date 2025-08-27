import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/verification_tier_manager.dart';

class WorkerJobDetailsScreen extends StatefulWidget {
  static const routeName = '/worker-job-details';

  final String bookingId;

  const WorkerJobDetailsScreen({super.key, required this.bookingId});

  @override
  State<WorkerJobDetailsScreen> createState() => _WorkerJobDetailsScreenState();
}

class _WorkerJobDetailsScreenState extends State<WorkerJobDetailsScreen> {
  bool hasVerified = true;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final verified = await VerificationTierManager().hasUploadedPanAndAadhaar(
      uid,
    );

    setState(() => hasVerified = verified);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Job not found."));
          }

          final job = snapshot.data!.data() as Map<String, dynamic>;
          final String status = job['status'] ?? 'pending';

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow("Service", job['service']),
                _detailRow(
                  "Customer",
                  hasVerified ? job['customerName'] : 'Restricted',
                ),
                _detailRow(
                  "Phone",
                  hasVerified ? job['customerPhone'] : 'Restricted',
                ),
                _detailRow("Address", job['address']),
                _detailRow("Issue", job['issueDescription']),
                _detailRow("Date", job['preferredDate']),
                _detailRow("Time", job['preferredTime']),
                _detailRow("Payment", job['paymentMethod']),
                const SizedBox(height: 16),

                Row(
                  children: [
                    const Text(
                      "Status: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        status,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _statusColor(status),
                    ),
                  ],
                ),

                const Spacer(),

                if (status == "confirmed") ...[
                  CustomButton(
                    text: "Mark as Completed",
                    backgroundColor: Colors.green,
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(widget.bookingId)
                          .update({'status': 'completed'});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Job marked as completed"),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Cancel Job",
                    backgroundColor: Colors.red,
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(widget.bookingId)
                          .update({'status': 'cancelled'});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Job cancelled")),
                      );
                    },
                  ),
                ] else if (status == "pending") ...[
                  CustomButton(
                    text: "Accept Job",
                    backgroundColor: Colors.green,
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;

                      final hasVerified = await VerificationTierManager()
                          .hasUploadedPanAndAadhaar(uid);
                      if (!hasVerified) {
                        _showUploadPanAadhaarDialog(context);
                        return;
                      }

                      await FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(widget.bookingId)
                          .update({'status': 'confirmed'});

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Job accepted")),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: "Decline Job",
                    backgroundColor: Colors.grey,
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(widget.bookingId)
                          .update({'status': 'cancelled'});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Job declined")),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? '-')),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  void _showUploadPanAadhaarDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Verification Required"),
        content: const Text(
          "To accept a job, you must first upload and verify your PAN card and Aadhaar card.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/identity-verification');
            },
            child: const Text("Go to Verification"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
}
