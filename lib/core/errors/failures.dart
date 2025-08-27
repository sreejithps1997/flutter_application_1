// lib/core/errors/failures.dart
// This file defines custom failure classes used throughout the application.
// It includes general failures like ServerFailure, CacheFailure, and NetworkFailure,
// as well as specific authentication failures like UserNotFoundFailure, InvalidCredentialsFailure, etc.
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

// General failures
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

// Auth failures
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Invalid email or password');
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure() : super('User not found');
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure() : super('Email already in use');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure() : super('Password is too weak');
}

class UserDisabledFailure extends AuthFailure {
  const UserDisabledFailure() : super('User account has been disabled');
}
