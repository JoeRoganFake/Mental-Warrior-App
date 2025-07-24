import 'package:flutter/material.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/pages/meditation.dart';
import 'package:mental_warior/pages/categories_page.dart';
import 'package:mental_warior/pages/splash_screen.dart';
import 'package:mental_warior/pages/workout/workout_page.dart'; // Added workout page import
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/background_task_manager.dart';
import 'package:mental_warior/services/notification_service.dart';
import 'package:mental_warior/services/foreground_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the background task manager (handles quotes, habits, and pending tasks)
  await BackgroundTaskManager.initialize();

  // Initialize the notification service for workout notifications
  await NotificationService.initialize();
  await NotificationService.requestPermissions();

  // Notification Initialization
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveBackgroundNotificationResponse: handleBackgroundNotification,
  );

  // Check for pending tasks on app startup (already integrated in BackgroundTaskManager, but useful on app launch)
  await _checkPendingTasks();

  // Initialize the foreground service for background workout tracking
  await WorkoutForegroundService.initialize();

  // Check for saved workout data and restore if needed
  await _checkAndRestoreSavedWorkout();

  runApp(MyApp());
}

// Check for pending tasks that are due today and make them active
Future<void> _checkPendingTasks() async {
  try {
    final pendingTaskService = PendingTaskService();
    await pendingTaskService.checkForDueTasks();
    print("✅ Checked pending tasks on app startup");
  } catch (e) {
    print("❌ Error checking pending tasks: $e");
  }
}

// Check and restore any saved workout data
Future<void> _checkAndRestoreSavedWorkout() async {
  try {
    // First check if there's already an active workout in memory
    if (WorkoutService.activeWorkoutNotifier.value != null) {
      print("ℹ️ Active workout already exists, skipping restoration");
      return;
    }

    final savedData = await WorkoutForegroundService.getSavedWorkoutData();
    if (savedData != null) {
      final workoutService = WorkoutService();
      await workoutService.restoreSavedWorkout(savedData);
      print("✅ Restored saved workout: ${savedData['workout_name']}");
    }
  } catch (e) {
    print("❌ Error restoring saved workout data: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: "Poppins"),
      home: SplashScreen(),
      routes: {
        '/home': (context) => HomePage(),
        '/meditation': (context) => MeditationPage(),
        '/categories': (context) => CategoriesPage(),
        '/workout': (context) => WorkoutPage(), // Added workout route
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
