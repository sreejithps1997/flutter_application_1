// driving_license_verification_screen.dart
import 'package:flutter/material.dart';
import '../helpers/document_ocr_helper.dart';
import '../screens/document_verification_base_screen.dart';

class DrivingLicenseVerificationScreen extends StatelessWidget {
  const DrivingLicenseVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DocumentVerificationBaseScreen(
      title: 'Driving License Verification',
      documentType: 'driving_license',
      storagePath: 'driving_licenses',
      extractor: DocumentOcrHelper.extractLicenseDetails,
      validator: (number) => RegExp(r'^[A-Z]{2}\d{2}\d{11}\$').hasMatch(number),
    );
  }
}
