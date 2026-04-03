import '../models/home.dart';

abstract class RemoteHomeRepository {
  Future<void> createHome(Home home);
  Future<Home?> getHome(String id);
  Future<void> updateHome(Home home);
}
