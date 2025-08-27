import 'package:flutter/material.dart';
import '../helpers/document_ocr_helper.dart';
import '../screens/document_verification_base_screen.dart';

class PassportVerificationScreen extends StatelessWidget {
  const PassportVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentVerificationBaseScreen(
      title: 'Passport Verification',
      documentType: 'passport',
      storagePath: 'passports',
      extractor: DocumentOcrHelper.extractPassportDetails,
      validator: (number) => RegExp(r'^[A-Z]{1}\d{7}\$').hasMatch(number),
    );
  }
}
