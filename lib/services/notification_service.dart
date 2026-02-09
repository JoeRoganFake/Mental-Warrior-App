import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();


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

    // NOTE: Active workout notifications are now handled by foreground_service.dart
    // to avoid duplicate notifications. This listener is disabled.
    // Listen to active workout changes
    // WorkoutService.activeWorkoutNotifier.addListener(_onActiveWorkoutChanged);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Handle notification tap - you can navigate to workout session here
    print('Notification tapped: ${notificationResponse.payload}');
  }




  /// Update the notification with new workout data (called periodically)
  /// DISABLED: This functionality has been moved to foreground_service.dart
  static Future<void> updateActiveWorkoutNotification() async {
    // Disabled - active workout notifications now handled by foreground service
    return;
    /*
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    if (activeWorkout != null) {
      await _showActiveWorkoutNotification(activeWorkout);
    }
    */
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

  /// Show task reminder notification
  Future<void> showTaskReminderNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'task_reminders_channel',
      'Task Reminders',
      channelDescription: 'Notifications for task reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF3F8EFC),
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
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Dispose resources
  static void dispose() {
    // Active workout listener is disabled - see initialize() method
    // WorkoutService.activeWorkoutNotifier.removeListener(_onActiveWorkoutChanged);
  }
}
