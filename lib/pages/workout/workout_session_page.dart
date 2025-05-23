import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/rest_timer_page.dart';

class WorkoutSessionPage extends StatefulWidget {
  final int workoutId;
  final bool readOnly;

  const WorkoutSessionPage({
    super.key,
    required this.workoutId,
    this.readOnly = false,
  });

  @override
  WorkoutSessionPageState createState() => WorkoutSessionPageState();
}

class WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final WorkoutService _workoutService = WorkoutService();

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

  // Defae
  final int _defaultRestTime = 90; // 1:30 min

  // Shared rest timer state
  final ValueNotifier<int> _restRemainingNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _restPausedNotifier = ValueNotifier(false);
  int _originalRestTime = 0;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
    if (!widget.readOnly) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _cancelRestTimer();
    _nameController.dispose();
    for (var c in _weightControllers.values) {
      c.dispose();
    }
    for (var c in _repsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadWorkout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workout = await _workoutService.getWorkout(widget.workoutId);

      if (workout != null) {
        if (mounted) {
          // Check if widget is still mounted before updating state
          setState(() {
            _workout = workout;
            _nameController.text = workout.name;
            _elapsedSeconds = workout.duration;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout not found')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workout: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _startTimer() {
    if (_isTimerRunning) return;

    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Avoid calling setState too frequently by using a more efficient approach
      _elapsedSeconds++;

      // Only update UI every second if the widget is still mounted
      if (mounted) {
        // Update timer display without rebuilding the entire widget
        if (_elapsedSeconds % 1 == 0) {
          setState(() {});
        }

        // Update workout duration in database less frequently
        if (_elapsedSeconds % 15 == 0) {
          _updateWorkoutDuration();
        }
      }
    });
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    setState(() {
      _isTimerRunning = false;
    });

    // Final update to the workout duration
    _updateWorkoutDuration();
  }

  void _updateWorkoutDuration() {
    // Update workout duration in the database
    if (_workout != null) {
      _workoutService.updateWorkoutDuration(
        widget.workoutId,
        _elapsedSeconds,
      );
    }
  }

  String _formatTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Starts a rest timer for a specific set and tracks its id
  void _startRestTimerForSet(int setId, int seconds) {
    _cancelRestTimer();
    setState(() {
      _currentRestSetId = setId;
      _restTimeRemaining = seconds;
      _originalRestTime = seconds;
      _restPausedNotifier.value = false;
      _restRemainingNotifier.value = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _restPausedNotifier.value) return;
      if (_restRemainingNotifier.value > 0) {
        _restRemainingNotifier.value--;
        setState(() => _restTimeRemaining = _restRemainingNotifier.value);
      } else {
        timer.cancel();
        setState(() => _currentRestSetId = null);
      }
    });
  }

  void _cancelRestTimer() {
    if (_restTimer != null) {
      _restTimer!.cancel();
      _restTimer = null;
    }
    setState(() {
      _restTimeRemaining = 0;
      _currentRestSetId = null;
      _restPausedNotifier.value = false;
      _restRemainingNotifier.value = 0;
    });
  }
  
  void _togglePauseRest() {
    if (_restPausedNotifier.value) {
      // resume
      _restPausedNotifier.value = false;
    } else {
      // pause
      _restPausedNotifier.value = true;
    }
  }

  void _incrementRest() {
    _restRemainingNotifier.value += 15;
    setState(() => _restTimeRemaining = _restRemainingNotifier.value);
  }

  void _decrementRest() {
    final newVal = (_restRemainingNotifier.value - 15)
        .clamp(0, _restRemainingNotifier.value);
    _restRemainingNotifier.value = newVal;
    setState(() => _restTimeRemaining = newVal);
    if (newVal == 0) _cancelRestTimer();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding exercise: $e')),
          );
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
      } else {
        // If we couldn't get the new set ID, fall back to full reload
        _loadWorkout();
      }
    } catch (e) {
      // Handle error case
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding set: $e')),
        );
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
    }

    // Then update the database in the background
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
      // Then delete from the database in the background
      await _workoutService.deleteSet(setId);

      // Also update the set numbers in the database for remaining sets
      // This ensures the database is consistent with our UI
      final db = await DatabaseService.instance.database;
      for (int i = 0; i < _workout!.exercises[exerciseIndex].sets.length; i++) {
        final set = _workout!.exercises[exerciseIndex].sets[i];
        await db.update(
          'exercise_sets',
          {'setNumber': i + 1},
          where: 'id = ?',
          whereArgs: [set.id],
        );
      }

      // Show a confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set deleted'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                // Implement undo functionality if needed
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting set: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating exercise: $e')),
        );
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

    // Then update database
    try {
      final db = await DatabaseService.instance.database;
      await db.delete(
        'exercises',
        where: 'id = ?',
        whereArgs: [exerciseId],
      );
      WorkoutService.workoutsUpdatedNotifier.value =
          !WorkoutService.workoutsUpdatedNotifier.value;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exercise deleted'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting exercise: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
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
                }

                // If all sets are empty, discard the entire workout
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
                    // Delete the workout and return to previous screen
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
                  } else {
                    return; // User chose to go back and fill in sets
                  }
                }                // Check for any issues: empty sets or uncompleted sets
                else {
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
                  }

                  // Prepare data for dialog
                  bool hasEmptySets = emptySets > 0;
                  bool hasUncompletedSets = uncompletedSetsByExercise.isNotEmpty;
                  String dialogTitle = '';
                  List<Widget> dialogContent = [];
                  
                  if (hasEmptySets && hasUncompletedSets) {
                    dialogTitle = 'Sets Need Attention';
                  } else if (hasEmptySets) {
                    dialogTitle = 'Empty Sets Detected';
                  } else if (hasUncompletedSets) {
                    dialogTitle = 'Uncompleted Sets Detected';
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
                  }

                  // Check if any exercises remain after deleting all empty sets
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
                
                _stopTimer();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Workout saved'),
                    backgroundColor: _successColor,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
    );
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

                  // Navigate to the detail page with the API ID if available, otherwise use the local ID
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailPage(
                        exerciseId:
                            apiId.isNotEmpty ? apiId : exercise.id.toString(),
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
                                  // Cancel rest when undoing
                                  _cancelRestTimer();
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
    final controller = TextEditingController(
      text: (exercise.sets.isNotEmpty
              ? exercise.sets.first.restTime
              : _defaultRestTime)
          .toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title:
            Text('Set Rest Time', style: TextStyle(color: _textPrimaryColor)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: _textPrimaryColor),
          decoration: InputDecoration(
            labelText: 'Rest Time (seconds)',
            labelStyle: TextStyle(color: _textSecondaryColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.dispose();
            },
            child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () async {
              final rest = int.tryParse(controller.text) ?? _defaultRestTime;
              Navigator.pop(context);
              controller.dispose();
              for (var set in exercise.sets) {
                await _updateSetData(set.id, set.weight, set.reps, rest);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
