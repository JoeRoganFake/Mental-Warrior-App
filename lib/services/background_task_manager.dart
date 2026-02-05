import 'dart:isolate';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/quote_service.dart';
import 'package:mental_warior/services/reminder_service.dart';
import 'package:mental_warior/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Define unique IDs for each background task
class BackgroundTaskIds {
  static const int dailyQuoteId = 0;
  static const int habitResetId = 1;
  static const int pendingTasksId = 2;
  static const int reminderCheckId = 3;
}

@pragma('vm:entry-point')
class BackgroundTaskManager {
  static const String isolateName = 'background_task_port';

  // Keys for shared preferences
  static const String quoteTextKey = 'daily_quote_text';
  static const String quoteAuthorKey = 'daily_quote_author';
  static const String quoteDateKey = 'daily_quote_date';

  // Initialize all background tasks
  static Future<void> initialize() async {
    bool initialized = await AndroidAlarmManager.initialize();
    print(initialized
        ? "🛠 Background Task Manager initialized successfully!"
        : "⚠️ Background Task Manager was already initialized.");

    // Register all tasks
    await _registerBackgroundTasks();
  }

  // Register all background tasks with the alarm manager
  static Future<void> _registerBackgroundTasks() async {
    // Schedule daily quote task - runs every day at 00:01
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      BackgroundTaskIds.dailyQuoteId,
      dailyQuoteCallback,
      startAt: DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 1),
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print("✅ Daily quote task scheduled");

    // Schedule habit reset task - runs every day at 00:05
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      BackgroundTaskIds.habitResetId,
      _resetHabitsCallback,
      startAt: DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 5),
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print("✅ Habit reset task scheduled");

    // Schedule checking for due pending tasks - runs every day at 00:10
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      BackgroundTaskIds.pendingTasksId,
      _checkPendingTasksCallback,
      startAt: DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day, 0, 10),
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print("✅ Check pending tasks scheduled");

    // Schedule reminder check task - runs every 5 minutes for testing (change to 30 minutes in production)
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 5),
      BackgroundTaskIds.reminderCheckId,
      checkRemindersCallback,
      exact: false,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print("✅ Reminder check task scheduled (every 5 minutes)");
  }

  // Callback for daily quote task
  @pragma('vm:entry-point')
  static Future<void> dailyQuoteCallback() async {
    final DateTime now = DateTime.now();
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(isolateName);

    print('📱 Daily quote task executing at ${now.hour}:${now.minute}');

    try {
      // Get the daily quote (implemented in QuoteService)
      final quoteService = QuoteService();
      final quote = quoteService.getDailyQuote();

      // Save the quote to shared preferences so it persists
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(quoteTextKey, quote.text);
      await prefs.setString(quoteAuthorKey, quote.author);
      await prefs.setString(quoteDateKey,
          DateTime(now.year, now.month, now.day).toIso8601String());

      print(
          '✅ Daily quote task completed successfully: "${quote.text}" - ${quote.author}');
    } catch (e) {
      print('❌ Error in daily quote task: $e');
    }

    // Notify main isolate to refresh UI if needed
    sendPort?.send('quote_updated');
  }

  // Callback for habit reset task
  @pragma('vm:entry-point')
  static Future<void> _resetHabitsCallback() async {
    final DateTime now = DateTime.now();
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(isolateName);

    print('🔄 Habit reset task executing at ${now.hour}:${now.minute}');

    try {
      // Reset all habits
      final habitService = HabitService();
      await habitService.resetAllHabits();

      print('✅ Habit reset task completed successfully');
    } catch (e) {
      print('❌ Error in habit reset task: $e');
    }

    // Notify main isolate to refresh UI
    sendPort?.send('habits_reset');
  }

  // Callback for checking pending tasks
  @pragma('vm:entry-point')
  static Future<void> _checkPendingTasksCallback() async {
    final DateTime now = DateTime.now();
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(isolateName);

    print('🔍 Checking pending tasks at ${now.hour}:${now.minute}');

    try {
      // Check for pending tasks that should be activated today
      final pendingTaskService = PendingTaskService();
      await pendingTaskService.checkForDueTasks();

      print('✅ Pending tasks check completed successfully');
    } catch (e) {
      print('❌ Error checking pending tasks: $e');
    }

    // Notify main isolate to refresh UI
    sendPort?.send('tasks_updated');
  }

  // Callback for checking due reminders
  @pragma('vm:entry-point')
  static Future<void> checkRemindersCallback() async {
    final DateTime now = DateTime.now();
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(isolateName);

    print('⏰ Checking due reminders at ${now.hour}:${now.minute}');

    try {
      final reminderService = ReminderService();
      final taskService = TaskService();
      
      // Get all reminders that are due and not yet sent
      final dueReminders = await reminderService.checkDueReminders();
      
      print('📋 Found ${dueReminders.length} due reminders');

      // Send notification for each due reminder
      for (final reminder in dueReminders) {
        try {
          final taskId = reminder['taskId'] as int;
          final reminderValue = reminder['reminderValue'] as int;
          final reminderUnit = reminder['reminderUnit'] as String;
          final reminderTime = reminder['reminderTime'] as String;
          
          // Get task details
          final tasks = await taskService.getTasks();
          final task = tasks.firstWhere(
            (t) => t.id == taskId,
            orElse: () => throw Exception('Task not found'),
          );
          
          // Show notification
          await _showReminderNotification(
            taskId: taskId,
            taskLabel: task.label,
            reminderValue: reminderValue,
            reminderUnit: reminderUnit,
            reminderTime: reminderTime,
            deadline: task.deadline,
          );
          
          // Mark reminder as sent
          await reminderService.markReminderSent(reminder['id'] as int);
          
          print('✅ Sent reminder for task: ${task.label}');
        } catch (e) {
          print('❌ Error sending reminder: $e');
        }
      }

      print('✅ Reminder check completed successfully');
    } catch (e) {
      print('❌ Error checking reminders: $e');
    }

    // Notify main isolate to refresh UI
    sendPort?.send('reminders_checked');
  }

  // Helper method to show reminder notification
  static Future<void> _showReminderNotification({
    required int taskId,
    required String taskLabel,
    required int reminderValue,
    required String reminderUnit,
    required String reminderTime,
    required String deadline,
  }) async {
    try {
      final notificationService = NotificationService();
      
      // Format deadline for display
      String deadlineText = deadline.isNotEmpty ? deadline.split(' ')[0] : 'soon';
      
      // Show notification (you'll need to implement this method in NotificationService)
      await notificationService.showTaskReminderNotification(
        id: taskId + 5000, // Offset to avoid ID conflicts
        title: '⏰ Task Reminder',
        body: '$taskLabel\nDue: $deadlineText',
        payload: 'task_$taskId',
      );
    } catch (e) {
      print('❌ Error showing reminder notification: $e');
    }
  }

  // Run all tasks manually (useful for testing or immediate execution)
  static Future<void> runAllTasksNow() async {
    print('🚀 Running all background tasks manually');
    await dailyQuoteCallback();
    await _resetHabitsCallback();
    await _checkPendingTasksCallback();
    await checkRemindersCallback();
  }

  // Method to get the stored daily quote
  static Future<Quote?> getStoredDailyQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(quoteTextKey);
      final author = prefs.getString(quoteAuthorKey);

      if (text != null && author != null) {
        return Quote(text: text, author: author);
      }
    } catch (e) {
      print('Error getting stored quote: $e');
    }
    return null;
  }
}
