import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/exercise_selection_page.dart';

class WorkoutSessionPage extends StatefulWidget {
  final int workoutId;
  final bool readOnly;

  const WorkoutSessionPage({
    Key? key,
    required this.workoutId,
    this.readOnly = false,
  }) : super(key: key);

  @override
  _WorkoutSessionPageState createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final WorkoutService _workoutService = WorkoutService();

  Workout? _workout;
  bool _isLoading = true;
  bool _isTimerRunning = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  Timer? _restTimer;
  bool _isRestTimerActive = false;
  int _restTimeRemaining = 0;
  final TextEditingController _nameController = TextEditingController();

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
        setState(() {
          _workout = workout;
          _nameController.text = workout.name;
          _elapsedSeconds = workout.duration;
          _isLoading = false;
        });
      } else {
        // Handle case where workout is not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading workout: $e')),
      );
      Navigator.pop(context);
    }
  }

  void _startTimer() {
    if (_isTimerRunning) return;

    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });

      // Update the workout duration in the database every 5 seconds
      if (_elapsedSeconds % 5 == 0) {
        _updateWorkoutDuration();
      }
    });
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

      // Add exercise to the database
      await _workoutService.addExercise(
        widget.workoutId,
        exerciseName,
        equipment,
      );

      // Reload workout to refresh the exercise list
      _loadWorkout();
    }
  }

  void _updateWorkoutName() {
    if (widget.readOnly) return;

    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && _workout != null) {
      _workoutService.updateWorkout(
        widget.workoutId,
        newName,
        _workout!.date,
        _workout!.duration,
      );
      _loadWorkout();
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
      _isRestTimerActive = true;
      _restTimeRemaining = seconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_restTimeRemaining > 0) {
          _restTimeRemaining--;
        } else {
          _isRestTimerActive = false;
          timer.cancel();
        }
      });
    });
  }

  void _cancelRestTimer() {
    if (_restTimer != null) {
      _restTimer!.cancel();
      _restTimer = null;
    }
    setState(() {
      _isRestTimerActive = false;
      _restTimeRemaining = 0;
    });
  }

  void _toggleSetCompletion(int exerciseId, int setId, bool completed) async {
    // Update set completion status in database
    await _updateSetComplete(setId, completed);
    _loadWorkout();
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

  void _addSetToExercise(int exerciseId) async {
    final exerciseIndex =
        _workout!.exercises.indexWhere((e) => e.id == exerciseId);

    if (exerciseIndex == -1) return;

    final exercise = _workout!.exercises[exerciseIndex];
    final setNumber = exercise.sets.length + 1;

    await _workoutService.addSet(
      exerciseId,
      setNumber,
      0.0, // Default weight
      0, // Default reps
      60, // Default rest time (seconds)
    );

    _loadWorkout();
  }

  void _editSet(int exerciseId, ExerciseSet set) {
    final weightController = TextEditingController(text: set.weight.toString());
    final repsController = TextEditingController(text: set.reps.toString());
    final restTimeController =
        TextEditingController(text: set.restTime.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Set ${set.setNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                ),
              ),
              TextField(
                controller: repsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                ),
              ),
              TextField(
                controller: restTimeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rest Time (seconds)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _updateSetData(
                set.id,
                double.tryParse(weightController.text) ?? set.weight,
                int.tryParse(repsController.text) ?? set.reps,
                int.tryParse(restTimeController.text) ?? set.restTime,
              );
              Navigator.pop(context);
              _loadWorkout();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetData(
    int setId,
    double weight,
    int reps,
    int restTime,
  ) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? const Text('Workout Session')
            : TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Workout Name',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                readOnly: widget.readOnly,
                onEditingComplete: _updateWorkoutName,
              ),
        actions: [
          if (!widget.readOnly)
            IconButton(
              icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (_isTimerRunning) {
                  _stopTimer();
                } else {
                  _startTimer();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: widget.readOnly
                ? null
                : () {
                    _stopTimer();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Workout saved')),
                    );
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Timer display
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${(_elapsedSeconds ~/ 3600).toString().padLeft(2, '0')}:' +
                            '${((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:' +
                            '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Date display
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // Rest timer if active
                if (_isRestTimerActive)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.amber[100],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_bottom,
                            color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Rest: $_restTimeRemaining seconds',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: _cancelRestTimer,
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),

                // Exercises list
                Expanded(
                  child: _workout!.exercises.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'No exercises yet',
                                style: TextStyle(fontSize: 18),
                              ),
                              if (!widget.readOnly) const SizedBox(height: 16),
                              if (!widget.readOnly)
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Exercise'),
                                  onPressed: _addExercise,
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _workout!.exercises.length,
                          itemBuilder: (context, index) {
                            final exercise = _workout!.exercises[index];
                            return Card(
                              margin: const EdgeInsets.all(8),
                              child: ExpansionTile(
                                title: Text(
                                  exercise.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  exercise.equipment.isEmpty
                                      ? 'No equipment'
                                      : exercise.equipment,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                children: [
                                  // Sets list
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: exercise.sets.length,
                                    itemBuilder: (context, setIndex) {
                                      final set = exercise.sets[setIndex];
                                      return ListTile(
                                        dense: true,
                                        title: Row(
                                          children: [
                                            Text('Set ${set.setNumber}'),
                                            const SizedBox(width: 16),
                                            Text('${set.weight} kg'),
                                            const SizedBox(width: 16),
                                            Text('${set.reps} reps'),
                                          ],
                                        ),
                                        trailing: widget.readOnly
                                            ? set.completed
                                                ? const Icon(Icons.check_circle,
                                                    color: Colors.green)
                                                : const Icon(
                                                    Icons.circle_outlined,
                                                    color: Colors.grey)
                                            : Checkbox(
                                                value: set.completed,
                                                onChanged: (value) {
                                                  _toggleSetCompletion(
                                                      exercise.id,
                                                      set.id,
                                                      value ?? false);
                                                },
                                              ),
                                        onTap: widget.readOnly
                                            ? null
                                            : () {
                                                _editSet(exercise.id, set);
                                              },
                                      );
                                    },
                                  ),

                                  // Add set button
                                  if (!widget.readOnly)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Set'),
                                        onPressed: () {
                                          _addSetToExercise(exercise.id);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[100],
                                          foregroundColor: Colors.blue[900],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: _addExercise,
              child: const Icon(Icons.add),
              tooltip: 'Add Exercise',
            ),
    );
  }
}
