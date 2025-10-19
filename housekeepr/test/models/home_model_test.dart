import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/home.dart';

void main() {
  test('Home toMap/fromMap and toJson/fromJson roundtrip', () {
    final h = Home(
      id: 'home1',
      name: 'My House',
      createdBy: 'uid-alice',
      members: ['uid-alice', 'uid-bob'],
      inviteCode: 'ABC123',
    );

    final map = h.toMap();
    final fromMap = Home.fromMap(map);

    expect(fromMap.id, equals(h.id));
    expect(fromMap.name, equals(h.name));
    expect(fromMap.createdBy, equals(h.createdBy));
    expect(fromMap.members, equals(h.members));
    expect(fromMap.inviteCode, equals(h.inviteCode));

    final jsonStr = h.toJson();
    final fromJson = Home.fromJson(jsonStr);
    expect(fromJson.id, equals(h.id));
    expect(fromJson.name, equals(h.name));
  });
}
