import 'package:flutter/material.dart';
import '../screens/worker_profile_screen.dart';

class WorkerListScreen extends StatelessWidget {
  static const routeName = '/worker-list';

  final List<Map<String, dynamic>> results;

  const WorkerListScreen({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Workers"),
        backgroundColor: Colors.deepPurple,
      ),
      body: results.isEmpty
          ? const Center(
              child: Text(
                "No workers found. Try a different keyword or filter.",
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final worker = results[index];
                return _buildWorkerCard(context, worker);
              },
            ),
    );
  }

  Widget _buildWorkerCard(BuildContext context, Map<String, dynamic> worker) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.deepPurple.shade100,
          backgroundImage:
              (worker['imageUrl'] != null && worker['imageUrl'] != '')
              ? NetworkImage(worker['imageUrl'])
              : null,
          child: (worker['imageUrl'] == null || worker['imageUrl'] == '')
              ? const Icon(Icons.person, color: Colors.deepPurple)
              : null,
        ),
        title: Text(
          worker['name'] ?? 'Unnamed Worker',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (worker['service'] != null)
                Text("Service: ${worker['service']}"),
              if (worker['pricing'] != null)
                Text("Price: ₹${worker['pricing']} per hour"),
              if (worker['averageRating'] != null)
                Text(
                  "⭐ ${worker['averageRating'].toStringAsFixed(1)} rating",
                  style: TextStyle(color: Colors.orange[800]),
                ),
              if (worker['completedJobsCount'] != null)
                Text("${worker['completedJobsCount']} jobs completed"),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerProfileScreen(
                workerId: worker['id'],
                name: worker['name'] ?? 'Worker',
              ),
            ),
          );
        },
      ),
    );
  }
}
