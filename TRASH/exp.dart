import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/services/database_services.dart';

class MeditationCountdownScreen extends StatefulWidget {
  static MeditationCountdownScreenState? currentState;
  final int duration;
  final String mode;

  const MeditationCountdownScreen(
      {super.key, required this.duration, required this.mode});

  @override
  MeditationCountdownScreenState createState() =>
      MeditationCountdownScreenState();
}

class MeditationCountdownScreenState extends State<MeditationCountdownScreen>
    with WidgetsBindingObserver {
  late int remainingSeconds;
  Timer? countdownTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final habits = HabitService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool isPaused = false;
  late String mode;
  bool isTerminateDialogOpen = false;

  @override
  void initState() {
    super.initState();
    MeditationCountdownScreen.currentState = this;
    WidgetsBinding.instance.addObserver(this);
    mode = widget.mode;
    remainingSeconds = widget.duration * 60;
    _initForegroundTask();
    startTimer(); // Start the combined timer
  }

  void startTimer() {
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final storedIsPaused =
          await FlutterForegroundTask.getData<bool>(key: 'isPaused') ?? false;

      if (!storedIsPaused) {
        setState(() {
          remainingSeconds = remainingSeconds - 1;
        });
        await FlutterForegroundTask.saveData(
            key: 'remainingSeconds', value: remainingSeconds);
      }

      if (remainingSeconds <= 0) {
        timer.cancel();
        playAlarm();
        showFinishedNotification();
      }
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
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
    );
    await startForegroundTask();
  }

  Future<void> startForegroundTask() async {
    await FlutterForegroundTask.saveData(
        key: 'remainingSeconds', value: remainingSeconds);
    await FlutterForegroundTask.saveData(key: 'isPaused', value: isPaused);

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

  @override
  void dispose() {
    stopForegroundTask();
    if (MeditationCountdownScreen.currentState == this) {
      MeditationCountdownScreen.currentState = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    countdownTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }

  void showFinishedNotification() async {
    flutterLocalNotificationsPlugin.cancel(0);
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
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
          cancelNotification: false,
        ),
      ],
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      1, // Use ID 1 for "Meditation Finished"
      'Meditation Finished',
      'You have completed $mode meditation',
      platformChannelSpecifics,
      payload: '${widget.duration}|$remainingSeconds|$mode',
    );
  }

  void pauseTimer() async {
    countdownTimer?.cancel();
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

  void showTerminateConfirmationDialog() {
    if (isTerminateDialogOpen) return;
    isTerminateDialogOpen = true;
    pauseTimer();
    flutterLocalNotificationsPlugin.cancelAll();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirm Termination"),
          content: Text("Are you sure you want to terminate the meditation?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                isTerminateDialogOpen = false;
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                terminateMeditation();
                isTerminateDialogOpen = false;
              },
              child: Text("Terminate"),
            ),
          ],
        );
      },
    ).then((value) {
      isTerminateDialogOpen = false;
    });
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
      _audioPlayer.release();
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

      if (habit != null && habit.status == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Habit meditation completed'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (remainingSeconds > 0) {
          showTerminateConfirmationDialog();
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
                child: TweenAnimationBuilder(
                  tween: Tween(
                      begin: 1.0,
                      end: remainingSeconds / (widget.duration * 60)),
                  duration: Duration(seconds: 1),
                  builder: (context, double value, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 400,
                          height: 400,
                          child: CircularProgressIndicator(
                            backgroundColor:
                                const Color.fromARGB(255, 197, 197, 197),
                            value: value,
                            strokeWidth: 10,
                          ),
                        ),
                        Text(
                          "${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                          style: TextStyle(
                              fontSize: 50, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
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
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final remainingSeconds =
          await FlutterForegroundTask.getData<int>(key: 'remainingSeconds') ??
              0;
      final isPaused =
          await FlutterForegroundTask.getData<bool>(key: 'isPaused') ?? false;

      if (!isPaused && remainingSeconds > 0) {
        final newTime = remainingSeconds - 1;

        // Update storage and UI
        await FlutterForegroundTask.saveData(
            key: 'remainingSeconds', value: newTime);

        // Update notification with live counter
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Meditation In Progress',
          notificationText: isPaused
              ? 'Meditation paused'
              : '${(newTime ~/ 60).toString().padLeft(2, '0')}:${(newTime % 60).toString().padLeft(2, '0')}',
        );

        // Update UI if available
        if (MeditationCountdownScreen.currentState != null &&
            MeditationCountdownScreen.currentState!.mounted) {
          MeditationCountdownScreen.currentState!.setState(() {
            MeditationCountdownScreen.currentState!.remainingSeconds = newTime;
          });
        }
      }
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer?.cancel();
    await FlutterForegroundTask.clearAllData();
  }

  void onButtonPressed(String id) {
    if (id == 'pause') {
      FlutterForegroundTask.getData<bool>(key: 'isPaused').then((isPaused) {
        FlutterForegroundTask.saveData(
            key: 'isPaused', value: !(isPaused ?? false));
      });
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }
}
