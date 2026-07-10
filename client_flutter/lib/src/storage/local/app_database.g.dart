// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserProfileCachesTable extends UserProfileCaches
    with TableInfo<$UserProfileCachesTable, UserProfileCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _firebaseUidMeta =
      const VerificationMeta('firebaseUid');
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
      'firebase_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [firebaseUid, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile_caches';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfileCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('firebase_uid')) {
      context.handle(
          _firebaseUidMeta,
          firebaseUid.isAcceptableOrUnknown(
              data['firebase_uid']!, _firebaseUidMeta));
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {firebaseUid};
  @override
  UserProfileCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileCache(
      firebaseUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firebase_uid'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserProfileCachesTable createAlias(String alias) {
    return $UserProfileCachesTable(attachedDatabase, alias);
  }
}

class UserProfileCache extends DataClass
    implements Insertable<UserProfileCache> {
  final String firebaseUid;
  final String payloadJson;
  final DateTime updatedAt;
  const UserProfileCache(
      {required this.firebaseUid,
      required this.payloadJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['firebase_uid'] = Variable<String>(firebaseUid);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfileCachesCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCachesCompanion(
      firebaseUid: Value(firebaseUid),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfileCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileCache(
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfileCache copyWith(
          {String? firebaseUid, String? payloadJson, DateTime? updatedAt}) =>
      UserProfileCache(
        firebaseUid: firebaseUid ?? this.firebaseUid,
        payloadJson: payloadJson ?? this.payloadJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserProfileCache copyWithCompanion(UserProfileCachesCompanion data) {
    return UserProfileCache(
      firebaseUid:
          data.firebaseUid.present ? data.firebaseUid.value : this.firebaseUid,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCache(')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(firebaseUid, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileCache &&
          other.firebaseUid == this.firebaseUid &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class UserProfileCachesCompanion extends UpdateCompanion<UserProfileCache> {
  final Value<String> firebaseUid;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProfileCachesCompanion({
    this.firebaseUid = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfileCachesCompanion.insert({
    required String firebaseUid,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : firebaseUid = Value(firebaseUid),
        payloadJson = Value(payloadJson),
        updatedAt = Value(updatedAt);
  static Insertable<UserProfileCache> custom({
    Expression<String>? firebaseUid,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfileCachesCompanion copyWith(
      {Value<String>? firebaseUid,
      Value<String>? payloadJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return UserProfileCachesCompanion(
      firebaseUid: firebaseUid ?? this.firebaseUid,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCachesCompanion(')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingPlanCachesTable extends TrainingPlanCaches
    with TableInfo<$TrainingPlanCachesTable, TrainingPlanCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingPlanCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _firebaseUidMeta =
      const VerificationMeta('firebaseUid');
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
      'firebase_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [planId, firebaseUid, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_plan_caches';
  @override
  VerificationContext validateIntegrity(Insertable<TrainingPlanCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
          _firebaseUidMeta,
          firebaseUid.isAcceptableOrUnknown(
              data['firebase_uid']!, _firebaseUidMeta));
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {planId};
  @override
  TrainingPlanCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingPlanCache(
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plan_id'])!,
      firebaseUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firebase_uid'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TrainingPlanCachesTable createAlias(String alias) {
    return $TrainingPlanCachesTable(attachedDatabase, alias);
  }
}

class TrainingPlanCache extends DataClass
    implements Insertable<TrainingPlanCache> {
  final int planId;
  final String firebaseUid;
  final String payloadJson;
  final DateTime updatedAt;
  const TrainingPlanCache(
      {required this.planId,
      required this.firebaseUid,
      required this.payloadJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plan_id'] = Variable<int>(planId);
    map['firebase_uid'] = Variable<String>(firebaseUid);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrainingPlanCachesCompanion toCompanion(bool nullToAbsent) {
    return TrainingPlanCachesCompanion(
      planId: Value(planId),
      firebaseUid: Value(firebaseUid),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrainingPlanCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingPlanCache(
      planId: serializer.fromJson<int>(json['planId']),
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'planId': serializer.toJson<int>(planId),
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrainingPlanCache copyWith(
          {int? planId,
          String? firebaseUid,
          String? payloadJson,
          DateTime? updatedAt}) =>
      TrainingPlanCache(
        planId: planId ?? this.planId,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        payloadJson: payloadJson ?? this.payloadJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  TrainingPlanCache copyWithCompanion(TrainingPlanCachesCompanion data) {
    return TrainingPlanCache(
      planId: data.planId.present ? data.planId.value : this.planId,
      firebaseUid:
          data.firebaseUid.present ? data.firebaseUid.value : this.firebaseUid,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingPlanCache(')
          ..write('planId: $planId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(planId, firebaseUid, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingPlanCache &&
          other.planId == this.planId &&
          other.firebaseUid == this.firebaseUid &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class TrainingPlanCachesCompanion extends UpdateCompanion<TrainingPlanCache> {
  final Value<int> planId;
  final Value<String> firebaseUid;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  const TrainingPlanCachesCompanion({
    this.planId = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TrainingPlanCachesCompanion.insert({
    this.planId = const Value.absent(),
    required String firebaseUid,
    required String payloadJson,
    required DateTime updatedAt,
  })  : firebaseUid = Value(firebaseUid),
        payloadJson = Value(payloadJson),
        updatedAt = Value(updatedAt);
  static Insertable<TrainingPlanCache> custom({
    Expression<int>? planId,
    Expression<String>? firebaseUid,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (planId != null) 'plan_id': planId,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TrainingPlanCachesCompanion copyWith(
      {Value<int>? planId,
      Value<String>? firebaseUid,
      Value<String>? payloadJson,
      Value<DateTime>? updatedAt}) {
    return TrainingPlanCachesCompanion(
      planId: planId ?? this.planId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingPlanCachesCompanion(')
          ..write('planId: $planId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WorkoutLogCachesTable extends WorkoutLogCaches
    with TableInfo<$WorkoutLogCachesTable, WorkoutLogCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutLogCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trainingPlanIdMeta =
      const VerificationMeta('trainingPlanId');
  @override
  late final GeneratedColumn<int> trainingPlanId = GeneratedColumn<int>(
      'training_plan_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _firebaseUidMeta =
      const VerificationMeta('firebaseUid');
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
      'firebase_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [trainingPlanId, firebaseUid, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_log_caches';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutLogCache> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('training_plan_id')) {
      context.handle(
          _trainingPlanIdMeta,
          trainingPlanId.isAcceptableOrUnknown(
              data['training_plan_id']!, _trainingPlanIdMeta));
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
          _firebaseUidMeta,
          firebaseUid.isAcceptableOrUnknown(
              data['firebase_uid']!, _firebaseUidMeta));
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trainingPlanId};
  @override
  WorkoutLogCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutLogCache(
      trainingPlanId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}training_plan_id'])!,
      firebaseUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firebase_uid'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WorkoutLogCachesTable createAlias(String alias) {
    return $WorkoutLogCachesTable(attachedDatabase, alias);
  }
}

class WorkoutLogCache extends DataClass implements Insertable<WorkoutLogCache> {
  final int trainingPlanId;
  final String firebaseUid;
  final String payloadJson;
  final DateTime updatedAt;
  const WorkoutLogCache(
      {required this.trainingPlanId,
      required this.firebaseUid,
      required this.payloadJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['training_plan_id'] = Variable<int>(trainingPlanId);
    map['firebase_uid'] = Variable<String>(firebaseUid);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkoutLogCachesCompanion toCompanion(bool nullToAbsent) {
    return WorkoutLogCachesCompanion(
      trainingPlanId: Value(trainingPlanId),
      firebaseUid: Value(firebaseUid),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkoutLogCache.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutLogCache(
      trainingPlanId: serializer.fromJson<int>(json['trainingPlanId']),
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trainingPlanId': serializer.toJson<int>(trainingPlanId),
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkoutLogCache copyWith(
          {int? trainingPlanId,
          String? firebaseUid,
          String? payloadJson,
          DateTime? updatedAt}) =>
      WorkoutLogCache(
        trainingPlanId: trainingPlanId ?? this.trainingPlanId,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        payloadJson: payloadJson ?? this.payloadJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WorkoutLogCache copyWithCompanion(WorkoutLogCachesCompanion data) {
    return WorkoutLogCache(
      trainingPlanId: data.trainingPlanId.present
          ? data.trainingPlanId.value
          : this.trainingPlanId,
      firebaseUid:
          data.firebaseUid.present ? data.firebaseUid.value : this.firebaseUid,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutLogCache(')
          ..write('trainingPlanId: $trainingPlanId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(trainingPlanId, firebaseUid, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutLogCache &&
          other.trainingPlanId == this.trainingPlanId &&
          other.firebaseUid == this.firebaseUid &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class WorkoutLogCachesCompanion extends UpdateCompanion<WorkoutLogCache> {
  final Value<int> trainingPlanId;
  final Value<String> firebaseUid;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  const WorkoutLogCachesCompanion({
    this.trainingPlanId = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  WorkoutLogCachesCompanion.insert({
    this.trainingPlanId = const Value.absent(),
    required String firebaseUid,
    required String payloadJson,
    required DateTime updatedAt,
  })  : firebaseUid = Value(firebaseUid),
        payloadJson = Value(payloadJson),
        updatedAt = Value(updatedAt);
  static Insertable<WorkoutLogCache> custom({
    Expression<int>? trainingPlanId,
    Expression<String>? firebaseUid,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (trainingPlanId != null) 'training_plan_id': trainingPlanId,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  WorkoutLogCachesCompanion copyWith(
      {Value<int>? trainingPlanId,
      Value<String>? firebaseUid,
      Value<String>? payloadJson,
      Value<DateTime>? updatedAt}) {
    return WorkoutLogCachesCompanion(
      trainingPlanId: trainingPlanId ?? this.trainingPlanId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trainingPlanId.present) {
      map['training_plan_id'] = Variable<int>(trainingPlanId.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutLogCachesCompanion(')
          ..write('trainingPlanId: $trainingPlanId, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionDraftsTable extends WorkoutSessionDrafts
    with TableInfo<$WorkoutSessionDraftsTable, WorkoutSessionDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _firebaseUidMeta =
      const VerificationMeta('firebaseUid');
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
      'firebase_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trainingPlanIdMeta =
      const VerificationMeta('trainingPlanId');
  @override
  late final GeneratedColumn<int> trainingPlanId = GeneratedColumn<int>(
      'training_plan_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _weekNumberMeta =
      const VerificationMeta('weekNumber');
  @override
  late final GeneratedColumn<int> weekNumber = GeneratedColumn<int>(
      'week_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dayNumberMeta =
      const VerificationMeta('dayNumber');
  @override
  late final GeneratedColumn<int> dayNumber = GeneratedColumn<int>(
      'day_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        firebaseUid,
        trainingPlanId,
        weekNumber,
        dayNumber,
        payloadJson,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_session_drafts';
  @override
  VerificationContext validateIntegrity(
      Insertable<WorkoutSessionDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('firebase_uid')) {
      context.handle(
          _firebaseUidMeta,
          firebaseUid.isAcceptableOrUnknown(
              data['firebase_uid']!, _firebaseUidMeta));
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('training_plan_id')) {
      context.handle(
          _trainingPlanIdMeta,
          trainingPlanId.isAcceptableOrUnknown(
              data['training_plan_id']!, _trainingPlanIdMeta));
    } else if (isInserting) {
      context.missing(_trainingPlanIdMeta);
    }
    if (data.containsKey('week_number')) {
      context.handle(
          _weekNumberMeta,
          weekNumber.isAcceptableOrUnknown(
              data['week_number']!, _weekNumberMeta));
    } else if (isInserting) {
      context.missing(_weekNumberMeta);
    }
    if (data.containsKey('day_number')) {
      context.handle(_dayNumberMeta,
          dayNumber.isAcceptableOrUnknown(data['day_number']!, _dayNumberMeta));
    } else if (isInserting) {
      context.missing(_dayNumberMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey =>
      {firebaseUid, trainingPlanId, weekNumber, dayNumber};
  @override
  WorkoutSessionDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSessionDraft(
      firebaseUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firebase_uid'])!,
      trainingPlanId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}training_plan_id'])!,
      weekNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}week_number'])!,
      dayNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_number'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $WorkoutSessionDraftsTable createAlias(String alias) {
    return $WorkoutSessionDraftsTable(attachedDatabase, alias);
  }
}

class WorkoutSessionDraft extends DataClass
    implements Insertable<WorkoutSessionDraft> {
  final String firebaseUid;
  final int trainingPlanId;
  final int weekNumber;
  final int dayNumber;
  final String payloadJson;
  final DateTime updatedAt;
  const WorkoutSessionDraft(
      {required this.firebaseUid,
      required this.trainingPlanId,
      required this.weekNumber,
      required this.dayNumber,
      required this.payloadJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['firebase_uid'] = Variable<String>(firebaseUid);
    map['training_plan_id'] = Variable<int>(trainingPlanId);
    map['week_number'] = Variable<int>(weekNumber);
    map['day_number'] = Variable<int>(dayNumber);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkoutSessionDraftsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionDraftsCompanion(
      firebaseUid: Value(firebaseUid),
      trainingPlanId: Value(trainingPlanId),
      weekNumber: Value(weekNumber),
      dayNumber: Value(dayNumber),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkoutSessionDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSessionDraft(
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      trainingPlanId: serializer.fromJson<int>(json['trainingPlanId']),
      weekNumber: serializer.fromJson<int>(json['weekNumber']),
      dayNumber: serializer.fromJson<int>(json['dayNumber']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'trainingPlanId': serializer.toJson<int>(trainingPlanId),
      'weekNumber': serializer.toJson<int>(weekNumber),
      'dayNumber': serializer.toJson<int>(dayNumber),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkoutSessionDraft copyWith(
          {String? firebaseUid,
          int? trainingPlanId,
          int? weekNumber,
          int? dayNumber,
          String? payloadJson,
          DateTime? updatedAt}) =>
      WorkoutSessionDraft(
        firebaseUid: firebaseUid ?? this.firebaseUid,
        trainingPlanId: trainingPlanId ?? this.trainingPlanId,
        weekNumber: weekNumber ?? this.weekNumber,
        dayNumber: dayNumber ?? this.dayNumber,
        payloadJson: payloadJson ?? this.payloadJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  WorkoutSessionDraft copyWithCompanion(WorkoutSessionDraftsCompanion data) {
    return WorkoutSessionDraft(
      firebaseUid:
          data.firebaseUid.present ? data.firebaseUid.value : this.firebaseUid,
      trainingPlanId: data.trainingPlanId.present
          ? data.trainingPlanId.value
          : this.trainingPlanId,
      weekNumber:
          data.weekNumber.present ? data.weekNumber.value : this.weekNumber,
      dayNumber: data.dayNumber.present ? data.dayNumber.value : this.dayNumber,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionDraft(')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('trainingPlanId: $trainingPlanId, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(firebaseUid, trainingPlanId, weekNumber,
      dayNumber, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSessionDraft &&
          other.firebaseUid == this.firebaseUid &&
          other.trainingPlanId == this.trainingPlanId &&
          other.weekNumber == this.weekNumber &&
          other.dayNumber == this.dayNumber &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class WorkoutSessionDraftsCompanion
    extends UpdateCompanion<WorkoutSessionDraft> {
  final Value<String> firebaseUid;
  final Value<int> trainingPlanId;
  final Value<int> weekNumber;
  final Value<int> dayNumber;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkoutSessionDraftsCompanion({
    this.firebaseUid = const Value.absent(),
    this.trainingPlanId = const Value.absent(),
    this.weekNumber = const Value.absent(),
    this.dayNumber = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSessionDraftsCompanion.insert({
    required String firebaseUid,
    required int trainingPlanId,
    required int weekNumber,
    required int dayNumber,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : firebaseUid = Value(firebaseUid),
        trainingPlanId = Value(trainingPlanId),
        weekNumber = Value(weekNumber),
        dayNumber = Value(dayNumber),
        payloadJson = Value(payloadJson),
        updatedAt = Value(updatedAt);
  static Insertable<WorkoutSessionDraft> custom({
    Expression<String>? firebaseUid,
    Expression<int>? trainingPlanId,
    Expression<int>? weekNumber,
    Expression<int>? dayNumber,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (trainingPlanId != null) 'training_plan_id': trainingPlanId,
      if (weekNumber != null) 'week_number': weekNumber,
      if (dayNumber != null) 'day_number': dayNumber,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSessionDraftsCompanion copyWith(
      {Value<String>? firebaseUid,
      Value<int>? trainingPlanId,
      Value<int>? weekNumber,
      Value<int>? dayNumber,
      Value<String>? payloadJson,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return WorkoutSessionDraftsCompanion(
      firebaseUid: firebaseUid ?? this.firebaseUid,
      trainingPlanId: trainingPlanId ?? this.trainingPlanId,
      weekNumber: weekNumber ?? this.weekNumber,
      dayNumber: dayNumber ?? this.dayNumber,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (trainingPlanId.present) {
      map['training_plan_id'] = Variable<int>(trainingPlanId.value);
    }
    if (weekNumber.present) {
      map['week_number'] = Variable<int>(weekNumber.value);
    }
    if (dayNumber.present) {
      map['day_number'] = Variable<int>(dayNumber.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionDraftsCompanion(')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('trainingPlanId: $trainingPlanId, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('dayNumber: $dayNumber, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncJobsTable extends SyncJobs with TableInfo<$SyncJobsTable, SyncJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _firebaseUidMeta =
      const VerificationMeta('firebaseUid');
  @override
  late final GeneratedColumn<String> firebaseUid = GeneratedColumn<String>(
      'firebase_uid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _trainingPlanIdMeta =
      const VerificationMeta('trainingPlanId');
  @override
  late final GeneratedColumn<int> trainingPlanId = GeneratedColumn<int>(
      'training_plan_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _entityKeyMeta =
      const VerificationMeta('entityKey');
  @override
  late final GeneratedColumn<String> entityKey = GeneratedColumn<String>(
      'entity_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localSnapshotJsonMeta =
      const VerificationMeta('localSnapshotJson');
  @override
  late final GeneratedColumn<String> localSnapshotJson =
      GeneratedColumn<String>('local_snapshot_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        firebaseUid,
        entityType,
        trainingPlanId,
        entityKey,
        payloadJson,
        localSnapshotJson,
        status,
        attempts,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_jobs';
  @override
  VerificationContext validateIntegrity(Insertable<SyncJob> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('firebase_uid')) {
      context.handle(
          _firebaseUidMeta,
          firebaseUid.isAcceptableOrUnknown(
              data['firebase_uid']!, _firebaseUidMeta));
    } else if (isInserting) {
      context.missing(_firebaseUidMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('training_plan_id')) {
      context.handle(
          _trainingPlanIdMeta,
          trainingPlanId.isAcceptableOrUnknown(
              data['training_plan_id']!, _trainingPlanIdMeta));
    }
    if (data.containsKey('entity_key')) {
      context.handle(_entityKeyMeta,
          entityKey.isAcceptableOrUnknown(data['entity_key']!, _entityKeyMeta));
    } else if (isInserting) {
      context.missing(_entityKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('local_snapshot_json')) {
      context.handle(
          _localSnapshotJsonMeta,
          localSnapshotJson.isAcceptableOrUnknown(
              data['local_snapshot_json']!, _localSnapshotJsonMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncJob(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      firebaseUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}firebase_uid'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      trainingPlanId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}training_plan_id']),
      entityKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_key'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      localSnapshotJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_snapshot_json']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SyncJobsTable createAlias(String alias) {
    return $SyncJobsTable(attachedDatabase, alias);
  }
}

class SyncJob extends DataClass implements Insertable<SyncJob> {
  final int id;
  final String firebaseUid;
  final String entityType;
  final int? trainingPlanId;
  final String entityKey;
  final String payloadJson;
  final String? localSnapshotJson;
  final String status;
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncJob(
      {required this.id,
      required this.firebaseUid,
      required this.entityType,
      this.trainingPlanId,
      required this.entityKey,
      required this.payloadJson,
      this.localSnapshotJson,
      required this.status,
      required this.attempts,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['firebase_uid'] = Variable<String>(firebaseUid);
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || trainingPlanId != null) {
      map['training_plan_id'] = Variable<int>(trainingPlanId);
    }
    map['entity_key'] = Variable<String>(entityKey);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || localSnapshotJson != null) {
      map['local_snapshot_json'] = Variable<String>(localSnapshotJson);
    }
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncJobsCompanion toCompanion(bool nullToAbsent) {
    return SyncJobsCompanion(
      id: Value(id),
      firebaseUid: Value(firebaseUid),
      entityType: Value(entityType),
      trainingPlanId: trainingPlanId == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingPlanId),
      entityKey: Value(entityKey),
      payloadJson: Value(payloadJson),
      localSnapshotJson: localSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(localSnapshotJson),
      status: Value(status),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncJob.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncJob(
      id: serializer.fromJson<int>(json['id']),
      firebaseUid: serializer.fromJson<String>(json['firebaseUid']),
      entityType: serializer.fromJson<String>(json['entityType']),
      trainingPlanId: serializer.fromJson<int?>(json['trainingPlanId']),
      entityKey: serializer.fromJson<String>(json['entityKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      localSnapshotJson:
          serializer.fromJson<String?>(json['localSnapshotJson']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'firebaseUid': serializer.toJson<String>(firebaseUid),
      'entityType': serializer.toJson<String>(entityType),
      'trainingPlanId': serializer.toJson<int?>(trainingPlanId),
      'entityKey': serializer.toJson<String>(entityKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'localSnapshotJson': serializer.toJson<String?>(localSnapshotJson),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncJob copyWith(
          {int? id,
          String? firebaseUid,
          String? entityType,
          Value<int?> trainingPlanId = const Value.absent(),
          String? entityKey,
          String? payloadJson,
          Value<String?> localSnapshotJson = const Value.absent(),
          String? status,
          int? attempts,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      SyncJob(
        id: id ?? this.id,
        firebaseUid: firebaseUid ?? this.firebaseUid,
        entityType: entityType ?? this.entityType,
        trainingPlanId:
            trainingPlanId.present ? trainingPlanId.value : this.trainingPlanId,
        entityKey: entityKey ?? this.entityKey,
        payloadJson: payloadJson ?? this.payloadJson,
        localSnapshotJson: localSnapshotJson.present
            ? localSnapshotJson.value
            : this.localSnapshotJson,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SyncJob copyWithCompanion(SyncJobsCompanion data) {
    return SyncJob(
      id: data.id.present ? data.id.value : this.id,
      firebaseUid:
          data.firebaseUid.present ? data.firebaseUid.value : this.firebaseUid,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      trainingPlanId: data.trainingPlanId.present
          ? data.trainingPlanId.value
          : this.trainingPlanId,
      entityKey: data.entityKey.present ? data.entityKey.value : this.entityKey,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      localSnapshotJson: data.localSnapshotJson.present
          ? data.localSnapshotJson.value
          : this.localSnapshotJson,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncJob(')
          ..write('id: $id, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('entityType: $entityType, ')
          ..write('trainingPlanId: $trainingPlanId, ')
          ..write('entityKey: $entityKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('localSnapshotJson: $localSnapshotJson, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      firebaseUid,
      entityType,
      trainingPlanId,
      entityKey,
      payloadJson,
      localSnapshotJson,
      status,
      attempts,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncJob &&
          other.id == this.id &&
          other.firebaseUid == this.firebaseUid &&
          other.entityType == this.entityType &&
          other.trainingPlanId == this.trainingPlanId &&
          other.entityKey == this.entityKey &&
          other.payloadJson == this.payloadJson &&
          other.localSnapshotJson == this.localSnapshotJson &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncJobsCompanion extends UpdateCompanion<SyncJob> {
  final Value<int> id;
  final Value<String> firebaseUid;
  final Value<String> entityType;
  final Value<int?> trainingPlanId;
  final Value<String> entityKey;
  final Value<String> payloadJson;
  final Value<String?> localSnapshotJson;
  final Value<String> status;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SyncJobsCompanion({
    this.id = const Value.absent(),
    this.firebaseUid = const Value.absent(),
    this.entityType = const Value.absent(),
    this.trainingPlanId = const Value.absent(),
    this.entityKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.localSnapshotJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SyncJobsCompanion.insert({
    this.id = const Value.absent(),
    required String firebaseUid,
    required String entityType,
    this.trainingPlanId = const Value.absent(),
    required String entityKey,
    required String payloadJson,
    this.localSnapshotJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : firebaseUid = Value(firebaseUid),
        entityType = Value(entityType),
        entityKey = Value(entityKey),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SyncJob> custom({
    Expression<int>? id,
    Expression<String>? firebaseUid,
    Expression<String>? entityType,
    Expression<int>? trainingPlanId,
    Expression<String>? entityKey,
    Expression<String>? payloadJson,
    Expression<String>? localSnapshotJson,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firebaseUid != null) 'firebase_uid': firebaseUid,
      if (entityType != null) 'entity_type': entityType,
      if (trainingPlanId != null) 'training_plan_id': trainingPlanId,
      if (entityKey != null) 'entity_key': entityKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (localSnapshotJson != null) 'local_snapshot_json': localSnapshotJson,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SyncJobsCompanion copyWith(
      {Value<int>? id,
      Value<String>? firebaseUid,
      Value<String>? entityType,
      Value<int?>? trainingPlanId,
      Value<String>? entityKey,
      Value<String>? payloadJson,
      Value<String?>? localSnapshotJson,
      Value<String>? status,
      Value<int>? attempts,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt}) {
    return SyncJobsCompanion(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      entityType: entityType ?? this.entityType,
      trainingPlanId: trainingPlanId ?? this.trainingPlanId,
      entityKey: entityKey ?? this.entityKey,
      payloadJson: payloadJson ?? this.payloadJson,
      localSnapshotJson: localSnapshotJson ?? this.localSnapshotJson,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (firebaseUid.present) {
      map['firebase_uid'] = Variable<String>(firebaseUid.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (trainingPlanId.present) {
      map['training_plan_id'] = Variable<int>(trainingPlanId.value);
    }
    if (entityKey.present) {
      map['entity_key'] = Variable<String>(entityKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (localSnapshotJson.present) {
      map['local_snapshot_json'] = Variable<String>(localSnapshotJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncJobsCompanion(')
          ..write('id: $id, ')
          ..write('firebaseUid: $firebaseUid, ')
          ..write('entityType: $entityType, ')
          ..write('trainingPlanId: $trainingPlanId, ')
          ..write('entityKey: $entityKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('localSnapshotJson: $localSnapshotJson, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfileCachesTable userProfileCaches =
      $UserProfileCachesTable(this);
  late final $TrainingPlanCachesTable trainingPlanCaches =
      $TrainingPlanCachesTable(this);
  late final $WorkoutLogCachesTable workoutLogCaches =
      $WorkoutLogCachesTable(this);
  late final $WorkoutSessionDraftsTable workoutSessionDrafts =
      $WorkoutSessionDraftsTable(this);
  late final $SyncJobsTable syncJobs = $SyncJobsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        userProfileCaches,
        trainingPlanCaches,
        workoutLogCaches,
        workoutSessionDrafts,
        syncJobs
      ];
}

typedef $$UserProfileCachesTableCreateCompanionBuilder
    = UserProfileCachesCompanion Function({
  required String firebaseUid,
  required String payloadJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$UserProfileCachesTableUpdateCompanionBuilder
    = UserProfileCachesCompanion Function({
  Value<String> firebaseUid,
  Value<String> payloadJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$UserProfileCachesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileCachesTable> {
  $$UserProfileCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$UserProfileCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileCachesTable> {
  $$UserProfileCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserProfileCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileCachesTable> {
  $$UserProfileCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfileCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfileCachesTable,
    UserProfileCache,
    $$UserProfileCachesTableFilterComposer,
    $$UserProfileCachesTableOrderingComposer,
    $$UserProfileCachesTableAnnotationComposer,
    $$UserProfileCachesTableCreateCompanionBuilder,
    $$UserProfileCachesTableUpdateCompanionBuilder,
    (
      UserProfileCache,
      BaseReferences<_$AppDatabase, $UserProfileCachesTable, UserProfileCache>
    ),
    UserProfileCache,
    PrefetchHooks Function()> {
  $$UserProfileCachesTableTableManager(
      _$AppDatabase db, $UserProfileCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> firebaseUid = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfileCachesCompanion(
            firebaseUid: firebaseUid,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String firebaseUid,
            required String payloadJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfileCachesCompanion.insert(
            firebaseUid: firebaseUid,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserProfileCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserProfileCachesTable,
    UserProfileCache,
    $$UserProfileCachesTableFilterComposer,
    $$UserProfileCachesTableOrderingComposer,
    $$UserProfileCachesTableAnnotationComposer,
    $$UserProfileCachesTableCreateCompanionBuilder,
    $$UserProfileCachesTableUpdateCompanionBuilder,
    (
      UserProfileCache,
      BaseReferences<_$AppDatabase, $UserProfileCachesTable, UserProfileCache>
    ),
    UserProfileCache,
    PrefetchHooks Function()>;
typedef $$TrainingPlanCachesTableCreateCompanionBuilder
    = TrainingPlanCachesCompanion Function({
  Value<int> planId,
  required String firebaseUid,
  required String payloadJson,
  required DateTime updatedAt,
});
typedef $$TrainingPlanCachesTableUpdateCompanionBuilder
    = TrainingPlanCachesCompanion Function({
  Value<int> planId,
  Value<String> firebaseUid,
  Value<String> payloadJson,
  Value<DateTime> updatedAt,
});

class $$TrainingPlanCachesTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingPlanCachesTable> {
  $$TrainingPlanCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TrainingPlanCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingPlanCachesTable> {
  $$TrainingPlanCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TrainingPlanCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingPlanCachesTable> {
  $$TrainingPlanCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TrainingPlanCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrainingPlanCachesTable,
    TrainingPlanCache,
    $$TrainingPlanCachesTableFilterComposer,
    $$TrainingPlanCachesTableOrderingComposer,
    $$TrainingPlanCachesTableAnnotationComposer,
    $$TrainingPlanCachesTableCreateCompanionBuilder,
    $$TrainingPlanCachesTableUpdateCompanionBuilder,
    (
      TrainingPlanCache,
      BaseReferences<_$AppDatabase, $TrainingPlanCachesTable, TrainingPlanCache>
    ),
    TrainingPlanCache,
    PrefetchHooks Function()> {
  $$TrainingPlanCachesTableTableManager(
      _$AppDatabase db, $TrainingPlanCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingPlanCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingPlanCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingPlanCachesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> planId = const Value.absent(),
            Value<String> firebaseUid = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              TrainingPlanCachesCompanion(
            planId: planId,
            firebaseUid: firebaseUid,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> planId = const Value.absent(),
            required String firebaseUid,
            required String payloadJson,
            required DateTime updatedAt,
          }) =>
              TrainingPlanCachesCompanion.insert(
            planId: planId,
            firebaseUid: firebaseUid,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrainingPlanCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TrainingPlanCachesTable,
    TrainingPlanCache,
    $$TrainingPlanCachesTableFilterComposer,
    $$TrainingPlanCachesTableOrderingComposer,
    $$TrainingPlanCachesTableAnnotationComposer,
    $$TrainingPlanCachesTableCreateCompanionBuilder,
    $$TrainingPlanCachesTableUpdateCompanionBuilder,
    (
      TrainingPlanCache,
      BaseReferences<_$AppDatabase, $TrainingPlanCachesTable, TrainingPlanCache>
    ),
    TrainingPlanCache,
    PrefetchHooks Function()>;
typedef $$WorkoutLogCachesTableCreateCompanionBuilder
    = WorkoutLogCachesCompanion Function({
  Value<int> trainingPlanId,
  required String firebaseUid,
  required String payloadJson,
  required DateTime updatedAt,
});
typedef $$WorkoutLogCachesTableUpdateCompanionBuilder
    = WorkoutLogCachesCompanion Function({
  Value<int> trainingPlanId,
  Value<String> firebaseUid,
  Value<String> payloadJson,
  Value<DateTime> updatedAt,
});

class $$WorkoutLogCachesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutLogCachesTable> {
  $$WorkoutLogCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$WorkoutLogCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutLogCachesTable> {
  $$WorkoutLogCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutLogCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutLogCachesTable> {
  $$WorkoutLogCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkoutLogCachesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutLogCachesTable,
    WorkoutLogCache,
    $$WorkoutLogCachesTableFilterComposer,
    $$WorkoutLogCachesTableOrderingComposer,
    $$WorkoutLogCachesTableAnnotationComposer,
    $$WorkoutLogCachesTableCreateCompanionBuilder,
    $$WorkoutLogCachesTableUpdateCompanionBuilder,
    (
      WorkoutLogCache,
      BaseReferences<_$AppDatabase, $WorkoutLogCachesTable, WorkoutLogCache>
    ),
    WorkoutLogCache,
    PrefetchHooks Function()> {
  $$WorkoutLogCachesTableTableManager(
      _$AppDatabase db, $WorkoutLogCachesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutLogCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutLogCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutLogCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> trainingPlanId = const Value.absent(),
            Value<String> firebaseUid = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              WorkoutLogCachesCompanion(
            trainingPlanId: trainingPlanId,
            firebaseUid: firebaseUid,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> trainingPlanId = const Value.absent(),
            required String firebaseUid,
            required String payloadJson,
            required DateTime updatedAt,
          }) =>
              WorkoutLogCachesCompanion.insert(
            trainingPlanId: trainingPlanId,
            firebaseUid: firebaseUid,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkoutLogCachesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkoutLogCachesTable,
    WorkoutLogCache,
    $$WorkoutLogCachesTableFilterComposer,
    $$WorkoutLogCachesTableOrderingComposer,
    $$WorkoutLogCachesTableAnnotationComposer,
    $$WorkoutLogCachesTableCreateCompanionBuilder,
    $$WorkoutLogCachesTableUpdateCompanionBuilder,
    (
      WorkoutLogCache,
      BaseReferences<_$AppDatabase, $WorkoutLogCachesTable, WorkoutLogCache>
    ),
    WorkoutLogCache,
    PrefetchHooks Function()>;
typedef $$WorkoutSessionDraftsTableCreateCompanionBuilder
    = WorkoutSessionDraftsCompanion Function({
  required String firebaseUid,
  required int trainingPlanId,
  required int weekNumber,
  required int dayNumber,
  required String payloadJson,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$WorkoutSessionDraftsTableUpdateCompanionBuilder
    = WorkoutSessionDraftsCompanion Function({
  Value<String> firebaseUid,
  Value<int> trainingPlanId,
  Value<int> weekNumber,
  Value<int> dayNumber,
  Value<String> payloadJson,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$WorkoutSessionDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionDraftsTable> {
  $$WorkoutSessionDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get weekNumber => $composableBuilder(
      column: $table.weekNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayNumber => $composableBuilder(
      column: $table.dayNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$WorkoutSessionDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionDraftsTable> {
  $$WorkoutSessionDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get weekNumber => $composableBuilder(
      column: $table.weekNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayNumber => $composableBuilder(
      column: $table.dayNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutSessionDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionDraftsTable> {
  $$WorkoutSessionDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => column);

  GeneratedColumn<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId, builder: (column) => column);

  GeneratedColumn<int> get weekNumber => $composableBuilder(
      column: $table.weekNumber, builder: (column) => column);

  GeneratedColumn<int> get dayNumber =>
      $composableBuilder(column: $table.dayNumber, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WorkoutSessionDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutSessionDraftsTable,
    WorkoutSessionDraft,
    $$WorkoutSessionDraftsTableFilterComposer,
    $$WorkoutSessionDraftsTableOrderingComposer,
    $$WorkoutSessionDraftsTableAnnotationComposer,
    $$WorkoutSessionDraftsTableCreateCompanionBuilder,
    $$WorkoutSessionDraftsTableUpdateCompanionBuilder,
    (
      WorkoutSessionDraft,
      BaseReferences<_$AppDatabase, $WorkoutSessionDraftsTable,
          WorkoutSessionDraft>
    ),
    WorkoutSessionDraft,
    PrefetchHooks Function()> {
  $$WorkoutSessionDraftsTableTableManager(
      _$AppDatabase db, $WorkoutSessionDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionDraftsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionDraftsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> firebaseUid = const Value.absent(),
            Value<int> trainingPlanId = const Value.absent(),
            Value<int> weekNumber = const Value.absent(),
            Value<int> dayNumber = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutSessionDraftsCompanion(
            firebaseUid: firebaseUid,
            trainingPlanId: trainingPlanId,
            weekNumber: weekNumber,
            dayNumber: dayNumber,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String firebaseUid,
            required int trainingPlanId,
            required int weekNumber,
            required int dayNumber,
            required String payloadJson,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutSessionDraftsCompanion.insert(
            firebaseUid: firebaseUid,
            trainingPlanId: trainingPlanId,
            weekNumber: weekNumber,
            dayNumber: dayNumber,
            payloadJson: payloadJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkoutSessionDraftsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $WorkoutSessionDraftsTable,
        WorkoutSessionDraft,
        $$WorkoutSessionDraftsTableFilterComposer,
        $$WorkoutSessionDraftsTableOrderingComposer,
        $$WorkoutSessionDraftsTableAnnotationComposer,
        $$WorkoutSessionDraftsTableCreateCompanionBuilder,
        $$WorkoutSessionDraftsTableUpdateCompanionBuilder,
        (
          WorkoutSessionDraft,
          BaseReferences<_$AppDatabase, $WorkoutSessionDraftsTable,
              WorkoutSessionDraft>
        ),
        WorkoutSessionDraft,
        PrefetchHooks Function()>;
typedef $$SyncJobsTableCreateCompanionBuilder = SyncJobsCompanion Function({
  Value<int> id,
  required String firebaseUid,
  required String entityType,
  Value<int?> trainingPlanId,
  required String entityKey,
  required String payloadJson,
  Value<String?> localSnapshotJson,
  Value<String> status,
  Value<int> attempts,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$SyncJobsTableUpdateCompanionBuilder = SyncJobsCompanion Function({
  Value<int> id,
  Value<String> firebaseUid,
  Value<String> entityType,
  Value<int?> trainingPlanId,
  Value<String> entityKey,
  Value<String> payloadJson,
  Value<String?> localSnapshotJson,
  Value<String> status,
  Value<int> attempts,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$SyncJobsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncJobsTable> {
  $$SyncJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityKey => $composableBuilder(
      column: $table.entityKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localSnapshotJson => $composableBuilder(
      column: $table.localSnapshotJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncJobsTable> {
  $$SyncJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityKey => $composableBuilder(
      column: $table.entityKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localSnapshotJson => $composableBuilder(
      column: $table.localSnapshotJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncJobsTable> {
  $$SyncJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firebaseUid => $composableBuilder(
      column: $table.firebaseUid, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<int> get trainingPlanId => $composableBuilder(
      column: $table.trainingPlanId, builder: (column) => column);

  GeneratedColumn<String> get entityKey =>
      $composableBuilder(column: $table.entityKey, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get localSnapshotJson => $composableBuilder(
      column: $table.localSnapshotJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncJobsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncJobsTable,
    SyncJob,
    $$SyncJobsTableFilterComposer,
    $$SyncJobsTableOrderingComposer,
    $$SyncJobsTableAnnotationComposer,
    $$SyncJobsTableCreateCompanionBuilder,
    $$SyncJobsTableUpdateCompanionBuilder,
    (SyncJob, BaseReferences<_$AppDatabase, $SyncJobsTable, SyncJob>),
    SyncJob,
    PrefetchHooks Function()> {
  $$SyncJobsTableTableManager(_$AppDatabase db, $SyncJobsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> firebaseUid = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<int?> trainingPlanId = const Value.absent(),
            Value<String> entityKey = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String?> localSnapshotJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              SyncJobsCompanion(
            id: id,
            firebaseUid: firebaseUid,
            entityType: entityType,
            trainingPlanId: trainingPlanId,
            entityKey: entityKey,
            payloadJson: payloadJson,
            localSnapshotJson: localSnapshotJson,
            status: status,
            attempts: attempts,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String firebaseUid,
            required String entityType,
            Value<int?> trainingPlanId = const Value.absent(),
            required String entityKey,
            required String payloadJson,
            Value<String?> localSnapshotJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
          }) =>
              SyncJobsCompanion.insert(
            id: id,
            firebaseUid: firebaseUid,
            entityType: entityType,
            trainingPlanId: trainingPlanId,
            entityKey: entityKey,
            payloadJson: payloadJson,
            localSnapshotJson: localSnapshotJson,
            status: status,
            attempts: attempts,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncJobsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncJobsTable,
    SyncJob,
    $$SyncJobsTableFilterComposer,
    $$SyncJobsTableOrderingComposer,
    $$SyncJobsTableAnnotationComposer,
    $$SyncJobsTableCreateCompanionBuilder,
    $$SyncJobsTableUpdateCompanionBuilder,
    (SyncJob, BaseReferences<_$AppDatabase, $SyncJobsTable, SyncJob>),
    SyncJob,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfileCachesTableTableManager get userProfileCaches =>
      $$UserProfileCachesTableTableManager(_db, _db.userProfileCaches);
  $$TrainingPlanCachesTableTableManager get trainingPlanCaches =>
      $$TrainingPlanCachesTableTableManager(_db, _db.trainingPlanCaches);
  $$WorkoutLogCachesTableTableManager get workoutLogCaches =>
      $$WorkoutLogCachesTableTableManager(_db, _db.workoutLogCaches);
  $$WorkoutSessionDraftsTableTableManager get workoutSessionDrafts =>
      $$WorkoutSessionDraftsTableTableManager(_db, _db.workoutSessionDrafts);
  $$SyncJobsTableTableManager get syncJobs =>
      $$SyncJobsTableTableManager(_db, _db.syncJobs);
}
