import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class MyReviewsScreen extends StatefulWidget {
  static const routeName = '/my-reviews';

  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  String activeFilter = 'all';
  String searchQuery = '';

  final stats = {
    'totalReviews': 24,
    'averageRating': 4.6,
    'helpfulVotes': 87,
    'recentReviews': 3,
  };

  final List<Map<String, dynamic>> filterOptions = [
    {'key': 'all', 'label': 'All Reviews', 'count': 24},
    {'key': 'recent', 'label': 'Recent', 'count': 3},
    {'key': '5star', 'label': '5 Star', 'count': 15},
    {'key': '4star', 'label': '4 Star', 'count': 6},
    {'key': '3star', 'label': '3 Star', 'count': 2},
    {'key': 'pending', 'label': 'Pending', 'count': 1},
  ];

  final List<Map<String, dynamic>> reviews = [
    {
      'id': 1,
      'workerName': 'Ravi Kumar',
      'workerImage': 'RK',
      'service': 'House Cleaning',
      'date': '2024-07-20',
      'rating': 5,
      'reviewText':
          'Excellent work! Ravi was very professional and thorough. My house was spotless after the cleaning. Highly recommend his services.',
      'photos': 2,
      'helpful': 12,
      'workerResponse':
          'Thank you so much for the kind words! It was a pleasure working for you.',
      'verified': true,
      'canEdit': true,
    },
    {
      'id': 2,
      'workerName': 'Priya Sharma',
      'workerImage': 'PS',
      'service': 'Cooking',
      'date': '2024-07-18',
      'rating': 4,
      'reviewText':
          'Good cooking skills. The food was tasty and prepared on time. Would book again for special occasions.',
      'photos': 1,
      'helpful': 8,
      'workerResponse': null,
      'verified': true,
      'canEdit': true,
    },
    {
      'id': 3,
      'workerName': 'Amit Singh',
      'workerImage': 'AS',
      'service': 'Plumbing',
      'date': '2024-07-15',
      'rating': 5,
      'reviewText':
          'Fixed my kitchen sink perfectly. Very knowledgeable and came with all necessary tools. Fair pricing too.',
      'photos': 0,
      'helpful': 15,
      'workerResponse':
          'Thanks for choosing my service! Always happy to help with plumbing needs.',
      'verified': true,
      'canEdit': false,
    },
    {
      'id': 4,
      'workerName': 'Sunita Devi',
      'workerImage': 'SD',
      'service': 'House Cleaning',
      'date': '2024-07-10',
      'rating': 3,
      'reviewText':
          'Average service. The cleaning was okay but missed some areas. Could improve attention to detail.',
      'photos': 0,
      'helpful': 3,
      'workerResponse':
          "Thank you for the feedback. I'll make sure to be more thorough next time.",
      'verified': true,
      'canEdit': false,
    },
  ];

  final List<Map<String, dynamic>> pendingReviews = [
    {
      'id': 1,
      'workerName': 'Rajesh Kumar',
      'service': 'Electrical Work',
      'date': '2024-07-23',
      'bookingId': 'BK12345',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("My Reviews"), leading: BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Section
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatsCard(
                  stats['totalReviews'],
                  'Total Reviews',
                  Colors.blue,
                  LucideIcons.star,
                ),
                _buildStatsCard(
                  stats['averageRating'],
                  'Avg Rating',
                  Colors.orange,
                  LucideIcons.star,
                ),
                _buildStatsCard(
                  stats['helpfulVotes'],
                  'Helpful Votes',
                  Colors.green,
                  LucideIcons.thumbsUp,
                ),
                _buildStatsCard(
                  stats['recentReviews'],
                  'This Month',
                  Colors.purple,
                  LucideIcons.calendar,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search reviews...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),

            // Filter Chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: filterOptions
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            "${filter['label'] as String} (${filter['count']})",
                          ),
                          selected: activeFilter == filter['key'],
                          onSelected: (_) {
                            setState(
                              () => activeFilter = filter['key'] as String,
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),

            if (activeFilter == 'all' && pendingReviews.isNotEmpty) ...[
              const Text(
                "Pending Reviews",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...pendingReviews.map((review) => _buildPendingReview(review)),
              const SizedBox(height: 20),
            ],

            Text(
              activeFilter == 'pending' ? "Pending Reviews" : "Your Reviews",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (activeFilter == 'pending')
              ...pendingReviews.map((review) => _buildPendingReview(review))
            else
              ...reviews.map((review) => _buildReviewCard(review)),

            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {},
              child: const Text("Load More Reviews"),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Review Guidelines",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text("• Be honest and constructive in your feedback"),
                  Text("• Focus on the service quality and professionalism"),
                  Text("• You can edit reviews within 48 hours of posting"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    dynamic number,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: (MediaQuery.of(context).size.width / 2) - 26,
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$number',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final formattedDate = DateFormat(
      'dd MMM yyyy',
    ).format(DateTime.parse(review['date']));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Worker info
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  review['workerImage'],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review['workerName'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (review['verified'])
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      review['service'],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Rating + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    Icons.star,
                    color: i < review['rating']
                        ? Colors.amber
                        : Colors.grey[300],
                    size: 18,
                  );
                }),
              ),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Review Text
          Text(review['reviewText']),
          if (review['photos'] > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${review['photos']} photo(s)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          if (review['workerResponse'] != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(left: BorderSide(color: Colors.blue[200]!)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.messageCircle,
                    color: Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review['workerResponse'],
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.thumbsUp, size: 16),
                    label: Text(
                      "${review['helpful']} helpful",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (review['canEdit'])
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(LucideIcons.edit3, size: 16),
                      label: const Text("Edit", style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.flag, size: 18, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReview(Map<String, dynamic> review) {
    final formattedDate = DateFormat(
      'dd MMM yyyy',
    ).format(DateTime.parse(review['date']));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.yellow[50]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(LucideIcons.clock, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review['workerName'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  review['service'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Completed on $formattedDate',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to review submission screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Write Review"),
          ),
        ],
      ),
    );
  }
}
