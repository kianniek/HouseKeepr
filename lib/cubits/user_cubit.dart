import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class UserCubit extends Cubit<fb.User?> {
  UserCubit(super.state);

  void setUser(fb.User? user) => emit(user);
}
