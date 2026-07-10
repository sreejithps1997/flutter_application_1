// lib/core/errors/exceptions.dart
// This file defines custom exceptions used throughout the application.

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}

// Auth exceptions
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}                                  

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException() : super('Invalid credentials');
}

class UserNotFoundException extends AuthException {
  const UserNotFoundException() : super('User not found');
}

class EmailAlreadyInUseException extends AuthException {
  const EmailAlreadyInUseException() : super('Email already in use');
}

class WeakPasswordException extends AuthException {
  const WeakPasswordException() : super('Weak password');
}
