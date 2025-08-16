import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/foreground_service.dart';
import 'package:mental_warior/pages/workout/workout_session_page.dart';
import 'package:audioplayers/audioplayers.dart';

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
  Timer? _restTimer; // Add rest timer for background operation
  DateTime? _workoutStartTime;
  bool _isInitializing = true; // Add flag to track initialization state
  @override
  void initState() {
    super.initState();
    // Check if we have an active workout and set initialization state accordingly
    if (WorkoutService.activeWorkoutNotifier.value != null) {
      // We have an active workout, but need to initialize timer
      _isInitializing = true;
      _startTimer();
      _checkAndStartRestTimer();
    } else {
      // No active workout
      _isInitializing = false;
    }
    
    // Listen to changes in the active workout notifier
    WorkoutService.activeWorkoutNotifier.addListener(_handleActiveWorkoutChanged);
  }
  @override
  void dispose() {
    _stopTimer();
    _stopRestTimer();
    WorkoutService.activeWorkoutNotifier.removeListener(_handleActiveWorkoutChanged);
    super.dispose();
  }
  void _handleActiveWorkoutChanged() {
    if (WorkoutService.activeWorkoutNotifier.value != null) {
      // Reset initialization flag when we get a new active workout
      _isInitializing = true;
      
      // Start or restart the timer if we have an active workout
      if (_timer == null) {
        _startTimer();
      }
      // Check if we need to start a rest timer
      _checkAndStartRestTimer();
    } else {
      // Stop the timer if there's no active workout
      _stopTimer();
      _stopRestTimer();
      // Reset to initial state
      _isInitializing = true;
      _formattedTime = "00:00";
    }
  }
  
  void _startTimer() {
    // Get the current elapsed seconds from the active workout
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    if (activeWorkout == null) return;
    
    _elapsedSeconds = activeWorkout['duration'] as int;
    _formattedTime = _formatTime(_elapsedSeconds);

    // Clear initialization flag since we have real data now
    _isInitializing = false;
    
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
          _isInitializing =
              false; // We have real data, not initializing anymore
        }
        final isTemporary = activeWorkout['isTemporary'] as bool? ?? false;

        return GestureDetector(
          onTap: () {
            // Restore the workout session with current workout data
            final currentWorkoutData =
                activeWorkout['workoutData'] as Map<String, dynamic>?;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkoutSessionPage(
                  workoutId: workoutId,
                  readOnly: false,
                  isTemporary: isTemporary,
                  minimized: true, // Indicate this workout was minimized
                  restoredWorkoutData:
                      currentWorkoutData, // Pass the workout data
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
                            // Check for active rest timer
                            Builder(builder: (context) {
                              // If there's workout data that contains rest timer info
                              final bool hasRestTimer =
                                  activeWorkout.containsKey('workoutData') &&
                                      activeWorkout['workoutData'] != null &&
                                      activeWorkout['workoutData']
                                          .containsKey('restTimerState') &&
                                      (activeWorkout['workoutData']
                                              ['restTimerState']['isActive'] ??
                                          false);

                              // If rest timer is active, show a different icon and color
                              if (hasRestTimer) {
                                final restState = activeWorkout['workoutData']
                                    ['restTimerState'];
                                final isPaused = restState['isPaused'] ?? false;

                                return Icon(
                                  isPaused
                                      ? Icons.hourglass_empty
                                      : Icons.hourglass_bottom,
                                  color: Colors.orange,
                                  size: 14,
                                );
                              }

                              // Default workout timer icon
                              return Icon(
                                Icons.timer,
                                color: _primaryColor,
                                size: 14,
                              );
                            }),
                            const SizedBox(width: 4),
                            Builder(builder: (context) {
                              // Check if we have an active rest timer
                              final bool hasRestTimer =
                                  activeWorkout.containsKey('workoutData') &&
                                      activeWorkout['workoutData'] != null &&
                                      activeWorkout['workoutData']
                                          .containsKey('restTimerState') &&
                                      (activeWorkout['workoutData']
                                              ['restTimerState']['isActive'] ??
                                          false);
                              if (hasRestTimer) {
                                final restState = activeWorkout['workoutData']
                                    ['restTimerState'];
                                final int timeRemaining =
                                    restState['timeRemaining'] as int? ?? 0;
                                final bool isPaused =
                                    restState['isPaused'] as bool? ?? false;
                                final int? startTimeMs =
                                    restState['startTime'] as int?;
                                final int originalTime =
                                    restState['originalTime'] as int? ??
                                        timeRemaining;
                                final int? setId = restState['setId'] as int?;

                                // Calculate accurate remaining time based on start time (like workout timer)
                                int adjustedTime = timeRemaining;

                                // If timer is running (not paused) and we have start time,
                                // calculate elapsed time since timer started
                                if (!isPaused && startTimeMs != null) {
                                  final restStartTime =
                                      DateTime.fromMillisecondsSinceEpoch(
                                          startTimeMs);
                                  final elapsed = DateTime.now()
                                      .difference(restStartTime)
                                      .inSeconds;
                                  adjustedTime = (originalTime - elapsed)
                                      .clamp(0, originalTime);
                                }

                                final String restTimeDisplay = _formatTime(
                                    adjustedTime); // Show rest timer with set info and orange color
                                String displayText = 'Rest: $restTimeDisplay';
                                if (setId != null) {
                                  // Try to find exercise and set info for better display
                                  final exercises = activeWorkout['workoutData']
                                      ['exercises'] as List?;
                                  if (exercises != null) {
                                    for (final exercise in exercises) {
                                      final sets = exercise['sets'] as List?;
                                      if (sets != null) {
                                        final set = sets.firstWhere(
                                            (s) => s['id'] == setId,
                                            orElse: () => null);
                                        if (set != null) {
                                          final setNumber =
                                              set['setNumber'] as int? ?? 1;
                                          final exerciseName =
                                              exercise['name'] as String? ?? '';

                                          // Clean up exercise name if it has API ID
                                          String cleanExerciseName =
                                              exerciseName;
                                          final RegExp apiIdRegex =
                                              RegExp(r'##API_ID:[^#]+##');
                                          cleanExerciseName = cleanExerciseName
                                              .replaceAll(apiIdRegex, '');

                                          // Show exercise name and set number for better context
                                          if (cleanExerciseName.length > 15) {
                                            cleanExerciseName =
                                                '${cleanExerciseName.substring(0, 12)}...';
                                          }
                                          displayText =
                                              '$cleanExerciseName Set $setNumber: $restTimeDisplay';
                                          break;
                                        }
                                      }
                                    }
                                  }
                                }

                                return Text(
                                  displayText,
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              // Default to showing workout duration or loading state
                              if (_isInitializing &&
                                  _formattedTime == "00:00") {
                                // Show loading indicator for the brief initialization period
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _textColor.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Loading...',
                                      style: TextStyle(
                                        color: _textColor.withOpacity(0.6),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Text(
                                _formattedTime,
                                style: TextStyle(
                                  color: _textColor.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: _timer != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }),
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
                      // Restore the workout session with current workout data
                      final currentWorkoutData =
                          activeWorkout['workoutData'] as Map<String, dynamic>?;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutSessionPage(
                            workoutId: workoutId,
                            readOnly: false,
                            isTemporary: isTemporary,
                            minimized: true, // Indicate this workout was minimized
                            restoredWorkoutData:
                                currentWorkoutData, // Pass the workout data
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
                      // Show options dialog for ending or discarding workout
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF26272B),
                          title: Text('Workout Session Options', 
                              style: TextStyle(color: _textColor)),
                          content: Text(
                            'Choose how you want to handle your current workout:',
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
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                // End workout - save progress
                                try {
                                  final activeWorkout = WorkoutService
                                      .activeWorkoutNotifier.value;
                                  if (activeWorkout != null) {
                                    final workoutId =
                                        activeWorkout['id'] as int;
                                    final isTemporary =
                                        activeWorkout['isTemporary'] as bool? ??
                                            false;

                                    // If it's a temporary workout, save it to the database
                                    if (isTemporary && workoutId > 0) {
                                      final workoutService = WorkoutService();
                                      await workoutService
                                          .saveTemporaryWorkout(workoutId);
                                      print(
                                          '✅ Temporary workout saved permanently');
                                    }
                                  }

                                  // Clear active workout from memory
                                  WorkoutService.activeWorkoutNotifier.value =
                                      null;

                                  // Stop the foreground service and clear its data
                                  await WorkoutForegroundService
                                      .stopWorkoutService();
                                  await WorkoutForegroundService
                                      .clearSavedWorkoutData();

                                  print(
                                      '✅ Workout ended and saved successfully');
                                } catch (e) {
                                  print('❌ Error saving workout: $e');
                                }
                                Navigator.pop(context);
                              },
                              child: const Text('End & Save'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                // Discard workout - mark for discard and clear active state
                                try {
                                  // First mark as discarded
                                  await WorkoutForegroundService
                                      .markWorkoutAsDiscarded();
                                  print('✅ Workout marked as discarded');

                                  // Clear active workout from memory
                                  WorkoutService.activeWorkoutNotifier.value =
                                      null;
                                  
                                  // Stop the foreground service
                                  await WorkoutForegroundService
                                      .stopWorkoutService();

                                  // Do NOT call clearSavedWorkoutData() here - let the restoration process handle it
                                  // This ensures the discard flag persists until the next app startup

                                  print('✅ Workout discarded successfully');
                                } catch (e) {
                                  print('❌ Error discarding workout: $e');
                                }
                                Navigator.pop(context);
                              },
                              child: const Text('Discard'),
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
  
  void _stopRestTimer() {
    if (_restTimer != null) {
      _restTimer!.cancel();
      _restTimer = null;
    }
  }

  void _checkAndStartRestTimer() {
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    if (activeWorkout == null) return;

    // Check if there's an active rest timer in the workout data
    final workoutData = activeWorkout['workoutData'] as Map<String, dynamic>?;
    if (workoutData?.containsKey('restTimerState') == true) {
      final restState = workoutData!['restTimerState'] as Map<String, dynamic>;
      final bool isActive = restState['isActive'] as bool? ?? false;
      final bool isPaused = restState['isPaused'] as bool? ?? false;

      if (isActive && !isPaused) {
        // Start the background rest timer if not already running
        if (_restTimer == null) {
          _startBackgroundRestTimer();
        }
      } else {
        _stopRestTimer();
      }
    } else {
      _stopRestTimer();
    }
  }

  void _startBackgroundRestTimer() {
    _stopRestTimer(); // Stop any existing timer

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
      if (activeWorkout == null) {
        timer.cancel();
        return;
      }

      final workoutData = activeWorkout['workoutData'] as Map<String, dynamic>?;
      if (workoutData?.containsKey('restTimerState') != true) {
        timer.cancel();
        return;
      }

      final restState = workoutData!['restTimerState'] as Map<String, dynamic>;
      final bool isActive = restState['isActive'] as bool? ?? false;
      final bool isPaused = restState['isPaused'] as bool? ?? false;
      final int? startTimeMs = restState['startTime'] as int?;
      final int originalTime = restState['originalTime'] as int? ?? 0;

      if (!isActive || isPaused || startTimeMs == null) {
        timer.cancel();
        return;
      }

      // Calculate remaining time
      final restStartTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
      final elapsed = DateTime.now().difference(restStartTime).inSeconds;
      final timeRemaining = (originalTime - elapsed).clamp(0, originalTime);

      if (timeRemaining <= 0) {
        // Timer finished! Play the bell sound and update the workout data
        _playBoxingBellSound();
        _clearRestTimerFromWorkoutData();
        timer.cancel();
        _restTimer = null;
      }
    });
  }

  Future<void> _playBoxingBellSound() async {
    try {
      // Import audioplayers at the top of the file if not already imported
      final player = AudioPlayer();
      await player.setSource(AssetSource('audio/BoxingBell.mp3'));
      await player.setReleaseMode(ReleaseMode.release);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.0);

      // Set audio context for background playback - use notification sounds that don't interrupt music
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));

      await player.resume();
      print(
          "Boxing bell sound played from active workout bar - rest timer completed");

      // Dispose after sound completes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Error playing boxing bell from active workout bar: $e');
    }
  }

  void _clearRestTimerFromWorkoutData() {
    final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
    if (activeWorkout == null) return;

    final workoutData = Map<String, dynamic>.from(
        activeWorkout['workoutData'] as Map<String, dynamic>? ?? {});
    if (workoutData.containsKey('restTimerState')) {
      workoutData['restTimerState'] = {
        'isActive': false,
        'setId': null,
        'timeRemaining': 0,
        'originalTime': 0,
        'isPaused': false,
        'startTime': null,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Update the active workout notifier
      WorkoutService.activeWorkoutNotifier.value = {
        ...activeWorkout,
        'workoutData': workoutData,
      };
    }
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
