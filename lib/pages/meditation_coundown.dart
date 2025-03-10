import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
    initializeNotifications();
    startTimer();
  }

  @override
  void dispose() {
    if (MeditationCountdownScreen.currentState == this) {
      MeditationCountdownScreen.currentState = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      showPersistentNotification();
    }
    if (state == AppLifecycleState.resumed) {
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  void initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (MeditationCountdownScreen.currentState == null) {
          if (response.payload != null) {
            final parts = response.payload!.split('|');
            final duration = int.parse(parts[0]);
            final remaining = int.parse(parts[1]);
            final mode = parts[2];
            print(parts);

            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MeditationCountdownScreen(
                  duration: duration,
                  mode: mode,
                ),
              ),
              (route) => false,
            );

            await Future.delayed(Duration(milliseconds: 200));
            if (mounted && MeditationCountdownScreen.currentState != null) {
              MeditationCountdownScreen.currentState?.remainingSeconds =
                  remaining;
              if (response.actionId == 'resume') {
                isPaused
                    ? MeditationCountdownScreen.currentState?.resumeTimer()
                    : MeditationCountdownScreen.currentState?.pauseTimer();
              } else if (response.actionId == 'terminate') {
                MeditationCountdownScreen.currentState
                    ?.showTerminateConfirmationDialog();
                print("0");
              }
            }
          }
        } else {
          if (response.actionId == 'resume' && mounted) {
            return isPaused ? resumeTimer() : pauseTimer();
          } else if (response.actionId == 'terminate' && mounted) {
            showTerminateConfirmationDialog();
            print("1");
          }
        }
      },
    );
  }

  void showPersistentNotification() async {
    if (remainingSeconds > 0) {
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'meditation_channel',
        'Meditation Timer',
        channelDescription: 'Shows if meditation is in progress',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        ongoing: false,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'resume',
            isPaused ? 'Resume' : 'Pause',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            'terminate',
            'Terminate',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await flutterLocalNotificationsPlugin.show(
        0,
        'Meditation In Progress',
        'Active $mode meditation',
        platformChannelSpecifics,
        payload: '${widget.duration}|$remainingSeconds',
      );
    }
  }

  void showFinishedTimerNotification() async {
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
      0,
      'Meditation Finished',
      'You have completed $mode meditation',
      platformChannelSpecifics,
      payload: '${widget.duration}|$remainingSeconds',
    );
  }

  void startTimer() {
    countdownTimer = Timer.periodic(Duration(milliseconds: 25), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        timer.cancel();
        playAlarm();
        flutterLocalNotificationsPlugin.cancelAll();
        showFinishedTimerNotification();
      }
    });
  }

  void pauseTimer() {
    setState(() {
      countdownTimer?.cancel();
    });
    isPaused = true;
  }

  void resumeTimer() {
    setState(() {
      startTimer();
    });
    isPaused = false;
  }

  void terminateMeditation() {
    if (!mounted) return;
    pauseTimer();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
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
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                terminateMeditation();
              },
              child: Text("Terminate"),
            ),
          ],
        );
      },
    );
  }

  Future<void> playAlarm() async {
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm, // Uses ring volume
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
              TweenAnimationBuilder(
                tween: Tween(
                    begin: 1.0, end: remainingSeconds / (widget.duration * 60)),
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
                      onPressed: () async {
                        final habit =
                            await habits.getHabitByLabel("meditation");
                        if (habit != null && habit.status == 0) {
                          await habits.updateHabitStatusByLabel(
                              "meditation", 1);
                        }
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
                          (Route<dynamic> route) => false,
                        );
                        if (habit != null && habit.status == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Habit meditation completed'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
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
