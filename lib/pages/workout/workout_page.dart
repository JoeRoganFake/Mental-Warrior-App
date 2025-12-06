import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/pages/workout/workout_session_page.dart';
import 'package:mental_warior/pages/workout/workout_details_page.dart';
import 'package:mental_warior/pages/workout/exercise_browse_page.dart';
import 'package:mental_warior/pages/workout/template_editor_page.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/widgets/workout_week_chart.dart';
import 'package:mental_warior/utils/functions.dart';


class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  WorkoutPageState createState() => WorkoutPageState();
}

class WorkoutPageState extends State<WorkoutPage>
    with SingleTickerProviderStateMixin {
  final WorkoutService _workoutService = WorkoutService();
  final TemplateService _templateService = TemplateService();
  late TabController _tabController;
  final SettingsService _settingsService = SettingsService();
  List<Workout> _workouts = [];
  List<WorkoutTemplate> _templates = [];
  bool _isLoading = true;
  int _weeklyWorkoutGoal = 5; // Default goal

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadWorkouts();
    _loadWeeklyGoal();
    _loadTemplates();

    // Listen for changes to workouts
    WorkoutService.workoutsUpdatedNotifier.addListener(_onWorkoutsUpdated);

    // Listen for settings changes
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsUpdated);
    
    // Listen for template changes
    TemplateService.templatesUpdatedNotifier.addListener(_onTemplatesUpdated);
  }

  @override
  void dispose() {
    _tabController.dispose();
    WorkoutService.workoutsUpdatedNotifier.removeListener(_onWorkoutsUpdated);
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsUpdated);
    TemplateService.templatesUpdatedNotifier
        .removeListener(_onTemplatesUpdated);
    super.dispose();
  }

  void _onWorkoutsUpdated() {
    _loadWorkouts();
  }

  void _onSettingsUpdated() {
    _loadWeeklyGoal();
  }
  
  void _onTemplatesUpdated() {
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _templateService.getTemplates();
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      // Silently fail - templates table might not exist yet
      debugPrint('Error loading templates: $e');
    }
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

  // Compact custom header to replace the default AppBar
  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 4),
      child: const Text(
        'Workouts',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Build the main workout tab content
  Widget _buildWorkoutTab() {
    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      child: ListView(
        children: [
          // Weekly Workout Chart - always show this
          WorkoutWeekChart(
            workouts: _workouts,
            onChangeGoal: _showChangeGoalDialog,
          ),
          const SizedBox(height: 24),
          // Start workout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 16),
          // Templates section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Template'),
                      onPressed: _showCreateTemplateDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildTemplatesSection(),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTemplatesSection() {
    // Show saved templates
    if (_templates.isEmpty) {
      return Card(
        color: Colors.grey[900],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create a template to quickly start workouts with predefined exercises',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _templates.take(3).map((template) {
        final exerciseCount = template.exercises.length;
        final exerciseNames = template.exercises
            .take(3)
            .map((e) => e.name
                .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
                .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
                .trim())
            .join(', ');

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _startWorkoutFromSavedTemplate(template),
            onLongPress: () => _showTemplateOptions(template),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$exerciseCount exercises • $exerciseNames${template.exercises.length > 3 ? '...' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.play_arrow,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showTemplateOptions(WorkoutTemplate template) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF26272B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white70),
                title: const Text('Edit Template',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TemplateEditorPage(
                        templateId: template.id,
                        initialName: template.name,
                      ),
                    ),
                  ).then((_) => _loadTemplates());
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Template',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF26272B),
                      title: const Text('Delete Template?',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                        'Are you sure you want to delete "${template.name}"?',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _templateService.deleteTemplate(template.id);
                    _loadTemplates();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startWorkoutFromSavedTemplate(WorkoutTemplate template) async {
    // Check if there's an active workout already
    if (WorkoutService.activeWorkoutNotifier.value != null) {
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
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard & Start New'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldContinue) return;
      WorkoutService.activeWorkoutNotifier.value = null;
    }

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    try {
      // Convert template exercises to the format expected by createTemporaryWorkoutFromTemplate
      final exercises = template.exercises
          .map((te) => Exercise(
                id: 0,
                workoutId: 0,
                name: te.name,
                equipment: te.equipment,
                supersetGroup: te.supersetGroup,
                sets: te.sets
                    .map((ts) => ExerciseSet(
                          id: 0,
                          exerciseId: 0,
                          setNumber: ts.setNumber,
                          weight: ts.targetWeight ?? 0.0,
                          reps: ts.targetReps ?? 0,
                          restTime: ts.restTime,
                          completed: false,
                        ))
                    .toList(),
              ))
          .toList();

      final tempWorkoutId = _workoutService.createTemporaryWorkoutFromTemplate(
        template.name,
        dateStr,
        exercises,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutSessionPage(
            workoutId: tempWorkoutId,
            readOnly: false,
            isTemporary: true,
          ),
        ),
      );

      _loadWorkouts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating workout from template: $e')),
      );
    }
  }

  void _showCreateTemplateDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TemplateEditorPage(),
      ),
    ).then((_) {
      // Refresh templates when returning
      _loadTemplates();
    });
  }

  // Build the history tab content
  Widget _buildHistoryTab() {
    if (_workouts.isEmpty) {
      return Center(
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
              'Complete a workout to see it here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkouts,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _workouts.length,
        itemBuilder: (context, index) {
          final workout = _workouts[index];

          // Parse date for better formatting
          DateTime workoutDate;
          try {
            workoutDate = DateFormat('yyyy-MM-dd').parse(workout.date);
          } catch (_) {
            workoutDate = DateTime.now();
          }
          // Format date like in the image
          final formattedDate =
              DateFormat('EEEE, MMMM d, yyyy').format(workoutDate);

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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onPressed: () => _deleteWorkout(workout.id),
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

                    // Exercise sets and details
                    if (workout.exercises.isNotEmpty)
                      Column(
                        children: [
                          // Show only first 3 exercises
                          ...workout.exercises.take(3).map((exercise) {
                            // Calculate best set
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
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercise.name
                                              .replaceAll(
                                                  RegExp(r'##API_ID:[^#]+##'),
                                                  '')
                                              .replaceAll(
                                                  RegExp(r'##CUSTOM:[^#]+##'),
                                                  '')
                                              .trim(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        // Show set details
                                        ...exercise.sets.map((set) {
                                          return Text(
                                            set.weight > 0
                                                ? "${set.weight.toStringAsFixed(set.weight.truncateToDouble() == set.weight ? 0 : 1)} kg × ${set.reps}"
                                                : "${set.reps} reps",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          "Best set",
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          bestSet,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
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
                              padding: const EdgeInsets.only(bottom: 12.0),
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
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer,
                                size: 16, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(workout.duration),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        // Volume calculation (total weight × reps)
                        Text(
                          _calculateTotalVolume(workout),
                          style: const TextStyle(color: Colors.white70),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Header with title and browse button
                  _buildCompactHeader(),
                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Workout'),
                      Tab(text: 'History'),
                      Tab(text: 'Exercises'),
                    ],
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                  ),
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildWorkoutTab(),
                        _buildHistoryTab(),
                        const ExerciseBrowsePage(embedded: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
