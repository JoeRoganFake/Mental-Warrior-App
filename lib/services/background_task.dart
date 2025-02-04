import 'package:workmanager/workmanager.dart';
import 'database_services.dart';
import 'package:flutter/material.dart';

// Global notifier to trigger UI updates when habits reset
ValueNotifier<bool> habitsUpdatedNotifier = ValueNotifier(false);

Duration getTimeUntilMidnight() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return midnight.difference(now);
}

void initializeBackgroundTasks() {
  print('Initializing WorkManager...');

  // Initialize WorkManager
  Workmanager().initialize(callbackDispatcher);

  // Register periodic task to reset habits at midnight
  Workmanager().registerPeriodicTask(
    'reset_habits_task', // Unique task ID
    'reset_all_habits', // Task name
    frequency: Duration(minutes: 15), // Minimum allowed interval (15 min)
  );
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Task triggered: $task');

    if (task.trim() == 'reset_all_habits') {
      print("STARTING HABIT RESET...");

      try {
        print("Initializing database...");
        await DatabaseService.instance
            .getDatabase(); // Ensure DB is initialized

        final habitService = HabitService();
        print("Calling resetAllHabits...");
        await habitService.resetAllHabits();

        print("✅ RESET FUNCTION CALLED SUCCESSFULLY!");

        // Notify UI that habits have been updated
        habitsUpdatedNotifier.value = !habitsUpdatedNotifier.value;
      } catch (e) {
        print("❌ ERROR in resetAllHabits: $e");
      }
    } else {
      print("Unexpected task received: $task");
    }

    return Future.value(true);
  });
}
