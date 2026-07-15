import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/app_dependencies.dart';
import 'src/settings/app_preferences.dart';
import 'src/storage/local/app_database.dart';
import 'src/storage/local/local_cache_repository.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final Map<String, dynamic> data = message.data;
  final String type = (data['type'] as String? ?? '').trim();
  final String jobID = (data['job_id'] as String? ?? '').trim();
  final String status = (data['status'] as String? ?? '').trim();
  if ((type != 'training_plan_ready' && type != 'training_plan_failed') ||
      jobID.isEmpty) {
    return;
  }

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString(AppPreferences.remotePlanSignalJobIDKey, jobID);
  await preferences.setString(
    AppPreferences.remotePlanSignalStatusKey,
    status.isEmpty ? type : status,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
