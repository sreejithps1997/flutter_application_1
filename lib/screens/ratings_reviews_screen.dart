import 'package:flutter/material.dart';

class RatingsReviewsScreen extends StatelessWidget {
  static const routeName = '/ratings-reviews';

  const RatingsReviewsScreen({super.key});

  final List<Map<String, dynamic>> reviews = const [
    {
      "name": "Akhil Raj",
      "rating": 5,
      "comment": "Excellent service, very punctual and polite.",
      "date": "03 July 2025",
    },
    {
      "name": "Nisha Menon",
      "rating": 4,
      "comment": "Good work, but arrived 10 minutes late.",
      "date": "30 June 2025",
    },
    {
      "name": "Rahul Pillai",
      "rating": 3,
      "comment": "Okay service. Could improve communication.",
      "date": "28 June 2025",
    },
  ];

  Widget _buildRatingStars(int count) {
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          index < count ? Icons.star : Icons.star_border,
          size: 18,
          color: Colors.amber,
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review['name'], style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            _buildRatingStars(review['rating']),
            SizedBox(height: 8),
            Text(
              review['comment'],
              style: TextStyle(color: Colors.grey[800]),
            ),
            SizedBox(height: 8),
            Text(
              review['date'],
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ratings & Reviews"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: reviews.isEmpty
            ? Center(child: Text("No reviews available yet."))
            : ListView.builder(
                itemCount: reviews.length,
                itemBuilder: (_, index) => _buildReviewCard(reviews[index]),
              ),
      ),
    );
  }
}
