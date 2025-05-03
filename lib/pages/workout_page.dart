import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/pages/workout_session_page.dart';
import 'package:mental_warior/services/database_services.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({Key? key}) : super(key: key);

  @override
  _WorkoutPageState createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final WorkoutService _workoutService = WorkoutService();
  List<Workout> _workouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();

    // Listen for changes to workouts
    WorkoutService.workoutsUpdatedNotifier.addListener(_onWorkoutsUpdated);
  }

  @override
  void dispose() {
    WorkoutService.workoutsUpdatedNotifier.removeListener(_onWorkoutsUpdated);
    super.dispose();
  }

  void _onWorkoutsUpdated() {
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workouts = await _workoutService.getWorkouts();
      setState(() {
        _workouts = workouts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading workouts: $e')),
      );
    }
  }

  Future<void> _startNewWorkout() async {
    // Create a new workout
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    try {
      final workoutId = await _workoutService.addWorkout(
        'New Workout',
        dateStr,
        0, // Initial duration is 0
      );

      if (workoutId != null) {
        // Navigate to the workout session page
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutSessionPage(
              workoutId: workoutId,
              readOnly: false,
            ),
          ),
        );

        // Refresh the list when returning
        _loadWorkouts();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating workout: $e')),
      );
    }
  }

  void _viewWorkoutDetails(int workoutId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutSessionPage(
          workoutId: workoutId,
          readOnly: true,
        ),
      ),
    );
  }

  Future<void> _deleteWorkout(int workoutId) async {
    try {
      await _workoutService.deleteWorkout(workoutId);
      _loadWorkouts();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting workout: $e')),
      );
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$seconds sec';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No workouts yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap the + button to create your first workout',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Start Workout'),
                        onPressed: _startNewWorkout,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWorkouts,
                  child: ListView.builder(
                    itemCount: _workouts.length,
                    itemBuilder: (context, index) {
                      final workout = _workouts[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: InkWell(
                          onTap: () => _viewWorkoutDetails(workout.id),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      workout.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () =>
                                          _deleteWorkout(workout.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 8),
                                    Text(workout.date),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.timer, size: 16),
                                    const SizedBox(width: 8),
                                    Text(_formatDuration(workout.duration)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Exercises: ${workout.exercises.length}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (workout.exercises.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    children: workout.exercises
                                            .take(3)
                                            .map((exercise) {
                                          return Chip(
                                            label: Text(
                                              exercise.name,
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                            backgroundColor: Colors.grey[200],
                                          );
                                        }).toList() +
                                        (workout.exercises.length > 3
                                            ? [
                                                Chip(
                                                  label: Text(
                                                    '+${workout.exercises.length - 3} more',
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                  ),
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                ),
                                              ]
                                            : []),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewWorkout,
        child: const Icon(Icons.add),
        tooltip: 'Start New Workout',
      ),
    );
  }
}
