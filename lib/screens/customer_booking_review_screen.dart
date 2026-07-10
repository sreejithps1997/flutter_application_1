import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/interactive_star_rating.dart';
import 'customer_dashboard_screen.dart';

class CustomerBookingReviewScreen extends StatefulWidget {
  static const routeName = '/customer-booking-review';

  final String bookingId;
  final String workerId;

  const CustomerBookingReviewScreen({
    super.key,
    required this.bookingId,
    required this.workerId,
  });

  @override
  State<CustomerBookingReviewScreen> createState() =>
      _CustomerBookingReviewScreenState();
}

class _CustomerBookingReviewScreenState
    extends State<CustomerBookingReviewScreen> {
  double _rating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic>? _bookingDetails;
  bool _reviewExists = false;

  final List<String> _availableTags = [
    "On time",
    "Professional",
    "Quality work",
    "Friendly",
    "Clean workspace",
  ];

  final Set<String> _selectedTags = {};

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please give a rating")));
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      // Save review
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.bookingId)
          .set({
            'workerId': widget.workerId,
            'customerId': userId,
            'bookingId': widget.bookingId,
            'rating': _rating,
            'review': _reviewController.text.trim(),
            'tags': _selectedTags.toList(), // ✅ NEW
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update booking rating
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
            'rating': _rating,
            'reviewTags': _selectedTags.toList(), // optional
            'hasReview': true, // ✅ New field
          });

      // Recalculate average
      final reviewSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('workerId', isEqualTo: widget.workerId)
          .get();

      final validRatings = reviewSnapshot.docs
          .map((doc) => doc.data()['rating'])
          .where((rating) => rating != null)
          .map((rating) => (rating as num).toDouble())
          .toList();

      final newAverage = validRatings.isEmpty
          ? 0
          : double.parse(
              (validRatings.reduce((a, b) => a + b) / validRatings.length)
                  .toStringAsFixed(1),
            );

      await FirebaseFirestore.instance
          .collection('workers')
          .doc(widget.workerId)
          .set({
            'averageRating': newAverage,
            'rating': newAverage,
            'reviewCount': validRatings.length,
            'totalReviews': validRatings.length,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Review submitted successfully!")),
        );

        Navigator.pushNamedAndRemoveUntil(
          context,
          CustomerDashboardScreen.routeName,
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error submitting review: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to submit review.")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _enforceCompletedStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .get();

    final data = doc.data();
    final isCompleted = data?['status']?.toLowerCase() == 'completed';

    if (!isCompleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only rate a completed booking.")),
      );
      Navigator.pop(context); // exit the screen
    }

    setState(() {
      _bookingDetails = data;
    });
  }

  void _loadExistingReview() async {
    final doc = await FirebaseFirestore.instance
        .collection('reviews')
        .doc(widget.bookingId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        _reviewController.text = data['review'] ?? '';
        _selectedTags.clear();
        _selectedTags.addAll(List<String>.from(data['tags'] ?? []));
        _reviewExists = true; // ✅ Mark review as existing
      });
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _enforceCompletedStatus();
    // _checkIfAlreadyReviewed();
    _loadExistingReview();
  }

  String get ratingLabel {
    switch (_rating.round()) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Rate Your Experience"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Service Card Placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      "JD",
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bookingDetails?['workerName'] ?? 'Worker Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _bookingDetails?['serviceType'] ??
                            _bookingDetails?['issue'] ??
                            'Service Type',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "${_bookingDetails?['preferredDate'] ?? ''} • ${_bookingDetails?['preferredTime'] ?? ''}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    "How was your service?",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Your feedback helps us improve",
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  // Stars
                  InteractiveStarRating(
                    rating: _rating,
                    onRatingChanged: (value) {
                      setState(() => _rating = value);
                    },
                    size: 40,
                  ),

                  if (_rating > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        ratingLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Review Text Field
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Tell us more (optional)",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: "Share your experience...",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.blue.shade400,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Quick feedback tags (non-functional for now)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Quick feedback",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    children: _availableTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor: Colors.blue.shade100,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.blue.shade800
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : CustomButton(
                        text: "Submit Review",
                        onPressed: _submitReview,
                      ),

                const SizedBox(height: 10), // spacing

                if (_reviewExists) ...[
                  TextButton(
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('reviews')
                            .doc(widget.bookingId)
                            .delete();

                        await FirebaseFirestore.instance
                            .collection('bookings')
                            .doc(widget.bookingId)
                            .update({
                              'hasReview': false,
                              'rating': FieldValue.delete(),
                              'reviewTags': FieldValue.delete(),
                            });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Review deleted.")),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error deleting review."),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      "Delete Review",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
