const String _defaultBackendBaseUrl = 'https://liftsforge.com';

class AppBackend {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: _defaultBackendBaseUrl,
  );

  static Uri me() => _uri('/api/v1/me');

  static Uri redeemPromoCode() => _uri('/api/v1/promo-codes/redeem');

  static Uri imports() => _uri('/api/v1/imports');

  static Uri workouts() => _uri('/api/v1/workouts');

  static Uri workoutLogs() => _uri('/api/v1/workout-logs');

  static Uri trainingPlans() => _uri('/api/v1/training-plans');

  static Uri latestTrainingPlan() => _uri('/api/v1/training-plans/latest');

  static Uri _uri(String path) {
    final Uri baseUri = Uri.parse(baseUrl);
    final String normalizedBasePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final String normalizedPath = path.startsWith('/') ? path : '/$path';

    return baseUri.replace(
      path: '$normalizedBasePath$normalizedPath',
    );
  }
}
