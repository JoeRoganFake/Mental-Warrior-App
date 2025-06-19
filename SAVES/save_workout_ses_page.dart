import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/rest_timer_page.dart';
import 'package:audioplayers/audioplayers.dart';

class WorkoutSessionPage extends StatefulWidget {
  final int workoutId;
  final bool readOnly;
  final bool isTemporary;
  final bool minimized;

  const WorkoutSessionPage({
    super.key,
    required this.workoutId,
    this.readOnly = false,
    this.isTemporary = false,
    this.minimized = false,
  });

  @override
  WorkoutSessionPageState createState() => WorkoutSessionPageState();
}

class WorkoutSessionPageState extends State<WorkoutSessionPage>
    with WidgetsBindingObserver {
  final WorkoutService _workoutService = WorkoutService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Workout? _workout;
  bool _isLoading = true;
  bool _isTimerRunning = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  Timer? _restTimer;
  int _restTimeRemaining = 0;
  int? _currentRestSetId;
  final TextEditingController _nameController = TextEditingController();
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};
  
  // Theme colors
  final Color _backgroundColor = Color(0xFF1A1B1E); // Dark background
  final Color _surfaceColor = Color(0xFF26272B); // Surface for cards
  final Color _primaryColor = Color(0xFF3F8EFC); // Blue accent
  final Color _successColor = Color(0xFF4CAF50); // Green for success
  final Color _dangerColor = Color(0xFFE53935); // Red for cancel/danger
  final Color _textPrimaryColor = Colors.white; // Main text
  final Color _textSecondaryColor = Color(0xFFBBBBBB); // Secondary text
  final Color _inputBgColor = Color(0xFF303136); // Input background

  // Default rest time
  final int _defaultRestTime = 90; // 1:30 min  // Timer tracking variables
  DateTime? _workoutStartTime; // To track real-world time elapsed
  // Shared rest timer state
  final ValueNotifier<int> _restRemainingNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _restPausedNotifier = ValueNotifier(false);
  int _originalRestTime = 0;  
  DateTime?
      _restStartTime; // Track when rest timer started (like workout timer)
  
  // Variables to track minimized workout restoration
  bool _isRestoringFromMinimized = false;
  Map<String, dynamic>? _savedWorkoutData;
  @override
  void initState() {
    super.initState();
    // Add app lifecycle observer for better handling of background/foreground transitions
    WidgetsBinding.instance.addObserver(this);
    _loadWorkout(); // If this was a minimized workout being restored
    if (widget.minimized &&
        WorkoutService.activeWorkoutNotifier.value != null) {
      print("Restoring minimized workout");
      // Store reference to the active workout data before clearing it
      final activeWorkout = WorkoutService.activeWorkoutNotifier.value!;
      
      // Get the current elapsed time from the notifier
      _elapsedSeconds = activeWorkout['duration'] as int;
      print("Restored elapsed time: $_elapsedSeconds seconds");
      
      // Save the workout data for restoration after _loadWorkout completes
      final workoutData = activeWorkout['workoutData'] as Map<String, dynamic>?;

      // We're maximizing the workout now, so clear the notifier
      // Defer clearing the notifier until after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WorkoutService.activeWorkoutNotifier.value = null;
      });
      
      // Start the timer with the restored elapsed seconds
      _startTimer();
      print("Started timer after workout restoration");
      
      // Wait for the workout to be fully loaded before restoring data
      if (workoutData != null) {
        _isRestoringFromMinimized = true; // Flag to track restoration process
        _savedWorkoutData = workoutData; // Save the data for later use
        print(
            "Saved workout data for restoration"); // Check if we need to immediately restore a rest timer
        // This ensures the rest timer doesn't get interrupted during minimization
        if (workoutData.containsKey('restTimerState')) {
          final restState =
              workoutData['restTimerState'] as Map<String, dynamic>;
          final bool isActive = restState['isActive'] as bool;

          if (isActive) {
            final int setId = restState['setId'] as int? ?? -1;
            final int timeRemaining = restState['timeRemaining'] as int? ?? 0;
            print(
                "Found active rest timer state to restore - SetID: $setId, Time Remaining: $timeRemaining seconds");

            // Set a flag to prioritize the rest timer restoration
            if (timeRemaining > 0) {
              print("Setting high priority for rest timer restoration");
            }
          }
          // Full timer restoration will be handled in _restoreWorkoutData after workout loads
        }
      }
    }
    // Otherwise start a new timer if this is not in read-only mode
    else if (!widget.readOnly) {
      _startTimer();
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is going to background
      // Save the current timer state to database
      if (_isTimerRunning) {
        _updateWorkoutDuration();
      }
      
      // Save the current state to the notifier for all workouts (including minimized)
      // This ensures timers continue to work even when app is backgrounded
      if (_workout != null && !widget.readOnly) {
        // Create a serialized version of the workout with all exercise data and timer state
        final workoutData = _serializeWorkoutData();

        // Ensure the workout duration is accurate before going to background
        if (_workoutStartTime != null && _isTimerRunning) {
          _elapsedSeconds =
              DateTime.now().difference(_workoutStartTime!).inSeconds;
        }

        // This will help restore the state if the app is killed and restarted
        // or when coming back from background
        WorkoutService.activeWorkoutNotifier.value = {
          'id': widget.workoutId,
          'name': _workout!.name,
          'duration': _elapsedSeconds,
          'isTemporary': widget.isTemporary,
          'workoutData': workoutData,
          'backgroundedAt': DateTime.now().millisecondsSinceEpoch,
        };
      }
    } else if (state == AppLifecycleState.resumed) {
      // App is coming back to foreground
      if (_isTimerRunning && _workoutStartTime != null) {
        // Recalculate elapsed time based on real-world time
        final now = DateTime.now();
        final newElapsedSeconds = now.difference(_workoutStartTime!).inSeconds;

        if (newElapsedSeconds != _elapsedSeconds) {
          setState(() {
            _elapsedSeconds = newElapsedSeconds;
          });
        }
      }
      // Rest timer recalculation based on real-world time (like workout timer)
      if (_currentRestSetId != null &&
          _restStartTime != null &&
          !_restPausedNotifier.value) {
        final elapsed = DateTime.now().difference(_restStartTime!).inSeconds;
        final newTimeRemaining =
            (_originalRestTime - elapsed).clamp(0, _originalRestTime);

        if (newTimeRemaining != _restTimeRemaining) {
          setState(() {
            _restTimeRemaining = newTimeRemaining;
            _restRemainingNotifier.value = newTimeRemaining;
          });
          _updateActiveNotifier();
        }
        
        // If timer expired while in background, play the sound and clear timer
        if (newTimeRemaining <= 0) {
          _playBoxingBellSound();
          if (mounted) {
            setState(() {
              _currentRestSetId = null;
              _restStartTime = null;
            });
          }
          _updateActiveNotifier();
        }
        // If the timer somehow got lost but we're still tracking a rest period, restart it
        if (_restTimer == null && _restTimeRemaining > 0) {
          print(
              "Restoring lost rest timer with $_restTimeRemaining seconds remaining");
          // Restart the timer with real-world time tracking
          _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted || _restPausedNotifier.value) return;

            if (_restStartTime != null) {
              final elapsed =
                  DateTime.now().difference(_restStartTime!).inSeconds;
              final newTimeRemaining =
                  (_originalRestTime - elapsed).clamp(0, _originalRestTime);

              if (newTimeRemaining != _restRemainingNotifier.value) {
                setState(() {
                  _restRemainingNotifier.value = newTimeRemaining;
                  _restTimeRemaining = newTimeRemaining;
                });
                _updateActiveNotifier();
              }

              if (newTimeRemaining <= 0) {
                timer.cancel();
                _restTimer = null;
                _playBoxingBellSound();
                if (mounted) {
                  setState(() {
                    _currentRestSetId = null;
                    _restStartTime = null;
                  });
                }
                _updateActiveNotifier();
              }
            }
          });
        }

        // Ensure UI shows correct time
        if (mounted) {
          setState(() {});
        }
      }
    }
  } // Flag to track if we're minimizing the workout

  bool _isMinimizing = false;
  
  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Only stop timers if we're not minimizing
    // Use our explicit flag rather than checking the notifier
    if (!_isMinimizing) {
      print("Dispose: Stopping timers as we're closing the workout");
      _stopTimer();
      _cancelRestTimer();
    } else {
      // If we're minimizing, make sure we have the latest data for the workout timer
      if (_workoutStartTime != null && _isTimerRunning) {
        _elapsedSeconds =
            DateTime.now().difference(_workoutStartTime!).inSeconds;
        print("Dispose: Minimizing workout - keeping timers alive");
        // No need to save since the workout_minimizer will handle this
      }
      
      // Also ensure rest timer state is properly preserved
      if (_currentRestSetId != null && _restTimeRemaining > 0) {
        print(
            "Dispose: Preserving rest timer with $_restTimeRemaining seconds remaining for SetID: $_currentRestSetId");
        // The timer state is saved through the _isMinimizing flag which prevents cancellation
      }
    }
    
    _nameController.dispose();
    for (var c in _weightControllers.values) {
      c.dispose();
    }
    for (var c in _repsControllers.values) {
      c.dispose();
    }
    
    // If this was a temporary workout and we're navigating away without saving,
    // discard the temporary workout
    if (widget.isTemporary && mounted) {
      // Check if any exercises were added
      bool hasExercises = _workout?.exercises.isNotEmpty ?? false;

      // If nothing was added, just discard it
      if (!hasExercises) {
        _workoutService.discardTemporaryWorkout(widget.workoutId);
      }
    }
    
    // Release audio player resources
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadWorkout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Workout? workout;
      // Check if this is a temporary workout
      if (widget.isTemporary) {
        // Get temporary workout data from memory
        final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
        if (tempWorkouts.containsKey(widget.workoutId)) {
          final tempData = tempWorkouts[widget.workoutId];

          // Build exercises list from temp workout data
          List<Exercise> exercises = [];
          if (tempData.containsKey('exercises') &&
              tempData['exercises'] is List) {
            for (var exerciseData in tempData['exercises']) {
              final exerciseId = exerciseData['id'] ??
                  -(DateTime.now().millisecondsSinceEpoch);

              // Build sets list for this exercise
              List<ExerciseSet> sets = [];
              if (exerciseData.containsKey('sets') &&
                  exerciseData['sets'] is List) {
                for (var setData in exerciseData['sets']) {
                  final setId =
                      setData['id'] ?? -(DateTime.now().millisecondsSinceEpoch);
                  sets.add(ExerciseSet(
                    id: setId,
                    exerciseId: exerciseId,
                    setNumber: setData['setNumber'] ?? 1,
                    weight: setData['weight'] ?? 0,
                    reps: setData['reps'] ?? 0,
                    restTime: setData['restTime'] ?? _defaultRestTime,
                    completed: setData['completed'] ?? false,
                  ));
                }
              }

              // Add exercise with its sets
              exercises.add(Exercise(
                id: exerciseId,
                workoutId: widget.workoutId,
                name: exerciseData['name'] ?? 'Exercise',
                equipment: exerciseData['equipment'] ?? '',
                sets: sets,
              ));
            }
          }

          // Create a Workout object from temporary data
          workout = Workout(
            id: widget.workoutId,
            name: tempData['name'],
            date: tempData['date'],
            duration: tempData['duration'],
            exercises: exercises, // Now properly loaded from temp data
          );
        }
      } else {
        // Regular database workout
        workout = await _workoutService.getWorkout(widget.workoutId);
      }

      if (workout != null) {
        if (mounted) {
          // Check if widget is still mounted before updating state
          setState(() {
            _workout = workout;
            _nameController.text = workout!.name;
            // Only set the elapsed seconds during the initial load, not on refreshes
            // This prevents timer resetting when adding exercises
            if (_elapsedSeconds == 0) {
              _elapsedSeconds = workout.duration;
            }
            _isLoading =
                false; // If we're restoring from minimized state, apply the saved data
            if (_isRestoringFromMinimized && _savedWorkoutData != null) {
              print("About to restore workout data after loading");
              // Add a slight delay to ensure everything is initialized
              Future.delayed(Duration(milliseconds: 200), () {
                print("Restoring workout data after initialization delay");
                _restoreWorkoutData(_savedWorkoutData!);

                // Restart workout timer after restoration
                if (!_isTimerRunning) {
                  _startTimer();
                }

                // Force another UI refresh after all restoration is complete
                Future.delayed(Duration(milliseconds: 100), () {
                  if (mounted) {
                    setState(() {});
                    print("Forced additional UI refresh after restoration");
                  }
                });
                
                _isRestoringFromMinimized = false;
                _savedWorkoutData = null;
              });
            }
          });
        }
      } else {
        if (mounted) {
          _showSnackBar('Workout not found', isError: true);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading workout: $e', isError: true);
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    if (_isTimerRunning) return;
    
    // Set the start time for accurate tracking even when app is in background
    _workoutStartTime ??=
        DateTime.now().subtract(Duration(seconds: _elapsedSeconds));

    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Calculate elapsed time based on real-world time difference
      // This allows the timer to accurately track time even when the app is in background
      final now = DateTime.now();
      final newElapsedSeconds = now.difference(_workoutStartTime!).inSeconds;

      // Only update if the value has changed
      if (newElapsedSeconds != _elapsedSeconds) {
        // Update the elapsed seconds based on the actual time difference
        _elapsedSeconds = newElapsedSeconds;

        // Only update UI if the widget is still mounted
        if (mounted) {
          // Update timer display without rebuilding the entire widget
          setState(() {});
          
          // Update workout duration in database less frequently
          if (_elapsedSeconds % 15 == 0) {
            _updateWorkoutDuration();
          }
        }
      }
    });
  }
  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    // Before stopping timer, ensure we have the most accurate elapsed time
    if (_workoutStartTime != null) {
      _elapsedSeconds = DateTime.now().difference(_workoutStartTime!).inSeconds;
    }

    if (mounted) {
      setState(() {
        _isTimerRunning = false;
      });
    }

    // Final update to the workout duration
    _updateWorkoutDuration();
  }
  void _updateWorkoutDuration() {
    // Update workout duration 
    if (_workout != null) {
      // Make sure we save the most accurate time
      if (_workoutStartTime != null && _isTimerRunning) {
        _elapsedSeconds =
            DateTime.now().difference(_workoutStartTime!).inSeconds;
      }

      if (widget.isTemporary) {
        // Update the temporary workout in memory
        final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
        if (tempWorkouts.containsKey(widget.workoutId)) {
          tempWorkouts[widget.workoutId]['duration'] = _elapsedSeconds;
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      } else {
        // Update regular workout in database
        _workoutService.updateWorkoutDuration(
          widget.workoutId,
          _elapsedSeconds,
        );
      }
    }
  }
  String _formatTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
  /// Play the boxing bell sound effect
  Future<void> _playBoxingBellSound() async {
    // Create a fresh player for each bell to allow replay
    final player = AudioPlayer();
    try {
      await player.setSource(AssetSource('audio/BoxingBell.mp3'));
      await player.setReleaseMode(ReleaseMode.release);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.0); // Ensure full volume

      // Set audio context for better background support
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType:
              AndroidUsageType.alarm, // Use alarm usage for background playback
          audioFocus: AndroidAudioFocus.gain,
        ),
      ));
      
      await player.resume();
      print("Boxing bell sound played - rest timer completed");
      
      // Dispose after sound completes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Error playing boxing bell: $e');
      player.dispose();
    }
  }
  
  /// Play the chime sound effect for set completion
  Future<void> _playChimeSound() async {
    // Create a new player per chime to allow multiple replays
    final player = AudioPlayer();
    try {
      await player.setSource(
          AssetSource('audio/11L-Subtle_mobile_Chime_-1748795262788.mp3'));
      await player.setReleaseMode(ReleaseMode.release);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(0.8);
      await player.resume();
      // Dispose player once playback completes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Error playing chime: $e');
      player.dispose();
    }
  }

  /// Starts a rest timer for a specific set and tracks its id
  void _startRestTimerForSet(int setId, int seconds) {
    // Cancel any ongoing rest timer without playing boxing bell
    _cancelRestTimer(playSound: false);
    
    // Set the rest start time for accurate tracking (like workout timer)
    _restStartTime = DateTime.now();
    
    if (mounted) {
      setState(() {
        _currentRestSetId = setId;
        _restTimeRemaining = seconds;
        _originalRestTime = seconds;
        _restPausedNotifier.value = false;
        _restRemainingNotifier.value = seconds;
      });
    }
    
    // Immediately synchronize state for minimized bar
    _updateActiveNotifier();
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Skip if not mounted or paused
      if (!mounted || _restPausedNotifier.value) return;
      
      // Calculate remaining time based on real-world time difference (like workout timer)
      if (_restStartTime != null) {
        final elapsed = DateTime.now().difference(_restStartTime!).inSeconds;
        final newTimeRemaining =
            (_originalRestTime - elapsed).clamp(0, _originalRestTime);

        if (newTimeRemaining != _restRemainingNotifier.value) {
          setState(() {
            _restTimeRemaining = newTimeRemaining;
            _restRemainingNotifier.value = newTimeRemaining;
          });
          // Update shared notifier so minimized bar reflects new time
          _updateActiveNotifier();
        }
        
        // Check if timer finished
        if (newTimeRemaining <= 0) {
          timer.cancel();
          _restTimer = null;
          // Play the boxing bell sound when timer finishes - this will work even in background
          _playBoxingBellSound();
          if (mounted) {
            setState(() {
              _currentRestSetId = null;
              _restStartTime = null;
            });
          }
          // Final update after timer ends
          _updateActiveNotifier();
        }
      }
    });
  }
  void _cancelRestTimer({bool playSound = true}) {
    // Don't cancel the rest timer if we're minimizing the app or restoring from minimized
    if (_isMinimizing || _isRestoringFromMinimized) {
      print("Not canceling rest timer - app is being minimized or restored");
      return;
    }
    
    if (_restTimer != null) {
      _restTimer!.cancel();
      _restTimer = null;
      
      // Play the boxing bell sound only when requested (skipping timer, not when uncompleting a set)
      if (playSound) {
        _playBoxingBellSound();
      }
    }
    
    if (mounted) {
      setState(() {
        _restTimeRemaining = 0;
        _currentRestSetId = null;
        _restStartTime = null;
        _restPausedNotifier.value = false;
        _restRemainingNotifier.value = 0;
      });
    }
  }
  void _togglePauseRest() {
    if (_restPausedNotifier.value) {
      // Resume: recalculate start time to account for paused duration
      if (_restStartTime != null) {
        final timeElapsedBeforePause = _originalRestTime - _restTimeRemaining;
        _restStartTime =
            DateTime.now().subtract(Duration(seconds: timeElapsedBeforePause));
      }
      _restPausedNotifier.value = false;
    } else {
      // Pause: just set the flag
      _restPausedNotifier.value = true;
    }
    _updateActiveNotifier();
  }

  void _incrementRest() {
    // Add 15 seconds to both original time and remaining time
    _originalRestTime += 15;

    // Calculate current elapsed time
    if (_restStartTime != null) {
      final currentElapsed =
          DateTime.now().difference(_restStartTime!).inSeconds;
      // Set the new remaining time
      final newRemainingTime = _originalRestTime - currentElapsed;
      _restRemainingNotifier.value =
          newRemainingTime.clamp(0, _originalRestTime);

      if (mounted) {
        setState(() => _restTimeRemaining = _restRemainingNotifier.value);
      }
    } else {
      // If no start time, just add 15 seconds to remaining time
      _restRemainingNotifier.value += 15;
      if (mounted) {
        setState(() => _restTimeRemaining = _restRemainingNotifier.value);
      }
    }

    _updateActiveNotifier();
  }

  void _decrementRest() {
    // Subtract 15 seconds from both original time and remaining time
    final newOriginalTime = (_originalRestTime - 15)
        .clamp(15, _originalRestTime); // Keep minimum of 15 seconds
    _originalRestTime = newOriginalTime;

    // Calculate current elapsed time
    if (_restStartTime != null) {
      final currentElapsed =
          DateTime.now().difference(_restStartTime!).inSeconds;
      // Set the new remaining time
      final newRemainingTime = _originalRestTime - currentElapsed;
      _restRemainingNotifier.value =
          newRemainingTime.clamp(0, _originalRestTime);

      if (mounted) {
        setState(() => _restTimeRemaining = _restRemainingNotifier.value);
      }

      // If time is up or very low, cancel the timer
      if (_restRemainingNotifier.value <= 0) {
        _cancelRestTimer(playSound: true);
        return;
      }
    } else {
      // If no start time, just subtract 15 seconds from remaining time
      final newRemainingTime = (_restRemainingNotifier.value - 15)
          .clamp(0, _restRemainingNotifier.value);
      _restRemainingNotifier.value = newRemainingTime;

      if (mounted) {
        setState(() => _restTimeRemaining = newRemainingTime);
      }
      
      if (newRemainingTime <= 0) {
        _cancelRestTimer(playSound: true);
        return;
      }
    }

    _updateActiveNotifier();
  }

  void _addExercise() async {
    if (widget.readOnly) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseSelectionPage(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final exerciseName = result['name'] as String;
      final equipment = result['equipment'] as String? ?? '';
      final apiId = result['apiId'] as String? ??
          ''; // Get API ID from the selection result

      setState(() {
        _isLoading = true;
      });

      try {
        // Add exercise to the database
        final exerciseId = await _workoutService.addExercise(
          widget.workoutId,
          exerciseName,
          equipment,
        );

        // Store the API ID in the exercise name with a special marker
        if (apiId.isNotEmpty) {
          await _workoutService.updateExercise(
              exerciseId,
              "$exerciseName ##API_ID:$apiId##", // Store API ID in the name with a special marker
              equipment);
        }

        // Add a set with null/empty values that will be displayed as empty fields in UI
        // The database needs some value, but we'll use the `_buildSetItem` logic to show empty fields
        await _workoutService.addSet(
          exerciseId,
          1, // Set number
          0, // Weight - will be displayed as empty
          0, // Reps - will be displayed as empty
          _defaultRestTime, // Default rest time
        );

        _loadWorkout();
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error adding exercise: $e', isError: true);
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  void _updateWorkoutName() {
    if (widget.readOnly) return;

    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && _workout != null) {
      // Update local state immediately
      if (mounted) {
        setState(() {
          _workout = Workout(
            id: _workout!.id,
            name: newName,
            date: _workout!.date,
            duration: _workout!.duration,
            exercises: _workout!.exercises,
          );
        });
      }

      if (widget.isTemporary) {
        // Update the temporary workout in memory
        final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
        if (tempWorkouts.containsKey(widget.workoutId)) {
          tempWorkouts[widget.workoutId]['name'] = newName;
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      } else {
        // Then update database in background
        _workoutService.updateWorkout(
          widget.workoutId,
          newName,
          _workout!.date,
          _workout!.duration,
        );
      }
    }
  }

  void _addSetToExercise(int exerciseId) async {
    final exerciseIndex =
        _workout!.exercises.indexWhere((e) => e.id == exerciseId);

    if (exerciseIndex == -1) return;

    final exercise = _workout!.exercises[exerciseIndex];
    final setNumber = exercise.sets.length + 1;

    // Show a loading indicator in the exercise card
    if (mounted) {
      setState(() {
        // We can add a temporary loading state flag here if needed
      });
    }

    try {
      // Add set to database - store empty fields as null in database
      final newSetId = await _workoutService.addSet(
        exerciseId,
        setNumber,
        0, // Initial weight (we'll show empty field in UI)
        0, // Initial reps (we'll show empty field in UI)
        _defaultRestTime, // Default rest time
      );

      // If we have the new set ID, create a local Set object and add it to our state
      if (mounted) {
        final newSet = ExerciseSet(
          id: newSetId,
          exerciseId: exerciseId,
          setNumber: setNumber,
          weight: 0, // This will be displayed as empty field
          reps: 0, // This will be displayed as empty field
          restTime: _defaultRestTime,
          completed: false,
        );

        // Update the UI immediately without a full reload
        setState(() {
          _workout!.exercises[exerciseIndex].sets.add(newSet);
        });
      } else {
        // If we couldn't get the new set ID, fall back to full reload
        _loadWorkout();
      }
    } catch (e) {
      // Handle error case
      if (mounted) {
        _showSnackBar('Error adding set: $e', isError: true);
      }
    }
  }

  void _toggleSetCompletion(int exerciseId, int setId, bool completed) async {
    // First update UI immediately without waiting for database operation
    if (mounted) {
      setState(() {
        // Find and update the set in the local state
        for (var exercise in _workout!.exercises) {
          if (exercise.id == exerciseId) {
            for (var set in exercise.sets) {
              if (set.id == setId) {
                set.completed = completed;
                // Play a sound when completing a set (not when uncompleting)
                if (completed) {
                  _playChimeSound();
                }
                break;
              }
            }
            break;
          }
        }
      });
    }

    // Then perform the database update in the background
    await _updateSetComplete(setId, completed);

    // No need to call _loadWorkout() since we already updated UI state
    // This prevents the screen freeze when toggling set completion
  }
  Future<void> _updateSetComplete(int setId, bool completed) async {
    // Handle temporary workouts (setId < 0)
    if (widget.isTemporary || setId < 0) {
      // Update the set in memory
      final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
      if (tempWorkouts.containsKey(widget.workoutId)) {
        bool found = false;
        final exercises = tempWorkouts[widget.workoutId]['exercises'];
        for (var i = 0; i < exercises.length && !found; i++) {
          final sets = exercises[i]['sets'];
          for (var j = 0; j < sets.length && !found; j++) {
            if (sets[j]['id'] == setId) {
              sets[j]['completed'] = completed;
              found = true;
            }
          }
        }
        if (found) {
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
          WorkoutService.workoutsUpdatedNotifier.value =
              !WorkoutService.workoutsUpdatedNotifier.value;
        }
      }
    } else {
      // Update in database for regular workouts
      final db = await DatabaseService.instance.database;
      await db.update(
        'exercise_sets',
        {'completed': completed ? 1 : 0},
        where: 'id = ?',
        whereArgs: [setId],
      );
      WorkoutService.workoutsUpdatedNotifier.value =
          !WorkoutService.workoutsUpdatedNotifier.value;
    }
  }

  Future<void> _updateSetData(
    int setId,
    double weight,
    int reps,
    int restTime,
  ) async {
    // Validate that weight is >= 0 (can be decimal) and reps is >= 0 (must be integer)
    // No need to block zero values as per new requirements
    if (weight < 0 || reps < 0) {
      // If invalid values, don't update the database
      if (mounted) {
        // Reset controller values if needed
        for (var exercise in _workout!.exercises) {
          for (var set in exercise.sets) {
            if (set.id == setId) {
              if (weight < 0) {
                _weightControllers[set.id]?.text = set.weight >= 0
                    ? ((set.weight % 1 == 0)
                        ? set.weight.toInt().toString()
                        : set.weight.toString())
                    : '';
              }
              if (reps < 0) {
                _repsControllers[set.id]?.text =
                    set.reps >= 0 ? set.reps.toString() : '';
              }
              break;
            }
          }
        }
      }
      return;
    }
    
    // First, update the local state to avoid UI freeze
    if (mounted) {
      setState(() {
        // Find and update the set in the local state
        for (var exercise in _workout!.exercises) {
          for (var set in exercise.sets) {
            if (set.id == setId) {
              set.weight = weight;
              set.reps = reps;
              set.restTime = restTime;
              break;
            }
          }
        }
      });
    } // Handle temporary vs regular workouts differently for database updates
    if (widget.isTemporary || setId < 0) {
      // Update set in memory
      final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
      if (tempWorkouts.containsKey(widget.workoutId)) {
        bool found = false;
        final exercises = tempWorkouts[widget.workoutId]['exercises'];
        for (var i = 0; i < exercises.length && !found; i++) {
          final sets = exercises[i]['sets'];
          for (var j = 0; j < sets.length && !found; j++) {
            if (sets[j]['id'] == setId) {
              sets[j]['weight'] = weight;
              sets[j]['reps'] = reps;
              sets[j]['restTime'] = restTime;
              found = true;
            }
          }
        }
        if (found) {
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      }
    } else {
      // Update the database for regular workouts
      final db = await DatabaseService.instance.database;
      await db.update(
        'exercise_sets',
        {
          'weight': weight,
          'reps': reps,
          'restTime': restTime,
        },
        where: 'id = ?',
        whereArgs: [setId],
      );
    }

    // Notify listeners in either case
    WorkoutService.workoutsUpdatedNotifier.value =
        !WorkoutService.workoutsUpdatedNotifier.value;
  }


  Future<void> _deleteSet(int exerciseId, int setId) async {
    // Find the exercise and set in our local state
    final exerciseIndex =
        _workout!.exercises.indexWhere((e) => e.id == exerciseId);
    if (exerciseIndex == -1) return;

    final exercise = _workout!.exercises[exerciseIndex];
    final setIndex = exercise.sets.indexWhere((s) => s.id == setId);
    if (setIndex == -1) return;

    // Check if this is the last set for this exercise
    final bool isLastSet = exercise.sets.length == 1;

    // If it's the last set, delete the entire exercise
    if (isLastSet) {
      // Delete the exercise from UI immediately
      if (mounted) {
        setState(() {
          _workout!.exercises.removeAt(exerciseIndex);
        });
      }

      await _deleteExercise(exerciseId);
    }

    // Update the local state first to immediately reflect the deletion in the UI
    if (mounted) {
      setState(() {
        // Remove the set from our local state
        _workout!.exercises[exerciseIndex].sets.removeAt(setIndex);

        // Since we can't directly modify the setNumber (it's final), we need to
        // create new set objects with updated set numbers
        if (exercise.sets.length > 0) {
          final List<ExerciseSet> updatedSets = [];

          // Create new set objects with correct numbers
          for (int i = 0; i < exercise.sets.length; i++) {
            final oldSet = exercise.sets[i];
            updatedSets.add(ExerciseSet(
              id: oldSet.id,
              exerciseId: oldSet.exerciseId,
              setNumber: i + 1, // New sequential set number
              weight: oldSet.weight,
              reps: oldSet.reps,
              restTime: oldSet.restTime,
              completed: oldSet.completed,
            ));
          }

          // Replace the sets list with our updated one
          _workout!.exercises[exerciseIndex].sets.clear();
          _workout!.exercises[exerciseIndex].sets.addAll(updatedSets);
        }
      });
    }
    try {
      if (widget.isTemporary || setId < 0) {
        // For temporary workouts, update the data in memory
        final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
        if (tempWorkouts.containsKey(widget.workoutId)) {
          final exercises = tempWorkouts[widget.workoutId]['exercises'];

          // Find and remove the exercise
          for (var i = 0; i < exercises.length; i++) {
            if (exercises[i]['id'] == exerciseId) {
              exercises.removeAt(i);
              break;
            }
          }
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      } else {
        // Regular database operations for permanent workouts
        // Then delete from the database in the background
        await _workoutService.deleteSet(setId);

        // Also update the set numbers in the database for remaining sets
        // This ensures the database is consistent with our UI
        final db = await DatabaseService.instance.database;
        for (int i = 0;
            i < _workout!.exercises[exerciseIndex].sets.length;
            i++) {
          final set = _workout!.exercises[exerciseIndex].sets[i];
          await db.update(
            'exercise_sets',
            {'setNumber': i + 1},
            where: 'id = ?',
            whereArgs: [set.id],
          );
        }
      }

      // Show a confirmation message
      if (mounted) {
        _showSnackBar(
          'Set deleted',
          customColor: _primaryColor,
          actionLabel: 'UNDO',
          actionCallback: () {
            // Implement undo functionality if needed
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error deleting set: $e', isError: true);
      }
    }
  }

  void _editExercise(Exercise exercise) {
    // Extract the API ID if it exists
    final String exerciseName = exercise.name;
    final RegExp apiIdRegex = RegExp(r'##API_ID:([^#]+)##');
    final Match? match = apiIdRegex.firstMatch(exerciseName);

    String cleanName = exerciseName;
    String apiId = '';

    if (match != null) {
      // Extract the API ID
      apiId = match.group(1) ?? '';
      // Remove the API ID marker from display name
      cleanName = exerciseName.replaceAll('##API_ID:$apiId##', '');
    }

    final nameController = TextEditingController(text: cleanName);
    final equipmentController = TextEditingController(text: exercise.equipment);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title:
            Text('Edit Exercise', style: TextStyle(color: _textPrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: _textPrimaryColor),
              decoration: InputDecoration(
                labelText: 'Exercise Name',
                labelStyle: TextStyle(color: _textSecondaryColor),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor.withOpacity(0.6)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: equipmentController,
              style: TextStyle(color: _textPrimaryColor),
              decoration: InputDecoration(
                labelText: 'Equipment (optional)',
                labelStyle: TextStyle(color: _textSecondaryColor),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor.withOpacity(0.6)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              final newEquipment = equipmentController.text.trim();

              // Add back the API ID marker if it was present
              final String finalName =
                  newName + (apiId.isNotEmpty ? "##API_ID:$apiId##" : "");

              if (newName.isNotEmpty) {
                Navigator.pop(context);
                _updateExercise(exercise.id, finalName, newEquipment);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      equipmentController.dispose();
    });
  }

  Future<void> _updateExercise(
      int exerciseId, String name, String equipment) async {
    // First update the UI
    if (mounted) {
      setState(() {
        final exerciseIndex =
            _workout!.exercises.indexWhere((e) => e.id == exerciseId);
        if (exerciseIndex != -1) {
          // Since Exercise is immutable, create a new one with updated fields
          final oldExercise = _workout!.exercises[exerciseIndex];
          final updatedExercise = Exercise(
            id: oldExercise.id,
            workoutId: oldExercise.workoutId,
            name: name,
            equipment: equipment,
            sets: oldExercise.sets,
          );

          // Replace the old exercise with the updated one
          _workout!.exercises[exerciseIndex] = updatedExercise;
        }
      });
    }

    // Then update the database
    try {
      final db = await DatabaseService.instance.database;
      await db.update(
        'exercises',
        {
          'name': name,
          'equipment': equipment,
        },
        where: 'id = ?',
        whereArgs: [exerciseId],
      );
      WorkoutService.workoutsUpdatedNotifier.value =
          !WorkoutService.workoutsUpdatedNotifier.value;
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating exercise: $e', isError: true);
      }
    }
  }

  void _confirmDeleteExercise(Exercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text('Delete Exercise?',
            style: TextStyle(color: _textPrimaryColor)),
        content: Text(
          'Are you sure you want to delete "${exercise.name}" and all its sets? This cannot be undone.',
          style: TextStyle(color: _textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteExercise(exercise.id);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
  Future<void> _deleteExercise(int exerciseId) async {
    // Update UI first
    if (mounted) {
      setState(() {
        _workout!.exercises.removeWhere((e) => e.id == exerciseId);
      });
    }

    // Then update database or memory store
    try {
      if (widget.isTemporary || exerciseId < 0) {
        // For temporary workouts, update the data in memory
        final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
        if (tempWorkouts.containsKey(widget.workoutId)) {
          final exercises = tempWorkouts[widget.workoutId]['exercises'];
          // Find and remove the exercise
          for (var i = 0; i < exercises.length; i++) {
            if (exercises[i]['id'] == exerciseId) {
              exercises.removeAt(i);
              break;
            }
          }
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      } else {
        // Regular database operations for permanent workouts
        final db = await DatabaseService.instance.database;
        await db.delete(
          'exercises',
          where: 'id = ?',
          whereArgs: [exerciseId],
        );
      }
      WorkoutService.workoutsUpdatedNotifier.value =
          !WorkoutService.workoutsUpdatedNotifier.value;

      if (mounted) {
        _showSnackBar('Exercise deleted', customColor: _primaryColor);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error deleting exercise: $e', isError: true);
      }
    }
  }

  // Helper method to update exercise data from text controllers
  void _updateExerciseDataFromControllers() {
    if (_workout == null) return;
    
    // Update all sets with current values from controllers
    for (final exercise in _workout!.exercises) {
      for (final set in exercise.sets) {
        // Get data from controllers if they exist
        if (_weightControllers.containsKey(set.id)) {
          final weightText = _weightControllers[set.id]!.text.trim();
          if (weightText.isNotEmpty) {
            set.weight = double.tryParse(weightText) ?? 0;
          }
        }
        
        if (_repsControllers.containsKey(set.id)) {
          final repsText = _repsControllers[set.id]!.text.trim();
          if (repsText.isNotEmpty) {
            set.reps = int.tryParse(repsText) ?? 0;
          }
        }
      }
    }
    
    // If this is a temporary workout, update the data in the temp storage as well
    if (widget.isTemporary) {
      _updateTemporaryWorkoutData();
    }
  }
  
  // Helper method to update temporary workout data to ensure consistency
  void _updateTemporaryWorkoutData() {
    if (_workout == null || !widget.isTemporary) return;
    
    final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
    if (!tempWorkouts.containsKey(widget.workoutId)) return;
    
    final workoutData = tempWorkouts[widget.workoutId];
    final exercisesList = workoutData['exercises'] as List;
    
    // Update each exercise
    for (var exercise in _workout!.exercises) {
      // Find the exercise data in the temp storage
      var exerciseData = exercisesList.firstWhere(
        (e) => e['id'] == exercise.id,
        orElse: () => <String, dynamic>{},
      );
      
      // Skip if exercise not found
      if (exerciseData.isEmpty) continue;
      
      // Update each set
      for (var set in exercise.sets) {
        var setsList =
            (exerciseData['sets'] as List).cast<Map<String, dynamic>>();
        var setData = setsList.firstWhere(
          (s) => s['id'] == set.id,
          orElse: () => <String, dynamic>{},
        );
        
        // Skip if set not found
        if (setData.isEmpty) continue;
        
        // Update weight and reps
        setData['weight'] = set.weight;
        setData['reps'] = set.reps;
        setData['completed'] = set.completed;
      }
    }
    
    // Update the notifier with the modified data to ensure changes persist    WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
  }    // Helper method to serialize workout data for storage  
  Map<String, dynamic> _serializeWorkoutData() {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> workoutData = {
      'exercises': [],
      // Store rest timer state for restoration
      'restTimerState': {
        'isActive': _currentRestSetId != null,
        'setId': _currentRestSetId,
        'timeRemaining': _restTimeRemaining,
        'originalTime': _originalRestTime,
        'isPaused': _restPausedNotifier.value,
        // Store the rest start time for accurate restoration
        'startTime': _restStartTime?.millisecondsSinceEpoch,
        'timestamp': nowMs,
      },
    };
    
    if (_workout == null) return workoutData;
    
    // Serialize all exercises and their sets
    for (final exercise in _workout!.exercises) {
      final Map<String, dynamic> exerciseData = {
        'id': exercise.id,
        'name': exercise.name,
        'equipment': exercise.equipment,
        'sets': [],
      };
      
      // Serialize all sets for this exercise
      for (final set in exercise.sets) {
        final Map<String, dynamic> setData = {
          'id': set.id,
          'exerciseId': set.exerciseId,
          'setNumber': set.setNumber,
          'weight': set.weight,
          'reps': set.reps,
          'restTime': set.restTime,
          'completed': set.completed,
        };
        
        exerciseData['sets'].add(setData);
      }
      
      workoutData['exercises'].add(exerciseData);
    }
    
    return workoutData;
  }
  // Synchronize current workout and rest timer state to activeWorkoutNotifier
  void _updateActiveNotifier() {
    if (_workout == null) return;
    final workoutData = _serializeWorkoutData();
    WorkoutService.activeWorkoutNotifier.value = {
      'id': widget.workoutId,
      'name': _workout!.name,
      'duration': _elapsedSeconds,
      'isTemporary': widget.isTemporary,
      'workoutData': workoutData,
      'minimizedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }
  // Helper method to restore workout data from serialized format
  void _restoreWorkoutData(Map<String, dynamic> workoutData) {
    if (_workout == null || workoutData['exercises'] == null) return;

    // Restore rest timer state if it was active
    if (workoutData.containsKey('restTimerState')) {
      final restState = workoutData['restTimerState'] as Map<String, dynamic>;
      final bool isActive = restState['isActive'] as bool;

      if (isActive && restState['setId'] != null) {
        final int setId = restState['setId'] as int;
        int timeRemaining = restState['timeRemaining'] as int;
        final bool isPaused = restState['isPaused'] as bool;
        final int originalTime = restState['originalTime'] as int;
        final int? startTimeMs = restState['startTime']
            as int?; // If timer was active (not paused) and we have a start time, adjust for time passed
        if (!isPaused && startTimeMs != null) {
          final restStartTime =
              DateTime.fromMillisecondsSinceEpoch(startTimeMs);
          final elapsed = DateTime.now().difference(restStartTime).inSeconds;
          timeRemaining = (originalTime - elapsed).clamp(0, originalTime);
          print(
              "Calculated rest time remaining: $timeRemaining seconds (elapsed: $elapsed)");
        } else if (!isPaused && restState.containsKey('timestamp')) {
          // If we don't have startTime but have timestamp, use that as a fallback
          final int timestampMs = restState['timestamp'] as int;
          final int elapsedSinceTimestamp =
              (DateTime.now().millisecondsSinceEpoch - timestampMs) ~/ 1000;
          // Adjust remaining time, ensuring it doesn't go below 0
          timeRemaining =
              (timeRemaining - elapsedSinceTimestamp).clamp(0, timeRemaining);
          print(
              "Adjusted time remaining based on timestamp: $timeRemaining seconds");
        }

        // If timer completed while minimized, play sound once
        if (!isPaused && timeRemaining <= 0) {
          _playBoxingBellSound();
          // Clear the rest timer state since it's complete
          setState(() {
            _currentRestSetId = null;
            _restTimeRemaining = 0;
            _restRemainingNotifier.value = 0;
            _restStartTime = null;
          });
          print("Rest timer completed while minimized");
        }
        // Restart the rest timer if it was active and has time remaining
        else if (timeRemaining > 0) {
          print(
              "Restoring rest timer with $timeRemaining seconds remaining for set $setId");
          // Cancel any existing rest timer first
          _cancelRestTimer(playSound: false);

          // Restore rest start time for continuous tracking
          if (startTimeMs != null) {
            _restStartTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
          }

          // Restore all rest timer state
          setState(() {
            _currentRestSetId = setId;
            _restTimeRemaining = timeRemaining;
            _originalRestTime = originalTime;
            _restRemainingNotifier.value = timeRemaining;
            _restPausedNotifier.value = isPaused;
          });

          // Force UI to update with rest timer
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Force a rebuild to ensure the timer UI appears
              setState(() {});
              print("Forced UI refresh to show rest timer");
            }
          }); // Only start the timer if it's not paused
          if (!isPaused) {
            // Create a new timer that updates the UI like the workout timer
            _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted || _restPausedNotifier.value) return;

              if (_restStartTime != null) {
                final elapsed =
                    DateTime.now().difference(_restStartTime!).inSeconds;
                final newTimeRemaining =
                    (_originalRestTime - elapsed).clamp(0, _originalRestTime);

                if (newTimeRemaining != _restRemainingNotifier.value) {
                  setState(() {
                    _restRemainingNotifier.value = newTimeRemaining;
                    _restTimeRemaining = newTimeRemaining;
                  });
                  _updateActiveNotifier();
                }

                if (newTimeRemaining <= 0) {
                  timer.cancel();
                  _restTimer = null;
                  _playBoxingBellSound();
                  if (mounted) {
                    setState(() {
                      _currentRestSetId = null;
                      _restStartTime = null;
                    });
                  }
                  _updateActiveNotifier();
                }
              }
            });
          }

          // Clear the restoration flag after successful restoration
          _isRestoringFromMinimized = false;
        }
      }
    }
    
    final List<dynamic> exercisesData = workoutData['exercises'];
    
    // Map to keep track of exercises by ID for quick lookup
    final Map<int, Exercise> exerciseMap = {};
    for (final exercise in _workout!.exercises) {
      exerciseMap[exercise.id] = exercise;
    }
    
    // Update exercise and set data
    for (final exerciseData in exercisesData) {
      final int exerciseId = exerciseData['id'];
      
      // Skip if we don't have this exercise
      if (!exerciseMap.containsKey(exerciseId)) continue;
      
      // Get the exercise reference
      final exercise = exerciseMap[exerciseId]!;

      // Map sets by ID for quick lookup
      final Map<int, ExerciseSet> setMap = {};
      for (final set in exercise.sets) {
        setMap[set.id] = set;
      }
      
      // Update set data
      final List<dynamic> setsData = exerciseData['sets'];
      for (final setData in setsData) {
        final int setId = setData['id'];
        
        // Skip if we don't have this set
        if (!setMap.containsKey(setId)) continue;
        
        // Update set data
        final set = setMap[setId]!;
        set.weight = setData['weight'] ?? 0;
        set.reps = setData['reps'] ?? 0;
        set.completed = setData['completed'] ?? false;
        
        // Make sure controllers exist for this set
        if (!_weightControllers.containsKey(setId)) {
          _weightControllers[setId] = TextEditingController();
        }
        
        if (!_repsControllers.containsKey(setId)) {
          _repsControllers[setId] = TextEditingController();
        }
        
        // Update controllers with the restored values
        // Format weight to remove .0 if it's an integer value
        final weightText = (set.weight % 1 == 0)
            ? set.weight.toInt().toString() 
            : set.weight.toString();
        _weightControllers[setId]!.text = set.weight > 0 ? weightText : '';
        
        _repsControllers[setId]!.text = set.reps > 0 ? set.reps.toString() : '';
      }
    }
    
    // Force UI update
    setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Don't minimize if in read-only mode, just pop
          if (widget.readOnly) {
            return true; // Allow pop to proceed normally
          }

          // Only minimize active workouts if we have data to save
          if (_workout != null && _workout!.exercises.isNotEmpty) {
            // Set the minimizing flag to prevent timer cancellation in dispose()
            _isMinimizing = true;

            // Save all current exercise data from text controllers before minimizing
            _updateExerciseDataFromControllers();

            // Create a serialized version of the workout with all exercise data
            final workoutData = _serializeWorkoutData();

            // Ensure the workout duration is accurate before minimizing
            if (_workoutStartTime != null && _isTimerRunning) {
              _elapsedSeconds =
                  DateTime.now().difference(_workoutStartTime!).inSeconds;
            }

            // Update the activeWorkoutNotifier with complete workout info
            WorkoutService.activeWorkoutNotifier.value = {
              'id': widget.workoutId,
              'name': _workout!.name,
              'duration': _elapsedSeconds,
              'isTemporary': widget.isTemporary,
              'workoutData':
                  workoutData, // Complete workout data with rest timer state
              'minimizedAt': DateTime.now()
                  .millisecondsSinceEpoch, // Track when it was minimized
            };

            print(
                "Minimizing workout via system back - saving rest timer state");
          }
          // Allow pop to proceed
          return true;
        },
        child: Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: _textPrimaryColor),
              onPressed: () {
                if (widget.readOnly) {
                  Navigator.of(context).pop();
                  return;
                }
                // Minimize and keep timers running
                if (_workout != null && _workout!.exercises.isNotEmpty) {
                  _isMinimizing = true;
                  _updateExerciseDataFromControllers();
                  final workoutData = _serializeWorkoutData();
                  if (_workoutStartTime != null && _isTimerRunning) {
                    _elapsedSeconds =
                        DateTime.now().difference(_workoutStartTime!).inSeconds;
                  }
                  WorkoutService.activeWorkoutNotifier.value = {
                    'id': widget.workoutId,
                    'name': _workout!.name,
                    'duration': _elapsedSeconds,
                    'isTemporary': widget.isTemporary,
                    'workoutData': workoutData,
                    'minimizedAt': DateTime.now().millisecondsSinceEpoch,
                  };
                }
                Navigator.of(context).pop();
              },
            ),
        title: Text(
          'Workout Session',
          style: TextStyle(
            color: _textPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (!widget.readOnly)
            TextButton.icon(
              icon: Icon(Icons.check, color: _successColor),
              label: Text(
                'Finish',
                style: TextStyle(
                  color: _successColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                // Check if the workout has no exercises at all
                if (_workout!.exercises.isEmpty) {
                  bool confirmDiscard = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: _surfaceColor,
                          title: Text('Empty Workout',
                              style: TextStyle(color: _textPrimaryColor)),
                          content: Text(
                            'This workout has no exercises and will be discarded.',
                            style: TextStyle(color: _textSecondaryColor),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Go Back',
                                  style: TextStyle(color: _textSecondaryColor)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _dangerColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Discard Workout'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirmDiscard) {
                    // Delete/discard the workout based on whether it's temporary
                    if (widget.isTemporary) {
                      _workoutService.discardTemporaryWorkout(widget.workoutId);
                    } else {
                      await _workoutService.deleteWorkout(widget.workoutId);
                    }
                    
                    _stopTimer();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Empty workout discarded'),
                        backgroundColor: _primaryColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  } else {
                    return; // User chose to go back
                  }
                }

                // Check for empty sets (no weight or reps) and illegal values and collect them
                Map<int, List<int>> emptySetsByExercise =
                    {}; // exerciseId -> list of setIds
                int totalSets = 0;
                int emptySets = 0;
                for (var exercise in _workout!.exercises) {
                  for (var set in exercise.sets) {
                    totalSets++;
                    final wText = _weightControllers[set.id]?.text ?? '';
                    final rText = _repsControllers[set.id]?.text ?? '';
                    
                    // Parse the values to check
                    final double? weight = double.tryParse(wText);
                    final int? repsInt = int.tryParse(rText);
                    final double? repsDouble = double.tryParse(rText);
                    // Check for illegal values:
                    // 1. Null values (empty fields)
                    // 2. Negative weights or reps
                    // 3. Non-integer reps (decimal reps)
                    bool hasIllegalValues = weight == null ||
                        repsInt == null || // Empty fields
                        (weight < 0) || // Negative weight
                        (repsInt < 0) || // Negative reps
                        (repsDouble != null &&
                            repsDouble != repsInt.toDouble()); // Decimal reps

                    if (hasIllegalValues) {
                      emptySets++;
                      if (!emptySetsByExercise.containsKey(exercise.id)) {
                        emptySetsByExercise[exercise.id] = [];
                      }
                      emptySetsByExercise[exercise.id]!.add(set.id);
                    }
                  }
                } // If all sets are empty, discard the entire workout
                if (emptySets == totalSets && totalSets > 0) {
                  bool confirmDiscard = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: _surfaceColor,
                          title: Text('Empty Workout',
                              style: TextStyle(color: _textPrimaryColor)),
                          content: Text(
                            'All sets in this workout are empty (missing weight or reps). The entire workout will be discarded.',
                            style: TextStyle(color: _textSecondaryColor),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Go Back',
                                  style: TextStyle(color: _textSecondaryColor)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _dangerColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Discard Workout'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirmDiscard) {
                    // Delete/discard the workout based on whether it's temporary
                    if (widget.isTemporary) {
                      _workoutService.discardTemporaryWorkout(widget.workoutId);
                    } else {
                      await _workoutService.deleteWorkout(widget.workoutId);
                    }
                    
                    _stopTimer();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Empty workout discarded'),
                        backgroundColor: _primaryColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  } else {
                    return; // User chose to go back and fill in sets
                  }
                } else {
                  // Check for any issues: empty sets or uncompleted sets
                  // First identify uncompleted sets (sets with weight and reps but not marked as completed)
                  Map<int, List<int>> uncompletedSetsByExercise = {}; // exerciseId -> list of setIds
                  
                  for (var exercise in _workout!.exercises) {
                    for (var set in exercise.sets) {
                      // Only check sets that aren't already identified as empty
                      if (!(emptySetsByExercise.containsKey(exercise.id) && 
                            emptySetsByExercise[exercise.id]!.contains(set.id))) {
                        // Check if set has valid weight and reps but is not marked as completed
                        final wText = _weightControllers[set.id]?.text ?? '';
                        final rText = _repsControllers[set.id]?.text ?? '';
                        // Parse values to check - now allowing for zero values
                        final double? weight = double.tryParse(wText);
                        final int? reps = int.tryParse(rText);
                        final hasData = weight != null &&
                            weight >= 0 &&
                            reps != null &&
                            reps >= 0;
                        
                        if (hasData && !set.completed) {
                          if (!uncompletedSetsByExercise.containsKey(exercise.id)) {
                            uncompletedSetsByExercise[exercise.id] = [];
                          }
                          uncompletedSetsByExercise[exercise.id]!.add(set.id);
                        }
                      }
                    }
                  } // Prepare data for dialog
                  bool hasEmptySets = emptySets > 0;
                  bool hasUncompletedSets = uncompletedSetsByExercise.isNotEmpty;
                  bool hasNoIssues =
                      !hasEmptySets && !hasUncompletedSets && totalSets > 0;
                  String dialogTitle = '';
                  List<Widget> dialogContent = [];
                  
                  if (hasEmptySets && hasUncompletedSets) {
                    dialogTitle = 'Sets Need Attention';
                  } else if (hasEmptySets) {
                    dialogTitle = 'Empty Sets Detected';
                  } else if (hasUncompletedSets) {
                    dialogTitle = 'Uncompleted Sets Detected';
                  } else if (hasNoIssues) {
                    dialogTitle = 'Finish Workout';
                  }

                  // Build content for dialog
                  if (hasEmptySets) {
                    // Build list of exercises with empty sets
                    List<Exercise> exercisesWithEmptySets = [];
                    for (var exercise in _workout!.exercises) {
                      if (emptySetsByExercise.containsKey(exercise.id)) {
                        exercisesWithEmptySets.add(exercise);
                      }
                    }

                    dialogContent.add(
                      Text(
                        'The following exercises have empty sets (missing weight or reps):',
                        style: TextStyle(color: _textSecondaryColor),
                      )
                    );
                    dialogContent.add(SizedBox(height: 10));
                    
                    for (var exercise in exercisesWithEmptySets) {
                      dialogContent.add(
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '• ${exercise.name.replaceAll(RegExp(r'##API_ID:[^#]+##'), '')}',
                            style: TextStyle(
                                color: _textPrimaryColor,
                                fontWeight: FontWeight.w500),
                          ),
                        )
                      );
                    }
                    
                    dialogContent.add(SizedBox(height: 10));
                    dialogContent.add(
                      Text(
                        'Empty sets will be discarded.',
                        style: TextStyle(color: _textSecondaryColor),
                      )
                    );
                  }
                  
                  if (hasEmptySets && hasUncompletedSets) {
                    dialogContent.add(SizedBox(height: 16));
                    dialogContent.add(Divider(color: _textSecondaryColor.withOpacity(0.2)));
                    dialogContent.add(SizedBox(height: 16));
                  }
                  if (hasUncompletedSets) {
                    // Count total uncompleted sets
                    int totalUncompletedSets = 0;
                    uncompletedSetsByExercise.forEach((_, sets) => totalUncompletedSets += sets.length);
                    
                    // Build list of exercises with uncompleted sets
                    List<Exercise> exercisesWithUncompletedSets = [];
                    for (var exercise in _workout!.exercises) {
                      if (uncompletedSetsByExercise.containsKey(exercise.id)) {
                        exercisesWithUncompletedSets.add(exercise);
                      }
                    }

                    dialogContent.add(
                      Text(
                        'You have $totalUncompletedSets set${totalUncompletedSets > 1 ? 's' : ''} with data but not marked as completed:',
                        style: TextStyle(color: _textSecondaryColor),
                      )
                    );
                    dialogContent.add(SizedBox(height: 10));
                    
                    for (var exercise in exercisesWithUncompletedSets) {
                      dialogContent.add(
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '• ${exercise.name.replaceAll(RegExp(r'##API_ID:[^#]+##'), '')} (${uncompletedSetsByExercise[exercise.id]!.length} set${uncompletedSetsByExercise[exercise.id]!.length > 1 ? 's' : ''})',
                            style: TextStyle(
                                color: _textPrimaryColor,
                                fontWeight: FontWeight.w500),
                          ),
                        )
                      );
                    }
                    
                    dialogContent.add(SizedBox(height: 10));
                    dialogContent.add(
                      Text(
                        'All uncompleted sets will be automatically completed when finishing.',
                        style: TextStyle(color: _textSecondaryColor.withOpacity(0.8), fontStyle: FontStyle.italic),
                      )
                    );
                  } else if (hasNoIssues) {
                    // Show a simple confirmation for workouts without issues
                    dialogContent.add(Text(
                      'All sets have valid data and are properly completed. Are you ready to finish this workout?',
                      style: TextStyle(color: _textSecondaryColor),
                    ));
                    dialogContent.add(SizedBox(height: 16));

                    // Show workout duration
                    dialogContent.add(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            color: _primaryColor, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Duration: ${_formatTime(_elapsedSeconds)}',
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ));
                  }

                  // Show the combined dialog
                  bool continueWithWorkout = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: _surfaceColor,
                      title: Text(dialogTitle, style: TextStyle(color: _textPrimaryColor)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: dialogContent,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Go Back', style: TextStyle(color: _textSecondaryColor)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Finish Workout'),
                        ),
                      ],
                    ),
                  ) ?? false;

                  if (!continueWithWorkout) {
                    return; // User chose to go back
                  }

                  // Process empty sets
                  if (hasEmptySets) {
                    // Delete all empty sets
                    for (var exerciseId in emptySetsByExercise.keys) {
                      for (var setId in emptySetsByExercise[exerciseId]!) {
                        await _workoutService.deleteSet(setId);
                      }

                      // If all sets in an exercise were deleted, delete the exercise too
                      var exercise = _workout!.exercises
                          .firstWhere((e) => e.id == exerciseId);
                      if (emptySetsByExercise[exerciseId]!.length ==
                          exercise.sets.length) {
                        await _workoutService.deleteExercise(exerciseId);
                      }
                    }
                  }

                  // Process uncompleted sets
                  if (hasUncompletedSets) {
                    // Mark all uncompleted sets as completed automatically
                    for (var exerciseId in uncompletedSetsByExercise.keys) {
                      for (var setId in uncompletedSetsByExercise[exerciseId]!) {
                        await _updateSetComplete(setId, true);
                      }
                    }
                  }

                  // Save any inline edits for non-empty sets
                  for (var exercise in _workout!.exercises) {
                    for (var set in exercise.sets) {
                      // Skip empty sets as they've already been deleted
                      if (emptySetsByExercise.containsKey(exercise.id) &&
                          emptySetsByExercise[exercise.id]!.contains(set.id)) {
                        continue;
                      }

                      final wText = _weightControllers[set.id]?.text ?? '';
                      final newWeight = double.tryParse(wText) ?? set.weight;
                      final rText = _repsControllers[set.id]?.text ?? '';
                      final newReps = int.tryParse(rText) ?? set.reps;
                      await _updateSetData(
                          set.id, newWeight, newReps, set.restTime);
                    }
                  } // Handle temporary vs regular workouts differently
                  if (widget.isTemporary) {
                    // For temporary workouts, check if we have any valid exercises and sets
                    if (_workout?.exercises.isEmpty ?? true) {
                      // No exercises, discard the temporary workout
                      _workoutService.discardTemporaryWorkout(widget.workoutId);
                      _stopTimer();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Empty workout discarded'),
                          backgroundColor: _primaryColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    } else {
                      // We have valid exercises, save the temporary workout to the database
                      try {
                        // Create data structure for the temporary workout with all its exercises and sets
                        final tempData = {
                          'name': _nameController.text,
                          'date': _workout!.date,
                          'duration': _elapsedSeconds,
                          'exercises': _workout!.exercises.map((exercise) {
                            return {
                              'name': exercise.name,
                              'equipment': exercise.equipment,
                              'sets': exercise.sets.map((set) {
                                return {
                                  'setNumber': set.setNumber,
                                  'weight': set.weight,
                                  'reps': set.reps,
                                  'restTime': set.restTime,
                                  'completed': set.completed,
                                };
                              }).toList(),
                            };
                          }).toList(),
                        };

                        // Add the temporary workout data to the value notifier
                        final tempWorkouts =
                            WorkoutService.tempWorkoutsNotifier.value;
                        tempWorkouts[widget.workoutId] = tempData;
                        WorkoutService.tempWorkoutsNotifier.value =
                            Map.from(tempWorkouts);

                        // Save to database
                        await _workoutService
                            .saveTemporaryWorkout(widget.workoutId);
                      } catch (e) {
                        print('Error saving temporary workout: $e');
                        // Even if there's an error, we'll dismiss this screen
                      }
                    }
                  } else {
                    // Regular workout - check if any exercises remain after deleting all empty sets
                    final remainingExercises = await _workoutService
                        .getExercisesForWorkout(widget.workoutId);
                    if (remainingExercises.isEmpty) {
                      // No exercises left, delete the workout
                      await _workoutService.deleteWorkout(widget.workoutId);
                      _stopTimer();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Empty workout discarded'),
                          backgroundColor: _primaryColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                  }
                } // We've already handled all the dialog cases above, no need for additional confirmation
                
                _stopTimer();
                    Navigator.pop(context);
                    _showSnackBar('Workout saved');
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : Column(
              children: [
                // Timer and workout name section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Workout name
                      if (!widget.readOnly)
                        TextField(
                              controller: _nameController,
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter workout name',
                            hintStyle: TextStyle(
                              color: _textSecondaryColor.withOpacity(0.5),
                              fontSize: 24,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onEditingComplete: _updateWorkoutName,
                        )
                      else
                        Text(
                          _workout?.name ?? 'Workout',
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                            ),

                      SizedBox(height: 16),

                      // Timer
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer,
                                    color: _primaryColor, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  _formatTime(_elapsedSeconds),
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Exercises list
                Expanded(
                  child: _workout!.exercises.isEmpty
                      ? _buildEmptyExercisesView()
                      : ListView.builder(
                          padding: EdgeInsets.only(top: 8),
                          itemCount: _workout!.exercises.length + 1,
                          itemBuilder: (context, index) {
                            if (index < _workout!.exercises.length) {
                              return _buildExerciseCard(
                                  _workout!.exercises[index]);
                            } else {
                              return Padding(
                                padding: EdgeInsets.all(16),

                                child: Center(
                                  child: TextButton.icon(
                                    icon: Icon(Icons.add, color: _primaryColor),
                                    label: Text('Add Exercise',
                                        style: TextStyle(color: _primaryColor)),
                                    onPressed: _addExercise,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: !widget.readOnly &&
              _workout != null &&
              _workout!.exercises.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: _dangerColor,
              child: Icon(Icons.close),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: _surfaceColor,
                    title: Text('Cancel Workout?',
                        style: TextStyle(color: _textPrimaryColor)),
                    content: Text(
                      'Are you sure you want to cancel this workout? All progress will be lost.',
                      style: TextStyle(color: _textSecondaryColor),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('No',
                            style: TextStyle(color: _textSecondaryColor)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _dangerColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // Discard temporary workout if needed
                          if (widget.isTemporary) {
                            _workoutService
                                .discardTemporaryWorkout(widget.workoutId);
                          }
                          
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Return to previous screen
                        },
                        child: Text('Yes, Cancel'),
                      ),
                    ],
                  ),
                );
              },
            )
          : null,
        ));
  }

  Widget _buildEmptyExercisesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: _textSecondaryColor.withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            'No exercises yet',
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 24),
          if (!widget.readOnly)
            TextButton.icon(
              icon: Icon(Icons.add, color: _primaryColor),
              label: Text('Add Your First Exercise',
                  style: TextStyle(color: _primaryColor)),
              onPressed: _addExercise,
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    // Determine if this is a default (API) exercise
    final bool isDefaultExercise =
        RegExp(r'##API_ID:[^#]+##').hasMatch(exercise.name);

    final bool allSetsCompleted =
        exercise.sets.isNotEmpty && exercise.sets.every((set) => set.completed);

    // Wrap with RepaintBoundary to isolate painting operations
    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header
            Padding(
              padding: EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  // Check if the exercise name contains an API ID marker
                  final String exerciseName = exercise.name;
                  final RegExp apiIdRegex = RegExp(r'##API_ID:([^#]+)##');
                  final Match? match = apiIdRegex.firstMatch(exerciseName);

                  String apiId = '';

                  if (match != null) {
                    // Extract the API ID
                    apiId = match.group(1) ?? '';
                  }
                  
                  // Get the clean exercise name without API ID markers
                  final String cleanName =
                      exerciseName.replaceAll(apiIdRegex, '').trim();

                  // Check if this is a temporary exercise (negative ID)
                  final bool isTemporary = exercise.id < 0;

                  print(
                      'Exercise ID: ${exercise.id}, Is Temporary: $isTemporary');

                  // Navigate to the detail page with the API ID if available, otherwise use the local ID
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailPage(
                        exerciseId:
                            apiId.isNotEmpty ? apiId : exercise.id.toString(),
                      ),
                      settings: RouteSettings(
                        arguments: {
                          'exerciseName': cleanName,
                          'exerciseEquipment': exercise.equipment,
                          'isTemporary': isTemporary,
                        },
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    // Exercise icon and name
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: _primaryColor,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              // Clean the name to remove API ID marker if present
                              exercise.name
                                  .replaceAll(RegExp(r'##API_ID:[^#]+##'), ''),
                              style: TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status indicator
                    // Show status indicator only if there are sets
                    if (exercise.sets.isNotEmpty)
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: allSetsCompleted
                              ? _successColor.withOpacity(0.2)
                              : _textSecondaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          allSetsCompleted ? 'Completed' : 'In Progress',
                          style: TextStyle(
                            color: allSetsCompleted
                                ? _successColor
                                : _textSecondaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // Options menu
                    // Show options menu only for non-default exercises
                    if (!widget.readOnly)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: _textSecondaryColor),
                        enabled: true,
                        offset: Offset(0, 0),
                        color: Colors.black,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (String value) {
                          if (value == 'edit') {
                            _editExercise(exercise);
                          } else if (value == 'delete') {
                            _confirmDeleteExercise(exercise);
                          } else if (value == 'set_rest') {
                            _showSetRestDialog(exercise);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return <PopupMenuEntry<String>>[
                            if (!isDefaultExercise)
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading:
                                      Icon(Icons.edit, color: _primaryColor),
                                  title: Text('Edit Exercise',
                                      style:
                                          TextStyle(color: _textPrimaryColor)),
                                ),
                              ),
                            PopupMenuItem<String>(
                              value: 'set_rest',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    Icon(Icons.timer, color: _primaryColor),
                                title: Text('Set Rest Time',
                                    style: TextStyle(color: _textPrimaryColor)),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading:
                                    Icon(Icons.delete, color: _dangerColor),
                                title: Text('Delete Exercise',
                                    style: TextStyle(color: _textPrimaryColor)),
                              ),
                            ),
                          ];
                        },
                      )
                    else
                      SizedBox(width: 40),
                  ],
                ),
              ),
            ),

            // Show exercise rest time if sets exist
            if (exercise.sets.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Rest time: ${exercise.sets.first.restTime}s',
                  style: TextStyle(color: _textSecondaryColor, fontSize: 12),
                ),
              ),

            // Sets table header
            if (exercise.sets.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(width: 40),
                    Expanded(
                        flex: 2,
                        child: Text('WEIGHT',
                            style: TextStyle(
                                color: _textSecondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('REPS',
                            style: TextStyle(
                                color: _textSecondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center)),
                    SizedBox(width: 44),
                  ],
                ),
              ),

            // Sets list
            if (exercise.sets.isNotEmpty)
              Column(
                children: List.generate(exercise.sets.length, (index) {
                  final set = exercise.sets[index];
                  return _buildSetItem(exercise, set);
                }),
              ),

            // Add set button (only for non-default exercises)
            if (!widget.readOnly)
              Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.add, size: 16),
                    label: Text(
                      exercise.sets.isEmpty ? 'Add First Set' : 'Add Set',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _addSetToExercise(exercise.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildSetItem(Exercise exercise, ExerciseSet set) {
    // initialize controllers if absent
    _weightControllers.putIfAbsent(set.id, () {
      // Show initial weight only if greater than zero
      String initialWeightText = '';
      if (set.weight > 0) {
        initialWeightText = (set.weight % 1 == 0)
            ? set.weight.toInt().toString()
            : set.weight.toString();
      }
      return TextEditingController(text: initialWeightText);
    });
    _repsControllers.putIfAbsent(set.id, () {
      // Show initial reps only if greater than zero
      String initialRepsText = '';
      if (set.reps > 0) {
        initialRepsText = set.reps.toString();
      }
      return TextEditingController(text: initialRepsText);
    }); // Determine if both fields have valid values (now allowing zero values) to enable the completion button
    final String weightTextStr = _weightControllers[set.id]?.text ?? '';
    final String repsTextStr = _repsControllers[set.id]?.text ?? '';
    final double? weightValue = double.tryParse(weightTextStr);
    final int? repsValue = int.tryParse(repsTextStr);
    final bool canCompleteButton =
        weightValue != null &&
        weightValue >= 0 &&
        repsValue != null &&
        repsValue >= 0;

    return RepaintBoundary(
      child: Dismissible(
        key: Key('set_${set.id}'),
        direction: widget.readOnly
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.0),
          color: _dangerColor,
          child: Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          // Return true to confirm the dismiss, false to cancel
          return !widget.readOnly;
        },
        onDismissed: (direction) {
          // Delete the set when dismissed
          _deleteSet(exercise.id, set.id);
        },
        child: InkWell(
        onTap: null,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: _textSecondaryColor.withOpacity(0.1), width: 1)),
            ),
            child: Column(children: [
            Row(children: [
              // Set number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: set.completed
                      ? _successColor.withOpacity(0.15)
                      : _primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${set.setNumber}',
                  style: TextStyle(
                    color: set.completed ? _successColor : _primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Weight and Reps columns (align with headers)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    controller: _weightControllers[set.id],
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                        color: _textPrimaryColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: _inputBgColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      // Use suffix widget with padding to avoid cramped edge
                      suffix: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'kg',
                          style: TextStyle(color: _textSecondaryColor),
                        ),
                      ),
                    ),
                    textAlign: TextAlign.center,
                    onSubmitted: (value) {
                      final weight = double.tryParse(value);
                      if (weight != null && weight >= 0) {
                        _updateSetData(set.id, weight, set.reps, set.restTime);
                      } else {
                        // Reset to previous valid value if negative or invalid, or empty if no valid value
                        _weightControllers[set.id]!.text = set.weight > 0
                            ? ((set.weight % 1 == 0)
                                ? set.weight.toInt().toString()
                                : set.weight.toString())
                            : '';
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    controller: _repsControllers[set.id],
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                          color: _textPrimaryColor,
                          fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                      filled: true,
                      fillColor: _inputBgColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                    textAlign: TextAlign.center,
                    onSubmitted: (value) {
                      final reps = int.tryParse(value);
                      if (reps != null && reps >= 0) {
                        _updateSetData(set.id, set.weight, reps, set.restTime);
                      } else {
                        // Reset to previous valid value if negative or invalid, or empty if no valid value
                        _repsControllers[set.id]!.text =
                            set.reps > 0 ? set.reps.toString() : '';
                      }
                    },
                  ),
                ),
              ),
              // Complete button
              Container(
                width: 44,
                height: 40,
                child: widget.readOnly
                    ? set.completed
                        ? Icon(Icons.check_circle, color: _successColor)
                        : Icon(Icons.circle_outlined,
                            color: _textSecondaryColor)                    : IconButton(
                        icon: set.completed
                            ? Icon(Icons.check_circle, color: _successColor)
                            : Icon(Icons.circle_outlined,
                                color: canCompleteButton
                                    ? _textSecondaryColor
                                    : _textSecondaryColor.withOpacity(0.3)),
                        tooltip: canCompleteButton
                            ? (set.completed ? 'Mark as incomplete' : 'Mark as completed')
                            : 'Enter weight and reps to complete',
                        onPressed: canCompleteButton
                            ? () {
                                final willComplete = !set.completed;
                              _toggleSetCompletion(
                                    exercise.id, set.id, willComplete);
                                if (willComplete) {
                                  // Start rest when completing
                                  _startRestTimerForSet(set.id, set.restTime);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RestTimerPage(
                                        originalDuration: _originalRestTime,
                                        remaining: _restRemainingNotifier,
                                        isPaused: _restPausedNotifier,
                                        onPause: _togglePauseRest,
                                        onIncrement: _incrementRest,
                                        onDecrement: _decrementRest,
                                        onSkip: _cancelRestTimer,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Cancel rest when undoing, but don't play sound
                                  _cancelRestTimer(playSound: false);
                                }
                              }
                            : null,
                      ), // close IconButton
              ),
            ]),
            // Show countdown under set when active
            if (_currentRestSetId == set.id && _restTimeRemaining > 0)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RestTimerPage(
                        originalDuration: _originalRestTime,
                        remaining: _restRemainingNotifier,
                        isPaused: _restPausedNotifier,
                        onPause: _togglePauseRest,
                        onIncrement: _incrementRest,
                        onDecrement: _decrementRest,
                        onSkip: _cancelRestTimer,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Rest: ${_formatTime(_restTimeRemaining)}',
                    style: TextStyle(color: _primaryColor),
                  ),
                ),
              ),
            ]),
          ),
        ),
    )); // close RepaintBoundary
  }
  /// Show dialog to set a custom rest time for all sets in an exercise
  void _showSetRestDialog(Exercise exercise) {
    // Get current rest time in seconds
    final initialSeconds = exercise.sets.isNotEmpty
        ? exercise.sets.first.restTime
        : _defaultRestTime;

    // Create a value notifier to track the current selection
    final ValueNotifier<int> totalSeconds = ValueNotifier(initialSeconds);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title:
            Text('Set Rest Time', style: TextStyle(color: _textPrimaryColor)),
        content: SizedBox(
          height: 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Minutes : Seconds',
                style: TextStyle(color: _textSecondaryColor, fontSize: 16),
              ),
              SizedBox(height: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minutes column
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_drop_up,
                              color: _primaryColor, size: 36),
                          onPressed: () {
                            totalSeconds.value += 60;
                          },
                        ),
                        Container(
                          width: 60,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _inputBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable: totalSeconds,
                            builder: (_, value, __) {
                              final mins =
                                  (value ~/ 60).toString().padLeft(2, '0');
                              return Text(
                                mins,
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimaryColor),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_drop_down,
                              color: _primaryColor, size: 36),
                          onPressed: () {
                            if (totalSeconds.value >= 60) {
                              totalSeconds.value -= 60;
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(width: 16),
                    Text(':',
                        style:
                            TextStyle(fontSize: 24, color: _textPrimaryColor)),
                    SizedBox(width: 16),
                    // Seconds column
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_drop_up,
                              color: _primaryColor, size: 36),
                          onPressed: () {
                            if (totalSeconds.value % 60 < 59) {
                              totalSeconds.value += 1;
                            } else {
                              // Roll over to next minute
                              totalSeconds.value = totalSeconds.value - 59;
                            }
                          },
                        ),
                        Container(
                          width: 60,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _inputBgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ValueListenableBuilder<int>(
                            valueListenable: totalSeconds,
                            builder: (_, value, __) {
                              final secs =
                                  (value % 60).toString().padLeft(2, '0');
                              return Text(
                                secs,
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimaryColor),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_drop_down,
                              color: _primaryColor, size: 36),
                          onPressed: () {
                            if (totalSeconds.value % 60 > 0) {
                              totalSeconds.value -= 1;
                            } else if (totalSeconds.value >= 60) {
                              // Roll over from previous minute
                              totalSeconds.value = totalSeconds.value - 60 + 59;
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
                ),
                ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              final rest = totalSeconds.value;
              Navigator.pop(context);
              for (var set in exercise.sets) {
                await _updateSetData(set.id, set.weight, set.reps, rest);
              }
            },
            child: Text('Save'),
          ),
        ],
            ));
  }

  // Shows a snack bar and removes any existing ones
  void _showSnackBar(
    String message, {
    bool isError = false,
    int durationSeconds = 2,
    String? actionLabel,
    VoidCallback? actionCallback,
    Color? customColor,
  }) {
    // Clear any existing snack bars first
    ScaffoldMessenger.of(context).clearSnackBars();

    // Determine background color
    final Color backgroundColor =
        customColor ?? (isError ? _dangerColor : _successColor);

    // Build action if provided
    final SnackBarAction? action = actionLabel != null && actionCallback != null
        ? SnackBarAction(
            label: actionLabel,
            textColor: Colors.white,
            onPressed: actionCallback,
          )
        : null;

    // Then show the new snack bar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: durationSeconds),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  // Shows "Empty workout discarded" notification
}
