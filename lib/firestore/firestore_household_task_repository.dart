import 'package:cloud_firestore/cloud_firestore.dart';

import 'remote_task_repository.dart';

class FirestoreHouseholdTaskRepository extends BaseFirestoreTaskRepository {
  final FirebaseFirestore firestore;
  final String householdId;

  FirestoreHouseholdTaskRepository(this.firestore, {required this.householdId});

  @override
  CollectionReference<Map<String, dynamic>> get tasksCollection =>
      firestore.collection('households').doc(householdId).collection('tasks');

  @override
  String get collectionLabel => 'households/$householdId/tasks';
}
