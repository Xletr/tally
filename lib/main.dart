import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/core/bootstrap/bootstrap.dart';
import 'src/data/services/notification_service.dart';
import 'src/data/services/service_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = AppBootstrap();
  await bootstrap.initialize();
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  final notificationService = NotificationService(notificationPlugin);
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appBootstrapProvider.overrideWithValue(bootstrap),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const TallyApp(),
    ),
  );
}
