import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/pages/workout/workout_session_page.dart';
import 'package:mental_warior/pages/workout/workout_details_page.dart';
import 'package:mental_warior/pages/workout/exercise_browse_page.dart';
import 'package:mental_warior/pages/workout/template_editor_page.dart';
import 'package:mental_warior/pages/workout/body_measurements_page.dart';
import 'package:mental_warior/pages/workout/workout_settings_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/widgets/workout_week_chart.dart';
import 'package:mental_warior/utils/functions.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'package:mental_warior/widgets/xp_bar.dart';

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
  List<TemplateFolder> _folders = [];
  Map<int, bool> _expandedFolders = {}; // Track which folders are expanded
  bool _isLoading = true;
  int _weeklyWorkoutGoal = 5; // Default goal
  bool _showWeightInLbs = false;
  List<Map<String, dynamic>> _personalRecords = [];
  String _prDisplayMode = 'random'; // 'random' or 'pinned'
  List<String> _pinnedExercises = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadWorkouts();
    _loadWeeklyGoal();
    _loadWeightUnit();
    _loadTemplates();
    _loadFolders();
    _loadPRSettings();
    _loadPersonalRecords();

    // Listen for changes to workouts
    WorkoutService.workoutsUpdatedNotifier.addListener(_onWorkoutsUpdated);

    // Listen for settings changes
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsUpdated);

    // Listen for template changes
    TemplateService.templatesUpdatedNotifier.addListener(_onTemplatesUpdated);

    // Listen for folder changes
    TemplateService.foldersUpdatedNotifier.addListener(_onFoldersUpdated);
  }

  @override
  void dispose() {
    _tabController.dispose();
    WorkoutService.workoutsUpdatedNotifier.removeListener(_onWorkoutsUpdated);
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsUpdated);
    TemplateService.templatesUpdatedNotifier
        .removeListener(_onTemplatesUpdated);
    TemplateService.foldersUpdatedNotifier.removeListener(_onFoldersUpdated);
    super.dispose();
  }

  void _onWorkoutsUpdated() {
    _loadWorkouts();
    _loadPersonalRecords();
  }

  void _onSettingsUpdated() {
    _loadWeeklyGoal();
    _loadWeightUnit();
    _loadPRSettings();
    _loadPersonalRecords();
  }

  void _onTemplatesUpdated() {
    _loadTemplates();
  }

  void _onFoldersUpdated() {
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await _templateService.getFolders();
      setState(() {
        _folders = folders;
        // Initialize expanded state for new folders
        for (var folder in folders) {
          _expandedFolders.putIfAbsent(folder.id, () => true);
        }
      });
    } catch (e) {
      debugPrint('Error loading folders: $e');
    }
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

  Future<void> _loadWeightUnit() async {
    final useLbs = await _settingsService.getShowWeightInLbs();
    setState(() => _showWeightInLbs = useLbs);
  }

  Future<void> _loadPRSettings() async {
    final mode = await _settingsService.getPrDisplayMode();
    final pinned = await _settingsService.getPinnedExercises();
    setState(() {
      _prDisplayMode = mode;
      _pinnedExercises = pinned;
    });
  }

  // Get the weight unit based on settings
  String get _weightUnit => _showWeightInLbs ? 'lbs' : 'kg';

  Future<void> _loadPersonalRecords() async {
    try {
      final prs = <Map<String, dynamic>>[];

      // Get all workouts with exercises
      final allWorkouts = await _workoutService.getWorkouts();

      // Track best set for each exercise
      final Map<String, Map<String, dynamic>> bestSets = {};

      for (var workout in allWorkouts) {
        for (var exercise in workout.exercises) {
          // Clean exercise name
          final cleanName = exercise.name
              .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
              .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
              .trim();

          for (var set in exercise.sets) {
            if (!set.completed) continue;

            // Calculate one-rep max estimate (Epley formula)
            final oneRepMax = set.weight * (1 + set.reps / 30.0);

            if (!bestSets.containsKey(cleanName) ||
                oneRepMax > (bestSets[cleanName]!['oneRepMax'] as double)) {
              bestSets[cleanName] = {
                'exerciseName': cleanName,
                'originalName': exercise
                    .name, // Keep original name with API_ID or CUSTOM tag
                'equipment': exercise.equipment,
                'weight': set.weight,
                'reps': set.reps,
                'oneRepMax': oneRepMax,
                'date': workout.date,
              };
            }
          }
        }
      }

      if (_prDisplayMode == 'pinned') {
        // Show only pinned exercises
        for (var exerciseName in _pinnedExercises) {
          if (bestSets.containsKey(exerciseName)) {
            prs.add(bestSets[exerciseName]!);
          }
        }
      } else {
        // Random mode - convert to list and sort by date (most recent first)
        prs.addAll(bestSets.values);
        prs.sort((a, b) {
          try {
            final dateA = DateFormat('yyyy-MM-dd').parse(a['date']);
            final dateB = DateFormat('yyyy-MM-dd').parse(b['date']);
            return dateB.compareTo(dateA);
          } catch (_) {
            return 0;
          }
        });

        // For random mode, shuffle based on current date for daily variety
        if (prs.length > 5) {
          final now = DateTime.now();
          final seed = now.year * 10000 + now.month * 100 + now.day;
          final random = DateTime(seed).millisecondsSinceEpoch;

          // Simple daily shuffle by rotating the list based on date
          final rotateAmount = random % prs.length;
          prs.addAll(prs.sublist(0, rotateAmount));
          prs.removeRange(0, rotateAmount);
        }
      }

      setState(() {
        _personalRecords = prs;
      });
    } catch (e) {
      debugPrint('Error loading personal records: $e');
    }
  }

  // Build PR card from database
  Widget _buildPRCard(int index) {
    final pr = _personalRecords[index];
    final exerciseName = pr['exerciseName'] as String;
    final originalName = pr['originalName'] as String? ?? exerciseName;
    final equipment = pr['equipment'] as String? ?? '';
    final weight = pr['weight'] as double;
    final reps = pr['reps'] as int;
    final dateStr = pr['date'] as String;

    // Format date
    DateTime prDate;
    try {
      prDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (_) {
      prDate = DateTime.now();
    }

    final now = DateTime.now();
    final difference = now.difference(prDate).inDays;
    final formattedDate = difference == 0
        ? 'Today'
        : difference == 1
            ? 'Yesterday'
            : DateFormat('MMM d').format(prDate);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 8,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.amber.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: () =>
              _navigateToExerciseDetail(originalName, exerciseName, equipment),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[900]!,
                  Colors.grey[850]!,
                  Colors.grey[900]!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.emoji_events,
                              size: 12, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            'PR',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.25),
                        Theme.of(context).primaryColor.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weight > 0
                            ? '${weight.toStringAsFixed(weight.truncateToDouble() == weight ? 0 : 1)} $_weightUnit'
                            : 'BW',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' × ',
                        style: TextStyle(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$reps',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Navigate to exercise detail page based on exercise type
  void _navigateToExerciseDetail(
      String originalName, String cleanName, String equipment) {
    // Check if it's a custom exercise
    final isCustomExercise = originalName.contains('##CUSTOM:');

    // Extract API ID or Custom ID
    String apiId = '';
    final apiIdMatch = RegExp(r'##API_ID:([^#]+)##').firstMatch(originalName);
    final customIdMatch =
        RegExp(r'##CUSTOM:([^#]+)##').firstMatch(originalName);

    if (apiIdMatch != null) {
      apiId = apiIdMatch.group(1) ?? '';
    } else if (customIdMatch != null) {
      apiId = customIdMatch.group(1) ?? '';
    }

    if (isCustomExercise) {
      // Navigate to custom exercise detail page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomExerciseDetailPage(
            exerciseId: apiId.isNotEmpty ? apiId : cleanName,
            exerciseName: cleanName,
            exerciseEquipment: equipment,
          ),
        ),
      );
    } else {
      // Navigate to the regular exercise detail page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseDetailPage(
            exerciseId: apiId.isNotEmpty ? apiId : cleanName,
          ),
          settings: RouteSettings(
            arguments: {
              'exerciseName': cleanName,
              'exerciseEquipment': equipment,
            },
          ),
        ),
      );
    }
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
    return '${totalVolume.toStringAsFixed(0)} $_weightUnit ${totalPrs > 0 ? '• $totalPrs PRs' : ''}';
  }

  // Compact custom header to replace the default AppBar
  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 20, right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Workouts',
                style: AppTheme.headlineLarge,
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: AppTheme.borderRadiusMd,
                ),
                child: IconButton(
                  icon: Icon(Icons.settings_outlined,
                      size: 22, color: AppTheme.textSecondary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WorkoutSettingsPage(),
                      ),
                    );
                  },
                  tooltip: 'Settings',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // XP Bar
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: XPBar(compact: true),
          ),
        ],
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
          // PRs Section - Carousel (only show if PRs exist and mode is not 'none')
          if (_personalRecords.isNotEmpty && _prDisplayMode != 'none') ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Personal Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 128,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.85),
                    padEnds: false,
                    itemCount: _personalRecords.length > 5
                        ? 5
                        : _personalRecords.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _buildPRCard(index),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.create_new_folder_outlined,
                              size: 20),
                          onPressed: _showCreateFolderDialog,
                          tooltip: 'New Folder',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Template'),
                          onPressed: _showCreateTemplateDialog,
                        ),
                      ],
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
    if (_templates.isEmpty && _folders.isEmpty) {
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

    // Group templates by folder
    final uncategorizedTemplates =
        _templates.where((t) => t.folderId == null).toList();

    return Column(
      children: [
        // Show folders first
        ..._folders.map((folder) {
          final folderTemplates =
              _templates.where((t) => t.folderId == folder.id).toList();
          final isExpanded = _expandedFolders[folder.id] ?? true;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.grey[900],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedFolders[folder.id] = !isExpanded;
                    });
                  },
                  onLongPress: () => _showFolderOptions(folder),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: folder.getColor().withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isExpanded ? Icons.folder_open : Icons.folder,
                            color: folder.getColor(),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${folderTemplates.length} template${folderTemplates.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
                // Show templates in this folder when expanded
                if (isExpanded && folderTemplates.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                    child: Column(
                      children: folderTemplates
                          .map((template) =>
                              _buildTemplateCard(template, inFolder: true))
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
        // Show uncategorized templates
        ...uncategorizedTemplates
            .map((template) => _buildTemplateCard(template)),
      ],
    );
  }

  Widget _buildTemplateCard(WorkoutTemplate template, {bool inFolder = false}) {
    final exerciseCount = template.exercises.length;
    final exerciseNames = template.exercises
        .take(3)
        .map((e) => e.name
            .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
            .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
            .trim())
        .join(', ');

    return Card(
      margin: EdgeInsets.only(bottom: 8, left: inFolder ? 0 : 0),
      color: inFolder ? Colors.grey[850] : Colors.grey[900],
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
                leading:
                    const Icon(Icons.folder_outlined, color: Colors.white70),
                title: const Text('Move to Folder',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveToFolderDialog(template);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white70),
                title: const Text('Duplicate Template',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await _duplicateTemplate(template);
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

  Future<void> _duplicateTemplate(WorkoutTemplate template) async {
    try {
      // Create a copy with "(Copy)" appended to the name
      final newName = '${template.name} (Copy)';

      await _templateService.createTemplate(
        newName,
        template.exercises,
        folderId: template.folderId,
      );

      _loadTemplates();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template duplicated as "$newName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating template: $e')),
        );
      }
    }
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

  // Show dialog to create a new folder
  void _showCreateFolderDialog() {
    final nameController = TextEditingController();
    int selectedColorIndex = 0;

    final List<Color> folderColors = [
      const Color(0xFF3F8EFC), // Blue (default)
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF4CAF50), // Green
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFFFF5722), // Deep Orange
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF26272B),
              title: const Text('New Folder',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Folder name',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF303136),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(folderColors.length, (index) {
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColorIndex = index),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: folderColors[index],
                            shape: BoxShape.circle,
                            border: selectedColorIndex == index
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: selectedColorIndex == index
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      await _templateService.createFolder(
                        name,
                        color: folderColors[selectedColorIndex].value,
                      );
                      Navigator.pop(context);
                      _loadFolders();
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show dialog to move template to a folder
  void _showMoveToFolderDialog(WorkoutTemplate template) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Move to Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Option to remove from folder (uncategorized)
              ListTile(
                leading: Icon(
                  Icons.folder_off_outlined,
                  color: template.folderId == null
                      ? Theme.of(context).primaryColor
                      : Colors.white70,
                ),
                title: const Text('No Folder',
                    style: TextStyle(color: Colors.white)),
                trailing: template.folderId == null
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                onTap: () async {
                  await _templateService.moveTemplateToFolder(
                      template.id, null);
                  Navigator.pop(context);
                  _loadTemplates();
                },
              ),
              const Divider(color: Colors.grey),
              // List folders
              ..._folders.map((folder) {
                final isSelected = template.folderId == folder.id;
                return ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: isSelected
                        ? folder.getColor()
                        : folder.getColor().withOpacity(0.7),
                  ),
                  title: Text(
                    folder.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () async {
                    await _templateService.moveTemplateToFolder(
                        template.id, folder.id);
                    Navigator.pop(context);
                    _loadTemplates();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Show options for a folder (edit, delete)
  void _showFolderOptions(TemplateFolder folder) {
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
                title: const Text('Rename Folder',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Folder',
                    style: TextStyle(color: Colors.red)),
                subtitle: const Text(
                  'Templates will be moved to uncategorized',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF26272B),
                      title: const Text('Delete Folder?',
                          style: TextStyle(color: Colors.white)),
                      content: Text(
                        'Are you sure you want to delete "${folder.name}"? Templates inside will be moved to uncategorized.',
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
                    await _templateService.deleteFolder(folder.id);
                    _loadFolders();
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

  // Show dialog to rename a folder
  void _showRenameFolderDialog(TemplateFolder folder) {
    final nameController = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF26272B),
          title: const Text('Rename Folder',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Folder name',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF303136),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  await _templateService.updateFolder(folder.id, name: name);
                  Navigator.pop(context);
                  _loadFolders();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
                                    ? '${bestWeight.toStringAsFixed(bestWeight.truncateToDouble() == bestWeight ? 0 : 1)} $_weightUnit × $bestReps'
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
                                                ? "${set.weight.toStringAsFixed(set.weight.truncateToDouble() == set.weight ? 0 : 1)} $_weightUnit × ${set.reps}"
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
      backgroundColor: AppTheme.background,
      appBar: null,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : SafeArea(
              child: Column(
                children: [
                  // Header with title and browse button
                  _buildCompactHeader(),
                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.surfaceBorder.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: 'Workout'),
                        Tab(text: 'History'),
                        Tab(text: 'Exercises'),
                        Tab(text: 'Measurements'),
                      ],
                      labelColor: AppTheme.accent,
                      unselectedLabelColor: AppTheme.textTertiary,
                      indicatorColor: AppTheme.accent,
                      indicatorWeight: 2,
                      labelStyle: AppTheme.titleSmall,
                      unselectedLabelStyle: AppTheme.titleSmall
                          .copyWith(fontWeight: FontWeight.w400),
                    ),
                  ),
                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildWorkoutTab(),
                        _buildHistoryTab(),
                        const ExerciseBrowsePage(embedded: true),
                        const BodyMeasurementsPage(embedded: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
