import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import 'worker_visibility_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ SIGN UP USER - FIXED VERSION
  Future<String?> signUpUser({
    required String email,
    required String password,
    required String name,
    required String userType, // "worker" or "customer"
    String? phone,
    File? profileImage,
  }) async {
    try {
      // Step 1: Create Firebase Auth user
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      final uid = user?.uid;

      if (uid == null) {
        return "User UID is null after signup.";
      }

      // Small delay to ensure auth state is updated
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Upload profile image if provided (new version with retry)
      String? profileImageUrl;
      if (profileImage != null) {
        profileImageUrl = await _uploadProfileImageWithRetry(
          uid: uid,
          file: profileImage,
          userType: userType,
        );

        if (profileImageUrl == null) {
          return 'Failed to upload profile image. Please try again.';
        }
      }

      // Step 3: Save user data in Firestore (always in USERS collection)
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'phone': phone ?? '', // ✅ Add this line
        'userType': userType,
        'profileImageUrl': profileImageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Step 4: Mirror into WORKERS collection if userType == worker
      if (userType == 'worker') {
        await _firestore.collection('workers').doc(uid).set({
          'uid': uid,
          'email': email,
          'name': name,
          'profileImageUrl': profileImageUrl ?? '',
          'status': 'onboarding',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      print("✅ User saved successfully to Firestore");
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("❌ FirebaseAuth error: ${e.code} - ${e.message}");

      switch (e.code) {
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled. Please contact support.';
        default:
          return e.message ?? 'Authentication failed. Please try again.';
      }
    } catch (e) {
      print("❌ Unexpected error during signUpUser: $e");
      return 'An unexpected error occurred: ${e.toString()}';
    }
  }

  // ✅ Upload helper with retry + unique filename
  Future<String?> _uploadProfileImageWithRetry({
    required String uid,
    required File file,
    required String userType,
  }) async {
    // Function to actually upload with a unique name
    Future<String?> doUpload() async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = userType == 'worker'
          ? "worker_profile_images/$uid/profile_$ts.jpg"
          : "users/$uid/profile_$ts.jpg";

      final ref = FirebaseStorage.instance.ref(path);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': uid,
          'userType': userType,
          'uploadTime': DateTime.now().toIso8601String(),
        },
      );

      print("DEBUG: Uploading profile image → $path");
      final task = ref.putFile(file, metadata);
      await task.whenComplete(() {});
      final url = await ref.getDownloadURL();
      print("✅ Upload successful: $url");
      return url;
    }

    try {
      return await doUpload();
    } on FirebaseException catch (e) {
      // Handle the “terminated upload session” / 412 case by retrying once
      final msg = (e.message ?? '').toLowerCase();
      final looksLike412 = msg.contains('terminated') || msg.contains('412');

      print("❌ Upload failed (first attempt): ${e.code} - ${e.message}");
      if (looksLike412 || e.code == 'unknown') {
        await Future.delayed(const Duration(seconds: 1));
        try {
          print("↻ Retrying upload with a fresh session...");
          return await doUpload();
        } catch (e2) {
          print("❌ Retry failed: $e2");
          return null;
        }
      }
      return null;
    } catch (e) {
      print("❌ Upload unexpected error: $e");
      return null;
    }
  }

  // ✅ Google Sign-In
  Future<UserCredential?> signInWithGoogle({required String userType}) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': user.displayName ?? '',
                'email': user.email ?? '',
                'userType': userType,
                'profileImage': user.photoURL ?? '',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      }

      return userCredential;
    } catch (e) {
      print('Google sign-in failed: $e');
      return null;
    }
  }

  //✅ Password Reset
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Failed to send reset email.";
    } catch (e) {
      return "Failed to send reset email. Please try again.";
    }
  }

  Future<String?> sendCustomResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.29.209:3000/send-reset-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        return null; // success
      } else {
        return "Failed to send reset email";
      }
    } catch (e) {
      return "Error: ${e.toString()}";
    }
  }

  // // ✅ Login
  // Future<String?> loginUser({
  //   required String email,
  //   required String password,
  // }) async {
  //   try {
  //     await _auth.signInWithEmailAndPassword(email: email, password: password);
  //     return null; // Success
  //   } on FirebaseAuthException catch (e) {
  //     print('Firebase error code: ${e.code}');
  //     print('Firebase error message: ${e.message}');
  //     switch (e.code) {
  //       case 'user-not-found':
  //         return 'No account found with this email.';
  //       case 'wrong-password':
  //         return 'Incorrect password.';
  //       case 'invalid-email':
  //         return 'Invalid email address.';
  //       case 'user-disabled':
  //         return 'This account has been disabled.';
  //       case 'invalid-credential':
  //         return 'Invalid email or password.';
  //       default:
  //         return 'Login failed. Please try again.';
  //     }
  //   } catch (e) {
  //     return 'An unexpected error occurred. Please try again.';
  //   }
  // }

  // ✅ Login — supports both email and phone number
  Future<String?> loginUser({
    required String email,
    required String password,
    required String userType, // ✅ NEW — 'customer' or 'worker'
  }) async {
    try {
      String loginEmail = email;

      if (email.endsWith('@phone.workable.com')) {
        final phone = email.replaceAll('@phone.workable.com', '');
        final foundEmail = await _getEmailByPhone(phone);
        if (foundEmail == null) {
          return 'No account found with this phone number.';
        }
        loginEmail = foundEmail;
      }

      // Step 1 — Sign in
      final credential = await _auth.signInWithEmailAndPassword(
        email: loginEmail,
        password: password,
      );

      // Step 2 — ✅ Check userType from Firestore
      final uid = credential.user?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('users').doc(uid).get();
        final savedUserType = doc.data()?['userType'] as String?;

        if (savedUserType == null) {
          await _auth.signOut();
          return 'Account type not found. Please contact support.';
        }

        // if (savedUserType != userType) {
        //   await _auth.signOut(); // ✅ Force sign out immediately
        //   if (userType == 'customer') {
        //     return 'This account is registered as a worker. Please use the Worker Login.';
        //   } else {
        //     return 'This account is registered as a customer. Please use the Customer Login.';
        //   }
        // }

        if (userType == 'customer') {
          // Customer login allows BOTH customer and admin
          if (savedUserType != 'customer' && savedUserType != 'admin') {
            await _auth.signOut();

            return 'This account is registered as a worker. Please use the Worker Login.';
          }
        } else {
          // Worker login only allows workers
          if (savedUserType != userType) {
            await _auth.signOut();

            return 'This account is registered as a customer. Please use the Customer Login.';
          }
        }
      }

      return null; // ✅ Success — correct user type
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with this email or phone.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'invalid-credential':
          return 'Invalid email/phone or password.';
        default:
          return 'Login failed. Please try again.';
      }
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  // // ✅ Helper — find email using phone number from Firestore
  // Future<String?> _getEmailByPhone(String phone) async {
  //   try {
  //     final query = await _firestore
  //         .collection('users')
  //         .where('phone', isEqualTo: phone)
  //         .limit(1)
  //         .get();

  //     if (query.docs.isEmpty) return null;
  //     return query.docs.first.data()['email'] as String?;
  //   } catch (e) {
  //     print("Error finding email by phone: $e");
  //     return null;
  //   }
  // }

  Future<String?> _getEmailByPhone(String phone) async {
    try {
      print("🔍 Searching for phone: '$phone'");

      // Search 1 — users collection (customers)
      final userQuery = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final email = userQuery.docs.first.data()['email'] as String?;
        print("✅ Found in users collection: $email");
        return email;
      }

      // Search 2 — workers collection
      final workerQuery = await _firestore
          .collection('workers')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (workerQuery.docs.isNotEmpty) {
        final email = workerQuery.docs.first.data()['email'] as String?;
        print("✅ Found in workers collection: $email");
        return email;
      }

      print("❌ Phone not found in any collection: $phone");
      return null;
    } catch (e) {
      print("❌ Error finding email by phone: $e");
      return null;
    }
  }

  // ✅ Logout
  Future<void> signOut() async {
    await NotificationService.removeCurrentDeviceToken();
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // ✅ Get Current User
  User? get currentUser => _auth.currentUser;

  // ✅ Get Current User Type
  Future<String?> getCurrentUserType() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['userType'] as String?;
    } catch (e) {
      print("Error getting user type: $e");
      return null;
    }
  }

  // ✅ Save Worker Onboarding Data
  Future<String?> saveWorkerOnboardingData(
    Map<String, dynamic> workerData,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "User not logged in";

      // Ensure required fields
      workerData['uid'] = user.uid;
      workerData['name'] = workerData['fullName'] ?? 'Unnamed Worker';
      final profileImageUrl =
          workerData['profileImageUrl']?.toString().trim() ?? '';
      if (profileImageUrl.isNotEmpty) {
        workerData['imageUrl'] = workerData['imageUrl'] ?? profileImageUrl;
      }
      workerData['pricing'] = workerData['pricing'] ?? '₹300';
      workerData['averageRating'] = workerData['averageRating'] ?? 0.0;
      workerData['completedJobsCount'] = workerData['completedJobsCount'] ?? 0;
      workerData['earnings'] = workerData['earnings'] ?? 0.0;
      final geoLocation = _resolveWorkerLocation(workerData);
      if (geoLocation != null) {
        workerData['location'] = geoLocation;
      } else {
        workerData['location'] = workerData['location'] ?? const GeoPoint(0, 0);
      }
      workerData['address'] = workerData['address'] ?? '';
      workerData['visibleToUsers'] = workerData['visibleToUsers'] ?? false;
      workerData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('workers')
          .doc(user.uid)
          .set(workerData, SetOptions(merge: true));

      await WorkerVisibilityService().syncWorkerVisibility(user.uid);

      print("✅ Worker data saved successfully");
      return null; // Success
    } catch (e) {
      print("❌ Error saving worker data: $e");
      return "Failed to save worker data. Please try again.";
    }
  }

  // ✅ Get Current User Profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print("Error getting user profile: $e");
      return null;
    }
  }

  // ✅ Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print("Error checking email: $e");
      return false;
    }
  }

  GeoPoint? _resolveWorkerLocation(Map<String, dynamic> workerData) {
    final location = workerData['location'];
    if (location is GeoPoint) return location;

    if (location is String) {
      final parts = location.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (_isUsableCoordinate(lat, lng)) return GeoPoint(lat!, lng!);
      }
    }

    final lat = _asDouble(workerData['latitude']);
    final lng = _asDouble(workerData['longitude']);
    if (_isUsableCoordinate(lat, lng)) return GeoPoint(lat!, lng!);

    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool _isUsableCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }
}
