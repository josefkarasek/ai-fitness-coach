import 'package:drift/drift.dart';

import 'app_database.dart';

class CachedPayloadSnapshot {
  const CachedPayloadSnapshot({
    required this.payloadJson,
    required this.updatedAt,
  });

  final String payloadJson;
  final DateTime updatedAt;
}

class DriftLocalCacheRepository {
  DriftLocalCacheRepository(this._database);

  final AppDatabase _database;

  Future<void> cacheUserProfile({
    required String firebaseUid,
    required String payloadJson,
  }) async {
    await _database
        .into(_database.userProfileCaches)
        .insertOnConflictUpdate(
          UserProfileCachesCompanion(
            firebaseUid: Value<String>(firebaseUid),
            payloadJson: Value<String>(payloadJson),
            updatedAt: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
  }

  Future<CachedPayloadSnapshot?> loadCachedUserProfile(
    String firebaseUid,
  ) async {
    final UserProfileCache? row =
        await (_database.select(_database.userProfileCaches)
              ..where((UserProfileCaches tbl) => tbl.firebaseUid.equals(firebaseUid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return CachedPayloadSnapshot(
      payloadJson: row.payloadJson,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> cacheTrainingPlan({
    required int planId,
    required String firebaseUid,
    required String payloadJson,
  }) async {
    await _database.into(_database.trainingPlanCaches).insertOnConflictUpdate(
          TrainingPlanCachesCompanion(
            planId: Value<int>(planId),
            firebaseUid: Value<String>(firebaseUid),
            payloadJson: Value<String>(payloadJson),
            updatedAt: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
  }

  Future<CachedPayloadSnapshot?> loadLatestTrainingPlan(String firebaseUid) async {
    final TrainingPlanCache? row =
        await (_database.select(_database.trainingPlanCaches)
              ..where((TrainingPlanCaches tbl) => tbl.firebaseUid.equals(firebaseUid))
              ..orderBy(<OrderingTerm Function(TrainingPlanCaches)>[
                (TrainingPlanCaches tbl) => OrderingTerm.desc(tbl.updatedAt),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return CachedPayloadSnapshot(
      payloadJson: row.payloadJson,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> cacheWorkoutLogs({
    required int trainingPlanId,
    required String firebaseUid,
    required String payloadJson,
  }) async {
    await _database.into(_database.workoutLogCaches).insertOnConflictUpdate(
          WorkoutLogCachesCompanion(
            trainingPlanId: Value<int>(trainingPlanId),
            firebaseUid: Value<String>(firebaseUid),
            payloadJson: Value<String>(payloadJson),
            updatedAt: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
  }

  Future<CachedPayloadSnapshot?> loadWorkoutLogs(int trainingPlanId) async {
    final WorkoutLogCache? row =
        await (_database.select(_database.workoutLogCaches)
              ..where((WorkoutLogCaches tbl) => tbl.trainingPlanId.equals(trainingPlanId)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return CachedPayloadSnapshot(
      payloadJson: row.payloadJson,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> saveWorkoutSessionDraft({
    required String firebaseUid,
    required int trainingPlanId,
    required int weekNumber,
    required int dayNumber,
    required String payloadJson,
  }) async {
    await _database
        .into(_database.workoutSessionDrafts)
        .insertOnConflictUpdate(
          WorkoutSessionDraftsCompanion(
            firebaseUid: Value<String>(firebaseUid),
            trainingPlanId: Value<int>(trainingPlanId),
            weekNumber: Value<int>(weekNumber),
            dayNumber: Value<int>(dayNumber),
            payloadJson: Value<String>(payloadJson),
            updatedAt: Value<DateTime>(DateTime.now().toUtc()),
          ),
        );
  }

  Future<CachedPayloadSnapshot?> loadWorkoutSessionDraft({
    required String firebaseUid,
    required int trainingPlanId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    final WorkoutSessionDraft? row =
        await (_database.select(_database.workoutSessionDrafts)
              ..where(
                (WorkoutSessionDrafts tbl) =>
                    tbl.firebaseUid.equals(firebaseUid) &
                    tbl.trainingPlanId.equals(trainingPlanId) &
                    tbl.weekNumber.equals(weekNumber) &
                    tbl.dayNumber.equals(dayNumber),
              ))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return CachedPayloadSnapshot(
      payloadJson: row.payloadJson,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> clearWorkoutSessionDraft({
    required String firebaseUid,
    required int trainingPlanId,
    required int weekNumber,
    required int dayNumber,
  }) async {
    await (_database.delete(_database.workoutSessionDrafts)
          ..where(
            (WorkoutSessionDrafts tbl) =>
                tbl.firebaseUid.equals(firebaseUid) &
                tbl.trainingPlanId.equals(trainingPlanId) &
                tbl.weekNumber.equals(weekNumber) &
                tbl.dayNumber.equals(dayNumber),
          ))
        .go();
  }

  Future<void> enqueueWorkoutLogSync({
    required String firebaseUid,
    required int trainingPlanId,
    required String entityKey,
    required String payloadJson,
    required String localSnapshotJson,
  }) async {
    await (_database.delete(_database.syncJobs)
          ..where(
            (SyncJobs tbl) =>
                tbl.firebaseUid.equals(firebaseUid) &
                tbl.entityType.equals('workout_log') &
                tbl.entityKey.equals(entityKey),
          ))
        .go();

    await _database.into(_database.syncJobs).insert(
          SyncJobsCompanion.insert(
            firebaseUid: firebaseUid,
            entityType: 'workout_log',
            trainingPlanId: Value<int>(trainingPlanId),
            entityKey: entityKey,
            payloadJson: payloadJson,
            localSnapshotJson: Value<String>(localSnapshotJson),
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> clearWorkoutLogSync({
    required String firebaseUid,
    required String entityKey,
  }) async {
    await (_database.delete(_database.syncJobs)
          ..where(
            (SyncJobs tbl) =>
                tbl.firebaseUid.equals(firebaseUid) &
                tbl.entityType.equals('workout_log') &
                tbl.entityKey.equals(entityKey),
          ))
        .go();
  }

  Future<List<String>> loadQueuedWorkoutLogs({
    required String firebaseUid,
    required int trainingPlanId,
  }) async {
    final List<SyncJob> rows =
        await (_database.select(_database.syncJobs)
              ..where(
                (SyncJobs tbl) =>
                    tbl.firebaseUid.equals(firebaseUid) &
                    tbl.entityType.equals('workout_log') &
                    tbl.trainingPlanId.equals(trainingPlanId) &
                    tbl.status.equals('pending'),
              )
              ..orderBy(<OrderingTerm Function(SyncJobs)>[
                (SyncJobs tbl) => OrderingTerm.asc(tbl.createdAt),
              ]))
            .get();

    return rows
        .map((SyncJob row) => row.localSnapshotJson)
        .whereType<String>()
        .toList(growable: false);
  }
}
