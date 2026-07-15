import 'package:flutter/material.dart';
import 'package:forge/src/app.dart';
import 'package:forge/src/app_dependencies.dart';
import 'package:forge/src/settings/app_preferences.dart';
import 'package:forge/src/storage/local/app_database.dart';
import 'package:forge/src/storage/local/local_cache_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders app shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AppDatabase database = AppDatabase.executor(NativeDatabase.memory());

    await tester.pumpWidget(
      AiFitnessCoachApp(
        dependencies: AppDependencies(
          preferences: AppPreferences(preferences),
          localCacheRepository: DriftLocalCacheRepository(database),
        ),
        home: const Scaffold(body: Text('Smoke Test Home')),
      ),
    );

    expect(find.text('Smoke Test Home'), findsOneWidget);

    await database.close();
  });
}
