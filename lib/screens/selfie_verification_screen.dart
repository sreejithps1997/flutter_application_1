import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelfieVerificationScreen extends StatefulWidget {
  static const routeName = '/selfie-verification';

  const SelfieVerificationScreen({super.key});

  @override
  State<SelfieVerificationScreen> createState() =>
      _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen> {
  String currentStep =
      'instructions'; // instructions, camera, processing, success, failed
  bool faceDetected = false;
  bool isProcessing = false;
  String livenessStep = 'center'; // center, blink, smile

  @override
  void initState() {
    super.initState();
  }

  void handleStartVerification() {
    setState(() {
      currentStep = 'camera';
      faceDetected = false;
      isProcessing = false;
      livenessStep = 'center';
    });

    // Simulate face detection after 2 seconds
    Timer(const Duration(seconds: 2), () {
      setState(() {
        faceDetected = true;
      });

      // Simulate liveness steps
      Timer(const Duration(seconds: 2), () {
        setState(() => livenessStep = 'blink');
        Timer(const Duration(seconds: 2), () {
          setState(() => livenessStep = 'smile');
        });
      });
    });
  }

  void handleCapture() {
    setState(() {
      isProcessing = true;
    });

    // Simulate processing animation
    Timer(const Duration(seconds: 1), () {
      setState(() {
        currentStep = 'processing';
      });

      // Simulate final result after 3 seconds
      Timer(const Duration(seconds: 3), () async {
        try {
          final uid = FirebaseAuth.instance.currentUser!.uid;

          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('identityVerification')
              .doc('status')
              .set({'selfie': 'verified'}, SetOptions(merge: true));

          if (mounted) Navigator.pop(context, true);
        } catch (e) {
          debugPrint("Error saving selfie verification: $e");
          if (mounted) {
            setState(() {
              currentStep = 'failed'; // Optional: show error
            });
          }
        }
      });
    });
  }

  void handleRetry() {
    setState(() {
      currentStep = 'camera';
      faceDetected = false;
      isProcessing = false;
      livenessStep = 'center';
    });

    handleStartVerification();
  }

  PreferredSizeWidget buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.black),
        onPressed: () {
          if (currentStep == 'instructions') {
            Navigator.pop(context);
          } else {
            setState(() {
              currentStep = 'instructions';
            });
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Selfie Verification",
            style: TextStyle(color: Colors.black),
          ),
          if (currentStep != 'instructions')
            const Text(
              "Step 2 of 3",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.helpCircle, color: Colors.grey),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget buildInstructionsScreen() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 32,
            backgroundColor: Color(0xFFDCEEFB),
            child: Icon(LucideIcons.camera, color: Colors.blue, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            "Selfie Verification",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll take a quick photo to verify your identity",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Instructions list
          _buildCheckItem(
            "Good lighting",
            "Make sure your face is well-lit and clearly visible",
          ),
          _buildCheckItem(
            "Remove accessories",
            "Take off glasses, hats, or anything covering your face",
          ),
          _buildCheckItem(
            "Look directly at camera",
            "Keep your face centered and look straight ahead",
          ),

          const SizedBox(height: 24),
          _buildTips(),
          const SizedBox(height: 24),
          _buildSecurityNote(),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(LucideIcons.camera),
            label: const Text("Start Verification"),
            onPressed: handleStartVerification,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFFD1FAE5),
            child: Icon(LucideIcons.check, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          Icon(LucideIcons.smile, color: Colors.green, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              "✅ Clear & Centered\n❌ Too dark or blurry",
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          Icon(LucideIcons.shield, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your privacy is protected. Photos are encrypted and used only for verification.",
              style: TextStyle(fontSize: 13, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCameraScreen() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.black12,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.camera, size: 48, color: Colors.grey),
                    Text(
                      "Camera Preview",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 240,
              width: 180,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(
                  color: faceDetected ? Colors.green : Colors.white,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          faceDetected
              ? "Face Detected - Hold Still"
              : "Position your face in the oval",
          style: TextStyle(
            color: faceDetected ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (faceDetected) _buildLivenessInstructions(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.rotateCcw),
              onPressed: () {},
            ),
            FloatingActionButton(
              onPressed: faceDetected && !isProcessing ? handleCapture : null,
              backgroundColor: faceDetected ? Colors.blue : Colors.grey,
              child: isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(LucideIcons.camera),
            ),
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: handleRetry,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLivenessInstructions() {
    String text = '';
    IconData icon = LucideIcons.eye;
    if (livenessStep == 'center') {
      text = "Look straight at the camera";
      icon = LucideIcons.eye;
    } else if (livenessStep == 'blink') {
      text = "Now blink your eyes";
      icon = LucideIcons.eye;
    } else if (livenessStep == 'smile') {
      text = "Please smile";
      icon = LucideIcons.smile;
    }

    return Column(
      children: [
        Text(text, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Icon(icon, size: 28, color: Colors.blue),
      ],
    );
  }

  Widget buildProcessingScreen() {
    return Column(
      children: const [
        SizedBox(height: 80),
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text("Verifying your photo...", style: TextStyle(fontSize: 18)),
        SizedBox(height: 8),
        Text("Please wait while we process your selfie"),
      ],
    );
  }

  Widget buildSuccessScreen() {
    return Column(
      children: [
        const SizedBox(height: 80),
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFD1FAE5),
          child: Icon(LucideIcons.checkCircle, size: 40, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text(
          "Verification Successful!",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text("Your selfie has been verified successfully"),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Continue to Profile"),
        ),
      ],
    );
  }

  Widget buildFailedScreen() {
    return Column(
      children: [
        const SizedBox(height: 80),
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFFEE2E2),
          child: Icon(LucideIcons.xCircle, size: 40, color: Colors.red),
        ),
        const SizedBox(height: 24),
        const Text(
          "Verification Failed",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text("We couldn't verify your selfie. Please try again."),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: handleRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Try Again"),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Go Back"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildHeader(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Builder(
          builder: (_) {
            if (currentStep == 'instructions') return buildInstructionsScreen();
            if (currentStep == 'camera') return buildCameraScreen();
            if (currentStep == 'processing') return buildProcessingScreen();
            if (currentStep == 'success') return buildSuccessScreen();
            if (currentStep == 'failed') return buildFailedScreen();

            return const SizedBox();
          },
        ),
      ),
    );
  }
}
