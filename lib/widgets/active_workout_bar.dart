import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/workout_session_page.dart';

class ActiveWorkoutBar extends StatefulWidget {
  const ActiveWorkoutBar({Key? key}) : super(key: key);

  @override
  State<ActiveWorkoutBar> createState() => _ActiveWorkoutBarState();
}

class _ActiveWorkoutBarState extends State<ActiveWorkoutBar> {
  final Color _backgroundColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textColor = Colors.white;
  String _formattedTime = "00:00";
  int _elapsedSeconds = 0;
  Timer? _timer;
  DateTime? _workoutStartTime;
    @override
  void initState() {
    super.initState();
    // Start the timer immediately if we have an active workout
    if (WorkoutService.activeWorkoutNotifier.value != null) {
      _startTimer();
    }
    
    // Listen to changes in the active workout notifier
    WorkoutService.activeWorkoutNotifier.addListener(_handleActiveWorkoutChanged);
  }
  
  @override
  void dispose() {
    _stopTimer();
    WorkoutService.activeWorkoutNotifier.removeListener(_handleActiveWorkoutChanged);
    super.dispose();
  }
  
  void _handleActiveWorkoutChanged() {
    if (WorkoutService.activeWorkoutNotifier.value != null) {
      // Start or restart the timer if we have an active workout
      if (_timer == null) {
        _startTimer();
      }
    } else {
      // Stop the timer if there's no active workout
      _stopTimer();
    }
  }
  
  void _startTimer() {
    // Get the current elapsed seconds from the active workout
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    if (activeWorkout == null) return;
    
    _elapsedSeconds = activeWorkout['duration'] as int;
    
    // Calculate the start time based on current time minus elapsed seconds
    _workoutStartTime = DateTime.now().subtract(Duration(seconds: _elapsedSeconds));
    
    // Start a timer to update the UI
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (WorkoutService.activeWorkoutNotifier.value == null) {
        _stopTimer();
        return;
      }
      
      // Calculate elapsed time based on real-world time difference
      final now = DateTime.now();
      final newElapsedSeconds = now.difference(_workoutStartTime!).inSeconds;
      
      if (newElapsedSeconds != _elapsedSeconds) {
        setState(() {
          _elapsedSeconds = newElapsedSeconds;
          _formattedTime = _formatTime(_elapsedSeconds);
          
          // Update the duration in the active workout notifier
          final currentWorkout = WorkoutService.activeWorkoutNotifier.value;
          if (currentWorkout != null) {
            WorkoutService.activeWorkoutNotifier.value = {
              ...currentWorkout,
              'duration': _elapsedSeconds,
            };
          }
        });
      }
    });
  }
  
  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: WorkoutService.activeWorkoutNotifier, 
      builder: (context, activeWorkout, child) {
        if (activeWorkout == null) {
          return const SizedBox.shrink();
        }

        final workoutId = activeWorkout['id'] as int;
        final workoutName = activeWorkout['name'] as String;
        // Make sure we're using the stored elapsed seconds, which our timer is updating
        // but also sync with the notifier in case it changed elsewhere
        if (activeWorkout['duration'] != null && _timer == null) {
          _elapsedSeconds = activeWorkout['duration'] as int;
          _formattedTime = _formatTime(_elapsedSeconds);
        }
        final isTemporary = activeWorkout['isTemporary'] as bool? ?? false;

        return GestureDetector(
          onTap: () {
            // Restore the workout session
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutSessionPage(
                  workoutId: workoutId,
                  readOnly: false,
                  isTemporary: isTemporary,
                  minimized: true, // Indicate this workout was minimized
                ),
              ),
            ).then((_) {
              // If the workout is no longer active after returning, update the UI
              if (WorkoutService.activeWorkoutNotifier.value == null) {
                setState(() {});
              }
            });
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: _backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Workout icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Workout name and timer
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workoutName,
                          style: TextStyle(
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: _primaryColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formattedTime,
                              style: TextStyle(
                                color: _textColor.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: _timer != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (_timer != null)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Maximize/continue button
                  TextButton.icon(
                    onPressed: () {
                      // Restore the workout session
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutSessionPage(
                            workoutId: workoutId,
                            readOnly: false,
                            isTemporary: isTemporary,
                            minimized: true, // Indicate this workout was minimized
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: const Text('Continue'),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.red,
                    onPressed: () {
                      // Show confirmation dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF26272B),
                          title: Text('End Workout Session?', 
                              style: TextStyle(color: _textColor)),
                          content: Text(
                            'This will end your current workout. Progress will be saved and can be viewed in your workout history.',
                            style: TextStyle(color: _textColor.withOpacity(0.8)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel', 
                                  style: TextStyle(color: _textColor.withOpacity(0.8))),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                // Clear the active workout
                                WorkoutService.activeWorkoutNotifier.value = null;
                                Navigator.pop(context);
                              },
                              child: const Text('End Workout'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
