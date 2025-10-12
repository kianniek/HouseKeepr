import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../auth/auth_repository.dart';
// firebase_auth is used by AuthRepository; not required directly here

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository repo;
  AuthCubit(this.repo) : super(AuthState.unknown()) {
    repo.userChanges.listen((u) {
      if (u == null) {
        emit(AuthState.unauthenticated());
      } else {
        emit(AuthState.authenticated(u.uid));
      }
    });
  }

  Future<void> signInWithGoogle() async {
    emit(AuthState.loading());
    try {
      final cred = await repo.signInWithGoogle();
      if (cred == null) emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  Future<void> signOut() async {
    await repo.signOut();
    emit(AuthState.unauthenticated());
  }
}
