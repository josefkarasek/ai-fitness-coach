import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/app_dependencies.dart';
import 'src/settings/app_preferences.dart';
import 'src/storage/local/app_database.dart';
import 'src/storage/local/local_cache_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();
  final AppDatabase database = AppDatabase();
  final AppDependencies dependencies = AppDependencies(
    preferences: AppPreferences(sharedPreferences),
    localCacheRepository: DriftLocalCacheRepository(database),
  );

  runApp(AiFitnessCoachApp(dependencies: dependencies));
}
