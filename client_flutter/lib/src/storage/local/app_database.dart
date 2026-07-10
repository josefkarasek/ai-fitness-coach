import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class UserProfileCaches extends Table {
  TextColumn get firebaseUid => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{firebaseUid};
}

class TrainingPlanCaches extends Table {
  IntColumn get planId => integer()();
  TextColumn get firebaseUid => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{planId};
}

class WorkoutLogCaches extends Table {
  IntColumn get trainingPlanId => integer()();
  TextColumn get firebaseUid => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{trainingPlanId};
}

class WorkoutSessionDrafts extends Table {
  TextColumn get firebaseUid => text()();
  IntColumn get trainingPlanId => integer()();
  IntColumn get weekNumber => integer()();
  IntColumn get dayNumber => integer()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
        firebaseUid,
        trainingPlanId,
        weekNumber,
        dayNumber,
      };
}

class SyncJobs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text()();
  TextColumn get entityType => text()();
  IntColumn get trainingPlanId => integer().nullable()();
  TextColumn get entityKey => text()();
  TextColumn get payloadJson => text()();
  TextColumn get localSnapshotJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(
  tables: <Type>[
    UserProfileCaches,
    TrainingPlanCaches,
    WorkoutLogCaches,
    WorkoutSessionDrafts,
    SyncJobs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.executor(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator migrator) async {
          await migrator.createAll();
        },
        onUpgrade: (Migrator migrator, int from, int to) async {
          if (from < 2) {
            await migrator.createTable(workoutSessionDrafts);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File(p.join(directory.path, 'lifts_forge.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
