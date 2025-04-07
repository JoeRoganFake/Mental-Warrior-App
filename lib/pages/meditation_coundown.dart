import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mental_warior/main.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/services/database_services.dart';

class MeditationCountdownScreen extends StatefulWidget {
  static MeditationCountdownScreenState? currentState;
  final int duration;
  final String mode;

  const MeditationCountdownScreen({
    super.key,
    required this.duration,
    required this.mode,
  });

  @override
  MeditationCountdownScreenState createState() =>
      MeditationCountdownScreenState();
}

class MeditationCountdownScreenState extends State<MeditationCountdownScreen>
    with WidgetsBindingObserver {
  late int remainingSeconds;
  Timer? uiTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final habits = HabitService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool isPaused = false;
  bool isTerminateDialogOpen = false;
  bool _alarmPlayed = false;

  @override
  void initState() {
    super.initState();
    MeditationCountdownScreen.currentState = this;
    WidgetsBinding.instance.addObserver(this);
    remainingSeconds = widget.duration * 60;

    // Delay initialization to allow UI rendering
    Future.delayed(Duration(milliseconds: 100), () {
      _initForegroundTask();
      _startUITimer();
      _initializeNotifications();
    });
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meditation_channel',
        channelName: 'Meditation Timer',
        channelDescription: 'Shows meditation progress',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
          autoRunOnBoot: false,
          allowWifiLock: false,
          eventAction: ForegroundTaskEventAction.nothing()),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
    );

    // Start the foreground task asynchronously
    _startForegroundTask();
  }

  Future<void> _startForegroundTask() async {
    // Save data asynchronously
    await Future.wait([
      FlutterForegroundTask.saveData(
          key: 'remainingSeconds', value: remainingSeconds),
      FlutterForegroundTask.saveData(key: 'isPaused', value: isPaused),
    ]);

    // Start or restart the foreground service
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Meditation In Progress',
        notificationText:
            '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
        callback: startCallback,
      );
    }
  }

  Future<void> stopForegroundTask() async {
    await FlutterForegroundTask.stopService();
  }

  void _startUITimer() {
    _updateUITimer();
    uiTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      await _updateUITimer();
    });
  }

  Future<void> _updateUITimer() async {
    if (isPaused) return;

    // Fetch the remaining time asynchronously
    final time =
        await FlutterForegroundTask.getData<int>(key: 'remainingSeconds') ??
            remainingSeconds;

    if (mounted) {
      setState(() {
        remainingSeconds = time;
      });
    }

    // Handle timer completion
    if (remainingSeconds <= 0 && !_alarmPlayed) {
      _alarmPlayed = true;
      playAlarm();
      showFinishedNotification();
      stopForegroundTask();
    }
  }

  @override
  void dispose() {
    uiTimer?.cancel();
    stopForegroundTask();
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  void showFinishedNotification() async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Finished Timer',
      channelDescription: 'Timer has finished',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      ongoing: false,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'finish',
          'Finish',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      1,
      'Meditation Finished',
      'You have completed ${widget.mode} meditation',
      platformDetails,
    );
  }

  void pauseTimer() async {
    await FlutterForegroundTask.saveData(key: 'isPaused', value: true);
    setState(() {
      isPaused = true;
    });
  }

  void resumeTimer() async {
    await FlutterForegroundTask.saveData(key: 'isPaused', value: false);
    setState(() {
      isPaused = false;
    });
  }

  void terminateMeditation() {
    if (!mounted) return;
    pauseTimer();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
      (Route<dynamic> route) => false,
    );
    flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> playAlarm() async {
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(
      AssetSource('audio/time_up_samsung.mp3'),
      volume: 1.0,
    );

    Future.delayed(Duration(minutes: 1), () {
      _audioPlayer.stop();
    });
  }

  void completeMeditation() async {
    final habit = await habits.getHabitByLabel("meditation");
    if (habit != null && habit.status == 0) {
      await habits.updateHabitStatusByLabel("meditation", 1);
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false,
      );
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  void updateFromTaskHandler(int newTime) {
    if (mounted) {
      setState(() {
        remainingSeconds = newTime;
      });
      if (newTime <= 0 && !_alarmPlayed) {
        _alarmPlayed = true;
        playAlarm();
        showFinishedNotification();
        stopForegroundTask();
      }
    }
  }

  void showTerminateConfirmationDialog() {
    if (isTerminateDialogOpen) return;

    isTerminateDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Terminate Meditation'),
          content: Text('Are you sure you want to terminate the meditation?'),
          actions: [
            TextButton(
              onPressed: () {
                isTerminateDialogOpen = false;
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                isTerminateDialogOpen = false;
                Navigator.of(context).pop(); // Close the dialog
                terminateMeditation(); // Terminate the meditation
              },
              child: Text('Terminate'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (remainingSeconds > 0) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Meditation Timer"),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 400,
                      height: 400,
                      child: CircularProgressIndicator(
                        backgroundColor:
                            const Color.fromARGB(255, 197, 197, 197),
                        value: remainingSeconds / (widget.duration * 60),
                        strokeWidth: 10,
                      ),
                    ),
                    Text(
                      "${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                      style:
                          TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (remainingSeconds > 0) ...[
                    IconButton(
                      icon: Icon(
                        isPaused ? Icons.play_arrow : Icons.pause,
                        color: isPaused ? Colors.green : Colors.orange,
                        size: 30,
                      ),
                      onPressed: isPaused ? resumeTimer : pauseTimer,
                    ),
                    IconButton(
                      icon: Icon(Icons.stop, color: Colors.red),
                      onPressed: showTerminateConfirmationDialog,
                      iconSize: 30,
                    ),
                  ] else ...[
                    IconButton(
                      iconSize: 30,
                      icon: Icon(Icons.check,
                          color: const Color.fromARGB(255, 33, 243, 86)),
                      onPressed: completeMeditation,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MeditationTaskHandler());
}

class MeditationTaskHandler extends TaskHandler {
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    await _executeTimerLogic();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      await _executeTimerLogic();
    });
  }

  Future<void> _executeTimerLogic() async {
    final storedSeconds =
        await FlutterForegroundTask.getData<int>(key: 'remainingSeconds') ?? 0;
    final isPaused =
        await FlutterForegroundTask.getData<bool>(key: 'isPaused') ?? false;

    if (!isPaused && storedSeconds > 0) {
      final newTime = storedSeconds - 1;

      if (MeditationCountdownScreen.currentState != null &&
          MeditationCountdownScreen.currentState!.mounted) {
        MeditationCountdownScreen.currentState!.updateFromTaskHandler(newTime);
      }

      await Future.wait([
        FlutterForegroundTask.saveData(key: 'remainingSeconds', value: newTime),
        FlutterForegroundTask.updateService(
          notificationTitle: 'Meditation In Progress',
          notificationText:
              '${(newTime ~/ 60).toString().padLeft(2, '0')}:${(newTime % 60).toString().padLeft(2, '0')}',
        ),
      ]);

      if (newTime <= 0) {
        _timer?.cancel();
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer?.cancel();
    await FlutterForegroundTask.clearAllData();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }
}

void _initializeNotifications() {
  final InitializationSettings initializationSettings =
      InitializationSettings();

  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    if (response.actionId == 'finish') {
      if (MeditationCountdownScreen.currentState != null &&
          MeditationCountdownScreen.currentState!.mounted) {
        MeditationCountdownScreen.currentState!.completeMeditation();
      }
    }
  });
}
