import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'worker_list_screen.dart';

class SearchScreen extends StatefulWidget {
  static const routeName = '/search';

  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  void _search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('workers')
          .where('services', arrayContainsAny: [query.toLowerCase()])
          .get();

      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'service': (data['services'] as List).join(', '),
          'rating': (data['averageRating'] ?? 0.0).toDouble(),
          'imageUrl': data['imageUrl'] ?? '',
          'location': data['location'] ?? '',
          'pricing': data['pricing'] ?? '',
          'completedJobsCount': data['completedJobsCount'] ?? 0,
        };
      }).toList();

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No workers found for this service.")),
        );
      } else {
        Navigator.pushNamed(
          context,
          WorkerListScreen.routeName,
          arguments: results,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error fetching search results.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Workers"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search: Plumber, Electrician, etc.",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    final query = _searchController.text.trim();
                    _search(query);
                  },
                ),
              ),
              textInputAction: TextInputAction.search,
              onFieldSubmitted: _search,
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
