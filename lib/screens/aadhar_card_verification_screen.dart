// aadhar_card_verification_screen.dart
import 'package:flutter/material.dart';
import '../helpers/document_ocr_helper.dart';
import '../screens/document_verification_base_screen.dart';

class AadharCardVerificationScreen extends StatelessWidget {
  const AadharCardVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentVerificationBaseScreen(
      title: 'Aadhar Card Verification',
      documentType: 'aadhar',
      storagePath: 'aadhar_cards',
      extractor: DocumentOcrHelper.extractAadharDetails,
      validator: (number) => RegExp(r'^\d{12}\$').hasMatch(number),
    );
  }
}
