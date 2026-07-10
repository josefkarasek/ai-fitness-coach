import 'settings/app_preferences.dart';
import 'storage/local/local_cache_repository.dart';

class AppDependencies {
  const AppDependencies({
    required this.preferences,
    required this.localCacheRepository,
  });

  final AppPreferences preferences;
  final DriftLocalCacheRepository localCacheRepository;
}
