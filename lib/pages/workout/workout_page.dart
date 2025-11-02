import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/pages/workout/workout_session_page.dart';
import 'package:mental_warior/pages/workout/workout_details_page.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/widgets/workout_week_chart.dart';
import 'package:mental_warior/utils/functions.dart';


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
    // Check if there's an active workout already
    if (WorkoutService.activeWorkoutNotifier.value != null) {
      // Show confirmation dialog
      bool shouldContinue = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: const Color(0xFF26272B),
                title: const Text('Active Workout Found',
                    style: TextStyle(color: Colors.white)),
                content: const Text(
                  'You already have an active workout. Starting a new workout will discard the current one. Do you want to continue?',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, false), // Don't continue
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(
                        context, true), // Continue with new workout
                    child: const Text('Discard & Start New'),
                  ),
                ],
              );
            },
          ) ??
          false; // Default to false if dialog is dismissed

      if (!shouldContinue) {
        return; // Exit if user cancels
      }

      // Clear the active workout if user wants to proceed
      WorkoutService.activeWorkoutNotifier.value = null;
    }

    // Create a new temporary workout with a unique ID (not saved to database yet)
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    try {
      // Get time-based greeting (Morning/Afternoon/Evening)
      final greeting = Functions().getTimeOfDayDescription();
      
      // Create temporary workout in memory, not in database
      final tempWorkoutId = _workoutService.createTemporaryWorkout(
        '$greeting Workout',
        dateStr,
        0, // Initial duration is 0
      );

      // Navigate to the workout session page with the temporary ID
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutSessionPage(
            workoutId: tempWorkoutId,
            readOnly: false,
            isTemporary: true, // Indicate this is a temporary workout
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
        builder: (context) => WorkoutDetailsPage(
          workoutId: workoutId,
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
  
  String _calculateTotalVolume(Workout workout) {
    double totalVolume = 0;
    int totalPrs = 0;

    for (var exercise in workout.exercises) {
      for (var set in exercise.sets) {
        // Calculate volume (weight * reps)
        totalVolume += set.weight * set.reps;

        // Count PRs if we had that data
        // if (set.isPR) totalPrs++;
      }
    }

    // Format it like in the image
    return '${totalVolume.toStringAsFixed(0)} kg ${totalPrs > 0 ? '• $totalPrs PRs' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWorkouts,
              child: ListView(
                children: [
                  // Weekly Workout Chart - always show this
                  WorkoutWeekChart(
                    workouts: _workouts,
                    onChangeGoal: _showChangeGoalDialog,
                  ), // Show message when no workouts
                  if (_workouts.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
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
                            label: Text(
                                'Start ${Functions().getTimeOfDayDescription()} Workout'),
                            onPressed: _startNewWorkout,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),

                  // Workouts List - only show when there are workouts
                  if (_workouts.isNotEmpty)
                    Column(
                      children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _workouts.length,
                        itemBuilder: (context, index) {
                          final workout = _workouts[index];

                            // Parse date for better formatting
                            DateTime workoutDate;
                            try {
                              workoutDate =
                                  DateFormat('yyyy-MM-dd').parse(workout.date);
                            } catch (_) {
                              workoutDate = DateTime.now();
                            } // Format date like in the image
                            final formattedDate =
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(workoutDate);
                            DateFormat('h:mm a').format(workoutDate);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.black,
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
                                      Expanded(
                                        child: Text(
                                          workout.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          ),
                                        ),
                                        IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.white70),
                                        onPressed: () =>
                                            _deleteWorkout(workout.id),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Sets",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                    const SizedBox(height: 8),
                                    
                                  // Exercise sets and details - similar to the image
                                  if (workout.exercises.isNotEmpty)
                                    Column(
                                          children: [
                                            // Show only first 3 exercises
                                            ...workout.exercises
                                                .take(3)
                                                .map((exercise) {
                                              // Calculate total sets and best set
                                              String bestSet = '';
                                              double bestWeight = 0;
                                              int bestReps = 0;

                                              for (var set in exercise.sets) {
                                                if (set.weight > bestWeight ||
                                                    (set.weight == bestWeight &&
                                                        set.reps > bestReps)) {
                                                  bestWeight = set.weight;
                                                  bestReps = set.reps;
                                                  bestSet = bestWeight > 0
                                                      ? '${bestWeight.toStringAsFixed(bestWeight.truncateToDouble() == bestWeight ? 0 : 1)} kg × $bestReps'
                                                      : '$bestReps reps';
                                                }
                                              }

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            exercise.name
                                                                .replaceAll(
                                                                    RegExp(
                                                                        r'##API_ID:[^#]+##'),
                                                                    '')
                                                                .replaceAll(
                                                                    RegExp(
                                                                        r'##CUSTOM:[^#]+##'),
                                                                    '')
                                                                .trim(),
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          // Show set details
                                                          ...exercise.sets
                                                              .map((set) {
                                                            return Text(
                                                              set.weight > 0
                                                                  ? "${set.weight.toStringAsFixed(set.weight.truncateToDouble() == set.weight ? 0 : 1)} kg × ${set.reps}"
                                                                  : "${set.reps} reps",
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .white70,
                                                                fontSize: 12,
                                                              ),
                                                            );
                                                          }), // Limit to first 2 sets
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          const Text(
                                                            "Best set",
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          Text(
                                                            bestSet,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                        
                                            // Show indicator if there are more than 3 exercises
                                            if (workout.exercises.length > 3)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.more_horiz,
                                                      color: Colors.white70,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${workout.exercises.length - 3} more exercise${workout.exercises.length - 3 > 1 ? 's' : ''}',
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                    ),
                                    
                                    const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.timer,
                                              size: 16, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDuration(workout.duration),
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                        ],
                                      ),

                                      // Volume calculation (total weight × reps)
                                      Text(
                                        _calculateTotalVolume(workout),
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                        // Add "Start New Workout" button below the list when workouts exist
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 24,
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text(
                                'Start ${Functions().getTimeOfDayDescription()} Workout'),
                            onPressed: _startNewWorkout,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ]),
              ));
  }
}
