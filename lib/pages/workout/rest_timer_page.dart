import 'package:flutter/material.dart';

/// Full-screen rest timer with circular countdown indicator
class RestTimerPage extends StatelessWidget {
  final int originalDuration;
  final ValueNotifier<int> remaining;
  final ValueNotifier<bool> isPaused;
  final VoidCallback onPause;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onSkip;
  const RestTimerPage({
    Key? key,
    required this.originalDuration,
    required this.remaining,
    required this.isPaused,
    required this.onPause,
    required this.onIncrement,
    required this.onDecrement,
    required this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: remaining,
            builder: (context, value, child) {
              // Auto-dismiss when timer reaches zero
              if (value == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(context)) Navigator.of(context).pop();
                });
              }
              final progress = value / originalDuration;
              Duration format(int sec) => Duration(seconds: sec);
              final minutes = format(value).inMinutes;
              final secs = format(value).inSeconds % 60;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Rest Time', style: TextStyle(fontSize: 24, color: Colors.white)),
                  SizedBox(height: 16),
                  Text('${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}', style: TextStyle(fontSize: 48, color: Colors.white)),
                  SizedBox(height: 32),
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: Icon(Icons.add, color: Colors.white), onPressed: onIncrement),
                      ValueListenableBuilder<bool>(
                        valueListenable: isPaused,
                        builder: (_, paused, __) => IconButton(
                          icon: Icon(paused ? Icons.play_arrow : Icons.pause, color: Colors.white),
                          onPressed: onPause,
                        ),
                      ),
                      IconButton(icon: Icon(Icons.remove, color: Colors.white), onPressed: onDecrement),
                    ],
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                    ),
                  ),                  SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Just set timer to 0 and let the auto-dismiss logic work
                      remaining.value = 0;
                      // Don't call onSkip() as it cancels the timer completely
                    },
                    icon: Icon(Icons.fast_forward),
                    label: Text('Skip'),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Return to Workout', style: TextStyle(color: Colors.white70))),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
