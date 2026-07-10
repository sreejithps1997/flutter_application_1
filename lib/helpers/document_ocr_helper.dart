import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class DocumentOcrHelper {
  static Future<Map<String, String>> extractAadharDetails(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String number = '';
    String name = '';

    final numberMatch = RegExp(
      r'\b\d{4}\s\d{4}\s\d{4}\b',
    ).firstMatch(recognizedText.text);
    if (numberMatch != null) {
      number = numberMatch.group(0)!.replaceAll(' ', '');
    }

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty &&
            !text.contains(RegExp(r'\d')) &&
            !text.toUpperCase().contains('GOVERNMENT') &&
            !text.toUpperCase().contains('INDIA')) {
          name = text;
          break;
        }
      }
      if (name.isNotEmpty) break;
    }

    return {'number': number, 'name': name};
  }

  static Future<Map<String, String>> extractPANDetails(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String number = '';
    String name = '';

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();

        if (number.isEmpty &&
            RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(text)) {
          number = text;
        }

        if (name.isEmpty &&
            text.length > 5 &&
            !text.contains(RegExp(r'\d')) &&
            !text.toUpperCase().contains('INCOME TAX') &&
            !text.toUpperCase().contains('GOVT') &&
            !text.toUpperCase().contains('DEPARTMENT')) {
          name = text;
        }
      }
    }

    return {'number': number, 'name': name};
  }

  static Future<Map<String, String>> extractPassportDetails(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String number = '';
    String name = '';

    final numberMatch = RegExp(
      r'\b[A-Z]{1}\d{7}\b',
    ).firstMatch(recognizedText.text);
    if (numberMatch != null) {
      number = numberMatch.group(0)!;
    }

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty &&
            !text.contains(RegExp(r'\d')) &&
            !text.toUpperCase().contains('PASSPORT')) {
          name = text;
          break;
        }
      }
      if (name.isNotEmpty) break;
    }

    return {'number': number, 'name': name};
  }

  static Future<Map<String, String>> extractVoterIDDetails(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String number = '';
    String name = '';

    final numberMatch = RegExp(
      r'\b[A-Z]{3}\d{7}\b',
    ).firstMatch(recognizedText.text);
    if (numberMatch != null) {
      number = numberMatch.group(0)!;
    }

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty &&
            !text.contains(RegExp(r'\d')) &&
            !text.toUpperCase().contains('ELECTION') &&
            !text.toUpperCase().contains('COMMISSION')) {
          name = text;
          break;
        }
      }
      if (name.isNotEmpty) break;
    }

    return {'number': number, 'name': name};
  }

  static Future<Map<String, String>> extractLicenseDetails(File file) async {
    final inputImage = InputImage.fromFile(file);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    String number = '';
    String name = '';

    final numberMatch = RegExp(
      r'\b[A-Z]{2}\d{2}\s?\d{11}\b',
    ).firstMatch(recognizedText.text);
    if (numberMatch != null) {
      number = numberMatch.group(0)!.replaceAll(' ', '');
    }

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty &&
            !text.contains(RegExp(r'\d')) &&
            !text.toUpperCase().contains('DRIVING') &&
            !text.toUpperCase().contains('LICENSE')) {
          name = text;
          break;
        }
      }
      if (name.isNotEmpty) break;
    }

    return {'number': number, 'name': name};
  }
}
