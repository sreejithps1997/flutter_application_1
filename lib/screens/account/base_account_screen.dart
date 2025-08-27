import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BaseAccountScreen extends StatefulWidget {
  const BaseAccountScreen({Key? key}) : super(key: key);
}

abstract class BaseAccountScreenState<T extends BaseAccountScreen>
    extends State<T> {
  // Common user data
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String? profileImageUrl;
  bool isVerified = false;
  String userType = ''; // 'customer' or 'worker'
  Map<String, dynamic> userStats = {};

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        userName = data['name'] ?? '';
        userEmail = data['email'] ?? user.email ?? '';
        userPhone = data['phone'] ?? '';
        profileImageUrl = data['imageUrl'];
        isVerified = data['isVerified'] ?? false;
        userType = data['userType'] ?? 'customer';
      });

      await fetchTypeSpecificData(user.uid, userType);
    }
  }

  // Implemented by customer/worker screens
  Future<void> fetchTypeSpecificData(String uid, String userType);

  /// COMMON REUSABLE UI

  Widget buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl!)
                : null,
            child: profileImageUrl == null
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName.isNotEmpty ? userName : 'User Name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                Text(userEmail, style: TextStyle(color: Colors.grey[600])),
                if (userPhone.isNotEmpty)
                  Text(userPhone, style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuItem(
    IconData icon,
    String title,
    String subtitle, {
    bool isVerified = false,
    int badge = 0,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade600, size: 20),
          ),
          if (badge > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  // Common logout functionality
  Future<void> handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}
