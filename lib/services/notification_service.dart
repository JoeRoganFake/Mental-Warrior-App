import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mental_warior/services/database_services.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _activeWorkoutNotificationId = 1001;

  /// Initialize the notification service
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Listen to active workout changes
    WorkoutService.activeWorkoutNotifier.addListener(_onActiveWorkoutChanged);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Handle notification tap - you can navigate to workout session here
    print('Notification tapped: ${notificationResponse.payload}');
  }

  /// Listen to active workout changes and update notification accordingly
  static void _onActiveWorkoutChanged() {
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    
    if (activeWorkout != null) {
      // Show active workout notification
      _showActiveWorkoutNotification(activeWorkout);
    } else {
      // Cancel active workout notification
      _cancelActiveWorkoutNotification();
    }
  }

  /// Show persistent notification for active workout
  static Future<void> _showActiveWorkoutNotification(
      Map<String, dynamic> activeWorkout) async {
    final workoutName = activeWorkout['name'] as String;
    final duration = activeWorkout['duration'] as int;
    final formattedTime = _formatTime(duration);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'active_workout_channel',
      'Active Workout',
      channelDescription: 'Notifications for active workout sessions',
      importance: Importance.low, // Low importance to avoid intrusive behavior
      priority: Priority.low,
      ongoing: true, // Makes the notification persistent
      autoCancel: false, // Prevents accidental dismissal
      showWhen: false, // Don't show timestamp
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF3F8EFC), // Your app's primary color
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'open_workout',
          'Open Workout',
          titleColor: Color(0xFF3F8EFC),
        ),
        AndroidNotificationAction(
          'stop_workout',
          'Stop Workout',
          titleColor: Color(0xFFE53935),
        ),
      ],
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: false, // Don't show alert popup
      presentBadge: true,
      presentSound: false,
      threadIdentifier: 'active_workout',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      _activeWorkoutNotificationId,
      'Workout in Progress',
      '$workoutName • $formattedTime',
      platformChannelSpecifics,
      payload: 'active_workout',
    );
  }

  /// Cancel the active workout notification
  static Future<void> _cancelActiveWorkoutNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(_activeWorkoutNotificationId);
  }

  /// Update the notification with new workout data (called periodically)
  static Future<void> updateActiveWorkoutNotification() async {
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    if (activeWorkout != null) {
      await _showActiveWorkoutNotification(activeWorkout);
    }
  }

  /// Format time duration in MM:SS format
  static String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Request notification permissions (call this when the app starts)
  static Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final IOSFlutterLocalNotificationsPlugin? iOSImplementation =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    } else if (iOSImplementation != null) {
      final bool? granted = await iOSImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return false;
  }

  /// Show rest timer completion notification
  static Future<void> showRestTimerCompletedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'rest_timer_channel',
      'Rest Timer',
      channelDescription: 'Notifications for rest timer completion',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4CAF50),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      2001, // Different ID for rest timer notifications
      'Rest Timer Completed',
      'Time to get back to your workout!',
      platformChannelSpecifics,
      payload: 'rest_timer_completed',
    );
  }

  /// Dispose resources
  static void dispose() {
    WorkoutService.activeWorkoutNotifier.removeListener(_onActiveWorkoutChanged);
  }
}
