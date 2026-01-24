import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/foreground_service.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/rest_timer_page.dart';
import 'package:mental_warior/pages/workout/workout_completion_page.dart';
import 'package:mental_warior/pages/workout/superset_selection_page.dart';
import 'package:mental_warior/widgets/barbell_plate_calculator.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  final ExerciseStickyNoteService _stickyNoteService =
      ExerciseStickyNoteService();
  final SettingsService _settingsService = SettingsService();
  final ExerciseRestTimerHistoryService _restTimerHistoryService =
      ExerciseRestTimerHistoryService();
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

  // Exercise notes tracking (exerciseId -> note text)
  final Map<int, String> _exerciseNotes = {};

  // Sticky notes tracking (exerciseId -> whether note is sticky)
  final Map<int, bool> _isNoteSticky = {};

  // Superset tracking (exerciseId -> supersetId)
  // Exercises with the same supersetId are part of the same superset
  final Map<int, String> _exerciseSupersets = {};
  int _supersetCounter = 0; // Counter for generating unique superset IDs

  // Superset colors - each superset gets a unique color
  static const List<Color> _supersetColors = [
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF8BC34A), // Light Green
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF009688), // Teal
    Color(0xFF673AB7), // Deep Purple
  ];

  // Note editing state
  final Map<int, bool> _noteEditingState = {};
  final Map<int, TextEditingController> _noteControllers = {};

  // Theme colors - using AppTheme for consistency
  final Color _backgroundColor = AppTheme.background;
  final Color _surfaceColor = AppTheme.surface;
  final Color _primaryColor = AppTheme.accent;
  final Color _successColor = AppTheme.success;
  final Color _dangerColor = AppTheme.error;
  final Color _textPrimaryColor = AppTheme.textPrimary;
  final Color _textSecondaryColor = AppTheme.textSecondary;
  final Color _inputBgColor = AppTheme.surfaceLight;

  // Default rest time (loaded from settings)
  int _defaultRestTime = 90; // Will be updated from settings

  // Settings loaded from SettingsService
  bool _autoStartRestTimer = true;
  bool _vibrateOnRestComplete = true;
  bool _soundOnRestComplete = true;
  bool _confirmFinishWorkout = true;
  bool _showWeightInLbs = false;
  bool _keepScreenOn = true;

  // Timer tracking variables
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

  // Flag to track if workout is being completed/discarded
  bool _isCompleting = false;

  // Flag to track when we're updating data internally (to avoid triggering reload)
  bool _isUpdatingInternally = false;

  // Cache for previous exercise history to show as greyed out placeholders
  final Map<String, List<ExerciseSet>> _exerciseHistoryCache = {};

  // Listener for temp workout data changes
  void _onTempWorkoutDataChanged() {
    // Skip if we're updating data internally (e.g., typing in a text field)
    if (_isUpdatingInternally) return;

    // Only reload if this is still the active temporary workout and we're not disposing
    if (widget.isTemporary && !_isDisposing && mounted) {
      final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
      if (tempWorkouts.containsKey(widget.workoutId)) {
        print('🔄 Temp workout data changed, reloading workout...');
        // Force a setState first to trigger immediate rebuild
        if (mounted) {
          setState(() {
            // Mark as loading to show visual feedback
            _isLoading = true;
          });
        }
        // Then load the updated workout data
        _loadWorkout();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Add app lifecycle observer for better handling of background/foreground transitions
    WidgetsBinding.instance.addObserver(this);

    // Add listener for temporary workouts to auto-reload when data changes
    if (widget.isTemporary) {
      WorkoutService.tempWorkoutsNotifier
          .addListener(_onTempWorkoutDataChanged);
    }

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
            if (timeRemaining > 0 && setId != null) {}
          }
          // Full timer restoration will be handled in _restoreWorkoutData after workout loads
        }
      }
    }

    // Load settings first
    _loadSettings();

    // Listen for settings changes
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsChanged);

    // Load the workout AFTER setting up restoration flags
    _loadWorkout();

    // If not minimized and not read-only, check for active session from database
    if (!widget.minimized && !widget.readOnly) {
      _checkForActiveSessionFromDatabase();
    } else if (!widget.minimized && !widget.readOnly) {
      _startTimer();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.getAllSettings();
    if (mounted) {
      setState(() {
        _defaultRestTime = settings['defaultRestTimer'];
        _autoStartRestTimer = settings['autoStartRestTimer'];
        _vibrateOnRestComplete = settings['vibrateOnRestComplete'];
        _soundOnRestComplete = settings['soundOnRestComplete'];
        _confirmFinishWorkout = settings['confirmFinishWorkout'];
        _showWeightInLbs = settings['showWeightInLbs'];
        _keepScreenOn = settings['keepScreenOn'];
      });

      // Apply wakelock setting (only for non-readonly sessions)
      if (!widget.readOnly) {
        _applyWakelockSetting();
      }
    }
  }

  /// Apply the wakelock setting to keep screen on during workout
  Future<void> _applyWakelockSetting() async {
    try {
      if (_keepScreenOn) {
        await WakelockPlus.enable();
        debugPrint('Wakelock enabled - screen will stay on');
      } else {
        await WakelockPlus.disable();
        debugPrint('Wakelock disabled - screen can sleep');
      }
    } catch (e) {
      debugPrint('Error applying wakelock: $e');
    }
  }

  // Get the weight unit based on settings
  String get _weightUnit => _showWeightInLbs ? 'lbs' : 'kg';

  void _onSettingsChanged() {
    _loadSettings();
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

    // Remove listener for temporary workouts
    if (widget.isTemporary) {
      WorkoutService.tempWorkoutsNotifier
          .removeListener(_onTempWorkoutDataChanged);
    }

    // Remove settings listener
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsChanged);

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

      // Disable wakelock when workout is closed
      WakelockPlus.disable();
      debugPrint('Wakelock disabled on workout close');
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
    }
    for (var c in _noteControllers.values) {
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

  // Helper method to clean exercise names by removing markers
  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
  }

  // Helper method to get set type display text
  String _getSetTypeDisplay(ExerciseSet set) {
    switch (set.setType) {
      case SetType.warmup:
        return 'W';
      case SetType.dropset:
        return 'D';
      case SetType.failure:
        return 'F';
      case SetType.normal:
        return '${set.setNumber}';
    }
  }

  // Helper method to check if an exercise uses plates (barbell, ez-curl bar, trap bar)
  bool _exerciseUsesPlates(String equipment) {
    final lowerEquipment = equipment.toLowerCase();
    return lowerEquipment.contains('barbell') ||
        lowerEquipment.contains('e-z curl') ||
        lowerEquipment.contains('ez curl') ||
        lowerEquipment.contains('trap bar') ||
        lowerEquipment.contains('smith') ||
        lowerEquipment.contains('dumbbell');
  }

  // Show the barbell plate calculator
  Future<void> _showPlateCalculator(ExerciseSet set, Exercise exercise) async {
    final currentWeightText = _weightControllers[set.id]?.text ?? '';
    double currentWeight =
        double.tryParse(currentWeightText.trim()) ?? set.weight;

    if (currentWeight <= 0) {
      final previousSet = _getPreviousSetValues(exercise.name, set.setNumber);
      if (previousSet != null && previousSet.weight > 0) {
        currentWeight = previousSet.weight;
      }
    }

    final newWeight = await showBarbellPlateCalculator(
      context: context,
      initialWeight: currentWeight,
      useLbs: _showWeightInLbs,
      exerciseName:
          exercise.name, // Pass exercise name to save/load plate config
      equipment: exercise.equipment, // Pass equipment to determine default bar
    );

    if (newWeight != null && mounted) {
      // Update the controller
      final weightText = newWeight % 1 == 0
          ? newWeight.toInt().toString()
          : newWeight.toString();
      _weightControllers[set.id]?.text = weightText;

      // Update the set data
      _updateSetData(set.id, newWeight, set.reps, set.restTime);
    }
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
                notes: exerciseData['notes'] as String?,
              ));

              // Restore notes to the tracking map
              if (exerciseData['notes'] != null &&
                  exerciseData['notes'] is String) {
                _exerciseNotes[exerciseId] = exerciseData['notes'] as String;
              }

              // Check if this exercise has a sticky note
              final exerciseName = exerciseData['name'] ?? 'Exercise';
              final hasStickyNote =
                  await _stickyNoteService.hasStickyNote(exerciseName);
              if (hasStickyNote) {
                _isNoteSticky[exerciseId] = true;
              }
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
            // Track unique superset groups to calculate counter
            final Set<String> uniqueSupersets = {};

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

                    // Parse set type
                    SetType setType = SetType.normal;
                    if (setData.containsKey('setType')) {
                      final String? setTypeStr = setData['setType'] as String?;
                      if (setTypeStr != null) {
                        switch (setTypeStr.toLowerCase()) {
                          case 'warmup':
                            setType = SetType.warmup;
                            break;
                          case 'dropset':
                            setType = SetType.dropset;
                            break;
                          case 'failure':
                            setType = SetType.failure;
                            break;
                          case 'normal':
                          default:
                            setType = SetType.normal;
                            break;
                        }
                      }
                    }

                    sets.add(ExerciseSet(
                      id: setId,
                      exerciseId: exerciseId,
                      setNumber: setData['setNumber'] ?? 1,
                      weight: setData['weight'] ?? 0,
                      reps: setData['reps'] ?? 0,
                      restTime: setData['restTime'] ?? _defaultRestTime,
                      completed: setData['completed'] ?? false,
                      isPR: setData['isPR'] ?? false,
                      setType: setType,
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
                  notes: exerciseData['notes'] as String?,
                  supersetGroup: exerciseData['supersetGroup'] as String?,
                ));

                // Load notes into the tracking map
                if (exerciseData['notes'] != null &&
                    exerciseData['notes'] is String) {
                  _exerciseNotes[exerciseId] = exerciseData['notes'] as String;
                }

                // Load superset group into tracking map
                if (exerciseData['supersetGroup'] != null &&
                    exerciseData['supersetGroup'] is String) {
                  final supersetGroup = exerciseData['supersetGroup'] as String;
                  _exerciseSupersets[exerciseId] = supersetGroup;
                  uniqueSupersets.add(supersetGroup);
                }

                // Check if this exercise has a sticky note
                final exerciseName = exerciseData['name'] ?? 'Exercise';
                final hasStickyNote =
                    await _stickyNoteService.hasStickyNote(exerciseName);
                if (hasStickyNote) {
                  _isNoteSticky[exerciseId] = true;
                }
              }
            }

            // Update superset counter based on highest number found
            for (var supersetId in uniqueSupersets) {
              final match = RegExp(r'superset_(\d+)').firstMatch(supersetId);
              if (match != null) {
                final num = int.parse(match.group(1)!);
                if (num >= _supersetCounter) {
                  _supersetCounter = num + 1;
                }
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

        // Load notes and superset data from database exercises into tracking maps
        if (workout != null) {
          // Track unique superset groups to calculate counter
          final Set<String> uniqueSupersets = {};

          for (var exercise in workout.exercises) {
            if (exercise.notes != null && exercise.notes!.isNotEmpty) {
              _exerciseNotes[exercise.id] = exercise.notes!;
            }

            // Load superset group from database
            if (exercise.supersetGroup != null &&
                exercise.supersetGroup!.isNotEmpty) {
              _exerciseSupersets[exercise.id] = exercise.supersetGroup!;
              uniqueSupersets.add(exercise.supersetGroup!);
            }

            // Check if this exercise has a sticky note
            final hasStickyNote =
                await _stickyNoteService.hasStickyNote(exercise.name);
            if (hasStickyNote) {
              _isNoteSticky[exercise.id] = true;
            }
          }

          // Update superset counter based on highest number found
          for (var supersetId in uniqueSupersets) {
            final match = RegExp(r'superset_(\d+)').firstMatch(supersetId);
            if (match != null) {
              final num = int.parse(match.group(1)!);
              if (num >= _supersetCounter) {
                _supersetCounter = num + 1;
              }
            }
          }
        }
      }

      if (workout != null) {
        if (mounted) {
          // Debug: Print all exercise names as loaded from database
          print(
              '🔄 LOADED ${workout.exercises.length} exercises from database:');
          for (var ex in workout.exercises) {
            print('   Exercise ID: ${ex.id}, Name: "${ex.name}"');
          }

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

            // Populate exercise history cache for all exercises in the workout
            _populateExerciseHistoryCache();

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

    // First, clean up any orphaned controllers that don't correspond to current sets
    _cleanupOrphanedControllers();

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

  // Helper method to clean up orphaned controllers that don't correspond to current sets
  void _cleanupOrphanedControllers() {
    if (_workout == null) return;

    // Get all valid set IDs from current workout
    final Set<int> validSetIds = {};
    for (final exercise in _workout!.exercises) {
      for (final set in exercise.sets) {
        validSetIds.add(set.id);
      }
    }

    // Remove controllers for IDs that no longer exist in the workout
    final List<int> orphanedWeightControllerIds = [];
    final List<int> orphanedRepsControllerIds = [];

    for (final setId in _weightControllers.keys) {
      if (!validSetIds.contains(setId)) {
        orphanedWeightControllerIds.add(setId);
      }
    }

    for (final setId in _repsControllers.keys) {
      if (!validSetIds.contains(setId)) {
        orphanedRepsControllerIds.add(setId);
      }
    }

    // Dispose and remove orphaned controllers
    for (final setId in orphanedWeightControllerIds) {
      _weightControllers[setId]?.dispose();
      _weightControllers.remove(setId);
    }

    for (final setId in orphanedRepsControllerIds) {
      _repsControllers[setId]?.dispose();
      _repsControllers.remove(setId);
    }
  }

  // Helper method to populate exercise history cache for all exercises in the workout
  void _populateExerciseHistoryCache() async {
    if (_workout == null) return;

    for (final exercise in _workout!.exercises) {
      // Clean exercise name to remove API ID and CUSTOM markers
      final String cleanExerciseName = _cleanExerciseName(exercise.name);

      // Skip if already cached
      if (_exerciseHistoryCache.containsKey(cleanExerciseName)) {
        continue;
      }

      // Get recent exercise history from database
      try {
        final previousSets = await _workoutService.getRecentExerciseHistory(
            exercise.name,
            excludeWorkoutId: widget.workoutId);
        if (previousSets != null && previousSets.isNotEmpty) {
          _exerciseHistoryCache[cleanExerciseName] = previousSets;
          print(
              '📋 Cached previous history for ${cleanExerciseName}: ${previousSets.length} sets');
        }
      } catch (e) {
        print('❌ Error loading history for ${cleanExerciseName}: $e');
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
      // Set completion flag to prevent any further state saves
      _isCompleting = true;

      // FIRST: Clear active workout from memory to immediately hide the active workout bar
      WorkoutService.activeWorkoutNotifier.value = null;

      // THEN: Stop the timer to prevent any further updates
      _stopTimer();

      // THEN: Clear the active session from database and discard the workout
      await _clearActiveSessionFromDatabase();

      // Discard the workout using the same logic as existing discard methods
      if (widget.isTemporary) {
        _workoutService.discardTemporaryWorkout(widget.workoutId);
      } else {
        await _workoutService.deleteWorkout(widget.workoutId);
      }

      // THEN: Mark workout as discarded for foreground service to prevent restoration
      await WorkoutForegroundService.markWorkoutAsDiscarded();

      // FINALLY: Stop the foreground service
      await WorkoutForegroundService.stopWorkoutService();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Workout discarded'),
          backgroundColor: _dangerColor,
          behavior: SnackBarBehavior.fixed,
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
    // Check if vibration is enabled and trigger it
    if (_vibrateOnRestComplete) {
      try {
        // Simple vibration for 500ms - more compatible across devices
        await Vibration.vibrate(duration: 500);
        // Second vibration after delay
        await Future.delayed(const Duration(milliseconds: 700));
        await Vibration.vibrate(duration: 500);
        print("Vibration triggered - rest timer completed");
      } catch (e) {
        print("Vibration error: $e");
      }
    }

    // Only play sound if enabled in settings
    if (!_soundOnRestComplete) {
      print("Boxing bell sound skipped - sound disabled in settings");
      return;
    }

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

      // Temporarily remove the listener to prevent multiple reloads during bulk add
      if (widget.isTemporary) {
        WorkoutService.tempWorkoutsNotifier
            .removeListener(_onTempWorkoutDataChanged);
      }

      try {
        // Add all selected exercises
        for (final exerciseData in result) {
          final exerciseName = exerciseData['name'] as String;
          final equipment = exerciseData['equipment'] as String? ?? '';
          final apiId = exerciseData['apiId'] as String? ??
              ''; // Get API ID from the selection result
          final isCustom =
              exerciseData['isCustom'] as bool? ?? false; // Get custom flag

          print('🔍 Adding exercise to workout:');
          print('   Name: $exerciseName');
          print('   API ID: $apiId');
          print('   isCustom: $isCustom');

          // Add exercise to the database
          final exerciseId = await _workoutService.addExercise(
            widget.workoutId,
            exerciseName,
            equipment,
          );

          // Load sticky note for this exercise if it exists
          final stickyNote =
              await _stickyNoteService.getStickyNote(exerciseName);
          if (stickyNote != null && stickyNote.isNotEmpty) {
            _exerciseNotes[exerciseId] = stickyNote;
            _isNoteSticky[exerciseId] = true;
          }

          // Store the API ID and custom flag in the exercise name with special markers
          if (apiId.isNotEmpty || isCustom) {
            String updatedName = exerciseName;
            if (apiId.isNotEmpty) {
              updatedName += " ##API_ID:$apiId##";
            }
            if (isCustom) {
              updatedName += " ##CUSTOM:true##";
            }
            print('   📌 STORING exercise with markers:');
            print('      Original name: $exerciseName');
            print('      Updated name: $updatedName');
            print('      Exercise ID in DB: $exerciseId');

            // Update in database (for permanent workouts)
            await _workoutService.updateExercise(
                exerciseId, updatedName, equipment);

            // CRITICAL: For temporary workouts, also update tempWorkoutsNotifier
            if (widget.isTemporary) {
              final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
              if (tempWorkouts.containsKey(widget.workoutId)) {
                final exercises =
                    tempWorkouts[widget.workoutId]['exercises'] as List;
                final exerciseIndex =
                    exercises.indexWhere((e) => e['id'] == exerciseId);
                if (exerciseIndex != -1) {
                  exercises[exerciseIndex]['name'] = updatedName;
                  // Trigger notifier update
                  WorkoutService.tempWorkoutsNotifier.value =
                      Map.from(tempWorkouts);
                  print('   ✅ Updated tempWorkoutsNotifier with markers');
                }
              }
            }

            // Also update the in-memory _workout object
            // so that when the workout is serialized, it has the correct name with markers
            if (_workout != null) {
              final exerciseIndex =
                  _workout!.exercises.indexWhere((e) => e.id == exerciseId);
              if (exerciseIndex != -1) {
                // Create a new Exercise object with the updated name
                final oldExercise = _workout!.exercises[exerciseIndex];
                _workout!.exercises[exerciseIndex] = Exercise(
                  id: oldExercise.id,
                  workoutId: oldExercise.workoutId,
                  name: updatedName, // Use the updated name with markers
                  equipment: oldExercise.equipment,
                  sets: oldExercise.sets,
                  finished: oldExercise.finished,
                );
                print('   ✅ Updated in-memory exercise name with markers');
              }
            }
          }

          // Check for previous exercise history to create sets based on previous workout
          final previousSets =
              await _workoutService.getRecentExerciseHistory(exerciseName);

          // Cache the previous exercise history for UI display
          final String cleanExerciseName = _cleanExerciseName(exerciseName);
          if (previousSets != null && previousSets.isNotEmpty) {
            _exerciseHistoryCache[cleanExerciseName] = previousSets;
          }

          if (previousSets != null && previousSets.isNotEmpty) {
            // Create sets based on previous exercise history
            print(
                '🏗️ Creating ${previousSets.length} sets based on previous history');

            for (int i = 0; i < previousSets.length; i++) {
              final previousSet = previousSets[i];
              await _workoutService.addSet(
                exerciseId,
                i + 1, // Set number (1-indexed)
                0, // Current weight starts as 0 (empty)
                0, // Current reps starts as 0 (empty)
                previousSet.restTime, // Use previous rest time
              );
            }
          } else {
            // No previous history, create a single empty set
            // Get the saved rest timer value for this exercise, or use default
            final savedRestTime =
                await _restTimerHistoryService.getRestTime(exerciseName);
            final restTime = savedRestTime ?? _defaultRestTime;

            await _workoutService.addSet(
              exerciseId,
              1, // Set number
              0, // Weight - will be displayed as empty
              0, // Reps - will be displayed as empty
              restTime, // Use saved rest time or default
            );
          }
        }

        // Reload the workout to show the new exercises
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
      } finally {
        // Re-add the listener after bulk add is complete
        if (widget.isTemporary) {
          WorkoutService.tempWorkoutsNotifier
              .addListener(_onTempWorkoutDataChanged);
        }
      }
    } else if (result != null && result is Map<String, dynamic>) {
      // Handle backward compatibility for single exercise selection (custom exercises)
      final exerciseName = result['name'] as String;
      final equipment = result['equipment'] as String? ?? '';
      final apiId = result['apiId'] as String? ?? '';
      final isCustom = result['isCustom'] as bool? ?? false;

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

        // Store the API ID and custom flag in the exercise name with special markers
        if (apiId.isNotEmpty || isCustom) {
          String updatedName = exerciseName;
          if (apiId.isNotEmpty) {
            updatedName += " ##API_ID:$apiId##";
          }
          if (isCustom) {
            updatedName += " ##CUSTOM:true##";
          }
          await _workoutService.updateExercise(
              exerciseId,
              updatedName, // Store API ID and custom flag in the name with special markers
              equipment);
        }

        // Check for previous exercise history to create sets based on previous workout
        final previousSets = await _workoutService.getRecentExerciseHistory(
            exerciseName,
            excludeWorkoutId: widget.workoutId);

        // Cache the previous exercise history for UI display
        final String cleanExerciseName = exerciseName
            .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
            .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
            .trim();
        if (previousSets != null && previousSets.isNotEmpty) {
          _exerciseHistoryCache[cleanExerciseName] = previousSets;
        }

        if (previousSets != null && previousSets.isNotEmpty) {
          // Create sets based on previous exercise history
          print(
              '🏗️ Creating ${previousSets.length} sets based on previous history');

          for (int i = 0; i < previousSets.length; i++) {
            final previousSet = previousSets[i];
            await _workoutService.addSet(
              exerciseId,
              i + 1, // Set number (1-indexed)
              0, // Current weight starts as 0 (empty)
              0, // Current reps starts as 0 (empty)
              previousSet.restTime, // Use previous rest time
            );
          }
        } else {
          // No previous history, create a single empty set
          // Get the saved rest timer value for this exercise, or use default
          final savedRestTime =
              await _restTimerHistoryService.getRestTime(exerciseName);
          final restTime = savedRestTime ?? _defaultRestTime;

          await _workoutService.addSet(
            exerciseId,
            1, // Set number
            0, // Weight - will be displayed as empty
            0, // Reps - will be displayed as empty
            restTime, // Use saved rest time or default
          );
        }

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
              child:
                  Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
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
      // Get the saved rest timer value for this exercise, or use default
      final savedRestTime =
          await _restTimerHistoryService.getRestTime(exercise.name);
      final restTime = savedRestTime ?? _defaultRestTime;

      // Add set to database - store empty fields as null in database
      final newSetId = await _workoutService.addSet(
        exerciseId,
        setNumber,
        0, // Initial weight (we'll show empty field in UI)
        0, // Initial reps (we'll show empty field in UI)
        restTime, // Use saved rest time or default
      );

      // If we have the new set ID, create a local Set object and add it to our state
      if (mounted) {
        final newSet = ExerciseSet(
          id: newSetId,
          exerciseId: exerciseId,
          setNumber: setNumber,
          weight: 0, // This will be displayed as empty field
          reps: 0, // This will be displayed as empty field
          restTime: restTime,
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
    // If completing a set, check if we should auto-fill with previous values
    if (completed) {
      // Find the exercise and set
      Exercise? targetExercise;
      ExerciseSet? targetSet;

      for (var exercise in _workout!.exercises) {
        if (exercise.id == exerciseId) {
          targetExercise = exercise;
          for (var set in exercise.sets) {
            if (set.id == setId) {
              targetSet = set;
              break;
            }
          }
          break;
        }
      }

      if (targetExercise != null && targetSet != null) {
        // Check if current values are empty/zero and we have previous values available
        final String currentWeightText = _weightControllers[setId]?.text ?? '';
        final String currentRepsText = _repsControllers[setId]?.text ?? '';
        final double currentWeight = double.tryParse(currentWeightText) ?? 0;
        final int currentReps = int.tryParse(currentRepsText) ?? 0;

        // Get previous values if current values are empty or zero
        final bool shouldUsePreviousValues =
            (currentWeightText.isEmpty || currentWeight == 0) &&
                (currentRepsText.isEmpty || currentReps == 0);

        if (shouldUsePreviousValues) {
          final previousSet =
              _getPreviousSetValues(targetExercise.name, targetSet.setNumber);

          if (previousSet != null &&
              previousSet.weight > 0 &&
              previousSet.reps > 0) {
            // Update the controllers with previous values
            final weightText = (previousSet.weight % 1 == 0)
                ? previousSet.weight.toInt().toString()
                : previousSet.weight.toString();
            final repsText = previousSet.reps.toString();

            _weightControllers[setId]?.text = weightText;
            _repsControllers[setId]?.text = repsText;

            // Update the set data in the database with previous values
            await _updateSetData(setId, previousSet.weight, previousSet.reps,
                targetSet.restTime);
          }
        } else if (currentWeight > 0 && currentReps > 0) {
          // If user has entered custom values, save those
          await _updateSetData(
              setId, currentWeight, currentReps, targetSet.restTime);
        }
      }
    }

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

                  // Save the rest timer value for this exercise if there's an active rest timer
                  if (_currentRestSetId == setId && _originalRestTime > 0) {
                    _restTimerHistoryService.saveRestTime(
                      exercise.name,
                      _originalRestTime,
                    );
                  }
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
        String? exerciseName;
        bool found = false;
        final exercises = tempWorkouts[widget.workoutId]['exercises'];

        // Find the exercise that contains this set
        for (var i = 0; i < exercises.length && !found; i++) {
          final sets = exercises[i]['sets'];
          for (var j = 0; j < sets.length && !found; j++) {
            if (sets[j]['id'] == setId) {
              sets[j]['completed'] = completed;
              exerciseName = exercises[i]['name'] ?? '';

              // If uncompleting the set, it's no longer a PR
              if (!completed) {
                sets[j]['isPR'] = false;
              }

              found = true;
            }
          }
        }

        // If completing a set, recalculate PR status for all sets in this exercise
        if (completed && found && exerciseName != null) {
          await _recalculatePRStatusForTempExercise(exerciseName);
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

  /// Recalculate PR status for all completed sets in a temporary workout exercise
  Future<void> _recalculatePRStatusForTempExercise(String exerciseName) async {
    final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
    if (!tempWorkouts.containsKey(widget.workoutId)) return;

    final exercises = tempWorkouts[widget.workoutId]['exercises'];
    final String cleanExerciseName = _cleanExerciseName(exerciseName);

    // Find ALL instances of the exercise and collect all their completed sets with volumes
    List<Map<String, dynamic>> completedSets = [];
    for (var exercise in exercises) {
      if (_cleanExerciseName(exercise['name'] ?? '') == cleanExerciseName) {
        final sets = exercise['sets'] as List;
        for (var set in sets) {
          if (set['completed'] == true) {
            final double weight = set['weight'] ?? 0.0;
            final int reps = set['reps'] ?? 0;
            final double volume = weight * reps;
            if (volume > 0) {
              completedSets.add({
                'set': set,
                'volume': volume,
              });
            }
          }
        }
        // Remove the break statement to process ALL instances of the exercise
      }
    }

    if (completedSets.isEmpty) return;

    // Get historical max volume from database (excluding current workout)
    double historicalMaxVolume = 0.0;
    try {
      // Get all completed sets for this exercise from database
      final db = await DatabaseService.instance.database;
      final result = await db.rawQuery('''
        SELECT es.volume, e.name
        FROM exercise_sets es
        INNER JOIN exercises e ON es.exerciseId = e.id
        WHERE es.completed = 1
      ''');

      for (final row in result) {
        final String dbExerciseName = row['name'] as String;
        final String cleanDbExerciseName = _cleanExerciseName(dbExerciseName);

        if (cleanDbExerciseName == cleanExerciseName) {
          final double rowVolume = row['volume'] as double;
          if (rowVolume > historicalMaxVolume) {
            historicalMaxVolume = rowVolume;
          }
        }
      }
    } catch (e) {
      print('Error getting historical PR data: $e');
    }

    // Find max volume in current workout
    double currentMaxVolume = 0.0;
    for (final setData in completedSets) {
      if (setData['volume'] > currentMaxVolume) {
        currentMaxVolume = setData['volume'];
      }
    }

    // Determine which sets should be PRs
    // Mark all sets that match or exceed the historical max volume as PRs
    double prVolume =
        currentMaxVolume > historicalMaxVolume ? currentMaxVolume : 0.0;

    // Update PR status for all sets
    // All sets with the max volume in current workout should be marked as PR
    // if they exceed or match historical records
    for (final setData in completedSets) {
      final set = setData['set'];
      final volume = setData['volume'];

      // Mark as PR if:
      // 1. Current workout has sets that exceed historical max (prVolume > 0)
      // 2. This set matches the max volume in current workout
      set['isPR'] = (prVolume > 0 && volume == prVolume);
    }

    // Update the notifier
    WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
  }

  Future<void> _updateSetData(
    int setId,
    double weight,
    int reps,
    int restTime,
  ) async {
    // Set flag to prevent listener from triggering a reload
    _isUpdatingInternally = true;

    try {
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
    } finally {
      // Reset the flag after update is complete
      _isUpdatingInternally = false;
    }
  }

  /// Update the set type for a specific set
  Future<void> _updateSetType(int setId, SetType newType) async {
    // Set flag to prevent listener from triggering a reload
    _isUpdatingInternally = true;

    try {
      // First, update the local state
      if (mounted) {
        setState(() {
          for (var exercise in _workout!.exercises) {
            for (var set in exercise.sets) {
              if (set.id == setId) {
                set.setType = newType;
                break;
              }
            }
          }
        });
      }

      // Handle temporary vs regular workouts differently for database updates
      if (widget.isTemporary || setId < 0) {
        // Update in-memory temporary workout
        final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
        if (tempWorkouts.containsKey(widget.workoutId)) {
          final exercises = tempWorkouts[widget.workoutId]['exercises'];
          bool found = false;
          for (int i = 0; i < exercises.length && !found; i++) {
            final sets = exercises[i]['sets'] as List;
            for (int j = 0; j < sets.length; j++) {
              if (sets[j]['id'] == setId) {
                sets[j]['setType'] = newType.name;
                found = true;
                break;
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
          {'set_type': newType.name},
          where: 'id = ?',
          whereArgs: [setId],
        );
      }

      // Notify listeners
      WorkoutService.workoutsUpdatedNotifier.value =
          !WorkoutService.workoutsUpdatedNotifier.value;

      // Auto-save the workout state
      _updateActiveNotifier();
    } finally {
      // Reset the flag after update is complete
      _isUpdatingInternally = false;
    }
  }

  /// Show dialog to select set type
  Future<void> _showSetTypeDialog(
      ExerciseSet set, BuildContext buttonContext) async {
    if (widget.readOnly) return;

    // Get the position of the tapped button
    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selectedType = await showMenu<SetType>(
      context: context,
      position: position,
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<SetType>(
          value: SetType.normal,
          child: _buildSetTypeMenuItem(
            'Normal',
            'Regular set',
            set.setType == SetType.normal,
            showHelp: false,
          ),
        ),
        PopupMenuItem<SetType>(
          value: SetType.warmup,
          child: _buildSetTypeMenuItem(
            'Warm-up',
            'Preparation set',
            set.setType == SetType.warmup,
            showHelp: true,
          ),
        ),
        PopupMenuItem<SetType>(
          value: SetType.dropset,
          child: _buildSetTypeMenuItem(
            'Drop Set',
            'Reduced weight set',
            set.setType == SetType.dropset,
            showHelp: true,
          ),
        ),
        PopupMenuItem<SetType>(
          value: SetType.failure,
          child: _buildSetTypeMenuItem(
            'Failure',
            'To muscular failure',
            set.setType == SetType.failure,
            showHelp: true,
          ),
        ),
      ],
    );

    if (selectedType != null && selectedType != set.setType) {
      await _updateSetType(set.id, selectedType);
    }
  }

  /// Build a set type menu item
  Widget _buildSetTypeMenuItem(String title, String subtitle, bool isSelected,
      {bool showHelp = true}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected
                ? _primaryColor
                : _textSecondaryColor.withOpacity(0.5),
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: _textPrimaryColor,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (showHelp)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: _surfaceColor,
                    title: Text(
                      title,
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      _getSetTypeDescription(title),
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontSize: 15,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Got it',
                          style: TextStyle(color: _primaryColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(
                Icons.help_outline,
                color: _textSecondaryColor,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  /// Get detailed description for set types
  String _getSetTypeDescription(String type) {
    switch (type) {
      case 'Warm-up':
        return 'A warm-up set is performed with lighter weight to prepare your muscles, joints, and nervous system for heavier working sets. It helps prevent injury and improves performance in subsequent sets.';
      case 'Drop Set':
        return 'A drop set is performed immediately after a regular set by reducing the weight and continuing without rest. This technique increases muscle fatigue and promotes muscle growth by pushing beyond normal failure.';
      case 'Failure':
        return 'A set taken to muscular failure means performing repetitions until you physically cannot complete another rep with proper form. This maximizes muscle fiber recruitment and stimulation for strength and hypertrophy gains.';
      default:
        return 'Regular working set performed at your target weight and rep range.';
    }
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
      print(
          'Warning: _deleteSet called for last set - this should be handled in confirmDismiss');
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
      cleanName = exerciseName
          .replaceAll('##API_ID:$apiId##', '')
          .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '');
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

              // Check if original exercise had custom marker
              final RegExp customRegex = RegExp(r'##CUSTOM:([^#]+)##');
              final bool hadCustomFlag = customRegex.hasMatch(exerciseName);

              // Rebuild the name with any markers that were present
              String finalName = newName;
              if (apiId.isNotEmpty) {
                finalName += "##API_ID:$apiId##";
              }
              if (hadCustomFlag) {
                finalName += "##CUSTOM:true##";
              }

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
          'Are you sure you want to delete "${_cleanExerciseName(exercise.name)}" and all its sets? This cannot be undone.',
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

  // Replace an exercise with a new one while keeping all its sets
  Future<void> _replaceExercise(Exercise exercise) async {
    if (widget.readOnly) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseSelectionPage(
          singleSelectionMode: true,
        ),
      ),
    );

    if (result != null) {
      // Handle both single exercise and multiple exercise selection
      List<Map<String, dynamic>> selectedExercises = [];

      if (result is List) {
        selectedExercises = result.cast<Map<String, dynamic>>();
      } else if (result is Map) {
        selectedExercises = [Map<String, dynamic>.from(result)];
      }

      // Only use the first selected exercise
      if (selectedExercises.isEmpty) return;

      final newExercise = selectedExercises.first;
      final String newExerciseName = newExercise['name'] as String;
      final String newEquipment = newExercise['equipment'] as String? ?? '';

      // When replacing an exercise, use plain name without any markers
      // This makes the replaced exercise editable like a regular exercise
      String fullExerciseName = newExerciseName;

      // Update the exercise name and equipment in local state
      if (mounted) {
        setState(() {
          final exerciseIndex =
              _workout!.exercises.indexWhere((e) => e.id == exercise.id);
          if (exerciseIndex != -1) {
            // Create a new Exercise object with updated name and equipment
            final oldExercise = _workout!.exercises[exerciseIndex];
            _workout!.exercises[exerciseIndex] = Exercise(
              id: oldExercise.id,
              name: fullExerciseName,
              equipment: newEquipment,
              sets: oldExercise.sets,
              workoutId: oldExercise.workoutId,
              notes: oldExercise.notes,
              supersetGroup: oldExercise.supersetGroup,
            );
          }
        });
      }

      // Update in database or temporary workout
      try {
        if (widget.isTemporary || exercise.id < 0) {
          // Update temporary workout data
          final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
          if (tempWorkouts.containsKey(widget.workoutId)) {
            final workoutData = tempWorkouts[widget.workoutId];
            final exercises = workoutData['exercises'] as List;

            final exerciseData = exercises.firstWhere(
              (e) => e['id'] == exercise.id,
              orElse: () => <String, dynamic>{},
            );

            if (exerciseData.isNotEmpty) {
              exerciseData['name'] = fullExerciseName;
              exerciseData['equipment'] = newEquipment;

              // Trigger notifier update
              WorkoutService.tempWorkoutsNotifier.value =
                  Map.from(tempWorkouts);
            }
          }
        } else {
          // Update in database for regular workouts
          await _updateExercise(exercise.id, fullExerciseName, newEquipment);
        }

        // Auto-save the workout state
        _updateActiveNotifier();

        if (mounted) {
          _showSnackBar(
            'Exercise replaced successfully',
            customColor: _successColor,
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(
            'Error replacing exercise: $e',
            isError: true,
          );
        }
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

      // Update exercise notes if present
      if (_exerciseNotes.containsKey(exercise.id) &&
          _exerciseNotes[exercise.id]!.isNotEmpty) {
        exerciseData['notes'] = _exerciseNotes[exercise.id];
      } else {
        exerciseData['notes'] = null;
      }

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

        // Update weight, reps, completed status, and set type
        setData['weight'] = set.weight;
        setData['reps'] = set.reps;
        setData['completed'] = set.completed;
        setData['setType'] = set.setType.name;
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
      // Store superset data
      'supersets': Map<String, String>.from(
        _exerciseSupersets.map((key, value) => MapEntry(key.toString(), value)),
      ),
      'supersetCounter': _supersetCounter,
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
        'notes':
            _exerciseNotes[exercise.id], // Include notes from the tracking map
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
            'setType': set.setType.name,
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

    // If the workout is being completed/discarded, don't save state to prevent recreation
    if (_isCompleting) {
      return;
    }

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

    // Restore superset data if present
    if (workoutData.containsKey('supersets')) {
      final supersetsData = workoutData['supersets'] as Map<String, dynamic>;
      _exerciseSupersets.clear();
      supersetsData.forEach((key, value) {
        final exerciseId = int.tryParse(key);
        if (exerciseId != null) {
          _exerciseSupersets[exerciseId] = value as String;
        }
      });
    }
    if (workoutData.containsKey('supersetCounter')) {
      _supersetCounter = workoutData['supersetCounter'] as int;
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

      // Restore exercise notes if present
      if (exerciseData.containsKey('notes') && exerciseData['notes'] != null) {
        final String note = exerciseData['notes'] as String;
        _exerciseNotes[exerciseId] = note;

        // Initialize note controller if it doesn't exist
        if (!_noteControllers.containsKey(exerciseId)) {
          _noteControllers[exerciseId] = TextEditingController(text: note);
        } else {
          _noteControllers[exerciseId]!.text = note;
        }
      }

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

        // Restore set type if present
        if (setData.containsKey('setType')) {
          final String? setTypeStr = setData['setType'] as String?;
          if (setTypeStr != null) {
            switch (setTypeStr.toLowerCase()) {
              case 'warmup':
                set.setType = SetType.warmup;
                break;
              case 'dropset':
                set.setType = SetType.dropset;
                break;
              case 'failure':
                set.setType = SetType.failure;
                break;
              case 'normal':
              default:
                set.setType = SetType.normal;
                break;
            }
          }
        }

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

    // Restore superset data if present
    if (workoutData.containsKey('supersets')) {
      final supersetsData = workoutData['supersets'] as Map<String, dynamic>;
      _exerciseSupersets.clear();
      supersetsData.forEach((key, value) {
        final exerciseId = int.tryParse(key);
        if (exerciseId != null) {
          _exerciseSupersets[exerciseId] = value as String;
        }
      });
      print(
          'RESTORE DEBUG: Restored ${_exerciseSupersets.length} superset mappings');
    }
    if (workoutData.containsKey('supersetCounter')) {
      _supersetCounter = workoutData['supersetCounter'] as int;
    }

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
                color: (_currentRestSetId != null)
                    ? _primaryColor.withOpacity(0.1)
                    : _surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: (_currentRestSetId != null)
                    ? Border.all(color: _primaryColor, width: 1)
                    : null,
              ),
              child: (_currentRestSetId != null)
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
                                  ? (_restTimeRemaining / _originalRestTime)
                                      .clamp(0.0, 1.0)
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Go Back',
                                      style: TextStyle(
                                          color: _textSecondaryColor)),
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
                          _workoutService
                              .discardTemporaryWorkout(widget.workoutId);
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
                            behavior: SnackBarBehavior.fixed,
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
                                repsDouble !=
                                    repsInt.toDouble()); // Decimal reps

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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Go Back',
                                      style: TextStyle(
                                          color: _textSecondaryColor)),
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
                          _workoutService
                              .discardTemporaryWorkout(widget.workoutId);
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
                            behavior: SnackBarBehavior.fixed,
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
                      // If confirm finish is disabled, skip the dialog
                      if (!_confirmFinishWorkout) {
                        // Skip directly to finishing the workout
                      } else {
                        dialogContent.add(Text(
                          'All sets are properly completed with valid data. Ready to finish this workout?',
                          style: TextStyle(color: _textSecondaryColor),
                        ));
                      }
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

                    // Skip confirmation dialog if there are no issues and confirm is disabled
                    bool continueWithWorkout = true;

                    if (hasNoIssues && !_confirmFinishWorkout) {
                      // Auto-proceed without dialog
                      continueWithWorkout = true;
                    } else {
                      // Show workout duration in dialog
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
                      continueWithWorkout = await showDialog(
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
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          color: _textSecondaryColor)),
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
                    }

                    if (!continueWithWorkout) {
                      return; // User chose to cancel
                    }

                    // Set completion flag to prevent any further state saves
                    _isCompleting = true;

                    // Play fanfare sound for workout completion
                    _playFanfareSound();

                    // Comprehensive cleanup when finishing workout
                    await _cleanupWorkoutOnFinish();

                    // Handle temporary vs regular workouts differently
                    if (widget.isTemporary) {
                      // For temporary workouts, check if we have any valid exercises and sets
                      if (_workout?.exercises.isEmpty ?? true) {
                        // FIRST: Clear active workout from memory to immediately hide the active workout bar
                        WorkoutService.activeWorkoutNotifier.value = null;

                        // THEN: Stop the timer to prevent any further updates
                        _stopTimer();

                        // THEN: Discard the temporary workout and clear database session
                        _workoutService
                            .discardTemporaryWorkout(widget.workoutId);
                        await _clearActiveSessionFromDatabase();

                        // THEN: Mark workout as discarded for foreground service to prevent restoration
                        await WorkoutForegroundService.markWorkoutAsDiscarded();

                        // FINALLY: Stop the foreground service and clear saved data
                        await WorkoutForegroundService.stopWorkoutService();
                        await WorkoutForegroundService.clearSavedWorkoutData();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Empty workout discarded'),
                            backgroundColor: _primaryColor,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                        return;
                      } else {
                        // We have valid exercises, save the temporary workout to the database
                        try {
                          // Create data structure for the temporary workout with all its exercises and sets
                          // AUTO-COMPLETE: Sets with valid data (weight > 0 AND reps > 0) are marked as completed
                          final tempData = {
                            'name': _workout!.name,
                            'date': _workout!.date,
                            'duration': _elapsedSeconds,
                            'exercises': _workout!.exercises.map((exercise) {
                              return {
                                'name': exercise.name,
                                'equipment': exercise.equipment,
                                'notes': _exerciseNotes[exercise
                                    .id], // Include notes from the tracking map
                                'supersetGroup': _exerciseSupersets[
                                    exercise.id], // Include superset group
                                'sets': exercise.sets.where((set) {
                                  // Include sets that have valid data (weight > 0 AND reps > 0) OR are already completed
                                  final bool hasValidData =
                                      set.weight > 0 && set.reps > 0;
                                  final bool isCompleted = set.completed;
                                  return hasValidData || isCompleted;
                                }).map((set) {
                                  // Auto-complete: mark sets with valid data as completed
                                  final bool hasValidData =
                                      set.weight > 0 && set.reps > 0;
                                  final bool shouldBeCompleted =
                                      set.completed || hasValidData;
                                  return {
                                    'setNumber': set.setNumber,
                                    'weight': set.weight,
                                    'reps': set.reps,
                                    'restTime': set.restTime,
                                    'completed': shouldBeCompleted,
                                    'setType': set.setType.name,
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

                          // Save to database and get the new workout ID
                          final savedWorkoutId = await _workoutService
                              .saveTemporaryWorkout(widget.workoutId);

                          // Reload the workout from database to get updated PR flags
                          // This ensures the completion page shows accurate PR counts
                          final savedWorkout =
                              await _workoutService.getWorkout(savedWorkoutId);
                          if (savedWorkout != null) {
                            _workout = savedWorkout.copyWith(
                                duration: _elapsedSeconds);
                          }
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
                        // FIRST: Clear active workout from memory to immediately hide the active workout bar
                        WorkoutService.activeWorkoutNotifier.value = null;

                        // THEN: Stop the timer to prevent any further updates
                        _stopTimer();

                        // THEN: Delete the empty workout and clear database session
                        await _workoutService.deleteWorkout(widget.workoutId);
                        await _clearActiveSessionFromDatabase();

                        // THEN: Mark workout as discarded for foreground service to prevent restoration
                        await WorkoutForegroundService.markWorkoutAsDiscarded();

                        // FINALLY: Stop the foreground service and clear saved data
                        await WorkoutForegroundService.stopWorkoutService();
                        await WorkoutForegroundService.clearSavedWorkoutData();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Empty workout discarded'),
                            backgroundColor: _primaryColor,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                        return;
                      }
                    }

                    // CAPTURE THE WORKOUT DATA FOR COMPLETION PAGE BEFORE ANY CLEARING
                    // This prevents race conditions where data is cleared before navigation
                    Workout? workoutForCompletion;

                    // For temporary workouts, _workout was already updated with saved data above
                    // For regular workouts, reload fresh data with PR flags now
                    if (widget.isTemporary) {
                      workoutForCompletion =
                          _workout?.copyWith(duration: _elapsedSeconds);
                    } else {
                      final freshWorkout =
                          await _workoutService.getWorkout(widget.workoutId);
                      if (freshWorkout != null) {
                        workoutForCompletion =
                            freshWorkout.copyWith(duration: _elapsedSeconds);
                      }
                    }

                    // Get workout count for completion screen BEFORE clearing
                    final workoutCount =
                        await _workoutService.getWorkoutCount();

                    // NOW do the clearing operations - after we've captured all needed data
                    // Clear active workout from memory to immediately hide the active workout bar
                    WorkoutService.activeWorkoutNotifier.value = null;

                    // Stop the timer to prevent any further updates
                    _stopTimer();

                    // Clear the active session from database since workout is being completed
                    await _clearActiveSessionFromDatabase();

                    // Mark workout as discarded for foreground service to prevent restoration
                    await WorkoutForegroundService.markWorkoutAsDiscarded();

                    // Clear saved foreground service data to prevent restoration
                    await WorkoutForegroundService.clearSavedWorkoutData();

                    // Mark workout habit as completed if it exists
                    final habitService = HabitService();
                    // Get all habits to check available labels
                    final allHabits = await habitService.getHabits();
                    debugPrint(
                        'All habits: ${allHabits.map((h) => '${h.label} (status: ${h.status})').toList()}');

                    // Try to find workout habit with case-insensitive search
                    var workoutHabit = allHabits.firstWhere(
                      (h) => h.label.toLowerCase() == 'workout',
                      orElse: () => allHabits.firstWhere(
                        (h) => h.label.toLowerCase().contains('workout'),
                        orElse: () => Habit(
                            id: -1, label: '', status: -1, description: ''),
                      ),
                    );

                    debugPrint(
                        'Found workout habit: ${workoutHabit.label} (id: ${workoutHabit.id}, status: ${workoutHabit.status})');

                    bool habitWasCompleted = false;
                    if (workoutHabit.id != -1 && workoutHabit.status == 0) {
                      await habitService.updateHabitStatus(workoutHabit.id, 1);
                      // Notify listeners that habits have been updated
                      DatabaseService.habitsUpdatedNotifier.value =
                          !DatabaseService.habitsUpdatedNotifier.value;
                      habitWasCompleted = true;
                      debugPrint('Workout habit marked as completed!');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Workout habit completed!'),
                            backgroundColor: _successColor,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      debugPrint(
                          'Workout habit not found or already completed');
                    }

                    // Add a small delay to allow snackbar to be visible
                    if (habitWasCompleted && mounted) {
                      await Future.delayed(Duration(milliseconds: 500));
                    }

                    // Navigate to completion screen with the captured workout data
                    if (mounted && workoutForCompletion != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkoutCompletionPage(
                            workout: workoutForCompletion!,
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
                          : ReorderableListView.builder(
                              padding: EdgeInsets.only(top: 8),
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, child) {
                                    final double animValue = Curves.easeInOut
                                        .transform(animation.value);
                                    final double elevation =
                                        lerpDouble(0, 6, animValue)!;
                                    final double scale =
                                        lerpDouble(1.0, 1.02, animValue)!;
                                    return Transform.scale(
                                      scale: scale,
                                      child: Material(
                                        elevation: elevation,
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: child,
                                );
                              },
                              itemCount: _workout!.exercises.length + 1,
                              onReorder: _reorderExercises,
                              itemBuilder: (context, index) {
                                if (index < _workout!.exercises.length) {
                                  final exercise = _workout!.exercises[index];
                                  final supersetId =
                                      _exerciseSupersets[exercise.id];

                                  // Determine superset position (first, middle, last)
                                  String? supersetPosition;
                                  if (supersetId != null) {
                                    final supersetExercises = _workout!
                                        .exercises
                                        .where((e) =>
                                            _exerciseSupersets[e.id] ==
                                            supersetId)
                                        .toList();
                                    final posInSuperset =
                                        supersetExercises.indexOf(exercise);
                                    if (supersetExercises.length == 1) {
                                      supersetPosition = 'only';
                                    } else if (posInSuperset == 0) {
                                      supersetPosition = 'first';
                                    } else if (posInSuperset ==
                                        supersetExercises.length - 1) {
                                      supersetPosition = 'last';
                                    } else {
                                      supersetPosition = 'middle';
                                    }
                                  }

                                  return ReorderableDelayedDragStartListener(
                                    key: Key('exercise_${exercise.id}'),
                                    index: index,
                                    enabled: !widget.readOnly,
                                    child: _buildExerciseCard(
                                      exercise,
                                      supersetId: supersetId,
                                      supersetPosition: supersetPosition,
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    key: Key('add_exercise_button'),
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: TextButton.icon(
                                        icon: Icon(Icons.add,
                                            color: _primaryColor),
                                        label: Text('Add Exercise',
                                            style: TextStyle(
                                                color: _primaryColor)),
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

  Widget _buildExerciseCard(
    Exercise exercise, {
    String? supersetId,
    String? supersetPosition,
  }) {
    // Determine exercise type based on markers
    // Only truly custom exercises (with CUSTOM marker) should be editable
    final bool isCustomExercise =
        RegExp(r'##CUSTOM:true##').hasMatch(exercise.name);

    final bool allSetsCompleted =
        exercise.sets.isNotEmpty && exercise.sets.every((set) => set.completed);

    // Superset indicator color - get unique color based on superset ID
    final Color supersetColor = supersetId != null
        ? _getColorForSuperset(supersetId)
        : _supersetColors[0];

    // Wrap with RepaintBoundary to isolate painting operations
    return RepaintBoundary(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Superset indicator bar on the left
            if (supersetId != null)
              Container(
                width: 4,
                margin: EdgeInsets.only(
                  left: 16,
                  top: supersetPosition == 'first' || supersetPosition == 'only'
                      ? 8
                      : 0,
                  bottom:
                      supersetPosition == 'last' || supersetPosition == 'only'
                          ? 8
                          : 0,
                ),
                decoration: BoxDecoration(
                  color: supersetColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(supersetPosition == 'first' ||
                            supersetPosition == 'only'
                        ? 4
                        : 0),
                    topRight: Radius.circular(supersetPosition == 'first' ||
                            supersetPosition == 'only'
                        ? 4
                        : 0),
                    bottomLeft: Radius.circular(
                        supersetPosition == 'last' || supersetPosition == 'only'
                            ? 4
                            : 0),
                    bottomRight: Radius.circular(
                        supersetPosition == 'last' || supersetPosition == 'only'
                            ? 4
                            : 0),
                  ),
                ),
              ),
            // Main exercise card
            Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  left: supersetId != null ? 8 : 16,
                  right: 16,
                  top: supersetPosition == 'first' ||
                          supersetPosition == 'only' ||
                          supersetId == null
                      ? 8
                      : 2,
                  bottom: supersetPosition == 'last' ||
                          supersetPosition == 'only' ||
                          supersetId == null
                      ? 8
                      : 2,
                ),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: supersetId != null
                      ? Border.all(
                          color: supersetColor.withOpacity(0.3), width: 1)
                      : null,
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
                    // Superset label at the top (only for first exercise in superset)
                    if (supersetId != null && supersetPosition == 'first')
                      Container(
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: supersetColor.withOpacity(0.15),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link, color: supersetColor, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'SUPERSET',
                              style: TextStyle(
                                color: supersetColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Exercise note bar (if note exists)
                    if (_exerciseNotes.containsKey(exercise.id))
                      Container(
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(supersetId != null &&
                                    supersetPosition == 'first'
                                ? 0
                                : 12),
                            topRight: Radius.circular(supersetId != null &&
                                    supersetPosition == 'first'
                                ? 0
                                : 12),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: _primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Dismissible note content
                            Expanded(
                              child: Dismissible(
                                key: Key('note_${exercise.id}'),
                                direction: DismissDirection.endToStart,
                                onDismissed: (direction) {
                                  _removeExerciseNote(exercise.id);
                                },
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: _dangerColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                    ),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: EdgeInsets.only(right: 16),
                                  child: Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.note_outlined,
                                        color: _primaryColor,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _noteEditingState[exercise.id] ==
                                                true
                                            ? TextField(
                                                controller: _noteControllers[
                                                    exercise.id],
                                                style: TextStyle(
                                                  color: _textPrimaryColor,
                                                  fontSize: 14,
                                                ),
                                                decoration: InputDecoration(
                                                  border: InputBorder.none,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  hintText:
                                                      'Enter your note...',
                                                  hintStyle: TextStyle(
                                                    color: _textSecondaryColor,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                                autofocus: true,
                                                onSubmitted: (value) =>
                                                    _finishEditingNote(
                                                        exercise.id),
                                                onTapOutside: (event) =>
                                                    _finishEditingNote(
                                                        exercise.id),
                                              )
                                            : GestureDetector(
                                                onTap: () => _startEditingNote(
                                                    exercise.id),
                                                child: Container(
                                                  width: double.infinity,
                                                  child: Text(
                                                    _exerciseNotes[
                                                            exercise.id] ??
                                                        '',
                                                    style: TextStyle(
                                                      color: _textPrimaryColor,
                                                      fontSize: 14,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                      // Pin icon to toggle sticky status
                                      IconButton(
                                        icon: Icon(
                                          _isNoteSticky[exercise.id] == true
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                          size: 16,
                                          color:
                                              _isNoteSticky[exercise.id] == true
                                                  ? Colors.amber
                                                  : _textSecondaryColor,
                                        ),
                                        onPressed: () =>
                                            _toggleStickyNote(exercise.id),
                                        visualDensity: VisualDensity.compact,
                                        tooltip: _isNoteSticky[exercise.id] ==
                                                true
                                            ? 'Sticky note (saved to exercise)'
                                            : 'Instance note (tap to make sticky)',
                                        padding: EdgeInsets.zero,
                                        constraints: BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Exercise header
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: InkWell(
                        onTap: () async {
                          // Check if the exercise name contains API ID or custom markers
                          final String exerciseName = exercise.name;
                          print(
                              '📖 TAPPED exercise - Raw name from DB: "$exerciseName"');

                          final RegExp apiIdRegex =
                              RegExp(r'##API_ID:([^#]+)##');
                          final RegExp customRegex =
                              RegExp(r'##CUSTOM:([^#]+)##');
                          final Match? apiMatch =
                              apiIdRegex.firstMatch(exerciseName);
                          final Match? customMatch =
                              customRegex.firstMatch(exerciseName);

                          String apiId = '';
                          bool isCustomExercise = false;

                          if (apiMatch != null) {
                            // Extract the API ID
                            apiId = apiMatch.group(1) ?? '';
                            print('   Found API ID marker: $apiId');
                            // Check if this is a custom exercise (API ID starts with 'custom_')
                            isCustomExercise = apiId.startsWith('custom_');
                          }

                          // Also check for explicit custom marker
                          if (customMatch != null) {
                            final customFlag = customMatch.group(1) ?? 'false';
                            print('   Found CUSTOM marker: $customFlag');
                            isCustomExercise = isCustomExercise ||
                                customFlag.toLowerCase() == 'true';
                          }

                          // Get the clean exercise name without any markers
                          final String cleanName = exerciseName
                              .replaceAll(apiIdRegex, '')
                              .replaceAll(customRegex, '')
                              .trim();

                          // Debug print
                          print(
                              'Exercise ID: ${exercise.id}, Is Temporary: ${exercise.id < 0}, Is Custom: $isCustomExercise, API ID: $apiId');

                          // Check if this is a temporary exercise (negative ID)
                          final bool isTemporary = exercise.id < 0;

                          print(
                              'Exercise ID: ${exercise.id}, Is Temporary: $isTemporary, Is Custom: $isCustomExercise, API ID: $apiId');

                          // Navigate to different pages based on exercise type
                          if (isCustomExercise) {
                            // Navigate to custom exercise detail page
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomExerciseDetailPage(
                                  exerciseId: apiId.isNotEmpty
                                      ? apiId
                                      : exercise.id.toString(),
                                  exerciseName: cleanName,
                                  exerciseEquipment: exercise.equipment,
                                ),
                              ),
                            );
                            // Note: For temporary workouts, the listener (_onTempWorkoutDataChanged)
                            // will automatically reload when the data changes
                          } else {
                            // Navigate to the regular exercise detail page
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExerciseDetailPage(
                                  exerciseId: apiId.isNotEmpty
                                      ? apiId
                                      : exercise.id.toString(),
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
                          }
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
                                      // Clean the name to remove API ID and CUSTOM markers if present
                                      _cleanExerciseName(exercise.name),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: allSetsCompleted
                                      ? _successColor.withOpacity(0.2)
                                      : _textSecondaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  allSetsCompleted
                                      ? 'Completed'
                                      : 'In Progress',
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
                                key: Key(
                                    'exercise_menu_${exercise.id}'), // Unique key to avoid hero tag conflicts
                                icon: Icon(Icons.more_vert,
                                    color: _textSecondaryColor),
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
                                  } else if (value == 'add_note') {
                                    _toggleExerciseNote(exercise.id);
                                  } else if (value == 'create_superset') {
                                    _openSupersetSelection(exercise);
                                  } else if (value == 'remove_superset') {
                                    _removeFromSuperset(exercise.id);
                                  } else if (value == 'replace') {
                                    _replaceExercise(exercise);
                                  }
                                },
                                itemBuilder: (BuildContext context) {
                                  final bool isInSuperset = supersetId != null;
                                  return <PopupMenuEntry<String>>[
                                    // Show Edit only for custom exercises (with ##CUSTOM:true## marker)
                                    if (isCustomExercise)
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.edit,
                                              color: _primaryColor),
                                          title: Text('Edit Exercise',
                                              style: TextStyle(
                                                  color: _textPrimaryColor)),
                                        ),
                                      ),
                                    PopupMenuItem<String>(
                                      value: 'replace',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.swap_horiz,
                                            color: _primaryColor),
                                        title: Text('Replace Exercise',
                                            style: TextStyle(
                                                color: _textPrimaryColor)),
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'set_rest',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.timer,
                                            color: _primaryColor),
                                        title: Text('Set Rest Time',
                                            style: TextStyle(
                                                color: _textPrimaryColor)),
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'add_note',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.note_add,
                                            color: _primaryColor),
                                        title: Text('Add Note',
                                            style: TextStyle(
                                                color: _textPrimaryColor)),
                                      ),
                                    ),
                                    if (isInSuperset)
                                      PopupMenuItem<String>(
                                        value: 'remove_superset',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.link_off,
                                              color: const Color(0xFFFF9800)),
                                          title: Text('Remove from Superset',
                                              style: TextStyle(
                                                  color: _textPrimaryColor)),
                                        ),
                                      )
                                    else
                                      PopupMenuItem<String>(
                                        value: 'create_superset',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.link,
                                              color: _primaryColor),
                                          title: Text('Create Superset',
                                              style: TextStyle(
                                                  color: _textPrimaryColor)),
                                        ),
                                      ),
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.delete,
                                            color: _dangerColor),
                                        title: Text('Delete Exercise',
                                            style: TextStyle(
                                                color: _textPrimaryColor)),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(
                          'Rest time: ${exercise.sets.first.restTime}s',
                          style: TextStyle(
                              color: _textSecondaryColor, fontSize: 12),
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
                                child: Text('PREVIOUS',
                                    style: TextStyle(
                                        color: _textSecondaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center)),
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
                              exercise.sets.isEmpty
                                  ? 'Add First Set'
                                  : 'Add Set',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryColor,
                              side: BorderSide(color: _primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _addSetToExercise(exercise.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get previous exercise values for display as greyed out placeholders
  ExerciseSet? _getPreviousSetValues(String exerciseName, int setNumber) {
    // Clean exercise name to remove API ID and CUSTOM markers
    final String cleanExerciseName = _cleanExerciseName(exerciseName);

    // Check cache
    if (_exerciseHistoryCache.containsKey(cleanExerciseName)) {
      final previousSets = _exerciseHistoryCache[cleanExerciseName]!;
      if (setNumber <= previousSets.length) {
        return previousSets[setNumber - 1]; // Convert to 0-based index
      }
    }

    return null;
  }

  Widget _buildSetItem(Exercise exercise, ExerciseSet set) {
    // Get previous set values for display as greyed out placeholders
    final previousSet = _getPreviousSetValues(exercise.name, set.setNumber);

    // Initialize controllers if absent with validation to prevent conflicts
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
    });

    // Validate that controllers exist and are correctly mapped
    if (!_weightControllers.containsKey(set.id) ||
        !_repsControllers.containsKey(set.id)) {
      // Emergency fallback: create controllers if they don't exist
      _weightControllers[set.id] = TextEditingController();
      _repsControllers[set.id] = TextEditingController();
    }

    // Determine if both fields have valid values (now allowing zero values) to enable the completion button
    final String weightTextStr = _weightControllers[set.id]?.text ?? '';
    final String repsTextStr = _repsControllers[set.id]?.text ?? '';
    final double? weightValue = double.tryParse(weightTextStr);
    final int? repsValue = int.tryParse(repsTextStr);

    // Check if current fields have valid values
    final bool hasCurrentValues = weightValue != null &&
        weightValue >= 0 &&
        repsValue != null &&
        repsValue >= 0;

    // Check if previous values are available when current fields are empty
    final bool hasPreviousValues =
        (weightTextStr.isEmpty || (weightValue ?? 0) == 0) &&
            (repsTextStr.isEmpty || (repsValue ?? 0) == 0) &&
            previousSet != null &&
            previousSet.weight > 0 &&
            previousSet.reps > 0;

    final bool canCompleteButton = hasCurrentValues || hasPreviousValues;

    // Removed PR checking for workout session UI

    return RepaintBoundary(
        child: Dismissible(
      key: Key(
          'set_${exercise.id}_${set.id}'), // More unique key including exercise ID
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
        final exerciseForSet = _workout!.exercises
            .firstWhere((e) => e.sets.any((s) => s.id == set.id));
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
              // Set number - tappable to change set type
              Builder(
                builder: (BuildContext context) {
                  return GestureDetector(
                    onTap: widget.readOnly
                        ? null
                        : () => _showSetTypeDialog(set, context),
                    child: Container(
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
                        _getSetTypeDisplay(set),
                        style: TextStyle(
                          color: set.completed ? _successColor : _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: set.setType != SetType.normal ? 16 : 14,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Previous values column
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Center(
                    child: previousSet != null
                        ? Text(
                            '${previousSet.weight > 0 ? (previousSet.weight % 1 == 0 ? previousSet.weight.toInt().toString() : previousSet.weight.toString()) : '-'}$_weightUnit x ${previousSet.reps > 0 ? previousSet.reps.toString() : '-'}',
                            style: TextStyle(
                              color: _textSecondaryColor.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : Text(
                            '-',
                            style: TextStyle(
                              color: _textSecondaryColor.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
              ),

              // Weight and Reps columns (align with headers)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onLongPress: _exerciseUsesPlates(exercise.equipment) &&
                            !widget.readOnly
                        ? () => _showPlateCalculator(set, exercise)
                        : null,
                    child: TextField(
                      controller: _weightControllers[set.id],
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
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
                        // Show previous weight as placeholder if available and current field is empty
                        hintText: (previousSet != null &&
                                (_weightControllers[set.id]?.text.isEmpty ??
                                    true))
                            ? (previousSet.weight > 0
                                ? (previousSet.weight % 1 == 0
                                    ? previousSet.weight.toInt().toString()
                                    : previousSet.weight.toString())
                                : null)
                            : null,
                        hintStyle: TextStyle(
                          color: _textSecondaryColor.withOpacity(0.6),
                          fontSize: 14,
                        ),
                        // Show plate calculator icon for barbell exercises
                        prefixIcon: _exerciseUsesPlates(exercise.equipment) &&
                                !widget.readOnly
                            ? GestureDetector(
                                onTap: () =>
                                    _showPlateCalculator(set, exercise),
                                child: Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.calculate_outlined,
                                    size: 16,
                                    color: _primaryColor.withOpacity(0.7),
                                  ),
                                ),
                              )
                            : null,
                        prefixIconConstraints: BoxConstraints(
                          minWidth: 20,
                          minHeight: 0,
                        ),
                        // Use suffix widget with padding to avoid cramped edge
                        suffix: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            _weightUnit,
                            style: TextStyle(color: _textSecondaryColor),
                          ),
                        ),
                      ),
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        // Save immediately when user types
                        final weight = double.tryParse(value);
                        if (weight != null && weight >= 0) {
                          _updateSetData(
                              set.id, weight, set.reps, set.restTime);
                        }
                      },
                      onSubmitted: (value) {
                        final weight = double.tryParse(value);
                        if (weight != null && weight >= 0) {
                          _updateSetData(
                              set.id, weight, set.reps, set.restTime);
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
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    controller: _repsControllers[set.id],
                    keyboardType: TextInputType.number,
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
                      // Show previous reps as placeholder if available and current field is empty
                      hintText: (previousSet != null &&
                              (_repsControllers[set.id]?.text.isEmpty ?? true))
                          ? (previousSet.reps > 0
                              ? previousSet.reps.toString()
                              : null)
                          : null,
                      hintStyle: TextStyle(
                        color: _textSecondaryColor.withOpacity(0.6),
                        fontSize: 14,
                      ),
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
                                : hasPreviousValues
                                    ? 'Mark as completed (will use previous values)'
                                    : 'Mark as completed')
                            : 'Enter weight and reps to complete',
                        onPressed: canCompleteButton
                            ? () {
                                final willComplete = !set.completed;
                                _toggleSetCompletion(
                                    exercise.id, set.id, willComplete);
                                if (willComplete && _autoStartRestTimer) {
                                  // Start rest when completing (if auto-start is enabled)
                                  _startRestTimerForSet(set.id, set.restTime);
                                } else if (!willComplete) {
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
              title: Text('Set Rest Time',
                  style: TextStyle(color: _textPrimaryColor)),
              content: SizedBox(
                height: 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Minutes : Seconds',
                      style:
                          TextStyle(color: _textSecondaryColor, fontSize: 16),
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
                                    final mins = (value ~/ 60)
                                        .toString()
                                        .padLeft(2, '0');
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
                              style: TextStyle(
                                  fontSize: 24, color: _textPrimaryColor)),
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
                                    totalSeconds.value =
                                        totalSeconds.value - 59;
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
                                    totalSeconds.value =
                                        totalSeconds.value - 60 + 59;
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
                  child: Text('Cancel',
                      style: TextStyle(color: _textSecondaryColor)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _primaryColor),
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
      final SnackBarAction? action =
          actionLabel != null && actionCallback != null
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
              behavior: SnackBarBehavior.fixed,
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

  // Open superset selection page
  void _openSupersetSelection(Exercise exercise) async {
    if (_workout == null || _workout!.exercises.isEmpty) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupersetSelectionPage(
          exercises: _workout!.exercises,
          currentExerciseId: exercise.id,
          existingSupersets: Map<int, String>.from(_exerciseSupersets),
          getColorForSuperset: _getColorForSuperset,
        ),
      ),
    );

    if (result != null && result is List<int>) {
      // Create a new superset with selected exercises
      if (result.length >= 2) {
        setState(() {
          // Generate a unique superset ID
          final supersetId = 'superset_${_supersetCounter++}';

          // Assign the superset ID to all selected exercises
          for (final exerciseId in result) {
            _exerciseSupersets[exerciseId] = supersetId;
          }
        });

        // Auto-save the workout state after creating superset
        _updateActiveNotifier();

        _showSnackBar('Superset created with ${result.length} exercises');
      }
    }
  }

  // Get a consistent color for a superset based on its ID
  Color _getColorForSuperset(String supersetId) {
    // Extract the number from superset ID (e.g., "superset_0" -> 0)
    final match = RegExp(r'superset_(\d+)').firstMatch(supersetId);
    if (match != null) {
      final index = int.tryParse(match.group(1) ?? '0') ?? 0;
      return _supersetColors[index % _supersetColors.length];
    }
    // Fallback: use hash code to get a consistent index
    final index = supersetId.hashCode.abs() % _supersetColors.length;
    return _supersetColors[index];
  }

  // Remove an exercise from its superset
  void _removeFromSuperset(int exerciseId) {
    final supersetId = _exerciseSupersets[exerciseId];
    if (supersetId == null) return;

    setState(() {
      // Remove the exercise from the superset
      _exerciseSupersets.remove(exerciseId);

      // Check if only one exercise remains in the superset - if so, remove it too
      final remainingInSuperset = _exerciseSupersets.entries
          .where((e) => e.value == supersetId)
          .toList();

      if (remainingInSuperset.length == 1) {
        // Only one exercise left, remove it from superset tracking
        _exerciseSupersets.remove(remainingInSuperset.first.key);
      }
    });

    // Auto-save the workout state after removing from superset
    _updateActiveNotifier();

    _showSnackBar('Exercise removed from superset');
  }

  // Reorder exercises when user drags and drops
  void _reorderExercises(int oldIndex, int newIndex) async {
    // Don't allow reordering in read-only mode
    if (widget.readOnly) return;

    if (oldIndex == newIndex) return;

    // Don't allow reordering the add button
    if (oldIndex >= _workout!.exercises.length) {
      return;
    }

    // If newIndex is at or beyond the exercises length (add button position), place at the end
    if (newIndex >= _workout!.exercises.length) {
      newIndex = _workout!.exercises.length - 1;
    } else if (newIndex > oldIndex) {
      // Only adjust if moving down and not to the end
      newIndex -= 1;
    }

    setState(() {
      final exercise = _workout!.exercises.removeAt(oldIndex);
      _workout!.exercises.insert(newIndex, exercise);
    });

    // Update the order in database for regular workouts (asynchronously to avoid blocking UI)
    if (!widget.isTemporary) {
      // Run database updates in background without awaiting
      Future.microtask(() async {
        try {
          // Update the display order for all exercises
          for (int i = 0; i < _workout!.exercises.length; i++) {
            final exercise = _workout!.exercises[i];
            await _workoutService.updateExerciseOrder(exercise.id, i);
          }
        } catch (e) {
          print('Error updating exercise order: $e');
        }
      });
    } else {
      // For temporary workouts, update the in-memory order
      final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
      if (tempWorkouts.containsKey(widget.workoutId)) {
        final workoutData = tempWorkouts[widget.workoutId];
        final exercises = workoutData['exercises'] as List;

        // Reorder the exercises list
        final exerciseData = exercises.removeAt(oldIndex);
        exercises.insert(newIndex, exerciseData);

        // Notify listeners
        WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
      }
    }

    // Auto-save the workout state
    _updateActiveNotifier();
  }

  // Toggle exercise note visibility
  void _toggleExerciseNote(int exerciseId) {
    setState(() {
      if (_exerciseNotes.containsKey(exerciseId)) {
        // If note exists, remove it
        _exerciseNotes.remove(exerciseId);
        _noteEditingState.remove(exerciseId);
        if (_noteControllers.containsKey(exerciseId)) {
          _noteControllers[exerciseId]!.dispose();
          _noteControllers.remove(exerciseId);
        }
      } else {
        // If no note exists, add an empty note and start editing immediately
        _exerciseNotes[exerciseId] = '';
        // Initialize controller and start editing
        if (!_noteControllers.containsKey(exerciseId)) {
          _noteControllers[exerciseId] = TextEditingController();
        }
        _noteControllers[exerciseId]!.text = '';
        _noteEditingState[exerciseId] = true;
      }
    });
  }

  // Start editing a note
  void _startEditingNote(int exerciseId) {
    // Initialize controller if not exists
    if (!_noteControllers.containsKey(exerciseId)) {
      _noteControllers[exerciseId] = TextEditingController();
    }

    // Set current text
    _noteControllers[exerciseId]!.text = _exerciseNotes[exerciseId] ?? '';

    setState(() {
      _noteEditingState[exerciseId] = true;
    });
  }

  // Finish editing a note
  void _finishEditingNote(int exerciseId) async {
    if (_noteControllers.containsKey(exerciseId)) {
      final newText = _noteControllers[exerciseId]!.text.trim();

      setState(() {
        // Always keep the note, even if empty - only remove via swipe or manual deletion
        _exerciseNotes[exerciseId] = newText;
        _noteEditingState[exerciseId] = false;
      });

      // Update sticky note if marked as sticky
      if (_isNoteSticky[exerciseId] == true && _workout != null) {
        final exercise =
            _workout!.exercises.firstWhere((e) => e.id == exerciseId);
        if (newText.isNotEmpty) {
          await _stickyNoteService.setStickyNote(exercise.name, newText);
        } else {
          await _stickyNoteService.deleteStickyNote(exercise.name);
        }
      }

      // Update temporary workout data to persist the note
      _updateTemporaryWorkoutData();
    }
  }

  // Remove a note completely
  void _removeExerciseNote(int exerciseId) async {
    setState(() {
      _exerciseNotes.remove(exerciseId);
      _noteEditingState.remove(exerciseId);
      _isNoteSticky.remove(exerciseId);
      if (_noteControllers.containsKey(exerciseId)) {
        _noteControllers[exerciseId]!.dispose();
        _noteControllers.remove(exerciseId);
      }
    });

    // Delete sticky note if it exists
    if (_workout != null) {
      try {
        final exercise =
            _workout!.exercises.firstWhere((e) => e.id == exerciseId);
        await _stickyNoteService.deleteStickyNote(exercise.name);
      } catch (e) {
        // Exercise not found, ignore
      }
    }

    // Update temporary workout data to persist the removal
    _updateTemporaryWorkoutData();
  }

  // Toggle sticky note status
  void _toggleStickyNote(int exerciseId) async {
    final wasSticky = _isNoteSticky[exerciseId] ?? false;

    setState(() {
      _isNoteSticky[exerciseId] = !wasSticky;
    });

    // If making sticky and note exists, save to sticky notes
    if (!wasSticky && _workout != null) {
      final exercise =
          _workout!.exercises.firstWhere((e) => e.id == exerciseId);
      final noteText = _exerciseNotes[exerciseId];
      if (noteText != null && noteText.isNotEmpty) {
        await _stickyNoteService.setStickyNote(exercise.name, noteText);
      }
    }
    // If unsticking, remove from sticky notes
    else if (wasSticky && _workout != null) {
      final exercise =
          _workout!.exercises.firstWhere((e) => e.id == exerciseId);
      await _stickyNoteService.deleteStickyNote(exercise.name);
    }
  }

  // Shows "Empty workout discarded" notification
}
