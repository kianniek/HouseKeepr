import '../models/home.dart';

abstract class RemoteHomeRepository {
  Future<void> createHome(Home home);
  Future<Home?> getHome(String id);
  Future<Home?> getHomeByInviteCode(String inviteCode);
  Future<void> joinHomeByInvite(String inviteCode, String userId);
  Future<void> updateHome(Home home);
}
