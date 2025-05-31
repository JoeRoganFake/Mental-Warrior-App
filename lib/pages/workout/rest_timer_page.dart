import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen rest timer with circular countdown indicator
/// Enhanced version with better UI, haptic feedback, and visuals
class RestTimerPage extends StatelessWidget {
  final int originalDuration;
  final ValueNotifier<int> remaining;
  final ValueNotifier<bool> isPaused;
  final VoidCallback onPause;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onSkip;
  
  // Colors for the timer UI
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _successColor = const Color(0xFF4CAF50);
  
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
              // Calculate progress with a minimum of 0
              final progress = value <= 0 ? 0.0 : value / originalDuration;

              // Format the time
              Duration format(int sec) => Duration(seconds: sec);
              final minutes = format(value).inMinutes;
              final secs = format(value).inSeconds % 60;
              // Determine if timer is done
              final bool isTimerDone = value <= 0;

              // Add vibration feedback when timer completes
              if (isTimerDone && value == 0) {
                // This ensures the vibration only happens once
                Future.microtask(() {
                  HapticFeedback.heavyImpact();
                });
              }
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Timer Title with animation if done
                  AnimatedSwitcher(
                    duration: Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      isTimerDone ? 'Rest Complete!' : 'Rest Time',
                      key: ValueKey<bool>(isTimerDone),
                      style: TextStyle(
                        fontSize: isTimerDone ? 28 : 24,
                        fontWeight:
                            isTimerDone ? FontWeight.bold : FontWeight.normal,
                        color: isTimerDone ? _successColor : Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Timer display
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: isTimerDone ? _successColor : Colors.white,
                      ),
                    ),
                  ),

                  // Status message when timer completes
                  if (value <= 0)
                    Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 16.0),
                      child: Text(
                        'Time\'s up! Press Done or Return to Workout when ready.',
                        style: TextStyle(
                          color: _successColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SizedBox(height: 48),

                  // Controls - larger buttons with better spacing
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // +15s button
                        ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onIncrement();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black45,
                            padding: EdgeInsets.all(16),
                            shape: CircleBorder(),
                          ),
                          child:
                              Icon(Icons.add, color: _primaryColor, size: 28),
                        ),
                        SizedBox(width: 16),

                        // Pause/Resume button
                        ValueListenableBuilder<bool>(
                          valueListenable: isPaused,
                          builder: (_, paused, __) => ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              onPause();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  paused ? _primaryColor : Colors.black45,
                              padding: EdgeInsets.all(16),
                              shape: CircleBorder(),
                            ),
                            child: Icon(paused ? Icons.play_arrow : Icons.pause,
                                color: paused ? Colors.white : _primaryColor,
                                size: 28),
                          ),
                        ),
                        SizedBox(width: 16),

                        // -15s button
                        ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onDecrement();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black45,
                            padding: EdgeInsets.all(16),
                            shape: CircleBorder(),
                          ),
                          child: Icon(Icons.remove,
                              color: _primaryColor, size: 28),
                        ),
                      ],
                    ),
                  ),
                  
                  // Circular progress indicator
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isTimerDone
                              ? _successColor.withOpacity(0.3)
                              : _primaryColor.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                        ),

                        // Progress indicator
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                isTimerDone ? _successColor : _primaryColor),
                          ),
                        ),

                        // Center icon
                        Icon(
                          isTimerDone ? Icons.check_circle : Icons.timer,
                          size: 64,
                          color: isTimerDone ? _successColor : _primaryColor,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),

                  // Skip/Done button
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (value > 0) {
                        // Call onSkip to handle proper sound playing and cleanup when skipping
                        onSkip();
                      }
                      // Pop the screen in either case
                      Navigator.of(context).pop();
                    },
                    icon: Icon(
                      value > 0 ? Icons.fast_forward : Icons.check_circle,
                      size: 24,
                    ),
                    label: Text(
                      value > 0 ? 'Skip Rest' : 'Done',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isTimerDone ? _successColor : _primaryColor,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  // Return button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Return to Workout',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
