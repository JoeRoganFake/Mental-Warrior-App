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
    
    // Print schedule
    _printTaskSchedule();

    // Run reminder check immediately on bootup
    print('\n🚀 Running initial reminder check on bootup...\n');
    await checkRemindersCallback();
  }

  // Print the schedule of all background tasks
  static void _printTaskSchedule() {
    print('\n' + '=' * 60);
    print('📅 BACKGROUND TASKS SCHEDULE');
    print('=' * 60);
    print('');
    print('🌅 Daily Quote Update');
    print('   ⏰ Schedule: Every day at 00:01 (12:01 AM)');
    print('   🔁 Frequency: Once per day');
    print('   📝 Task: Fetch and update daily motivational quote');
    print('');
    print('🔄 Habit Reset');
    print('   ⏰ Schedule: Every day at 00:05 (12:05 AM)');
    print('   🔁 Frequency: Once per day');
    print('   📝 Task: Reset all daily habit tracking');
    print('');
    print('📋 Pending Tasks Check');
    print('   ⏰ Schedule: Every day at 00:10 (12:10 AM)');
    print('   🔁 Frequency: Once per day');
    print('   📝 Task: Activate tasks that are due today');
    print('');
    print('⏰ Reminder Check');
    print('   ⏰ Schedule: Every 30 minutes (continuous)');
    print('   🔁 Frequency: 48 times per day');
    print('   📝 Task: Check for due reminders and send notifications');
    print('');
    print('   📌 NEXT 5 REMINDER CHECKS:');
    final nextChecks = _getNextReminderChecks(5);
    for (int i = 0; i < nextChecks.length; i++) {
      print('      ${i + 1}. ${nextChecks[i]}');
    }
    print('');
    print('=' * 60);
    print('✅ All tasks registered and scheduled successfully');
    print('=' * 60 + '\n');
  }

  // Calculate the next N reminder check times
  static List<String> _getNextReminderChecks(int count) {
    final now = DateTime.now();
    final checks = <String>[];

    // Start from the next 5-minute interval
    int minutesToAdd = 5 - (now.minute % 5);
    if (minutesToAdd == 0) minutesToAdd = 5;

    var nextCheck = now.add(Duration(minutes: minutesToAdd));

    for (int i = 0; i < count; i++) {
      final formattedTime =
          '${nextCheck.hour.toString().padLeft(2, '0')}:${nextCheck.minute.toString().padLeft(2, '0')}';
      final minutesUntil = nextCheck.difference(now).inMinutes;
      checks.add('$formattedTime (in ~$minutesUntil min)');
      nextCheck = nextCheck.add(const Duration(minutes: 5));
    }

    return checks;
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

    // Schedule reminder check task - runs every 30 minutes
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 30),
      BackgroundTaskIds.reminderCheckId,
      checkRemindersCallback,
      exact: false,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print("✅ Reminder check task scheduled (every 30 minutes)");
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
      String deadlineText = _formatDeadlineForNotification(deadline);
      
      // Show notification (you'll need to implement this method in NotificationService)
      await notificationService.showTaskReminderNotification(
        id: taskId + 5000, // Offset to avoid ID conflicts
        title: 'Task Reminder',
        body: '$taskLabel\n$deadlineText',
        payload: 'task_$taskId',
      );
    } catch (e) {
      print('Error showing reminder notification: $e');
    }
  }

  // Format deadline as "Tomorrow at HH:mm", "Apr 5", or "Apr 5, 2027" depending on current year
  static String _formatDeadlineForNotification(String deadline) {
    try {
      if (deadline.isEmpty) return 'soon';

      final parts = deadline.split(' ');
      final datePart = parts[0]; // "2026-02-10"
      final timePart = parts.length > 1 ? parts[1] : '00:00'; // "14:30"

      final dateParts = datePart.split('-');

      if (dateParts.length != 3) return deadline;

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      final deadlineDate = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Check if deadline is tomorrow
      if (deadlineDate.year == tomorrow.year &&
          deadlineDate.month == tomorrow.month &&
          deadlineDate.day == tomorrow.day) {
        return 'Tomorrow at $timePart';
      }

      // Month names
      const monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];

      final monthName = monthNames[month - 1];
      final currentYear = DateTime.now().year;

      if (year == currentYear) {
        return '$monthName $day';
      } else {
        return '$monthName $day, $year';
      }
    } catch (e) {
      return deadline;
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
