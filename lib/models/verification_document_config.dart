import 'dart:io';

typedef VerificationExtractor = Future<Map<String, String>> Function(File file);
typedef VerificationValidator = bool Function(String value);

class VerificationDocumentConfig {
  final String documentId;
  final String documentName;
  final String storageFolder;
  final String type;
  final VerificationExtractor? extractor;
  final VerificationValidator? validator;
  final bool requiresImage;
  final bool requiresName;
  final bool requiresNumber;

  const VerificationDocumentConfig({
    required this.documentId,
    required this.documentName,
    required this.storageFolder,
    String? type,
    this.extractor,
    this.validator,
    this.requiresImage = true,
    this.requiresName = false,
    this.requiresNumber = false,
  }) : type = type ?? documentId;

  bool isValidNumber(String value) {
    final activeValidator = validator;
    if (activeValidator == null) return true;
    return activeValidator(value);
  }
}
