import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../core/theme/workable_design.dart';
import '../../services/notification_service.dart';

abstract class BaseAccountScreen extends StatefulWidget {
  const BaseAccountScreen({super.key});
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

  // @override
  // void initState() {
  //   super.initState();
  //   _fetchUserData();
  // }

  // Future<void> _fetchUserData() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return;

  //   final doc = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(user.uid)
  //       .get();

  //   if (doc.exists) {
  //     final data = doc.data()!;
  //     setState(() {
  //       userName = data['name'] ?? '';
  //       userEmail = data['email'] ?? user.email ?? '';
  //       userPhone = data['phone'] ?? '';
  //       profileImageUrl = data['imageUrl'];
  //       isVerified = data['isVerified'] ?? false;
  //       userType = data['userType'] ?? 'customer';
  //     });

  //     await fetchTypeSpecificData(user.uid, userType);
  //   }
  // }

  StreamSubscription? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userDataSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) async {
          if (!doc.exists || !mounted) return;
          final data = doc.data()!;
          setState(() {
            userName = data['name'] ?? '';
            userEmail = data['email'] ?? user.email ?? '';
            userPhone = data['phone'] ?? '';
            profileImageUrl = data['profileImageUrl']; // ✅ fixed key
            isVerified = data['isVerified'] ?? false;
            userType = data['userType'] ?? 'customer';
          });

          await fetchTypeSpecificData(user.uid, userType);
        });
  }

  // Implemented by customer/worker screens
  Future<void> fetchTypeSpecificData(String uid, String userType);

  /// COMMON REUSABLE UI

  Widget buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WorkableDesign.cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: WorkableDesign.primary.withValues(alpha: 0.1),
            backgroundImage: profileImageUrl != null
                ? NetworkImage(profileImageUrl!)
                : null,
            child: profileImageUrl == null
                ? Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: WorkableDesign.primary,
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
                          color: WorkableDesign.success,
                        ),
                      ),
                  ],
                ),
                Text(
                  userEmail,
                  style: const TextStyle(color: WorkableDesign.muted),
                ),
                if (userPhone.isNotEmpty)
                  Text(
                    userPhone,
                    style: const TextStyle(color: WorkableDesign.muted),
                  ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WorkableDesign.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: WorkableDesign.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        WorkableDesign.radius,
                      ),
                    ),
                    child: Icon(icon, color: WorkableDesign.primary, size: 20),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: WorkableDesign.danger,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          badge > 99 ? '99+' : badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: WorkableDesign.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: WorkableDesign.success,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: WorkableDesign.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: WorkableDesign.muted),
            ],
          ),
        ),
      ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: WorkableDesign.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationService.removeCurrentDeviceToken();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}
