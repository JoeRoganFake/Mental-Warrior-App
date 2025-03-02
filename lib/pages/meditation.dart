import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    remainingSeconds = widget.duration * 60;
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        timer.cancel();
        playAlarm();
      }
    });
  }

  Future<void> playAlarm() async {
    await _audioPlayer.play(AssetSource('time_up_samsung.mp3')); // Play sound
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder(
          tween:
              Tween(begin: 1.0, end: remainingSeconds / (widget.duration * 60)),
          duration: Duration(seconds: 1),
          builder: (context, double value, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 400,
                  height: 400,
                  child: CircularProgressIndicator(
                    backgroundColor: const Color.fromARGB(255, 197, 197, 197),
                    value: value,
                    strokeWidth: 10,
                  ),
                ),
                Text(
                  "${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
