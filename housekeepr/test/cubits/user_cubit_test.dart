import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/user_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class _FakeUser implements fb.User {
  @override
  final String uid;
  @override
  String? displayName;

  _FakeUser({required this.uid, this.displayName});

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    this.displayName = displayName ?? this.displayName;
  }

  @override
  Future<void> reload() async {}

  // Delegate other members to noSuchMethod
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('UserCubit setUser emits new user', () async {
    final cubit = UserCubit(null);
    final user = _FakeUser(uid: 'u1', displayName: 'A');

    final states = <fb.User?>[];
    final sub = cubit.stream.listen(states.add);

    cubit.setUser(user);
    await Future.delayed(Duration.zero);

    expect(states, [user]);
    await sub.cancel();
  });
}
