import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'database_services.dart';
import 'dart:isolate';
import 'dart:ui';

final StreamController<String> taskCompletionController =
    StreamController<String>.broadcast();

const String isolateName = "background_task_port";

@pragma('vm:entry-point')
void resetHabitsTask() async {
  print("🔄 Background task triggered: reset_all_habits");

  try {
    await DatabaseService.instance.getDatabase();
    final habitService = HabitService();
    await habitService.resetAllHabits();

    print("✅ RESET FUNCTION CALLED SUCCESSFULLY!");

    final SendPort? sendPort = IsolateNameServer.lookupPortByName(isolateName);
    sendPort?.send("Task Completed!");
  } catch (e) {
    print("❌ ERROR in resetAllHabits: $e");
  }
}

Duration getTimeUntilMidnight() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day, 18, 44, 59);
  return midnight.difference(now);
}

Future<void> initializeBackgroundTasks() async {
  print("🛠 Initializing Background Tasks...");

  try {
    // Cancel any existing alarms
    await AndroidAlarmManager.cancel(0);

    // Get the next runtime
    final duration = getTimeUntilMidnight();
    final DateTime scheduledTime = DateTime.now().add(duration);

    print("📅 Next scheduled run: ${scheduledTime.toString()}");

    // Schedule the periodic task
    bool success = await AndroidAlarmManager.periodic(
      const Duration(minutes: 1),
      0, // Unique ID
      resetHabitsTask,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    print(success
        ? "✅ Task Scheduled Successfully!"
        : "❌ Failed to Schedule Task");
  } catch (e, stackTrace) {
    print("❌ Error initializing background tasks: $e");
    print("Stack trace: $stackTrace");
  }
}

void registerIsolate() {
  final ReceivePort receivePort = ReceivePort();
  IsolateNameServer.registerPortWithName(receivePort.sendPort, isolateName);

  receivePort.listen((message) {
    print("📢 Background task message: $message");
    taskCompletionController.add(message);
  });
}
