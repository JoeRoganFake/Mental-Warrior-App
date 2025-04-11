import 'package:flutter/material.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/pages/meditation.dart';
import 'package:mental_warior/pages/categories_page.dart';
import 'services/background_restet_habits.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background Task Initialization
  bool initialized = await AndroidAlarmManager.initialize();
  print(initialized
      ? "🛠 Alarm Manager Initialized Successfully !"
      : "⚠️ Alarm Manager was already initialized.");

  registerIsolate();
  await initializeBackgroundTasks();

  // Notification Initialization

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveBackgroundNotificationResponse: handleBackgroundNotification,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: "Poppins"),
      routes: {
        '/': (context) => HomePage(),
        '/meditation': (context) => MeditationPage(),
        '/categories': (context) => CategoriesPage(), // Add this route
      },
    );
  }
}

@pragma('vm:entry-point')
void handleBackgroundNotification(NotificationResponse response) {
  if (response.actionId == 'resume') {
    navigatorKey.currentState
        ?.pushNamed('/meditation', arguments: {'resume': true});
  } else if (response.actionId == 'terminate') {
    navigatorKey.currentState
        ?.pushNamed('/meditation', arguments: {'terminate': true});
  }
}
