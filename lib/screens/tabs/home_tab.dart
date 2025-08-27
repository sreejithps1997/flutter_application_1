import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String userName = '';
  String? profileImageUrl;
  String uid = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    uid = user.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        userName = data['name'] ?? '';
        profileImageUrl = data['imageUrl'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: profileImageUrl != null
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: profileImageUrl == null
                    ? Text(
                        userName.isNotEmpty ? userName[0] : '',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "User ID: $uid",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.person),
          title: const Text("Personal Info"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            DefaultTabController.of(context).animateTo(1);
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text("Security"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            DefaultTabController.of(context).animateTo(2);
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip),
          title: const Text("Privacy & Data"),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            DefaultTabController.of(context).animateTo(3);
          },
        ),
      ],
    );
  }
}
