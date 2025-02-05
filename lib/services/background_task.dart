import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'database_services.dart';
import 'dart:isolate';
import 'dart:ui';

final StreamController<String> taskCompletionController =
    StreamController<String>.broadcast();

Duration getTimeUntilMidnight() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day, 12, 33, 0);
  return midnight.difference(now);
}

void initializeBackgroundTasks() {
  print('Initializing WorkManager...');
  Workmanager().cancelAll();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  Workmanager().registerPeriodicTask(
    'reset_habits_task',
    'reset_all_habits',
    frequency: Duration(minutes: 15),
    // initialDelay: getTimeUntilMidnight(),
  );
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Background task triggered: $task");

    if (task == 'reset_all_habits') {
      print("STARTING HABIT RESET...");

      try {
        await DatabaseService.instance.getDatabase();
        final habitService = HabitService();
        await habitService.resetAllHabits();

        print("✅ RESET FUNCTION CALLED SUCCESSFULLY!");

        // Send data to main isolate
        final SendPort? sendPort =
            IsolateNameServer.lookupPortByName('background_task_port');
        sendPort?.send("Task Completed!");
      } catch (e) {
        print("❌ ERROR in resetAllHabits: $e");
      }
    } else {
      print("Unexpected task received: $task");
    }

    return Future.value(true);
  });
}
