import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FavoriteWorkersScreen extends StatefulWidget {
  static const routeName = '/favorite-workers';

  const FavoriteWorkersScreen({super.key});

  @override
  State<FavoriteWorkersScreen> createState() => _FavoriteWorkersScreenState();
}

class _FavoriteWorkersScreenState extends State<FavoriteWorkersScreen> {
  String viewMode = 'grid';
  String searchQuery = '';
  String selectedCategory = 'all';
  String sortBy = 'rating';
  bool showFilters = false;

  final List<Map<String, dynamic>> categories = [
    {'id': 'all', 'name': 'All Services', 'icon': LucideIcons.user},
    {'id': 'plumber', 'name': 'Plumber', 'icon': LucideIcons.droplets},
    {'id': 'electrician', 'name': 'Electrician', 'icon': LucideIcons.zap},
    {'id': 'carpenter', 'name': 'Carpenter', 'icon': LucideIcons.hammer},
    {'id': 'painter', 'name': 'Painter', 'icon': LucideIcons.paintbrush},
    {'id': 'mechanic', 'name': 'Mechanic', 'icon': LucideIcons.wrench},
  ];

  final List<Map<String, dynamic>> workers = [
    {
      'id': 1,
      'name': 'Rajesh Kumar',
      'service': 'Plumber',
      'rating': 4.8,
      'reviews': 156,
      'price': 300,
      'distance': 2.3,
      'avatar': 'RK',
      'isOnline': true,
      'lastBooked': '2 days ago',
      'completedJobs': 89,
      'skills': ['Pipe Repair', 'Installation', 'Maintenance'],
      'joinedDate': 'Jan 2023',
    },
    {
      'id': 2,
      'name': 'Amit Singh',
      'service': 'Electrician',
      'rating': 4.9,
      'reviews': 203,
      'price': 350,
      'distance': 1.8,
      'avatar': 'AS',
      'isOnline': false,
      'lastBooked': '1 week ago',
      'completedJobs': 127,
      'skills': ['Wiring', 'Appliance Repair', 'Installation'],
      'joinedDate': 'Mar 2022',
    },
    {
      'id': 3,
      'name': 'Priya Sharma',
      'service': 'Painter',
      'rating': 4.7,
      'reviews': 98,
      'price': 250,
      'distance': 3.1,
      'avatar': 'PS',
      'isOnline': true,
      'lastBooked': '3 days ago',
      'completedJobs': 67,
      'skills': ['Interior Painting', 'Wall Design', 'Texture'],
      'joinedDate': 'Aug 2023',
    },
    {
      'id': 4,
      'name': 'Mohammed Ali',
      'service': 'Carpenter',
      'rating': 4.6,
      'reviews': 134,
      'price': 280,
      'distance': 4.2,
      'avatar': 'MA',
      'isOnline': true,
      'lastBooked': '5 days ago',
      'completedJobs': 95,
      'skills': ['Furniture Repair', 'Installation', 'Custom Work'],
      'joinedDate': 'Dec 2022',
    },
    {
      'id': 5,
      'name': 'Suresh Gupta',
      'service': 'Mechanic',
      'rating': 4.5,
      'reviews': 87,
      'price': 400,
      'distance': 2.7,
      'avatar': 'SG',
      'isOnline': false,
      'lastBooked': '1 month ago',
      'completedJobs': 73,
      'skills': ['AC Repair', 'Appliance Service', 'Motor Repair'],
      'joinedDate': 'May 2023',
    },
  ];

  List<Map<String, dynamic>> get filteredWorkers {
    return workers.where((worker) {
      final matchesSearch =
          worker['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
          worker['service'].toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == 'all' ||
          worker['service'].toLowerCase() == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Map<String, dynamic>> get sortedWorkers {
    List<Map<String, dynamic>> list = [...filteredWorkers];
    list.sort((a, b) {
      switch (sortBy) {
        case 'rating':
          return (b['rating'] as double).compareTo(a['rating'] as double);
        case 'price':
          return (a['price'] as int).compareTo(b['price'] as int);
        case 'distance':
          return (a['distance'] as double).compareTo(b['distance'] as double);
        default:
          return 0;
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: BackButton(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Favorite Workers",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "${filteredWorkers.length} saved workers",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              viewMode == 'grid' ? LucideIcons.list : LucideIcons.grid,
            ),
            onPressed: () {
              setState(() {
                viewMode = viewMode == 'grid' ? 'list' : 'grid';
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                hintText: 'Search workers...',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: categories.map((category) {
                  final isActive = selectedCategory == category['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isActive,
                      label: Row(
                        children: [
                          Icon(category['icon'], size: 16),
                          const SizedBox(width: 4),
                          Text(category['name']),
                        ],
                      ),
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: isActive ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = category['id'];
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Sort Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: sortBy,
                  underline: Container(),
                  borderRadius: BorderRadius.circular(10),
                  items: const [
                    DropdownMenuItem(
                      value: 'rating',
                      child: Text("Sort by Rating"),
                    ),
                    DropdownMenuItem(
                      value: 'price',
                      child: Text("Sort by Price"),
                    ),
                    DropdownMenuItem(
                      value: 'distance',
                      child: Text("Sort by Distance"),
                    ),
                  ],
                  onChanged: (val) => setState(() => sortBy = val!),
                ),
                TextButton.icon(
                  icon: const Icon(LucideIcons.filter, size: 16),
                  label: const Text("Filters"),
                  onPressed: () => setState(() => showFilters = !showFilters),
                ),
              ],
            ),

            if (showFilters)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [Text("Advanced Filters Coming Soon")],
                ),
              ),

            const SizedBox(height: 12),

            // Worker Cards
            if (filteredWorkers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: const [
                    Icon(LucideIcons.heart, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      "No favorite workers found",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "Try adjusting your search or filters",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              viewMode == 'grid'
                  ? Column(
                      children: sortedWorkers
                          .map((w) => _buildWorkerCard(w))
                          .toList(),
                    )
                  : Column(
                      children: sortedWorkers
                          // .map((w) => _buildWorkerCard(w, isListView: true))
                          .map((w) => _buildWorkerCard(w))
                          .toList(),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Heart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blue,
                    child: Text(
                      worker['avatar'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (worker['isOnline'] == true)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: Colors.green,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.favorite, color: Colors.red, size: 20),
            ],
          ),

          const SizedBox(height: 8),

          // Name
          Text(
            worker['name'],
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),

          const SizedBox(height: 2),

          // Profession
          Text(
            worker['service'],
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 6),

          // Rating Row
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 3),
              Text(
                "${worker['rating']}",
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              Text(
                " (${worker['reviews']} reviews)",
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(width: 6),
              const Text("•", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 6),
              Text(
                "${worker['completedJobs']} jobs",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Skills
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ...worker['skills']
                  .take(2)
                  .map<Widget>(
                    (skill) => Chip(
                      label: Text(skill, style: const TextStyle(fontSize: 10)),
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  )
                  .toList(),
              if (worker['skills'].length > 2)
                Chip(
                  label: Text(
                    "+${worker['skills'].length - 2}",
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.grey.shade200,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Price, Distance, Last Booked
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "₹${worker['price']}/hr",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    "${worker['distance']} km",
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time, size: 13),
                  const SizedBox(width: 2),
                  Text(
                    "Last: ${worker['lastBooked']}",
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: const Text("Book Now", style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size.fromHeight(36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _circleIconButton(Icons.phone, onPressed: () {}),
              const SizedBox(width: 6),
              _circleIconButton(Icons.chat_bubble_outline, onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, {required VoidCallback onPressed}) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: Colors.black87),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }
}
