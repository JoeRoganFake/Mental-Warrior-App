import 'package:flutter/material.dart';
import 'package:mental_warior/pages/home.dart';
import 'services/background_task.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize only once
  bool initialized = await AndroidAlarmManager.initialize();
  print(initialized
      ? "🛠 Alarm Manager Initialized Successfully!"
      : "⚠️ Alarm Manager was already initialized.");

  // Register isolate before scheduling tasks
  registerIsolate();
  await initializeBackgroundTasks();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: "Poppins"),
      home: HomePage(),
    );
  }
}
