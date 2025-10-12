// ignore_for_file: prefer_const_constructors_in_immutables
part of 'auth_cubit.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  factory AuthState.unknown() = _Unknown;
  factory AuthState.authenticated(String uid) = _Authenticated;
  factory AuthState.unauthenticated() = _Unauthenticated;
  factory AuthState.loading() = _Loading;
  factory AuthState.failure(String message) = _Failure;

  @override
  List<Object?> get props => [];

  /// Helper: whether this state represents an authenticated user
  bool get isAuthenticated => false;

  /// Helper: uid if authenticated, otherwise null
  String? get uid => null;
}

class _Unknown extends AuthState {
  const _Unknown();
}

class _Authenticated extends AuthState {
  final String _uid;
  const _Authenticated(this._uid);

  @override
  List<Object?> get props => [_uid];

  @override
  bool get isAuthenticated => true;

  @override
  String? get uid => _uid;
}

class _Unauthenticated extends AuthState {
  const _Unauthenticated();
}

class _Loading extends AuthState {
  const _Loading();
}

class _Failure extends AuthState {
  final String message;
  const _Failure(this.message);

  @override
  List<Object?> get props => [message];
}
