import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/home.dart';

void main() {
  test('Home.fromMap parses members and defaults createdAt', () {
    final m = {
      'id': 'h1',
      'name': 'My Home',
      'createdBy': 'u1',
      'members': ['u1', null, 123, 'u2'],
    };

    final home = Home.fromMap(m);
    expect(home.id, 'h1');
    expect(home.name, 'My Home');
    expect(home.createdBy, 'u1');
    expect(home.members, containsAll(['u1', '123', 'u2']));
    expect(home.createdAt, isA<DateTime>());
  });
}
