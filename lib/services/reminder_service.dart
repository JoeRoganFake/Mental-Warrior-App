import 'package:mental_warior/services/database_services.dart';
import 'package:sqflite/sqflite.dart';

/// Service for managing task reminders with database persistence
/// 
/// This service handles:
/// - Storing reminders in a dedicated database table
/// - Calculating reminder trigger times based on task deadlines
/// - Tracking notification delivery status
/// - Cleaning up reminders when tasks are deleted
class ReminderService {
  // Table and column names
  final String _reminderTableName = "reminders";
  final String _reminderIdColumnName = "id";
  final String _reminderTaskIdColumnName = "taskId";
  final String _reminderValueColumnName = "reminderValue";
  final String _reminderUnitColumnName = "reminderUnit";
  final String _reminderTimeColumnName = "reminderTime";
  final String _reminderDueDateTimeColumnName = "dueDateTime";
  final String _reminderNotificationSentColumnName = "notificationSent";
  final String _reminderCreatedAtColumnName = "createdAt";

  /// Creates the reminders table in the database
  /// 
  /// Schema:
  /// - id: Primary key
  /// - taskId: Foreign key linking to tasks table
  /// - reminderValue: Numeric value (1, 2, 3, etc.)
  /// - reminderUnit: Time unit ('day', 'week', 'month')
  /// - reminderTime: Time of day in HH:mm format
  /// - dueDateTime: Calculated trigger timestamp (ISO 8601)
  /// - notificationSent: Boolean flag (0 or 1)
  /// - createdAt: Timestamp when reminder was created
  void createReminderTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_reminderTableName (
          $_reminderIdColumnName INTEGER PRIMARY KEY AUTOINCREMENT,
          $_reminderTaskIdColumnName INTEGER NOT NULL,
          $_reminderValueColumnName INTEGER NOT NULL,
          $_reminderUnitColumnName TEXT NOT NULL,
          $_reminderTimeColumnName TEXT NOT NULL,
          $_reminderDueDateTimeColumnName TEXT NOT NULL,
          $_reminderNotificationSentColumnName INTEGER NOT NULL DEFAULT 0,
          $_reminderCreatedAtColumnName TEXT NOT NULL,
          FOREIGN KEY ($_reminderTaskIdColumnName) REFERENCES tasks(id) ON DELETE CASCADE
        )
      ''');
      print('✅ Reminders table created successfully');
    } catch (e) {
      print('❌ Error creating reminders table: $e');
    }
  }

  /// Schedules reminders for a task by calculating trigger times and storing in database
  /// 
  /// Parameters:
  /// - taskDeadline: Task due date/time in format "YYYY-MM-DD HH:mm"
  /// - selectedReminders: List of reminder maps with keys: 'value', 'unit', 'time'
  /// - taskId: ID of the task these reminders belong to
  /// 
  /// Returns: true if all reminders were scheduled successfully, false otherwise
  /// 
  /// Example:
  /// ```dart
  /// await scheduleReminders(
  ///   "2026-02-10 15:00",
  ///   [
  ///     {'value': 1, 'unit': 'day', 'time': 'at 09:00'},
  ///     {'value': 3, 'unit': 'days', 'time': 'at 09:00'}
  ///   ],
  ///   taskId: 42
  /// );
  /// ```
  Future<bool> scheduleReminders(
    String taskDeadline,
    List<Map<String, dynamic>> selectedReminders,
    int taskId,
  ) async {
    if (taskDeadline.isEmpty || selectedReminders.isEmpty) {
      print('⚠️ Cannot schedule reminders: empty deadline or reminder list');
      return false;
    }

    try {
      final db = await DatabaseService.instance.database;
      final now = DateTime.now().toIso8601String();
      int successCount = 0;

      for (final reminder in selectedReminders) {
        try {
          // Extract reminder details
          final int value = reminder['value'] as int;
          final String unit = reminder['unit'] as String;
          final String timeStr = reminder['time'] as String;

          // Parse time from "at HH:mm" format
          String reminderTime = _parseTimeFromString(timeStr);

          // Calculate when this reminder should trigger
          final DateTime? dueDateTime = _calculateReminderDateTime(
            taskDeadline,
            value,
            unit,
            reminderTime,
          );

          if (dueDateTime == null) {
            print('❌ Failed to calculate reminder time for: $reminder');
            continue;
          }

          // Only schedule if the reminder is within 7 days in the past (still useful)
          // or in the future. Skip reminders older than 7 days.
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          if (dueDateTime.isBefore(sevenDaysAgo)) {
            print('⚠️ Skipping reminder older than 7 days: ${dueDateTime.toIso8601String()}');
            continue;
          }

          // Insert reminder into database
          await db.insert(
            _reminderTableName,
            {
              _reminderTaskIdColumnName: taskId,
              _reminderValueColumnName: value,
              _reminderUnitColumnName: unit,
              _reminderTimeColumnName: reminderTime,
              _reminderDueDateTimeColumnName: dueDateTime.toIso8601String(),
              _reminderNotificationSentColumnName: 0,
              _reminderCreatedAtColumnName: now,
            },
          );

          successCount++;
          print(
              '✅ Scheduled reminder: $value $unit before at $reminderTime → ${dueDateTime.toIso8601String()}');
        } catch (e) {
          print('❌ Error scheduling individual reminder: $e');
        }
      }

      print(
          '📋 Scheduled $successCount/${selectedReminders.length} reminders for task $taskId');
      return successCount > 0;
    } catch (e) {
      print('❌ Error in scheduleReminders: $e');
      return false;
    }
  }

  /// Checks for reminders that are due and haven't been sent yet
  /// 
  /// Returns: List of due reminder maps containing:
  /// - id: Reminder ID
  /// - taskId: Associated task ID
  /// - reminderValue: Numeric value
  /// - reminderUnit: Time unit
  /// - reminderTime: Time of day
  /// - dueDateTime: When reminder should trigger
  /// 
  /// This method should be called periodically (every 15-30 minutes) by
  /// the background task service to check for due reminders
  Future<List<Map<String, dynamic>>> checkDueReminders() async {
    try {
      final db = await DatabaseService.instance.database;
      final now = DateTime.now().toIso8601String();

      // Get reminders that are due (before or at current time) but not older than 7 days
      // and haven't been sent yet
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      
      final List<Map<String, dynamic>> dueReminders = await db.query(
        _reminderTableName,
        where:
            '$_reminderDueDateTimeColumnName <= ? AND $_reminderDueDateTimeColumnName >= ? AND $_reminderNotificationSentColumnName = 0',
        whereArgs: [now, sevenDaysAgo],
      );

      if (dueReminders.isNotEmpty) {
        print('🔔 Found ${dueReminders.length} due reminders');
      }

      return dueReminders;
    } catch (e) {
      print('❌ Error checking due reminders: $e');
      return [];
    }
  }

  /// Marks a reminder as sent to prevent duplicate notifications
  /// 
  /// Parameters:
  /// - reminderId: ID of the reminder that was sent
  /// 
  /// Returns: true if successfully marked, false otherwise
  /// 
  /// Call this after successfully sending a notification
  Future<bool> markReminderSent(int reminderId) async {
    try {
      final db = await DatabaseService.instance.database;

      final int rowsAffected = await db.update(
        _reminderTableName,
        {_reminderNotificationSentColumnName: 1},
        where: '$_reminderIdColumnName = ?',
        whereArgs: [reminderId],
      );

      if (rowsAffected > 0) {
        print('✅ Marked reminder $reminderId as sent');
        return true;
      } else {
        print('⚠️ Reminder $reminderId not found');
        return false;
      }
    } catch (e) {
      print('❌ Error marking reminder as sent: $e');
      return false;
    }
  }

  /// Deletes all reminders associated with a task
  /// 
  /// Parameters:
  /// - taskId: ID of the task whose reminders should be deleted
  /// 
  /// Returns: Number of reminders deleted
  /// 
  /// Call this when a task is deleted or when updating reminders
  Future<int> deleteRemindersForTask(int taskId) async {
    try {
      final db = await DatabaseService.instance.database;

      final int deletedCount = await db.delete(
        _reminderTableName,
        where: '$_reminderTaskIdColumnName = ?',
        whereArgs: [taskId],
      );

      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount reminder(s) for task $taskId');
      }

      return deletedCount;
    } catch (e) {
      print('❌ Error deleting reminders for task: $e');
      return 0;
    }
  }

  /// Retrieves all reminders for a specific task
  /// 
  /// Parameters:
  /// - taskId: ID of the task
  /// 
  /// Returns: List of reminder maps with all reminder details
  /// 
  /// Use this when editing a task to show existing reminders
  Future<List<Map<String, dynamic>>> getRemindersByTaskId(int taskId) async {
    try {
      final db = await DatabaseService.instance.database;

      final List<Map<String, dynamic>> reminders = await db.query(
        _reminderTableName,
        where: '$_reminderTaskIdColumnName = ?',
        whereArgs: [taskId],
        orderBy: _reminderDueDateTimeColumnName,
      );

      return reminders;
    } catch (e) {
      print('❌ Error getting reminders for task: $e');
      return [];
    }
  }

  /// Gets the count of pending (unsent) reminders for a task
  /// 
  /// Parameters:
  /// - taskId: ID of the task
  /// 
  /// Returns: Number of pending reminders
  Future<int> getPendingReminderCount(int taskId) async {
    try {
      final db = await DatabaseService.instance.database;

      final List<Map<String, dynamic>> result = await db.query(
        _reminderTableName,
        columns: ['COUNT(*) as count'],
        where:
            '$_reminderTaskIdColumnName = ? AND $_reminderNotificationSentColumnName = 0',
        whereArgs: [taskId],
      );

      return result.isNotEmpty ? result.first['count'] as int : 0;
    } catch (e) {
      print('❌ Error getting pending reminder count: $e');
      return 0;
    }
  }

  /// Updates reminders for an existing task
  /// 
  /// This is a convenience method that:
  /// 1. Deletes all existing reminders for the task
  /// 2. Schedules new reminders
  /// 
  /// Parameters:
  /// - taskId: ID of the task
  /// - taskDeadline: Updated task deadline
  /// - selectedReminders: New list of reminders
  /// 
  /// Returns: true if update was successful
  Future<bool> updateRemindersForTask(
    int taskId,
    String taskDeadline,
    List<Map<String, dynamic>> selectedReminders,
  ) async {
    try {
      // Delete existing reminders
      await deleteRemindersForTask(taskId);

      // Schedule new reminders
      if (selectedReminders.isEmpty) {
        print('✅ Cleared all reminders for task $taskId');
        return true;
      }

      return await scheduleReminders(
        taskDeadline,
        selectedReminders,
        taskId,
      );
    } catch (e) {
      print('❌ Error updating reminders for task: $e');
      return false;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Calculates the exact DateTime when a reminder should trigger
  /// 
  /// Parameters:
  /// - taskDeadline: Task due date/time in "YYYY-MM-DD HH:mm" format
  /// - value: Numeric value (1, 2, 3, etc.)
  /// - unit: Time unit ('day', 'week', 'month', 'days', 'weeks', 'months')
  /// - reminderTime: Time of day in "HH:mm" format
  /// 
  /// Returns: DateTime when reminder should trigger, or null if calculation fails
  /// 
  /// Example:
  /// - Task deadline: "2026-02-10 15:00"
  /// - Reminder: 2 days before at 09:00
  /// - Result: DateTime(2026, 2, 8, 9, 0)
  DateTime? _calculateReminderDateTime(
    String taskDeadline,
    int value,
    String unit,
    String reminderTime,
  ) {
    try {
      // Parse task deadline
      final deadlineParts = taskDeadline.split(' ');
      if (deadlineParts.length != 2) {
        print('❌ Invalid deadline format: $taskDeadline');
        return null;
      }

      final dateParts = deadlineParts[0].split('-');
      if (dateParts.length != 3) {
        print('❌ Invalid date format: ${deadlineParts[0]}');
        return null;
      }

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      // Parse reminder time
      final timeParts = reminderTime.split(':');
      if (timeParts.length != 2) {
        print('❌ Invalid time format: $reminderTime');
        return null;
      }

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Create deadline DateTime
      final deadline = DateTime(year, month, day);

      // Calculate reminder DateTime by subtracting value/unit from deadline
      DateTime reminderDate;
      final normalizedUnit = unit.toLowerCase().replaceAll('s', ''); // Normalize plural forms

      switch (normalizedUnit) {
        case 'day':
          reminderDate = deadline.subtract(Duration(days: value));
          break;
        case 'week':
          reminderDate = deadline.subtract(Duration(days: value * 7));
          break;
        case 'month':
          // Handle months carefully (varying days per month)
          reminderDate = DateTime(year, month - value, day);
          break;
        default:
          print('❌ Unknown time unit: $unit');
          return null;
      }

      // Combine date with specified time
      final reminderDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        hour,
        minute,
      );

      return reminderDateTime;
    } catch (e) {
      print('❌ Error calculating reminder DateTime: $e');
      return null;
    }
  }

  /// Parses time string from various formats to "HH:mm"
  /// 
  /// Handles formats like:
  /// - "at 09:00"
  /// - "at 9 AM"
  /// - "09:00"
  /// 
  /// Returns: Time in "HH:mm" format
  String _parseTimeFromString(String timeStr) {
    try {
      // Remove "at " prefix if present
      String cleaned = timeStr.toLowerCase().replaceAll('at ', '').trim();

      // Check if already in HH:mm format
      if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(cleaned)) {
        final parts = cleaned.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }

      // Handle AM/PM format (e.g., "9 AM", "2:30 PM")
      final amPmMatch = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false)
          .firstMatch(cleaned);
      
      if (amPmMatch != null) {
        int hour = int.parse(amPmMatch.group(1)!);
        final minute = amPmMatch.group(2) != null ? int.parse(amPmMatch.group(2)!) : 0;
        final period = amPmMatch.group(3)!.toLowerCase();

        // Convert to 24-hour format
        if (period == 'pm' && hour != 12) {
          hour += 12;
        } else if (period == 'am' && hour == 12) {
          hour = 0;
        }

        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }

      // Fallback: assume it's a plain number (hour)
      final hourOnly = int.tryParse(cleaned);
      if (hourOnly != null) {
        return '${hourOnly.toString().padLeft(2, '0')}:00';
      }

      print('⚠️ Could not parse time from: $timeStr, using default 09:00');
      return '09:00';
    } catch (e) {
      print('❌ Error parsing time string: $e');
      return '09:00'; // Default fallback
    }
  }

  /// Cleans up old sent reminders (housekeeping)
  /// 
  /// Deletes reminders that were sent more than 30 days ago
  /// Call this periodically to prevent database bloat
  Future<int> cleanupOldReminders() async {
    try {
      final db = await DatabaseService.instance.database;
      
      // Clean up sent reminders older than 30 days
      final thirtyDaysAgo = DateTime.now()
          .subtract(Duration(days: 30))
          .toIso8601String();

      final int sentDeleted = await db.delete(
        _reminderTableName,
        where:
            '$_reminderNotificationSentColumnName = 1 AND $_reminderDueDateTimeColumnName < ?',
        whereArgs: [thirtyDaysAgo],
      );

      // Clean up unsent reminders older than 7 days (expired lifespan)
      final sevenDaysAgo = DateTime.now()
          .subtract(Duration(days: 7))
          .toIso8601String();

      final int unsentDeleted = await db.delete(
        _reminderTableName,
        where:
            '$_reminderNotificationSentColumnName = 0 AND $_reminderDueDateTimeColumnName < ?',
        whereArgs: [sevenDaysAgo],
      );

      final totalDeleted = sentDeleted + unsentDeleted;
      
      if (totalDeleted > 0) {
        print('🧹 Cleaned up $totalDeleted old reminders ($sentDeleted sent, $unsentDeleted unsent)');
      }

      return totalDeleted;
    } catch (e) {
      print('❌ Error cleaning up old reminders: $e');
      return 0;
    }
  }
}

// ==================== INTEGRATION NOTES ====================
// 
// INTEGRATION POINT 1: Scheduling Reminders When Creating/Updating Tasks
// -----------------------------------------------------------------------
// In home.dart and categories_page.dart, after saving a task with reminders:
// 
// ```dart
// final taskId = await _taskService.addTask(
//   label,
//   deadline,
//   description,
//   category,
//   reminders: savedReminders.isNotEmpty ? savedReminders : null,
// );
// 
// // Schedule reminders
// if (savedReminders.isNotEmpty && deadline.isNotEmpty) {
//   final reminderService = ReminderService();
//   await reminderService.scheduleReminders(
//     deadline,
//     savedReminders,
//     taskId,
//   );
// }
// ```
// 
// INTEGRATION POINT 2: Updating Reminders When Task is Modified
// --------------------------------------------------------------
// In home.dart when updating task reminders:
// 
// ```dart
// final reminderService = ReminderService();
// await reminderService.updateRemindersForTask(
//   task.id,
//   _dateController.text,
//   savedReminders,
// );
// ```
// 
// INTEGRATION POINT 3: Deleting Reminders When Task is Deleted
// -------------------------------------------------------------
// In home.dart and categories_page.dart when deleting a task:
// 
// ```dart
// await _taskService.deleteTask(task.id);
// 
// // Clean up reminders
// final reminderService = ReminderService();
// await reminderService.deleteRemindersForTask(task.id);
// ```
// 
// INTEGRATION POINT 4: Background Task for Checking Due Reminders
// ----------------------------------------------------------------
// In background_task_manager.dart, add a new callback:
// 
// ```dart
// @pragma('vm:entry-point')
// static Future<void> _checkRemindersCallback() async {
//   final DateTime now = DateTime.now();
//   print('🔔 Checking reminders at ${now.hour}:${now.minute}');
// 
//   try {
//     final reminderService = ReminderService();
//     final dueReminders = await reminderService.checkDueReminders();
// 
//     for (final reminder in dueReminders) {
//       // TODO: Get task details
//       final taskId = reminder['taskId'] as int;
//       
//       // TODO: Send notification via NotificationService
//       // await notificationService.showReminder(taskId, ...);
// 
//       // Mark as sent
//       await reminderService.markReminderSent(reminder['id'] as int);
//     }
// 
//     print('✅ Processed ${dueReminders.length} reminders');
//   } catch (e) {
//     print('❌ Error checking reminders: $e');
//   }
// }
// ```
// 
// Schedule the reminder check task:
// 
// ```dart
// await AndroidAlarmManager.periodic(
//   const Duration(minutes: 30),
//   BackgroundTaskIds.reminderCheckId,
//   _checkRemindersCallback,
//   exact: true,
//   wakeup: true,
//   rescheduleOnReboot: true,
// );
// ```
// 
// INTEGRATION POINT 5: Database Schema Update
// -------------------------------------------
// In database_services.dart DatabaseService.getDatabase():
// 
// ```dart
// final reminderService = ReminderService();
// reminderService.createReminderTable(db);
// ```
// 
// INTEGRATION POINT 6: Loading Reminders When Editing Task
// ---------------------------------------------------------
// When opening edit dialog, check if reminders are in database:
// 
// ```dart
// if (task != null) {
//   final reminderService = ReminderService();
//   final dbReminders = await reminderService.getRemindersByTaskId(task.id);
//   
//   if (dbReminders.isNotEmpty) {
//     // Convert from database format to UI format
//     savedReminders = dbReminders.map((r) => {
//       'value': r['reminderValue'],
//       'unit': r['reminderUnit'],
//       'time': 'at ${r['reminderTime']}',
//       'title': '${r['reminderValue']} ${r['reminderUnit']} before at ${r['reminderTime']}',
//     }).toList();
//   }
// }
// ```
