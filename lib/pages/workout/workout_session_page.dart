import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/foreground_service.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/rest_timer_page.dart';
import 'package:mental_warior/pages/workout/workout_completion_page.dart';
import 'package:audioplayers/audioplayers.dart';

class WorkoutSessionPage extends StatefulWidget {
  final int workoutId;
  final bool readOnly;
  final bool isTemporary;
  final bool minimized;
  final Map<String, dynamic>? restoredWorkoutData;

  const WorkoutSessionPage({
    super.key,
    required this.workoutId,
    this.readOnly = false,
    this.isTemporary = false,
    this.minimized = false,
    this.restoredWorkoutData,
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
  bool _isDisposing = false; // Flag to prevent setState during disposal
  int _elapsedSeconds = 0;
  Timer? _timer;
  Timer? _restTimer;
  int _restTimeRemaining = 0;
  int? _currentRestSetId;
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
  final int _defaultRestTime = 150; // 2:30 min  // Timer tracking variables
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
    
    // If this was a minimized workout being restored, set up restoration data FIRST
    if (widget.minimized) {
      print("Restoring minimized workout");
      
      // Use the passed restoredWorkoutData if available, otherwise fall back to activeWorkoutNotifier
      Map<String, dynamic>? activeWorkout;
      Map<String, dynamic>? workoutData;

      if (widget.restoredWorkoutData != null) {
        // Use the passed workout data directly
        workoutData = widget.restoredWorkoutData;

        // Get elapsed time from active workout notifier if still available
        final notifierWorkout = WorkoutService.activeWorkoutNotifier.value;
        if (notifierWorkout != null) {
          _elapsedSeconds = notifierWorkout['duration'] as int;
        }
      } else if (WorkoutService.activeWorkoutNotifier.value != null) {
        // Fall back to getting data from notifier (old behavior)
        activeWorkout = WorkoutService.activeWorkoutNotifier.value!;
        _elapsedSeconds = activeWorkout['duration'] as int;
        workoutData = activeWorkout['workoutData'] as Map<String, dynamic>?;
      }
      

      // Don't clear the notifier when opening from active workout bar
      // This allows the user to view the workout session while keeping the active workout bar
      // The notifier should only be cleared when the workout is actually completed or discarded
      print(
          "Opened minimized workout from active workout bar - keeping notifier active");
      
      // Start the timer with the restored elapsed seconds
      _startTimer();

      
      // Set up restoration data BEFORE loading the workout
      if (workoutData != null) {
        _isRestoringFromMinimized = true; // Flag to track restoration process
        _savedWorkoutData = workoutData; // Save the data for later use

        // Check if we need to immediately restore a rest timer
        // This ensures the rest timer doesn't get interrupted during minimization
        if (workoutData.containsKey('restTimerState')) {
          final restState =
              workoutData['restTimerState'] as Map<String, dynamic>;
          final bool isActive = restState['isActive'] as bool? ?? false;

          if (isActive) {
            final int? setId = restState['setId'] as int?;
            final int timeRemaining = restState['timeRemaining'] as int? ?? 0;
            final bool isPaused = restState['isPaused'] as bool? ?? false;
            print(
                "Found active rest timer state to restore - SetID: $setId, Time Remaining: $timeRemaining seconds, Paused: $isPaused");

            // Set a flag to prioritize the rest timer restoration
            if (timeRemaining > 0 && setId != null) {
            }
          }
          // Full timer restoration will be handled in _restoreWorkoutData after workout loads
        }
      }
    }
    
    // Load the workout AFTER setting up restoration flags
    _loadWorkout();
    
    // If not minimized and not read-only, check for active session from database
    if (!widget.minimized && !widget.readOnly) {
      _checkForActiveSessionFromDatabase();
    } else if (!widget.minimized && !widget.readOnly) {
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
        
        // Also update the foreground service with the latest workout data
        if (WorkoutForegroundService.isServiceRunning) {
          WorkoutForegroundService.startWorkoutService(
            _workout!.name,
            startTime: _workoutStartTime,
            workoutData: workoutData,
            workoutId: widget.workoutId,
            isTemporary: widget.isTemporary,
          );
        }
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
          // Restart the timer with real-world time tracking
          _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted || _isDisposing || _restPausedNotifier.value) return;

            if (_restStartTime != null) {
              final elapsed =
                  DateTime.now().difference(_restStartTime!).inSeconds;
              final newTimeRemaining =
                  (_originalRestTime - elapsed).clamp(0, _originalRestTime);

              if (newTimeRemaining != _restRemainingNotifier.value) {
                if (mounted && !_isDisposing) {
                  setState(() {
                    _restRemainingNotifier.value = newTimeRemaining;
                    _restTimeRemaining = newTimeRemaining;
                  });
                  _updateActiveNotifier();
                }
              }

              if (newTimeRemaining <= 0) {
                timer.cancel();
                _restTimer = null;
                _playBoxingBellSound();
                if (mounted && !_isDisposing) {
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
    // Set disposal flag to prevent any setState calls
    _isDisposing = true;

    // Cancel timers immediately to prevent callbacks during disposal
    _timer?.cancel();
    _timer = null;
    _restTimer?.cancel();
    _restTimer = null;
    
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // If this was opened from the active workout bar (minimized = true), 
    // treat navigation back as minimizing to preserve the workout state
    final bool shouldPreserveWorkout = _isMinimizing || widget.minimized;

    // Only stop timers if we're not minimizing/preserving the workout
    if (!shouldPreserveWorkout) {
      print("Dispose: Stopping timers as we're closing the workout");
      // Note: timers already cancelled above, just clean up foreground service
      WorkoutForegroundService.stopWorkoutService();
      
      // Clear the active session from database if we're truly closing the workout
      _clearActiveSessionFromDatabase();
    } else {
      // If we're minimizing or preserving, make sure we have the latest data for the workout timer
      if (_workoutStartTime != null && _isTimerRunning) {
        _elapsedSeconds =
            DateTime.now().difference(_workoutStartTime!).inSeconds;
        print("Dispose: Preserving workout state - keeping timers alive");

        // Update the active notifier with the latest state before closing
        _updateActiveNotifier();
      }
      
      // Also ensure rest timer state is properly preserved
      if (_currentRestSetId != null && _restTimeRemaining > 0) {
        print(
            "Dispose: Preserving rest timer with $_restTimeRemaining seconds remaining for SetID: $_currentRestSetId");
      }
    }
    
    for (var c in _weightControllers.values) {
      c.dispose();
    }
    for (var c in _repsControllers.values) {
      c.dispose();
    } // If this was a temporary workout and we're navigating away without saving,
    // discard the temporary workout (but not if we're minimizing)
    if (widget.isTemporary && mounted && !_isMinimizing) {
      // Check if any exercises were added
      bool hasExercises = _workout?.exercises.isNotEmpty ?? false;

      // If nothing was added, just discard it (fire and forget)
      if (!hasExercises) {
        print(
            '🗑️ WorkoutSessionPage: Disposing empty temporary workout with ID: ${widget.workoutId}');
        _workoutService.discardTemporaryWorkout(widget.workoutId);
      } else {
        print(
            'ℹ️ WorkoutSessionPage: Not discarding temporary workout ${widget.workoutId} - has exercises');
      }
    }
    
    // Release audio player resources
    _audioPlayer.dispose();
    super.dispose();
  }

  // Clear active session from database (when workout is completed or discarded)
  Future<void> _clearActiveSessionFromDatabase() async {
    try {
      await _workoutService.clearActiveWorkoutSessions();
      print('Active session cleared from database');
    } catch (e) {
      print('Error clearing active session: $e');
    }
  }

  void _loadWorkout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Workout? workout;
      // Check if this is a temporary workout
      if (widget.isTemporary) {
        // If we're restoring from minimized state and have saved workout data, use it directly
        if (_isRestoringFromMinimized && _savedWorkoutData != null) {
          final savedExercisesData = _savedWorkoutData!['exercises'] as List?;

          // Build exercises list from saved workout data instead of temp storage
          List<Exercise> exercises = [];
          if (savedExercisesData != null) {
            for (var exerciseData in savedExercisesData) {
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

          // Get basic workout info from temp storage
          final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
          final tempData = tempWorkouts[widget.workoutId];

          // Create a Workout object using saved exercise data but temp workout info
          workout = Workout(
            id: widget.workoutId,
            name: tempData?['name'] ?? 'Workout',
            date: tempData?['date'] ?? DateTime.now(),
            duration: tempData?['duration'] ?? 0,
            exercises: exercises, // Use exercises from saved data
          );
        } else {
          // Normal temporary workout loading from temp storage
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
                    final setId = setData['id'] ??
                        -(DateTime.now().millisecondsSinceEpoch);
                    sets.add(ExerciseSet(
                      id: setId,
                      exerciseId: exerciseId,
                      setNumber: setData['setNumber'] ?? 1,
                      weight: setData['weight'] ?? 0,
                      reps: setData['reps'] ?? 0,
                      restTime: setData['restTime'] ?? _defaultRestTime,
                      completed: setData['completed'] ?? false,
                      isPR: setData['isPR'] ?? false,
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
        }
      } else {
        // Regular database workout
        workout = await _workoutService.getWorkout(widget.workoutId);
        print(
            'LOAD DEBUG: Loaded workout from database - exercises count: ${workout?.exercises.length ?? 0}');
      }

      if (workout != null) {
        if (mounted) {
          // Check if widget is still mounted before updating state
          setState(() {
            _workout = workout;
            // Only set the elapsed seconds during the initial load, not on refreshes
            // This prevents timer resetting when adding exercises
            if (_elapsedSeconds == 0) {
              _elapsedSeconds = workout!.duration;
            }
            _isLoading = false;
            
            // Initialize all controllers for all sets after workout is loaded
            _initializeAllControllers();
            
            // If we're restoring from minimized state, apply the saved data
            if (_isRestoringFromMinimized && _savedWorkoutData != null) {
              print(
                  "LOAD DEBUG: Starting restoration - workout has ${_workout!.exercises.length} exercises");
              print(
                  "Saved workout data contains rest timer: ${_savedWorkoutData!.containsKey('restTimerState')}");
              print(
                  "Saved workout data exercises count: ${(_savedWorkoutData!['exercises'] as List?)?.length ?? 0}");

              // For temporary workouts, exercises are already loaded from saved data
              // Only restore rest timer state and initialize controllers with saved values
              if (widget.isTemporary) {
                // Initialize controllers with values from saved data
                _initializeControllersFromSavedData(_savedWorkoutData!);
                // Only restore rest timer state for temporary workouts
                _restoreRestTimerOnly(_savedWorkoutData!);
              } else {
                // For regular workouts, restore all data including exercises
                _restoreWorkoutData(_savedWorkoutData!);
              }
              
              // Restart workout timer after restoration
              if (!_isTimerRunning) {
                _startTimer();
              }

              // Reset flags AFTER restoration is complete
              _savedWorkoutData = null;
              _isRestoringFromMinimized = false;
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
  
  // Helper method to initialize controllers for all sets in the workout
  void _initializeAllControllers() {
    if (_workout == null) return;

    for (final exercise in _workout!.exercises) {
      for (final set in exercise.sets) {
        // Initialize weight controller if it doesn't exist
        if (!_weightControllers.containsKey(set.id)) {
          String initialWeightText = '';
          if (set.weight > 0) {
            initialWeightText = (set.weight % 1 == 0)
                ? set.weight.toInt().toString()
                : set.weight.toString();
          }
          _weightControllers[set.id] =
              TextEditingController(text: initialWeightText);
        }

        // Initialize reps controller if it doesn't exist
        if (!_repsControllers.containsKey(set.id)) {
          String initialRepsText = '';
          if (set.reps > 0) {
            initialRepsText = set.reps.toString();
          }
          _repsControllers[set.id] =
              TextEditingController(text: initialRepsText);
        }
      }
    }
  }

  // Check for active workout session from database and restore if found
  Future<void> _checkForActiveSessionFromDatabase() async {
    try {
      final activeSession = await _workoutService.getActiveWorkoutSession();

      if (activeSession != null) {
        final sessionWorkoutId = activeSession['workoutId'] as int;

        // Only restore if this is the same workout ID
        if (sessionWorkoutId == widget.workoutId) {
          print(
              'Found active session for workout ${widget.workoutId}, restoring...');

          // Restore elapsed time
          _elapsedSeconds = activeSession['elapsedSeconds'] as int;

          // Restore start time if available
          final startTime = activeSession['startTime'] as DateTime?;
          if (startTime != null) {
            _workoutStartTime = startTime;
          }

          // Parse and restore workout data
          final workoutDataString = activeSession['workoutData'] as String;
          final workoutData =
              jsonDecode(workoutDataString) as Map<String, dynamic>;

          // Set up restoration
          _isRestoringFromMinimized = true;
          _savedWorkoutData = workoutData;

          // Start timer with restored state
          _startTimer();

          print('Active session restored successfully');
        } else {
          // Different workout, clear the session and start fresh
          await _workoutService.clearActiveWorkoutSessions();
          _startTimer();
        }
      } else {
        // No active session, start fresh
        _startTimer();
      }
    } catch (e) {
      print('Error checking for active session: $e');
      // Fall back to starting fresh
      _startTimer();
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

    // Save initial workout state to database when timer starts
    _updateActiveNotifier();

    // Start the foreground service to keep workout running in background
    if (_workout != null) {
      final workoutData = _serializeWorkoutData();
      WorkoutForegroundService.startWorkoutService(
        _workout!.name,
        startTime: _workoutStartTime,
        workoutData: workoutData,
        workoutId: widget.workoutId,
        isTemporary: widget.isTemporary,
      );
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final newElapsedSeconds = now.difference(_workoutStartTime!).inSeconds;

      if (newElapsedSeconds != _elapsedSeconds) {
        _elapsedSeconds = newElapsedSeconds;

        if (mounted && !_isDisposing) {
          setState(() {});
          
          // ✅ FIXED: Update workout duration every 60 seconds (not 15 seconds)
          if (_elapsedSeconds % 60 == 0) {
            _updateWorkoutDuration();
            _updateActiveNotifier();
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

    // Stop the foreground service
    WorkoutForegroundService.stopWorkoutService();

    // Before stopping timer, ensure we have the most accurate elapsed time
    if (_workoutStartTime != null) {
      _elapsedSeconds = DateTime.now().difference(_workoutStartTime!).inSeconds;
    }

    // Only update UI state if widget is still mounted and not being disposed
    if (mounted && !_isDisposing) {
      setState(() {
        _isTimerRunning = false;
      });
      
      // Final update to the workout duration only if still mounted
      _updateWorkoutDuration();
    }
  }

  Future<void> _discardWorkout() async {
    // Show confirmation dialog for discarding workout
    bool confirmDiscard = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _surfaceColor,
            title: Text('Discard Workout',
                style: TextStyle(color: _textPrimaryColor)),
            content: Text(
              'Are you sure you want to discard this workout? This action cannot be undone and your progress will be lost.',
              style: TextStyle(color: _textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel',
                    style: TextStyle(color: _textSecondaryColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _dangerColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmDiscard) {
      // Mark workout as discarded for foreground service to prevent restoration
      await WorkoutForegroundService.markWorkoutAsDiscarded();

      // Clear the active session from database
      await _clearActiveSessionFromDatabase();

      // Discard the workout using the same logic as existing discard methods
      if (widget.isTemporary) {
        _workoutService.discardTemporaryWorkout(widget.workoutId);
      } else {
        await _workoutService.deleteWorkout(widget.workoutId);
      }

      // Clear active workout from memory
      WorkoutService.activeWorkoutNotifier.value = null;

      // Stop the foreground service
      await WorkoutForegroundService.stopWorkoutService();

      _stopTimer();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout discarded'),
          backgroundColor: _dangerColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

      // Set audio context for better background support - use notification sounds that don't interrupt music
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

      // Set audio context to avoid interrupting background music
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
      // Dispose player once playback completes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Error playing chime: $e');
      player.dispose();
    }
  }

  /// Play the fanfare sound effect for workout completion
  Future<void> _playFanfareSound() async {
    // Create a new player for fanfare
    final player = AudioPlayer();
    try {
      await player.setSource(AssetSource('audio/fanfare chime.mp3'));
      await player.setReleaseMode(ReleaseMode.release);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.0); // Full volume for celebration

      // Set audio context
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
      // Dispose player once playback completes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Error playing fanfare: $e');
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
      if (!mounted || _isDisposing || _restPausedNotifier.value) return;
      
      // Calculate remaining time based on real-world time difference (like workout timer)
      if (_restStartTime != null) {
        final elapsed = DateTime.now().difference(_restStartTime!).inSeconds;
        final newTimeRemaining =
            (_originalRestTime - elapsed).clamp(0, _originalRestTime);

        if (newTimeRemaining != _restRemainingNotifier.value) {
          if (mounted && !_isDisposing) {
            setState(() {
              _restTimeRemaining = newTimeRemaining;
              _restRemainingNotifier.value = newTimeRemaining;
            });
            // Update shared notifier so minimized bar reflects new time
            _updateActiveNotifier();
          }
        }
        
        // Check if timer finished
        if (newTimeRemaining <= 0) {
          timer.cancel();
          _restTimer = null;
          // Play the boxing bell sound when timer finishes - this will work even in background
          _playBoxingBellSound();
          if (mounted && !_isDisposing) {
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
  void _cancelRestTimer({bool playSound = true}) {
    // Don't cancel the rest timer if we're minimizing the app or restoring from minimized
    if (_isMinimizing || _isRestoringFromMinimized) {
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
    
    // Only update UI state if widget is still mounted
    if (mounted && !_isDisposing) {
      setState(() {
        _restTimeRemaining = 0;
        _currentRestSetId = null;
        _restStartTime = null;
        _restPausedNotifier.value = false;
        _restRemainingNotifier.value = 0;
      });
      
      // Update the active workout notifier to reflect the rest timer state change
      _updateActiveNotifier();
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

    if (result != null && result is List<Map<String, dynamic>>) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Add all selected exercises
        for (final exerciseData in result) {
          final exerciseName = exerciseData['name'] as String;
          final equipment = exerciseData['equipment'] as String? ?? '';
          final apiId = exerciseData['apiId'] as String? ??
              ''; // Get API ID from the selection result

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
        }

        _loadWorkout();

        // Auto-save the workout state after adding exercises
        _updateActiveNotifier();

        // Show success message
        _showSnackBar(
          'Added ${result.length} exercise${result.length == 1 ? '' : 's'}',
          customColor: _primaryColor,
        );
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error adding exercises: $e', isError: true);
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else if (result != null && result is Map<String, dynamic>) {
      // Handle backward compatibility for single exercise selection (custom exercises)
      final exerciseName = result['name'] as String;
      final equipment = result['equipment'] as String? ?? '';
      final apiId = result['apiId'] as String? ?? '';

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
        
        // Auto-save the workout state after adding an exercise
        _updateActiveNotifier();
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
  Future<void> _showEditNameDialog() async {
    if (widget.readOnly) return;

    // Create a temporary controller for the dialog
    final dialogController = TextEditingController(text: _workout?.name ?? '');
    String? result;

    try {
      result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _surfaceColor,
          title: Text('Edit Workout Name',
              style: TextStyle(color: _textPrimaryColor)),
          content: TextField(
            controller: dialogController,
            autofocus: true,
            style: TextStyle(color: _textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Enter workout name',
              hintStyle: TextStyle(color: _textSecondaryColor.withOpacity(0.7)),
              enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: _textSecondaryColor.withOpacity(0.5)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _primaryColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
            ),
            TextButton(
              onPressed: () {
                final newName = dialogController.text.trim();
                Navigator.pop(context, newName.isNotEmpty ? newName : null);
              },
              child: Text('Save', style: TextStyle(color: _primaryColor)),
            ),
          ],
        ),
      );
    } finally {
      // Always dispose the controller, even if dialog is dismissed by back button
      // Use a delay to ensure dialog is fully disposed first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dialogController.dispose();
      });
    }

    // Update the workout name if a valid name was provided
    if (result != null && result.isNotEmpty) {
      _updateWorkoutName(result);
    }
  }

  void _updateWorkoutName(String newName) {
    if (widget.readOnly || _workout == null) return;

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
        
        // Auto-save the workout state after adding a set
        _updateActiveNotifier();
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
              
              // If completing the set, check if it's a PR based on volume
              if (completed) {
                final double weight = sets[j]['weight'] ?? 0.0;
                final int reps = sets[j]['reps'] ?? 0;
                final double volume = weight * reps;
                final String currentExerciseName = exercises[i]['name'] ?? '';
                
                // For temporary workouts, check against historical data from database
                bool isPR = false;
                if (volume > 0) {
                  // Only check for PR if volume is greater than 0
                  // Clean the exercise name (remove API ID markers)
                  String cleanExerciseName = currentExerciseName.replaceAll(
                      RegExp(r'##API_ID:[^#]+##'), '');
                  isPR = await _workoutService.isPersonalRecord(
                      cleanExerciseName, volume);
                }
                
                sets[j]['isPR'] = isPR;
              } else {
                sets[j]['isPR'] = false;
              }
              
              found = true;
            }
          }
        }
        if (found) {
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
          WorkoutService.workoutsUpdatedNotifier.value =
              !WorkoutService.workoutsUpdatedNotifier.value;
          // Auto-save the workout state after updating set completion
          _updateActiveNotifier();
        }
      }
    } else {
      // Update in database for regular workouts - use the proper service method that includes PR calculation
      await _workoutService.updateSetStatus(setId, completed);
      // Auto-save the workout state after updating set completion
      _updateActiveNotifier();
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
              sets[j]['volume'] = weight * reps;
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
          'volume': weight * reps,
        },
        where: 'id = ?',
        whereArgs: [setId],
      );
    }

    // Notify listeners in either case
    WorkoutService.workoutsUpdatedNotifier.value =
        !WorkoutService.workoutsUpdatedNotifier.value;
    
    // Auto-save the workout state after updating set data
    _updateActiveNotifier();
  }

  /// Comprehensive cleanup when finishing workout
  /// 1. Keep sets already marked as completed (they are safe)
  /// 2. Auto-complete valid sets that have weight >= 0 AND reps >= 0 but aren't completed yet
  /// 3. Hard delete invalid sets that have negative values or empty fields
  Future<void> _cleanupWorkoutOnFinish() async {
    if (_workout == null) return;

    // Keep track of exercises to delete if they become empty
    final exercisesToDelete = <int>[];

    // Process each exercise
    for (var exercise in _workout!.exercises) {
      final setsToDelete = <int>[];

      // Process each set in the exercise
      for (var set in exercise.sets) {
        // Save any pending inline edits first
        final wText = _weightControllers[set.id]?.text ?? '';
        final rText = _repsControllers[set.id]?.text ?? '';

        final weight = double.tryParse(wText) ?? set.weight;
        final reps = int.tryParse(rText) ?? set.reps;

        // Update the set with current input values
        await _updateSetData(set.id, weight, reps, set.restTime);

        // Skip sets already marked as completed (they are safe)
        if (set.completed) {
          continue;
        }

        // Check if set has valid data - 0 is a valid value for weight and reps
        // Only consider a set invalid if both weight and reps are negative or null
        final bool hasValidWeight = weight >= 0;
        final bool hasValidReps = reps >= 0;

        if (hasValidWeight && hasValidReps) {
          // Valid set but not completed - mark as completed to make it safe
          await _updateSetComplete(set.id, true);
        } else {
          // Invalid set (negative values) - mark for deletion
          setsToDelete.add(set.id);
        }
      }

      // Delete invalid sets
      for (var setId in setsToDelete) {
        await _workoutService.deleteSet(setId);
      }

      // If all sets in this exercise were deleted, mark exercise for deletion
      if (setsToDelete.length == exercise.sets.length) {
        exercisesToDelete.add(exercise.id);
      }
    }

    // Delete exercises that have no valid sets left
    for (var exerciseId in exercisesToDelete) {
      await _workoutService.deleteExercise(exerciseId);
    }

    // Refresh the workout data to reflect all changes
    _loadWorkout();
  }


  Future<void> _deleteSet(int exerciseId, int setId) async {
    // Find the exercise and set in our local state
    final exerciseIndex =
        _workout!.exercises.indexWhere((e) => e.id == exerciseId);
    if (exerciseIndex == -1) return;

    final exercise = _workout!.exercises[exerciseIndex];
    final setIndex = exercise.sets.indexWhere((s) => s.id == setId);
    if (setIndex == -1) return;

    // Check if this set has an active rest timer and cancel it
    if (_currentRestSetId == setId) {
      _cancelRestTimer(playSound: false);
    }

    // Check if this is the last set for this exercise
    final bool isLastSet = exercise.sets.length == 1;

    // If it's the last set, this should not happen anymore since we handle it in confirmDismiss
    // But keep as safety check
    if (isLastSet) {
      print('Warning: _deleteSet called for last set - this should be handled in confirmDismiss');
      _confirmDeleteExercise(exercise);
      return; // Exit early since we're delegating to the confirmation dialog
    }

    // If not the last set, proceed with set deletion
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

          // Find the exercise and remove the specific set
          for (var exerciseData in exercises) {
            if (exerciseData['id'] == exerciseId) {
              final sets = exerciseData['sets'] as List;
              sets.removeWhere((setData) => setData['id'] == setId);

              // Update set numbers in the temporary data
              for (int i = 0; i < sets.length; i++) {
                sets[i]['setNumber'] = i + 1;
              }
              break;
            }
          }
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      } else {
        // Regular database operations for permanent workouts
        // Delete from the database in the background
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
        );
      }
      
      // Auto-save the workout state after deleting set
      _updateActiveNotifier();
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
    // Check if any sets in this exercise have an active rest timer
    Exercise? exerciseToDelete;
    try {
      exerciseToDelete = _workout!.exercises.firstWhere(
        (e) => e.id == exerciseId,
      );
    } catch (e) {
      // Exercise not found, it might have already been deleted
      print('Exercise with ID $exerciseId not found, skipping deletion');
      return;
    }

    // Cancel rest timer if any set in this exercise has an active rest timer
    for (final set in exerciseToDelete.sets) {
      if (_currentRestSetId == set.id) {
        _cancelRestTimer(playSound: false);
        break;
      }
    }
    
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
    
    // Track if any changes were made
    bool hasChanges = false;
    
    // Update all sets with current values from controllers
    for (final exercise in _workout!.exercises) {
      for (final set in exercise.sets) {
        double originalWeight = set.weight;
        int originalReps = set.reps;
        
        // Get data from controllers if they exist
        if (_weightControllers.containsKey(set.id)) {
          final weightText = _weightControllers[set.id]!.text.trim();
          if (weightText.isNotEmpty) {
            final newWeight = double.tryParse(weightText) ?? 0;
            if (newWeight != originalWeight) {
              set.weight = newWeight;
              hasChanges = true;
            }
          }
        }
        
        if (_repsControllers.containsKey(set.id)) {
          final repsText = _repsControllers[set.id]!.text.trim();
          if (repsText.isNotEmpty) {
            final newReps = int.tryParse(repsText) ?? 0;
            if (newReps != originalReps) {
              set.reps = newReps;
              hasChanges = true;
            }
          }
        }

        // If changes were made, persist them to database/temp storage immediately
        // Use direct database update to avoid recursive calls to _updateActiveNotifier
        if (hasChanges &&
            (set.weight != originalWeight || set.reps != originalReps)) {
          // Direct database update without calling _updateSetData to avoid recursion
          if (widget.isTemporary || set.id < 0) {
            // Update temporary workout in memory
            final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
            if (tempWorkouts.containsKey(widget.workoutId)) {
              final exercises = tempWorkouts[widget.workoutId]['exercises'];
              for (var i = 0; i < exercises.length; i++) {
                final sets = exercises[i]['sets'];
                for (var j = 0; j < sets.length; j++) {
                  if (sets[j]['id'] == set.id) {
                    sets[j]['weight'] = set.weight;
                    sets[j]['reps'] = set.reps;
                    sets[j]['volume'] = set.weight * set.reps;
                    break;
                  }
                }
              }
              WorkoutService.tempWorkoutsNotifier.value =
                  Map.from(tempWorkouts);
            }
          } else {
            // Update regular workout in database asynchronously
            DatabaseService.instance.database.then((db) {
              db.update(
                'exercise_sets',
                {
                  'weight': set.weight,
                  'reps': set.reps,
                  'volume': set.weight * set.reps,
                },
                where: 'id = ?',
                whereArgs: [set.id],
              );
            });
          }
          hasChanges = false; // Reset flag for next set
        }
      }
    }
    
    // If this is a temporary workout, update the data in the temp storage as well
    if (widget.isTemporary) {
      _updateTemporaryWorkoutData();
    }
    
    // Auto-save the complete workout state
    _updateActiveNotifier();
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
    // Update the notifier with the modified data to ensure changes persist
    WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
  }
  
  // Helper method to serialize workout data for storage  
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
    

    
    if (_workout == null) {
      return workoutData;
    }
    
    // Serialize all exercises and their sets
    for (final exercise in _workout!.exercises) {
      final Map<String, dynamic> exerciseData = {
        'id': exercise.id,
        'name': exercise.name,
        'equipment': exercise.equipment,
        'sets': [],
      };
      
      // Serialize all sets for this exercise, but only include valid sets
      bool hasValidSets = false;
      for (final set in exercise.sets) {
        // Include sets that have valid data (weight >= 0 AND reps >= 0) OR are completed
        // 0 is a valid value for both weight and reps
        final bool hasValidWeight = set.weight >= 0;
        final bool hasValidReps = set.reps >= 0;
        final bool isCompleted = set.completed;
        
        // Include the set if it has valid data or if it's marked as completed
        if ((hasValidWeight && hasValidReps) || isCompleted) {
          hasValidSets = true;
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
      }
      
      // Only add exercise to workoutData if it has at least one valid set
      if (hasValidSets) {
        workoutData['exercises'].add(exerciseData);
      }
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
      'isRunning': _isTimerRunning,
      'currentRestSetId': _currentRestSetId,
      'restTimeRemaining': _restTimeRemaining,
      'restPaused': _restPausedNotifier.value,
    };
    
    // Update the foreground service with current workout data
    // Always store to SharedPreferences for foreground service access
    WorkoutForegroundService.updateWorkoutData(workoutData);
    
    // Save to persistent storage for app restart recovery
    _saveCompleteWorkoutState();
  }

  // Save complete workout state to persistent storage for hot restart recovery
  Future<void> _saveCompleteWorkoutState() async {
    if (_workout == null) return;

    try {
      final workoutData = _serializeWorkoutData();

      // Save to database for persistent storage across app restarts
      await _workoutService.updateActiveWorkoutSession(
        workoutId: widget.workoutId,
        workoutData: jsonEncode(workoutData),
        elapsedSeconds: _elapsedSeconds,
      );

      // Always save to foreground service to ensure workout state is preserved
      await WorkoutForegroundService.startWorkoutService(
        _workout!.name,
        startTime: _workoutStartTime,
        workoutData: workoutData,
        workoutId: widget.workoutId,
        isTemporary: widget.isTemporary,
      );
    } catch (e) {
      print('Error saving complete workout state: $e');
    }
  } // Helper method to restore workout data from serialized format
  void _restoreWorkoutData(Map<String, dynamic> workoutData) {
    print('RESTORE DEBUG: Starting restoration process');
    print('RESTORE DEBUG: Workout is null: ${_workout == null}');
    print(
        'RESTORE DEBUG: Workout exercises count: ${_workout?.exercises.length ?? 0}');
    print(
        'RESTORE DEBUG: Saved exercises count: ${(workoutData['exercises'] as List?)?.length ?? 0}');

    if (_workout == null || workoutData['exercises'] == null) {
      print("RESTORE DEBUG: Early return - workout or exercises is null");
      return;
    }

    // Restore rest timer state if it was active
    if (workoutData.containsKey('restTimerState')) {
      final restState = workoutData['restTimerState'] as Map<String, dynamic>;
      final bool isActive = restState['isActive'] as bool? ?? false;

      if (isActive) {
        print(
            "RESTORE DEBUG: Active rest timer detected, proceeding with restoration");
      } else {
        print("RESTORE DEBUG: Rest timer was not active, skipping restoration");
      }

      if (isActive && restState['setId'] != null) {
        final int setId = restState['setId'] as int;
        int timeRemaining = restState['timeRemaining'] as int;
        final bool isPaused = restState['isPaused'] as bool? ?? false;
        final int originalTime =
            restState['originalTime'] as int? ?? timeRemaining;
        final int? startTimeMs = restState['startTime'] as int?;



        // If timer was active (not paused) and we have a start time, adjust for time passed
        if (!isPaused && startTimeMs != null) {
          final restStartTime =
              DateTime.fromMillisecondsSinceEpoch(startTimeMs);
          final elapsed = DateTime.now().difference(restStartTime).inSeconds;
          timeRemaining = (originalTime - elapsed).clamp(0, originalTime);
        } else if (!isPaused && restState.containsKey('timestamp')) {
          // If we don't have startTime but have timestamp, use that as a fallback
          final int timestampMs = restState['timestamp'] as int;
          final int elapsedSinceTimestamp =
              (DateTime.now().millisecondsSinceEpoch - timestampMs) ~/ 1000;
          // Adjust remaining time, ensuring it doesn't go below 0
          timeRemaining =
              (timeRemaining - elapsedSinceTimestamp).clamp(0, timeRemaining);
          print(
              "RESTORE DEBUG: Adjusted time remaining based on timestamp: $timeRemaining seconds");
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
        } // Restart the rest timer if it was active and has time remaining
        else if (timeRemaining > 0) {
          print(
              "RESTORE DEBUG: Restoring rest timer with $timeRemaining seconds remaining for set $setId");
          
          // Cancel any existing rest timer first
          if (_restTimer != null) {
            _restTimer!.cancel();
            _restTimer = null;
          }

          // Restore rest start time for continuous tracking
          if (startTimeMs != null) {
            _restStartTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
            print("RESTORE DEBUG: Restored rest start time: $_restStartTime");
          } else {
            // If we don't have a start time, create one based on the current remaining time
            _restStartTime = DateTime.now()
                .subtract(Duration(seconds: originalTime - timeRemaining));
            print(
                "RESTORE DEBUG: Created rest start time based on remaining time: $_restStartTime");
          }

          // Restore all rest timer state
          setState(() {
            _currentRestSetId = setId;
            _restTimeRemaining = timeRemaining;
            _originalRestTime = originalTime;
            _restRemainingNotifier.value = timeRemaining;
            _restPausedNotifier.value = isPaused;
          });

          print(
              "RESTORE DEBUG: Rest timer state set - CurrentSetId: $_currentRestSetId, TimeRemaining: $_restTimeRemaining");

          // Only start the timer if it's not paused
          if (!isPaused) {
            print("RESTORE DEBUG: Starting rest timer (not paused)");
            // Create a new timer that updates the UI like the workout timer
            _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted || _isDisposing || _restPausedNotifier.value) return;

              if (_restStartTime != null) {
                final elapsed =
                    DateTime.now().difference(_restStartTime!).inSeconds;
                final newTimeRemaining =
                    (_originalRestTime - elapsed).clamp(0, _originalRestTime);

                if (newTimeRemaining != _restRemainingNotifier.value) {
                  if (mounted && !_isDisposing) {
                    setState(() {
                      _restTimeRemaining = newTimeRemaining;
                      _restRemainingNotifier.value = newTimeRemaining;
                    });
                    _updateActiveNotifier();
                  }
                }

                if (newTimeRemaining <= 0) {
                  timer.cancel();
                  _restTimer = null;
                  _playBoxingBellSound();
                  if (mounted && !_isDisposing) {
                    setState(() {
                      _currentRestSetId = null;
                      _restStartTime = null;
                    });
                  }
                  _updateActiveNotifier();
                }
              }
            });
            print("RESTORE DEBUG: Rest timer started successfully");
          } else {
            print(
                "RESTORE DEBUG: Rest timer is paused, not starting periodic timer");
          } // Update the active notifier with restored state
          _updateActiveNotifier();
          print(
              "RESTORE DEBUG: Updated active notifier with restored rest timer state");
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
    } // Force UI update
    setState(() {});

    // Clear the restoration flag after successful restoration (at the end of the method)
    _isRestoringFromMinimized = false;

    // Final debug check to verify restoration
    print(
        "RESTORE DEBUG: Final state check - CurrentRestSetId: $_currentRestSetId, RestTimeRemaining: $_restTimeRemaining, RestTimer: ${_restTimer != null ? 'Active' : 'Null'}");
    print("RESTORE DEBUG: Restoration completed and flag cleared");
  }

  // Helper method to initialize controllers with values from saved workout data
  void _initializeControllersFromSavedData(Map<String, dynamic> workoutData) {
    final List<dynamic> exercisesData = workoutData['exercises'] ?? [];

    for (final exerciseData in exercisesData) {
      final List<dynamic> setsData = exerciseData['sets'] ?? [];

      for (final setData in setsData) {
        final int setId = setData['id'];
        final double weight = (setData['weight'] ?? 0).toDouble();
        final int reps = setData['reps'] ?? 0;

        // Initialize weight controller if it doesn't exist
        if (!_weightControllers.containsKey(setId)) {
          _weightControllers[setId] = TextEditingController();
        }

        // Initialize reps controller if it doesn't exist
        if (!_repsControllers.containsKey(setId)) {
          _repsControllers[setId] = TextEditingController();
        }

        // Set controller values from saved data
        final weightText =
            (weight % 1 == 0) ? weight.toInt().toString() : weight.toString();
        _weightControllers[setId]!.text = weight > 0 ? weightText : '';
        _repsControllers[setId]!.text = reps > 0 ? reps.toString() : '';
      }
    }
  }

  // Helper method to restore only rest timer state (for temporary workouts with exercises already loaded)
  void _restoreRestTimerOnly(Map<String, dynamic> workoutData) {
    print('RESTORE DEBUG: Restoring rest timer only');

    // Restore rest timer state if it was active
    if (workoutData.containsKey('restTimerState')) {
      final restState = workoutData['restTimerState'] as Map<String, dynamic>;
      final bool isActive = restState['isActive'] as bool? ?? false;

      if (isActive && restState['setId'] != null) {
        final int setId = restState['setId'] as int;
        int timeRemaining = restState['timeRemaining'] as int;
        final bool isPaused = restState['isPaused'] as bool? ?? false;
        final int originalTime =
            restState['originalTime'] as int? ?? timeRemaining;
        final int? startTimeMs = restState['startTime'] as int?;

        // If timer was active (not paused) and we have a start time, adjust for time passed
        if (!isPaused && startTimeMs != null) {
          final restStartTime =
              DateTime.fromMillisecondsSinceEpoch(startTimeMs);
          final elapsed = DateTime.now().difference(restStartTime).inSeconds;
          timeRemaining = (originalTime - elapsed).clamp(0, originalTime);
        } else if (!isPaused && restState.containsKey('timestamp')) {
          final int timestampMs = restState['timestamp'] as int;
          final int elapsedSinceTimestamp =
              (DateTime.now().millisecondsSinceEpoch - timestampMs) ~/ 1000;
          timeRemaining =
              (timeRemaining - elapsedSinceTimestamp).clamp(0, timeRemaining);
        }

        // If timer completed while minimized, play sound once
        if (!isPaused && timeRemaining <= 0) {
          _playBoxingBellSound();
          setState(() {
            _currentRestSetId = null;
            _restTimeRemaining = 0;
            _restRemainingNotifier.value = 0;
            _restStartTime = null;
          });
        } else if (timeRemaining > 0) {
          // Restore rest start time for continuous tracking
          if (startTimeMs != null) {
            _restStartTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
          } else {
            _restStartTime = DateTime.now()
                .subtract(Duration(seconds: originalTime - timeRemaining));
          }

          // Restore all rest timer state
          setState(() {
            _currentRestSetId = setId;
            _restTimeRemaining = timeRemaining;
            _originalRestTime = originalTime;
            _restRemainingNotifier.value = timeRemaining;
            _restPausedNotifier.value = isPaused;
          });

          // Only start the timer if it's not paused
          if (!isPaused) {
            _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted || _isDisposing || _restPausedNotifier.value) return;

              if (_restStartTime != null) {
                final elapsed =
                    DateTime.now().difference(_restStartTime!).inSeconds;
                final newTimeRemaining =
                    (_originalRestTime - elapsed).clamp(0, _originalRestTime);

                if (newTimeRemaining != _restRemainingNotifier.value) {
                  if (mounted && !_isDisposing) {
                    setState(() {
                      _restTimeRemaining = newTimeRemaining;
                      _restRemainingNotifier.value = newTimeRemaining;
                    });
                    _updateActiveNotifier();
                  }
                }

                if (newTimeRemaining <= 0) {
                  timer.cancel();
                  _restTimer = null;
                  _playBoxingBellSound();
                  if (mounted && !_isDisposing) {
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

          _updateActiveNotifier();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {


    
    return WillPopScope(
        onWillPop: () async {
          // Don't minimize if in read-only mode, just pop
          if (widget.readOnly) {
            return true; // Allow pop to proceed normally
          }

          // Minimize active workouts regardless of whether they have exercises
          if (_workout != null) {
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
            
            // Update the foreground service with the latest workout data
            if (WorkoutForegroundService.isServiceRunning) {
              WorkoutForegroundService.startWorkoutService(
                _workout!.name,
                startTime: _workoutStartTime,
                workoutData: workoutData,
                workoutId: widget.workoutId,
                isTemporary: widget.isTemporary,
              );
            }

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
              icon: Icon(Icons.keyboard_arrow_down,
                  color: _textPrimaryColor, size: 28),
              onPressed: () {
                if (widget.readOnly) {
                  Navigator.of(context).pop();
                  return;
                }
                // Minimize and keep timers running for any active workout
                if (_workout != null) {
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
                  
                  // Update the foreground service with the latest workout data
                  if (WorkoutForegroundService.isServiceRunning) {
                    WorkoutForegroundService.startWorkoutService(
                      _workout!.name,
                      startTime: _workoutStartTime,
                      workoutData: workoutData,
                      workoutId: widget.workoutId,
                      isTemporary: widget.isTemporary,
                    );
                  }
                }
                Navigator.of(context).pop();
              },
            ),
            title: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _currentRestSetId != null ? _primaryColor.withOpacity(0.1) : _surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: _currentRestSetId != null 
                    ? Border.all(color: _primaryColor, width: 1)
                    : null,
              ),
              child: _currentRestSetId != null 
                  ? GestureDetector(
                      onTap: () async {
                        // Navigate to rest timer page when rest timer is active
                        if (_currentRestSetId != null) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RestTimerPage(
                                originalDuration: _originalRestTime,
                                remaining: _restRemainingNotifier,
                                isPaused: _restPausedNotifier,
                                onPause: _togglePauseRest,
                                onIncrement: _incrementRest,
                                onDecrement: _decrementRest,
                                onSkip: () {
                                  _cancelRestTimer(playSound: true);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                color: _primaryColor,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                _formatTime(_restTimeRemaining),
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Container(
                            width: 100,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _originalRestTime > 0 
                                  ? (_restTimeRemaining / _originalRestTime).clamp(0.0, 1.0)
                                  : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      _formatTime(_elapsedSeconds),
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
            actions: [
              if (!widget.readOnly)
            TextButton.icon(
              icon: Icon(Icons.check, color: _successColor),
              label: Text(
                    'Finished',
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
                          print(
                              '🗑️ WorkoutSessionPage: User confirmed discard of empty temporary workout ID: ${widget.workoutId}');
                      _workoutService.discardTemporaryWorkout(widget.workoutId);
                    } else {
                          print(
                              '🗑️ WorkoutSessionPage: User confirmed delete of empty regular workout ID: ${widget.workoutId}');
                      await _workoutService.deleteWorkout(widget.workoutId);
                    }
                    
                        // Clear active workout from memory to remove the active workout bar
                        WorkoutService.activeWorkoutNotifier.value = null;
                    
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

                    // Analyze all sets and categorize them
                    Map<int, List<int>> invalidSetsByExercise =
                        {}; // exerciseId -> list of invalid setIds
                    Map<int, List<int>> validUncompletedSetsByExercise =
                        {}; // exerciseId -> list of valid uncompleted setIds
                int totalSets = 0;
                    int invalidSets = 0;
                    int validUncompletedSets = 0;
                
                for (var exercise in _workout!.exercises) {
                  for (var set in exercise.sets) {
                    totalSets++;
                    final wText = _weightControllers[set.id]?.text ?? '';
                    final rText = _repsControllers[set.id]?.text ?? '';
                    
                        // Parse the values using existing validation logic
                    final double? weight = double.tryParse(wText);
                    final int? repsInt = int.tryParse(rText);
                    final double? repsDouble = double.tryParse(rText);
                    
                        // Check for invalid values using existing validation:
                    // 1. Null values (empty fields) 
                    // 2. Negative weights or reps
                    // 3. Non-integer reps (decimal reps)
                        // Note: 0 is a valid value for both weight and reps
                        bool isInvalid = weight == null ||
                        repsInt == null || // Empty fields
                        (weight < 0) || // Negative weight
                        (repsInt < 0) || // Negative reps
                        (repsDouble != null &&
                            repsDouble != repsInt.toDouble()); // Decimal reps

                        if (isInvalid) {
                          // This set is invalid and will be removed
                          invalidSets++;
                          if (!invalidSetsByExercise.containsKey(exercise.id)) {
                            invalidSetsByExercise[exercise.id] = [];
                          }
                          invalidSetsByExercise[exercise.id]!.add(set.id);
                        } else if (!set.completed) {
                          // This set is valid but not completed - will be auto-completed
                          validUncompletedSets++;
                          if (!validUncompletedSetsByExercise
                              .containsKey(exercise.id)) {
                            validUncompletedSetsByExercise[exercise.id] = [];
                          }
                          validUncompletedSetsByExercise[exercise.id]!
                              .add(set.id);
                        }
                      }
                    } // If all sets are invalid, discard the entire workout
                    if (invalidSets == totalSets && totalSets > 0) {
                  bool confirmDiscard = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: _surfaceColor,
                              title: Text('Invalid Workout',
                              style: TextStyle(color: _textPrimaryColor)),
                          content: Text(
                                'All sets in this workout are invalid (missing or incorrect weight/reps). The entire workout will be discarded.',
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
                    
                        // Clear the active session from database
                        await _clearActiveSessionFromDatabase();

                        // Clear active workout from memory to remove the active workout bar
                        WorkoutService.activeWorkoutNotifier.value = null;
                    
                    _stopTimer();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                            content: Text('Invalid workout discarded'),
                        backgroundColor: _primaryColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  } else {
                        return; // User chose to go back
                      }
                    }

                    // Show confirmation dialog explaining what will happen
                    String dialogTitle = 'Finish Workout';
                    List<Widget> dialogContent = [];
                
                    bool hasInvalidSets = invalidSets > 0;
                    bool hasValidUncompletedSets = validUncompletedSets > 0;
                    bool hasNoIssues = !hasInvalidSets &&
                        !hasValidUncompletedSets &&
                        totalSets > 0;
                
                    if (hasNoIssues) {
                      // Perfect workout - all sets are valid and completed
                      dialogContent.add(Text(
                        'All sets are properly completed with valid data. Ready to finish this workout?',
                        style: TextStyle(color: _textSecondaryColor),
                      ));
                    } else {
                      // Workout needs cleanup
                      dialogContent.add(Text(
                        'The following actions will be performed:',
                        style: TextStyle(
                            color: _textSecondaryColor,
                            fontWeight: FontWeight.bold),
                      ));
                      dialogContent.add(SizedBox(height: 12));
                  
                      if (hasInvalidSets) {
                        dialogContent.add(Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.delete_outline,
                                color: _dangerColor, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                          child: Text(
                                '$invalidSets invalid set${invalidSets > 1 ? 's' : ''} will be removed (missing or incorrect weight/reps)',
                                style: TextStyle(color: _textSecondaryColor),
                          ),
                            ),
                          ],
                        ));
                        dialogContent.add(SizedBox(height: 8));
                      }
                  
                      if (hasValidUncompletedSets) {
                        dialogContent.add(Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: _successColor, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$validUncompletedSets valid set${validUncompletedSets > 1 ? 's' : ''} will be marked as completed',
                                style: TextStyle(color: _textSecondaryColor),
                              ),
                            ),
                          ],
                        ));
                      }
                    }
                
                    // Show workout duration
                    dialogContent.add(SizedBox(height: 16));
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

                    // Show the confirmation dialog
                    bool continueWithWorkout = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: _surfaceColor,
                            title: Text(dialogTitle,
                                style: TextStyle(color: _textPrimaryColor)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: dialogContent,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text('Cancel',
                                    style:
                                        TextStyle(color: _textSecondaryColor)),
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
                        ) ??
                        false;

                    if (!continueWithWorkout) {
                      return; // User chose to cancel
                    }

                    // Play fanfare sound for workout completion
                    _playFanfareSound();

                    // Comprehensive cleanup when finishing workout
                    await _cleanupWorkoutOnFinish();

                    // Handle temporary vs regular workouts differently
                    if (widget.isTemporary) {
                      // For temporary workouts, check if we have any valid exercises and sets
                      if (_workout?.exercises.isEmpty ?? true) {
                        // No exercises, discard the temporary workout
                        _workoutService
                            .discardTemporaryWorkout(widget.workoutId);
                        // Clear the active session from database
                        await _clearActiveSessionFromDatabase();
                        
                        // Mark workout as discarded for foreground service to prevent restoration
                        await WorkoutForegroundService.markWorkoutAsDiscarded();

                        // Clear active workout from memory to remove the active workout bar
                        WorkoutService.activeWorkoutNotifier.value = null;

                        // Stop the foreground service and clear saved data
                        await WorkoutForegroundService.stopWorkoutService();
                        await WorkoutForegroundService.clearSavedWorkoutData();
                        
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
                            'name': _workout!.name,
                          'date': _workout!.date,
                          'duration': _elapsedSeconds,
                          'exercises': _workout!.exercises.map((exercise) {
                            return {
                              'name': exercise.name,
                              'equipment': exercise.equipment,
                                'sets': exercise.sets.where((set) {
                                  // Include sets that have valid data (weight >= 0 AND reps >= 0) OR are completed
                                  // 0 is a valid value for both weight and reps
                                  final bool hasValidWeight = set.weight >= 0;
                                  final bool hasValidReps = set.reps >= 0;
                                  final bool isCompleted = set.completed;
                                  return (hasValidWeight && hasValidReps) ||
                                      isCompleted;
                                }).map((set) {
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
                        // Clear the active session from database
                        await _clearActiveSessionFromDatabase();
                        
                        // Mark workout as discarded for foreground service to prevent restoration
                        await WorkoutForegroundService.markWorkoutAsDiscarded();
                      
                        // Clear active workout from memory to remove the active workout bar
                        WorkoutService.activeWorkoutNotifier.value = null;
                        
                        // Stop the foreground service and clear saved data
                        await WorkoutForegroundService.stopWorkoutService();
                        await WorkoutForegroundService.clearSavedWorkoutData();
                      
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

                    // Clear the active session from database since workout is being completed
                    await _clearActiveSessionFromDatabase();
                    
                    // Mark workout as discarded for foreground service to prevent restoration
                    await WorkoutForegroundService.markWorkoutAsDiscarded();
                  
                    // Clear active workout from memory to remove the active workout bar
                    WorkoutService.activeWorkoutNotifier.value = null;
                  
                    // Stop the timer and foreground service
                    _stopTimer();
                    
                    // Clear saved foreground service data to prevent restoration
                    await WorkoutForegroundService.clearSavedWorkoutData();
                    
                    // Get workout count for completion screen
                    final workoutCount = await _workoutService.getWorkoutCount();
                    
                    // Navigate to completion screen instead of just popping
                    if (mounted && _workout != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutCompletionPage(
                            workout: _workout!.copyWith(duration: _elapsedSeconds),
                            workoutNumber: workoutCount,
                          ),
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
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
                          // Workout name and menu
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _workout?.name ?? 'Workout',
                                  style: TextStyle(
                                    color: _textPrimaryColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!widget.readOnly)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      color: _textPrimaryColor),
                                  color: _surfaceColor,
                                  onSelected: (value) async {
                                    if (value == 'edit_name') {
                                      await _showEditNameDialog();
                                    } else if (value == 'discard') {
                                      await _discardWorkout();
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'edit_name',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined,
                                              color: _textPrimaryColor),
                                          SizedBox(width: 8),
                                          Text('Edit Name',
                                              style: TextStyle(
                                                  color: _textPrimaryColor)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'discard',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline,
                                              color: _dangerColor),
                                          SizedBox(width: 8),
                                          Text('Discard Workout',
                                              style: TextStyle(
                                                  color: _dangerColor)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
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
                        key: Key('exercise_menu_${exercise.id}'), // Unique key to avoid hero tag conflicts
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

    // Removed PR checking for workout session UI

    return RepaintBoundary(
      child: Dismissible(
        key: Key('set_${exercise.id}_${set.id}'), // More unique key including exercise ID
        direction:
          widget.readOnly ? DismissDirection.none : DismissDirection.endToStart,
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
          // For last set, we need to handle this specially to avoid the dismissed widget issue
          final exerciseForSet = _workout!.exercises.firstWhere((e) => e.sets.any((s) => s.id == set.id));
          final bool isLastSet = exerciseForSet.sets.length == 1;
          
          if (isLastSet) {
            // Don't allow dismissal - we'll handle this through the confirmation dialog
            // Show the confirmation dialog directly
            _confirmDeleteExercise(exerciseForSet);
            return false; // Don't dismiss the widget
          }
          
          // For non-last sets, allow normal dismissal
          return !widget.readOnly;
        },
        onDismissed: (direction) {
          // This should only be called for non-last sets now
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
                    color: set.completed 
                        ? _successColor 
                        : _primaryColor,
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
                    onChanged: (value) {
                      // Save immediately when user types
                      final weight = double.tryParse(value);
                      if (weight != null && weight >= 0) {
                        _updateSetData(set.id, weight, set.reps, set.restTime);
                      }
                    },
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
                    onChanged: (value) {
                      // Save immediately when user types
                      final reps = int.tryParse(value);
                      if (reps != null && reps >= 0) {
                        _updateSetData(set.id, set.weight, reps, set.restTime);
                      }
                    },
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
                            color: _textSecondaryColor)
                    : IconButton(
                        icon: set.completed
                            ? Icon(Icons.check_circle, color: _successColor)
                            : Icon(Icons.circle_outlined,
                                color: canCompleteButton
                                    ? _textSecondaryColor
                                    : _textSecondaryColor.withOpacity(0.3)),
                        tooltip: canCompleteButton
                            ? (set.completed
                                ? 'Mark as incomplete'
                                : 'Mark as completed')
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
    // Check if widget is still mounted and context is valid
    if (!mounted || !context.mounted) return;
    
    try {
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

      // Add a slight delay to ensure proper positioning, especially if dialogs are present
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted && context.mounted) {
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
      });
    } catch (e) {
      // Silently handle any SnackBar positioning errors
      print('SnackBar display error: $e');
    }
  }

  // Shows "Empty workout discarded" notification
}
