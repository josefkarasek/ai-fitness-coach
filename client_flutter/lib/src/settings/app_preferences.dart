import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences(this._prefs);

  static const String _measurementSystemKey = 'measurement_system';
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _lastSignedInUidKey = 'last_signed_in_uid';
  static const String _activePlanWeekNumberPrefix = 'active_plan_week_number';
  static const String _activePlanWeekAnchorPrefix = 'active_plan_week_anchor';

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
}
