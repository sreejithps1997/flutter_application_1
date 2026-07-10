import '../helpers/document_ocr_helper.dart';
import 'verification_document_config.dart';

class VerificationDocuments {
  static final pan = VerificationDocumentConfig(
    documentId: 'pan',
    documentName: 'PAN Card',
    storageFolder: 'pan_cards',
    requiresName: true,
    requiresNumber: true,
    extractor: DocumentOcrHelper.extractPANDetails,
    validator: (value) => RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(value),
  );

  static final aadhaar = VerificationDocumentConfig(
    documentId: 'aadhaar',
    documentName: 'Aadhaar Card',
    storageFolder: 'aadhaar_cards',
    requiresName: true,
    requiresNumber: true,
    extractor: DocumentOcrHelper.extractAadharDetails,
    validator: (value) => RegExp(r'^\d{12}$').hasMatch(value),
  );

  static final passport = VerificationDocumentConfig(
    documentId: 'passport',
    documentName: 'Passport',
    storageFolder: 'passports',
    requiresName: true,
    requiresNumber: true,
    extractor: DocumentOcrHelper.extractPassportDetails,
    validator: (value) =>
        RegExp(r'^[A-Z][0-9]{7}$', caseSensitive: false).hasMatch(value),
  );

  static final voterId = VerificationDocumentConfig(
    documentId: 'voter_id',
    documentName: 'Voter ID Card',
    storageFolder: 'voter_ids',
    requiresName: true,
    requiresNumber: true,
    extractor: DocumentOcrHelper.extractVoterIDDetails,
    validator: (value) => RegExp(r'^[A-Z]{3}\d{7}$').hasMatch(value),
  );

  static final drivingLicense = VerificationDocumentConfig(
    documentId: 'driving_license',
    documentName: 'Driving License',
    storageFolder: 'driving_licenses',
    requiresName: true,
    requiresNumber: true,
    extractor: DocumentOcrHelper.extractLicenseDetails,
    validator: (value) => RegExp(r'^[A-Z]{2}\d{13}$').hasMatch(value),
  );

  static const addressProof = VerificationDocumentConfig(
    documentId: 'addressProof',
    documentName: 'Address Proof',
    storageFolder: 'address_proofs',
  );

  static const policeCertificate = VerificationDocumentConfig(
    documentId: 'policeCertificate',
    documentName: 'Police Clearance Certificate',
    storageFolder: 'police_certificates',
  );

  static const selfie = VerificationDocumentConfig(
    documentId: 'selfie',
    documentName: 'Selfie Verification',
    storageFolder: 'selfie',
    requiresName: true,
  );
}
