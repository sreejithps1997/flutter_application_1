// lib/services/user_type_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserTypeService {
  static Future<String> getCurrentUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'guest';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data()?['userType'] ?? 'customer';
  }
}
