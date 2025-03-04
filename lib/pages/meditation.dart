import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:permission_handler/permission_handler.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  _MeditationPageState createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  String? selectedMode;
  final List<int> durations = [5, 10, 15, 20, 25, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa_outlined, size: 70, color: Colors.blue),
          SizedBox(height: 10),
          Text(
            "Recharge Your Mind",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text(
            "Choose your meditation mode.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildModeButton("Guided", Icons.headset, Colors.blue),
              SizedBox(width: 20),
              _buildModeButton(
                  "Unguided", Icons.self_improvement, Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMode = title;
        });
        _showDurationSelection();
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 2)
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showDurationSelection() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Duration"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...durations.map((duration) => ListTile(
                    title: Text("$duration minutes"),
                    onTap: () {
                      Navigator.pop(context);
                      _startMeditation(duration);
                    },
                  )),
              ListTile(
                title: Text(
                  "Custom",
                  textAlign: TextAlign.center,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCustomTimePicker();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomTimePicker() {
    int customMinutes = 5;
    Timer? timer;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Set Custom Time"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onLongPressStart: (_) {
                          timer =
                              Timer.periodic(Duration(milliseconds: 100), (t) {
                            if (customMinutes > 1) {
                              setDialogState(() => customMinutes--);
                            }
                          });
                        },
                        onLongPressEnd: (_) {
                          timer?.cancel();
                        },
                        child: IconButton(
                          icon: Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (customMinutes > 1) {
                              setDialogState(() => customMinutes--);
                            }
                          },
                        ),
                      ),
                      Text("$customMinutes min",
                          style: TextStyle(fontSize: 24)),
                      GestureDetector(
                        onLongPressStart: (_) {
                          timer =
                              Timer.periodic(Duration(milliseconds: 50), (t) {
                            setDialogState(() => customMinutes++);
                          });
                        },
                        onLongPressEnd: (_) {
                          timer?.cancel();
                        },
                        child: IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setDialogState(() => customMinutes++);
                          },
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _startMeditation(customMinutes);
                    },
                    child: Text("Start"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startMeditation(int minutes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeditationCountdownScreen(duration: minutes),
      ),
    );
  }
}

// Meditation Countdown Screen
class MeditationCountdownScreen extends StatefulWidget {
  final int duration;
  const MeditationCountdownScreen({super.key, required this.duration});

  @override
  _MeditationCountdownScreenState createState() =>
      _MeditationCountdownScreenState();
}

class _MeditationCountdownScreenState extends State<MeditationCountdownScreen> {
  late int remainingSeconds;
  Timer? countdownTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPaused = false;
  final habits = HabitService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.duration * 60;
    initializeNotifications();
    requestNotificationPermission();
    startTimer();
  }

  void initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
      if (response.payload != null) {
        if (response.payload == 'resume') {
          resumeTimer();
        } else if (response.payload == 'terminate') {
          terminateMeditation();
        }
      }
    });
  }

  void requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  void startTimer() {
    countdownTimer = Timer.periodic(Duration(milliseconds: 25), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
        if (isPaused) {
          showNotification();
        }
      } else {
        timer.cancel();
        playAlarm();
      }
    });
  }

  void showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'meditation_channel',
      'Meditation Timer',
      channelDescription: 'Shows the remaining time for meditation',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'resume',
          'Resume',
        ),
        AndroidNotificationAction(
          'terminate',
          'Terminate',
        ),
      ],
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Meditation Timer',
      'Time remaining: ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  void pauseTimer() {
    countdownTimer?.cancel();
    setState(() {
      isPaused = true;
    });
    showNotification();
  }

  void resumeTimer() {
    startTimer();
    setState(() {
      isPaused = false;
    });
  }

  void terminateMeditation() {
    countdownTimer?.cancel();
    Navigator.pop(context);
  }

  void showTerminateConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Confirm Termination"),
          content: Text("Are you sure you want to terminate the meditation?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                resumeTimer(); // Resume the meditation
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                terminateMeditation(); // Terminate the meditation
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
          usageType: AndroidUsageType.notification, // Uses ring volume
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
  void dispose() {
    countdownTimer?.cancel();
    _audioPlayer.dispose();
    flutterLocalNotificationsPlugin.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      iconSize: 40,
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
        ));
  }
}
