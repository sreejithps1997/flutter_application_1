//lib/core/errors/error_handler.dart
// This file handles exceptions and converts them into Failure objects.
// It provides a centralized way to manage errors across the application.
import 'package:firebase_auth/firebase_auth.dart';
import 'exceptions.dart';
import 'failures.dart';

class ErrorHandler {
  static Failure handleException(dynamic error) {
    if (error is ServerException) {
      return ServerFailure(error.message);
    } else if (error is CacheException) {
      return CacheFailure(error.message);
    } else if (error is NetworkException) {
      return NetworkFailure(error.message);
    } else if (error is AuthException) {
      return AuthFailure(error.message);
    } else if (error is FirebaseAuthException) {
      return _handleFirebaseAuthException(error);
    } else {
      return ServerFailure('Unexpected error occurred: ${error.toString()}');
    }
  }

  static AuthFailure _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const UserNotFoundFailure();
      case 'wrong-password':
        return const InvalidCredentialsFailure();
      case 'invalid-email':
        return const AuthFailure('Invalid email address');
      case 'user-disabled':
        return const UserDisabledFailure();
      case 'email-already-in-use':
        return const EmailAlreadyInUseFailure();
      case 'weak-password':
        return const WeakPasswordFailure();
      case 'operation-not-allowed':
        return const AuthFailure('Operation not allowed');
      case 'invalid-credential':
        return const InvalidCredentialsFailure();
      case 'account-exists-with-different-credential':
        return const AuthFailure('Account exists with different credential');
      case 'invalid-verification-code':
        return const AuthFailure('Invalid verification code');
      case 'invalid-verification-id':
        return const AuthFailure('Invalid verification ID');
      case 'network-request-failed':
        return const AuthFailure('Network error occurred');
      case 'too-many-requests':
        return const AuthFailure('Too many requests. Please try again later');
      default:
        return AuthFailure(
          'Authentication error: ${e.message ?? 'Unknown error'}',
        );
    }
  }

  static String getErrorMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'Please check your internet connection';
    } else if (failure is ServerFailure) {
      return 'Server error occurred. Please try again';
    } else if (failure is AuthFailure) {
      return failure.message;
    } else if (failure is ValidationFailure) {
      return failure.message;
    } else if (failure is CacheFailure) {
      return 'Local storage error occurred';
    } else {
      return 'Something went wrong. Please try again';
    }
  }
}
