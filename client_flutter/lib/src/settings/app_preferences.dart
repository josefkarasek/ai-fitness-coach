import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._prefs);

  static const String measurementSystemKey = 'measurement_system';
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String lastSignedInUidKey = 'last_signed_in_uid';
  static const String remotePlanSignalJobIDKey = 'remote_plan_signal_job_id';
  static const String remotePlanSignalStatusKey = 'remote_plan_signal_status';

  static const String _measurementSystemKey = 'measurement_system';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _lastSignedInUidKey = 'last_signed_in_uid';
  static const String _activePlanWeekNumberPrefix = 'active_plan_week_number';
  static const String _activePlanWeekAnchorPrefix = 'active_plan_week_anchor';
  static const String _weeklyPreviewCachePrefix = 'weekly_preview_cache';
  static const String _weeklyPreviewAnchorPrefix = 'weekly_preview_anchor';
  static const String _pendingTrainingPlanJobPrefix =
      'pending_training_plan_job';

  final SharedPreferences _prefs;

  String get measurementSystem =>
      _prefs.getString(_measurementSystemKey) ?? 'Metric';

  Future<void> setMeasurementSystem(String value) async {
    await _prefs.setString(_measurementSystemKey, value);
  }

  bool get onboardingCompleted =>
      _prefs.getBool(_onboardingCompletedKey) ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_onboardingCompletedKey, value);
  }

  String get lastSignedInUid => _prefs.getString(_lastSignedInUidKey) ?? '';

  Future<void> setLastSignedInUid(String value) async {
    await _prefs.setString(_lastSignedInUidKey, value);
  }

  String getPendingTrainingPlanJobID(String firebaseUid) {
    return _prefs.getString('$_pendingTrainingPlanJobPrefix:$firebaseUid') ??
        '';
  }

  Future<void> setPendingTrainingPlanJobID({
    required String firebaseUid,
    required String jobID,
  }) async {
    await _prefs.setString(
        '$_pendingTrainingPlanJobPrefix:$firebaseUid', jobID);
  }

  Future<void> clearPendingTrainingPlanJobID(String firebaseUid) async {
    await _prefs.remove('$_pendingTrainingPlanJobPrefix:$firebaseUid');
  }

  String get remotePlanSignalJobID =>
      _prefs.getString(remotePlanSignalJobIDKey) ?? '';

  String get remotePlanSignalStatus =>
      _prefs.getString(remotePlanSignalStatusKey) ?? '';

  Future<void> setRemotePlanSignal({
    required String jobID,
    required String status,
  }) async {
    await _prefs.setString(remotePlanSignalJobIDKey, jobID);
    await _prefs.setString(remotePlanSignalStatusKey, status);
  }

  Future<void> clearRemotePlanSignal() async {
    await _prefs.remove(remotePlanSignalJobIDKey);
    await _prefs.remove(remotePlanSignalStatusKey);
  }

  int? activePlanWeekNumber({
    required String firebaseUid,
    required int trainingPlanId,
  }) {
    return _prefs.getInt(
      '$_activePlanWeekNumberPrefix:$firebaseUid:$trainingPlanId',
    );
  }

  Future<void> setActivePlanWeekNumber({
    required String firebaseUid,
    required int trainingPlanId,
    required int value,
  }) async {
    await _prefs.setInt(
      '$_activePlanWeekNumberPrefix:$firebaseUid:$trainingPlanId',
      value,
    );
  }

  String getActivePlanWeekAnchor({
    required String firebaseUid,
    required int trainingPlanId,
  }) {
    return _prefs.getString(
          '$_activePlanWeekAnchorPrefix:$firebaseUid:$trainingPlanId',
        ) ??
        '';
  }

  Future<void> setActivePlanWeekAnchor({
    required String firebaseUid,
    required int trainingPlanId,
    required String value,
  }) async {
    await _prefs.setString(
      '$_activePlanWeekAnchorPrefix:$firebaseUid:$trainingPlanId',
      value,
    );
  }

  String getWeeklyPreviewAnchor({
    required String firebaseUid,
    required int trainingPlanId,
  }) {
    return _prefs.getString(
          '$_weeklyPreviewAnchorPrefix:$firebaseUid:$trainingPlanId',
        ) ??
        '';
  }

  Future<void> setWeeklyPreviewAnchor({
    required String firebaseUid,
    required int trainingPlanId,
    required String value,
  }) async {
    await _prefs.setString(
      '$_weeklyPreviewAnchorPrefix:$firebaseUid:$trainingPlanId',
      value,
    );
  }

  String getWeeklyPreviewCache({
    required String firebaseUid,
    required int trainingPlanId,
  }) {
    return _prefs.getString(
          '$_weeklyPreviewCachePrefix:$firebaseUid:$trainingPlanId',
        ) ??
        '';
  }

  Future<void> setWeeklyPreviewCache({
    required String firebaseUid,
    required int trainingPlanId,
    required String value,
  }) async {
    await _prefs.setString(
      '$_weeklyPreviewCachePrefix:$firebaseUid:$trainingPlanId',
      value,
    );
  }

  Future<void> clearWeeklyPreviewCache({
    required String firebaseUid,
    required int trainingPlanId,
  }) async {
    await _prefs.remove(
      '$_weeklyPreviewCachePrefix:$firebaseUid:$trainingPlanId',
    );
    await _prefs.remove(
      '$_weeklyPreviewAnchorPrefix:$firebaseUid:$trainingPlanId',
    );
  }
}
