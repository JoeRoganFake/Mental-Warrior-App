import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/exercise_selection_page.dart';

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
  final TextEditingController _nameController = TextEditingController();

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

  void _startRestTimer(int seconds) {
    _cancelRestTimer();
    setState(() {
      _restTimeRemaining = seconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_restTimeRemaining > 0) {
        _restTimeRemaining--;
        // Only rebuild UI when necessary
        setState(() {});
      } else {
        timer.cancel();
        if (mounted) {
          setState(() {});
        }
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
    });
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

        await _workoutService.addSet(
          exerciseId,
          1, // Set number
          0.0, // Default weight
          0, // Default reps
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
      // Add set to database
      final newSetId = await _workoutService.addSet(
        exerciseId,
        setNumber,
        0.0, // Default weight
        0, // Default reps
        _defaultRestTime, // Default rest time
      );

      // If we have the new set ID, create a local Set object and add it to our state
      if (mounted) {
        final newSet = ExerciseSet(
          id: newSetId,
          exerciseId: exerciseId,
          setNumber: setNumber,
          weight: 0.0,
          reps: 0,
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
        'rest_time': restTime,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
    WorkoutService.workoutsUpdatedNotifier.value =
        !WorkoutService.workoutsUpdatedNotifier.value;
  }

  void _editSet(int exerciseId, ExerciseSet set) {
    final weightController = TextEditingController(text: set.weight.toString());
    final repsController = TextEditingController(text: set.reps.toString());
    final restTimeController =
        TextEditingController(text: set.restTime.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text('Edit Set ${set.setNumber}',
            style: TextStyle(color: _textPrimaryColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimaryColor),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: TextStyle(color: _textSecondaryColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: _primaryColor.withOpacity(0.6)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimaryColor),
                decoration: InputDecoration(
                  labelText: 'Reps',
                  labelStyle: TextStyle(color: _textSecondaryColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: _primaryColor.withOpacity(0.6)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: restTimeController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: _textPrimaryColor),
                decoration: InputDecoration(
                  labelText: 'Rest Time (seconds)',
                  labelStyle: TextStyle(color: _textSecondaryColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: _primaryColor.withOpacity(0.6)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                ),
              ),
            ],
          ),
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
            onPressed: () async {
              // Update data without waiting for database
              final weight =
                  double.tryParse(weightController.text) ?? set.weight;
              final reps = int.tryParse(repsController.text) ?? set.reps;
              final restTime =
                  int.tryParse(restTimeController.text) ?? set.restTime;

              // Close dialog immediately to improve responsiveness
              Navigator.pop(context);

              // Then update database in background
              await _updateSetData(set.id, weight, reps, restTime);

              // No need to reload the entire workout as we're updating local state in _updateSetData
            },
            child: Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Properly dispose controllers when dialog is closed
      weightController.dispose();
      repsController.dispose();
      restTimeController.dispose();
    });
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
    final nameController = TextEditingController(text: exercise.name);
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

              if (newName.isNotEmpty) {
                Navigator.pop(context);
                _updateExercise(exercise.id, newName, newEquipment);
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
          tooltip: '', // Empty tooltip to prevent tooltip creation
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
              onPressed: () {
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
                          padding: EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: _workout!.exercises.length,
                          itemBuilder: (context, index) {
                            return _buildExerciseCard(
                                _workout!.exercises[index]);
                          },
                        ),
                ),

                // Add exercise button (fixed position)
                if (!widget.readOnly)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _addExercise,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add),
                            SizedBox(width: 8),
                            Text(
                              'Add Exercise',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Add Your First Exercise'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _addExercise,
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
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
                            exercise.name,
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
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: _textSecondaryColor),
                    enabled: !widget.readOnly,
                    offset: Offset(
                        0, 0), // This forces the menu to appear at the button
                    color: Colors.black, // Set background color to black
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (String value) {
                      if (value == 'edit') {
                        _editExercise(exercise);
                      } else if (value == 'delete') {
                        _confirmDeleteExercise(exercise);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit, color: _primaryColor),
                          title: Text('Edit Exercise',
                              style: TextStyle(color: _textPrimaryColor)),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete, color: _dangerColor),
                          title: Text('Delete Exercise',
                              style: TextStyle(color: _textPrimaryColor)),
                        ),
                      ),
                    ],
                  ),
                ],
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
                      child: Text(
                        'WEIGHT',
                        style: TextStyle(
                          color: _textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'REPS',
                        style: TextStyle(
                          color: _textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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

            // Add set button
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
          onTap: widget.readOnly ? null : () => _editSet(exercise.id, set),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _textSecondaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(children: [
              Row(
                children: [
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

                  // Weight value
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 40,
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _inputBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${set.weight} kg',
                        style: TextStyle(
                          color: _textPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Reps value
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 40,
                      margin: EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _inputBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${set.reps}',
                        style: TextStyle(
                          color: _textPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
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
                                    color: _textSecondaryColor),
                            onPressed: () {
                              _toggleSetCompletion(
                                  exercise.id, set.id, !set.completed);
                              if (!set.completed) {
                                _startRestTimer(set.restTime);
                              }
                            },
                          ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
