import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/pages/workout/workout_session_page.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/widgets/workout_week_chart.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  WorkoutPageState createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage> {
  final WorkoutService _workoutService = WorkoutService();
  final SettingsService _settingsService = SettingsService();
  List<Workout> _workouts = [];
  bool _isLoading = true;
  int _weeklyWorkoutGoal = 5; // Default goal

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
    _loadWeeklyGoal();

    // Listen for changes to workouts
    WorkoutService.workoutsUpdatedNotifier.addListener(_onWorkoutsUpdated);

    // Listen for settings changes
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsUpdated);
  }

  @override
  void dispose() {
    WorkoutService.workoutsUpdatedNotifier.removeListener(_onWorkoutsUpdated);
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onWorkoutsUpdated() {
    _loadWorkouts();
  }

  void _onSettingsUpdated() {
    _loadWeeklyGoal();
  }

  Future<void> _loadWeeklyGoal() async {
    final goal = await _settingsService.getWeeklyWorkoutGoal();
    setState(() {
      _weeklyWorkoutGoal = goal;
    });
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

  void _showChangeGoalDialog() {
    int tempGoal = _weeklyWorkoutGoal;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Weekly Workout Goal'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'How many workouts do you aim to complete each week?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: tempGoal > 1
                            ? () => setState(() => tempGoal--)
                            : null,
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).primaryColor,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tempGoal.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: tempGoal < 14
                            ? () => setState(() => tempGoal++)
                            : null,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                _settingsService.setWeeklyWorkoutGoal(tempGoal);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
                  child: ListView(
                    children: [
                      // Weekly Workout Chart
                      WorkoutWeekChart(
                        workouts: _workouts,
                        onChangeGoal: _showChangeGoalDialog,
                      ),

                      // Workouts List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
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
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () =>
                                              _deleteWorkout(workout.id),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            size: 16),
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
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                                backgroundColor:
                                                    Colors.grey[200],
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
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewWorkout,
        child: const Icon(Icons.add),
      ),
    );
  }
}
