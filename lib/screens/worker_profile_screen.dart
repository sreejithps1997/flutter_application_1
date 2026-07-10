import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/theme/workable_design.dart';
import '../widgets/star_rating.dart';
import '../widgets/verification_tier_badge.dart';
import 'chat_screen.dart';
import 'booking_form_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  static const routeName = '/worker-profile';

  final String workerId;
  final String name;

  const WorkerProfileScreen({
    super.key,
    required this.workerId,
    required this.name,
  });

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  Map<String, dynamic>? workerData;
  List<Map<String, dynamic>> reviews = [];
  List<Map<String, dynamic>> portfolioItems = [];
  bool isFavorited = false;
  bool _favLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkerData();
    _loadReviews();
    _loadPortfolio();
    _checkIfFavorited();
  }

  Future<void> _checkIfFavorited() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(uid)
        .collection('favoriteWorkers')
        .doc(widget.workerId)
        .get();
    if (mounted) setState(() => isFavorited = doc.exists);
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _favLoading = true);

    final ref = FirebaseFirestore.instance
        .collection('customers')
        .doc(uid)
        .collection('favoriteWorkers')
        .doc(widget.workerId);

    if (isFavorited) {
      await ref.delete();
    } else {
      await ref.set({
        'workerId': widget.workerId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      setState(() {
        isFavorited = !isFavorited;
        _favLoading = false;
      });
    }
  }

  Future<void> _loadWorkerData() async {
    final doc = await FirebaseFirestore.instance
        .collection('workers')
        .doc(widget.workerId)
        .get();
    if (!mounted) return;
    if (doc.exists) {
      setState(() {
        workerData = doc.data();
      });
    }
  }

  Future<void> _loadReviews() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('workerId', isEqualTo: widget.workerId)
        .get();
    if (!mounted) return;

    setState(() {
      reviews = snapshot.docs.map((e) => e.data()).toList();
    });
  }

  Future<void> _loadPortfolio() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('workers')
        .doc(widget.workerId)
        .collection('portfolio')
        .orderBy('createdAt', descending: true)
        .get();
    if (!mounted) return;

    setState(() {
      portfolioItems = snapshot.docs.map((e) => e.data()).toList();
    });
  }

  Color _getColorFromName(String name) {
    final hash = name.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = (hash & 0x0000FF);
    return Color.fromARGB(255, r, g, b);
  }

  Widget _buildFavoriteButton() {
    return _favLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              isFavorited ? Icons.favorite : Icons.favorite_border,
              color: isFavorited ? WorkableDesign.danger : WorkableDesign.muted,
            ),
          );
  }

  String _workerName() {
    final fullName = workerData?['fullName']?.toString().trim();
    final name = workerData?['name']?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    if (name != null && name.isNotEmpty) return name;
    return widget.name;
  }

  String? _workerImageUrl() {
    final image = workerData?['profileImageUrl'] ?? workerData?['imageUrl'];
    final text = image?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }

  List<String> _skills() {
    return (workerData?['skills'] as List<dynamic>?)
            ?.map((skill) => skill.toString().trim())
            .where((skill) => skill.isNotEmpty)
            .toList() ??
        [];
  }

  String _primarySkill() {
    final skills = _skills();
    return skills.isNotEmpty ? skills.first : 'Service Provider';
  }

  String _pricingLabel([dynamic value]) {
    final text = (value ?? workerData?['pricing'])?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return 'Rate not set';
    }
    return text.contains('Rs') || text.contains('/hr') || text.contains('hour')
        ? text
        : 'Rs $text / hr';
  }

  String _aboutText() {
    final about =
        workerData?['about'] ??
        workerData?['bio'] ??
        workerData?['description'] ??
        workerData?['professionalSummary'];
    final text = about?.toString().trim();
    if (text != null && text.isNotEmpty) return text;

    final skill = _primarySkill().toLowerCase();
    return 'Experienced $skill professional focused on reliable service, clear communication, and quality work.';
  }

  String _locationText() {
    final parts =
        [workerData?['area'], workerData?['city'], workerData?['pincode']]
            .where((part) {
              final text = part?.toString().trim();
              return text != null &&
                  text.isNotEmpty &&
                  text.toLowerCase() != 'null';
            })
            .map((part) => part.toString().trim())
            .toList();
    return parts.isEmpty ? 'Service location available' : parts.join(', ');
  }

  String _tier() {
    return workerData?['verification']?['tier']?.toString() ?? 'new';
  }

  bool _isVisibleToCustomers() => workerData?['visibleToUsers'] == true;

  void _openBookingForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingFormScreen(
          workerId: widget.workerId,
          workerName: _workerName(),
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.pushNamed(
      context,
      ChatScreen.routeName,
      arguments: {
        'chatWithId': widget.workerId,
        'chatWithName': _workerName(),
        'userRole': 'customer',
        'workerService': _primarySkill(),
        'workerRating': (workerData?['averageRating'] as num?)?.toDouble(),
      },
    );
  }

  void _showContactUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone contact is not available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (workerData == null) {
      return const Scaffold(
        backgroundColor: WorkableDesign.canvas,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final workerName = _workerName();
    final imageUrl = _workerImageUrl();
    final isAvailable = workerData!['isAvailable'] ?? false;

    return Scaffold(
      backgroundColor: WorkableDesign.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: WorkableDesign.ink,
                      ),
                    ),
                    const Spacer(),
                    _buildFavoriteButton(),
                  ],
                ),
              ),
            ),

            // Profile information
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Profile image or initials
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: imageUrl == null
                          ? _getColorFromName(workerName)
                          : Colors.transparent,
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: imageUrl == null
                        ? Text(
                            _getInitials(workerName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    workerName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: WorkableDesign.ink,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Skills as subtitle
                  Text(
                    _primarySkill(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: WorkableDesign.muted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location and availability
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: WorkableDesign.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _locationText(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: WorkableDesign.muted,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: isAvailable
                            ? WorkableDesign.success
                            : WorkableDesign.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAvailable ? 'Available Now' : 'Unavailable',
                        style: TextStyle(
                          fontSize: 14,
                          color: isAvailable
                              ? WorkableDesign.success
                              : WorkableDesign.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard(
                        icon: Icons.star,
                        iconColor: Colors.amber,
                        value: (workerData!['averageRating'] ?? 0.0)
                            .toStringAsFixed(1),
                        label: "${reviews.length} reviews",
                      ),
                      _buildStatCard(
                        icon: Icons.check_circle,
                        iconColor: WorkableDesign.success,
                        value: "${workerData!['completedJobsCount'] ?? 0}",
                        label: "Jobs completed",
                      ),
                      _buildStatCard(
                        icon: Icons.currency_rupee,
                        iconColor: WorkableDesign.primary,
                        value: _pricingLabel(),
                        label: "Per hour",
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      VerificationTierBadge(tier: _tier()),
                      if (_isVisibleToCustomers())
                        _buildBadge(
                          "Customer Visible",
                          Icons.visibility,
                          WorkableDesign.success,
                        ),
                      if (isAvailable)
                        _buildBadge(
                          "Available",
                          Icons.access_time,
                          WorkableDesign.primary,
                        ),
                      _buildBadge(
                        _primarySkill(),
                        Icons.work,
                        WorkableDesign.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _openBookingForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: WorkableDesign.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                WorkableDesign.radius,
                              ),
                            ),
                          ),
                          child: const Text(
                            "Book Now",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: WorkableDesign.border),
                          borderRadius: BorderRadius.circular(
                            WorkableDesign.radius,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _showContactUnavailable,
                          icon: const Icon(
                            Icons.phone,
                            color: WorkableDesign.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: WorkableDesign.border),
                          borderRadius: BorderRadius.circular(
                            WorkableDesign.radius,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _openChat,
                          icon: const Icon(
                            Icons.message,
                            color: WorkableDesign.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // About section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WorkableDesign.surface,
                      borderRadius: BorderRadius.circular(
                        WorkableDesign.radius,
                      ),
                      border: Border.all(color: WorkableDesign.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "About",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: WorkableDesign.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _aboutText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: WorkableDesign.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: WorkableDesign.canvas,
                                  borderRadius: BorderRadius.circular(
                                    WorkableDesign.radius,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.currency_rupee,
                                          size: 16,
                                          color: WorkableDesign.muted,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Hourly Rate",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: WorkableDesign.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _pricingLabel(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: WorkableDesign.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: WorkableDesign.canvas,
                                  borderRadius: BorderRadius.circular(
                                    WorkableDesign.radius,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 16,
                                          color: WorkableDesign.success,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Availability",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: WorkableDesign.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (workerData!['isAvailable'] ?? false)
                                          ? 'Available Now'
                                          : 'Not Available',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            (workerData!['isAvailable'] ??
                                                false)
                                            ? WorkableDesign.success
                                            : WorkableDesign.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_skills().isNotEmpty) ...[
                    _buildServicesOfferedSection(),
                    const SizedBox(height: 32),
                  ],

                  // Skills & Pricing section (from wageMap)
                  if (workerData!['wageMap'] != null) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Services & Pricing",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: WorkableDesign.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...(workerData!['wageMap'] as Map<String, dynamic>).entries
                        .map<Widget>((entry) {
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: WorkableDesign.surface,
                              borderRadius: BorderRadius.circular(
                                WorkableDesign.radius,
                              ),
                              border: Border.all(color: WorkableDesign.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: WorkableDesign.ink,
                                  ),
                                ),
                                Text(
                                  _pricingLabel(entry.value),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: WorkableDesign.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    const SizedBox(height: 32),
                  ],

                  if (portfolioItems.isNotEmpty) ...[
                    _buildPortfolioSection(),
                    const SizedBox(height: 32),
                  ],

                  // Reviews section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Customer Reviews",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: WorkableDesign.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  reviews.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: WorkableDesign.surface,
                            borderRadius: BorderRadius.circular(
                              WorkableDesign.radius,
                            ),
                            border: Border.all(color: WorkableDesign.border),
                          ),
                          child: const Text(
                            "No reviews yet.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: WorkableDesign.muted),
                          ),
                        )
                      : Column(
                          children: reviews.map((review) {
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: WorkableDesign.border,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Customer",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: WorkableDesign.ink,
                                            ),
                                          ),
                                          Text(
                                            "2 days ago",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: WorkableDesign.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      StarRating(
                                        rating: (review['rating'] ?? 0)
                                            .toDouble(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    review['review'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: WorkableDesign.muted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: WorkableDesign.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: WorkableDesign.muted),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesOfferedSection() {
    final serviceRadius =
        workerData?['serviceRadiusKm'] ?? workerData?['serviceRadius'];
    final radiusText = serviceRadius == null
        ? null
        : '${serviceRadius.toString()} km service radius';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        border: Border.all(color: WorkableDesign.border),
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services Offered',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: WorkableDesign.ink,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills()
                .map(
                  (skill) => Chip(
                    label: Text(skill),
                    backgroundColor: WorkableDesign.primary.withValues(
                      alpha: 0.08,
                    ),
                    side: BorderSide(
                      color: WorkableDesign.primary.withValues(alpha: 0.18),
                    ),
                    labelStyle: TextStyle(color: WorkableDesign.primary),
                  ),
                )
                .toList(),
          ),
          if (radiusText != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.my_location_outlined,
                  size: 16,
                  color: WorkableDesign.muted,
                ),
                const SizedBox(width: 6),
                Text(radiusText, style: TextStyle(color: WorkableDesign.muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortfolioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Portfolio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: WorkableDesign.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Recent work samples uploaded by this professional.',
          style: TextStyle(color: WorkableDesign.muted),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: portfolioItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildPortfolioCard(portfolioItems[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioCard(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Work sample';
    final description = item['description']?.toString() ?? '';

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: WorkableDesign.surface,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        border: Border.all(color: WorkableDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 125,
            width: double.infinity,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: WorkableDesign.canvas,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: WorkableDesign.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (parts.length == 1) {
      final word = parts[0];
      return word.length >= 2
          ? '${word[0]}${word[word.length - 1]}'.toUpperCase()
          : word[0].toUpperCase();
    }
    return 'U';
  }
}
