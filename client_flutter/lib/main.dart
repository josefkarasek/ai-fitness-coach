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
  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();
  final AppDatabase database = AppDatabase();
  final AppDependencies dependencies = AppDependencies(
    preferences: AppPreferences(sharedPreferences),
    localCacheRepository: DriftLocalCacheRepository(database),
  );

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(AiFitnessCoachApp(dependencies: dependencies));
  } on UnsupportedError catch (error) {
    runApp(
      AiFitnessCoachApp(
        dependencies: dependencies,
        home: _FirebaseConfigurationMissingScreen(
          message: error.message ??
              'Firebase is not configured for iOS in this build.',
        ),
      ),
    );
  } catch (error) {
    runApp(
      AiFitnessCoachApp(
        dependencies: dependencies,
        home: _FirebaseConfigurationMissingScreen(
          message: 'Failed to initialize Firebase on this device.\n\n$error',
        ),
      ),
    );
  }
}

class _FirebaseConfigurationMissingScreen extends StatelessWidget {
  const _FirebaseConfigurationMissingScreen({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFFEEF3F8);
    const Color textSecondary = Color(0xFF96A0AD);
    const Color accent = Color(0xFF42D392);
    const Color outline = Color(0xFF2A2F37);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF171A1F),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: outline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'iPhone Setup Needed',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This iOS build is running, but Firebase is not configured for iPhone yet.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Next steps',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. Register the iOS app in Firebase for bundle id com.liftsforge.app.\n'
                    '2. Run flutterfire configure and include iOS.\n'
                    '3. Add GoogleService-Info.plist to ios/Runner/.',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
