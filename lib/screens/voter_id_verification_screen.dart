// voter_id_verification_screen.dart
import 'package:flutter/material.dart';
import '../helpers/document_ocr_helper.dart';
import '../screens/document_verification_base_screen.dart';

class VoterIDVerificationScreen extends StatelessWidget {
  const VoterIDVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentVerificationBaseScreen(
      title: 'Voter ID Verification',
      documentType: 'voter_id',
      storagePath: 'voter_ids',
      extractor: DocumentOcrHelper.extractVoterIDDetails,
      validator: (number) => RegExp(r'^[A-Z]{3}\d{7}\$').hasMatch(number),
    );
  }
}
