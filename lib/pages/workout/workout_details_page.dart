import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/workout_edit_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';
import 'package:mental_warior/widgets/barbell_plate_calculator.dart';
import 'package:mental_warior/utils/app_theme.dart';

class WorkoutDetailsPage extends StatefulWidget {
  final int workoutId;

  const WorkoutDetailsPage({
    super.key,
    required this.workoutId,
  });

  @override
  WorkoutDetailsPageState createState() => WorkoutDetailsPageState();
}

class WorkoutDetailsPageState extends State<WorkoutDetailsPage> {
  final WorkoutService _workoutService = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;

  // Theme colors for prettier styling
  final Color _backgroundColor = const Color(0xFF0A0A0B);
  final Color _surfaceColor = const Color(0xFF1A1B1E);
  final Color _cardColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);
  final Color _accentColor = const Color(0xFF7C4DFF);
  
  bool _showWeightInLbs = false;
  String get _weightUnit => _showWeightInLbs ? 'lbs' : 'kg';

  // Superset colors - same as workout_session_page
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

  // Get a consistent color for a superset based on its group ID
  Color _getColorForSuperset(String supersetGroup) {
    // Extract the number from superset group (e.g., "superset_0" -> 0)
    final match = RegExp(r'superset_(\d+)').firstMatch(supersetGroup);
    if (match != null) {
      final index = int.tryParse(match.group(1) ?? '0') ?? 0;
      return _supersetColors[index % _supersetColors.length];
    }
    // Fallback: use hash code to get a consistent index
    final index = supersetGroup.hashCode.abs() % _supersetColors.length;
    return _supersetColors[index];
  }

  // Helper method to clean exercise names by removing markers
  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
  }

  // Helper method to get set type display text
  String _getSetTypeDisplay(SetType setType) {
    switch (setType) {
      case SetType.warmup:
        return 'W';
      case SetType.dropset:
        return 'D';
      case SetType.failure:
        return 'F';
      case SetType.normal:
        return '';
    }
  }


  // Helper method to check if an exercise uses plates (barbell, ez-curl bar, trap bar, smith machine)
  bool _exerciseUsesPlates(String equipment) {
    final lowerEquipment = equipment.toLowerCase();
    return lowerEquipment.contains('barbell') ||
        lowerEquipment.contains('e-z curl') ||
        lowerEquipment.contains('ez curl') ||
        lowerEquipment.contains('trap bar') ||
        lowerEquipment.contains('smith') ||
        lowerEquipment.contains('dumbbell');
  }

  // Show plate viewer for an exercise set at a specific weight
  Future<void> _showPlateViewer(Exercise exercise, double weight) async {
    if (!_exerciseUsesPlates(exercise.equipment)) return;
    
    await showBarbellPlateViewer(
      context: context,
      exerciseName: exercise.name,
      useLbs: _showWeightInLbs,
      weight: weight,
    );
  }

  // Navigate to exercise detail page
  void _navigateToExerciseDetail(Exercise exercise) async {
    final String exerciseName = exercise.name;
    
    final RegExp apiIdRegex = RegExp(r'##API_ID:([^#]+)##');
    final RegExp customRegex = RegExp(r'##CUSTOM:([^#]+)##');
    final Match? apiMatch = apiIdRegex.firstMatch(exerciseName);
    final Match? customMatch = customRegex.firstMatch(exerciseName);

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
      isCustomExercise = isCustomExercise || customFlag.toLowerCase() == 'true';
    }
    
    // Get the clean exercise name without any markers
    final String cleanName = exerciseName
        .replaceAll(apiIdRegex, '')
        .replaceAll(customRegex, '')
        .trim();

    // Debug print
    print(
        'Exercise ID: ${exercise.id}, Is Custom: $isCustomExercise, API ID: $apiId');
    
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
            exerciseId: apiId.isNotEmpty ? apiId : exercise.id.toString(),
            exerciseName: cleanName,
            exerciseEquipment: exercise.equipment,
          ),
        ),
      );
      
      // Reload workout data after returning from custom exercise detail
      // This ensures any changes to the exercise name are reflected
      await _loadWorkout();
    } else {
      // Navigate to the regular exercise detail page
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseDetailPage(
            exerciseId: apiId.isNotEmpty ? apiId : exercise.id.toString(),
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
      
      // Reload workout data after returning from exercise detail
      // This ensures any changes are reflected
      await _loadWorkout();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWeightUnit();
    _loadWorkout();
  }

  Future<void> _loadWeightUnit() async {
    final useLbs = await SettingsService().getShowWeightInLbs();
    if (mounted) {
      setState(() => _showWeightInLbs = useLbs);
    }
  }

  Future<void> _loadWorkout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workout = await _workoutService.getWorkout(widget.workoutId);
      setState(() {
        _workout = workout;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workout: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${remainingSeconds.toString().padLeft(2, '0')}s';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds.toString().padLeft(2, '0')}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatWeight(double weight) {
    if (weight % 1 == 0) {
      return weight.toInt().toString();
    }
    return weight.toString();
  }

  double _calculateTotalVolume() {
    if (_workout == null) return 0;
    
    double totalVolume = 0;
    for (var exercise in _workout!.exercises) {
      for (var set in exercise.sets) {
        // Include all sets that have actual weight/reps data
        if (set.weight > 0 && set.reps > 0) {
          totalVolume += set.weight * set.reps;
        }
      }
    }
    return totalVolume;
  }

  int _getTotalSets() {
    if (_workout == null) return 0;
    
    int totalSets = 0;
    for (var exercise in _workout!.exercises) {
      totalSets +=
          exercise.sets.where((set) => set.weight > 0 && set.reps > 0).length;
    }
    return totalSets;
  }

  int _getTotalPRs() {
    if (_workout == null) return 0;
    
    int totalPRs = 0;
    for (var exercise in _workout!.exercises) {
      for (var set in exercise.sets) {
        // Only count sets that are marked as PR in the database
        // and have valid weight/reps data
        if (set.isPR && set.weight > 0 && set.reps > 0) {
          totalPRs++;
        }
      }
    }
    return totalPRs;
  }

  void _editWorkout() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return WorkoutEditPage(
            key: ValueKey(
                'edit_${widget.workoutId}_${DateTime.now().millisecondsSinceEpoch}'),
            workoutId: widget.workoutId,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeInOut)),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      ),
    );

    // Add a small delay to ensure any database transactions are completed
    await Future.delayed(const Duration(milliseconds: 100));

    // Always reload fresh data from database when returning from edit
    // This ensures we display the latest saved state
    await _loadWorkout();

    // Force a rebuild to ensure UI updates
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            )
          : _workout == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Workout not found',
                        style: TextStyle(
                          fontSize: 20,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The workout you\'re looking for doesn\'t exist.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: RefreshIndicator(
                        onRefresh: _loadWorkout,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildWorkoutStats(),
                              const SizedBox(height: 24),
                              _buildExercisesList(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSliverAppBar() {
    DateTime workoutDate;
    try {
      workoutDate = DateFormat('yyyy-MM-dd').parse(_workout!.date);
    } catch (_) {
      workoutDate = DateTime.now();
    }

    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(workoutDate);

    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit, color: AppTheme.textPrimary),
          onPressed: _editWorkout,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _workout!.name,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accent.withOpacity(0.8),
                AppTheme.purple.withOpacity(0.6),
                AppTheme.surface,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 60,
              top: 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: AppTheme.textPrimary.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: AppTheme.textPrimary.withOpacity(0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_workout!.duration),
                      style: TextStyle(
                        color: AppTheme.textPrimary.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutStats() {
    final totalVolume = _calculateTotalVolume();
    final totalSets = _getTotalSets();
    final totalPRs = _getTotalPRs();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.fitness_center,
                  label: 'Exercises',
                  value: _workout!.exercises.length.toString(),
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.repeat,
                  label: 'Sets',
                  value: totalSets.toString(),
                  color: AppTheme.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.monitor_weight,
                  label: 'Volume',
                  value: '${totalVolume.toStringAsFixed(0)} $_weightUnit',
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.emoji_events,
                  label: 'PRs',
                  value: totalPRs.toString(),
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesList() {
    // Group exercises by superset
    final exercises = _workout!.exercises;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercises',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            final supersetGroup = exercise.supersetGroup;

            // Determine superset position
            String? supersetPosition;
            if (supersetGroup != null) {
              final supersetExercises = exercises
                  .where((e) => e.supersetGroup == supersetGroup)
                  .toList();
              final posInSuperset = supersetExercises.indexOf(exercise);
              if (supersetExercises.length == 1) {
                supersetPosition = 'only';
              } else if (posInSuperset == 0) {
                supersetPosition = 'first';
              } else if (posInSuperset == supersetExercises.length - 1) {
                supersetPosition = 'last';
              } else {
                supersetPosition = 'middle';
              }
            }

            return _buildExerciseCard(
              exercise,
              supersetGroup: supersetGroup,
              supersetPosition: supersetPosition,
            );
          },
        ),
      ],
    );
  }

  Widget _buildExerciseCard(
    Exercise exercise, {
    String? supersetGroup,
    String? supersetPosition,
  }) {
    final allSets = exercise.sets.toList(); // Show all sets
    final validSets = exercise.sets
        .where((set) => set.weight > 0 && set.reps > 0)
        .toList(); // For calculations only
    final bestSet = validSets.isNotEmpty
        ? validSets
            .reduce((a, b) => 
            (a.weight * a.reps) > (b.weight * b.reps) ? a : b)
        : null;

    // Use only database PR flags - no calculation needed
    // The database service handles PR calculation correctly
    
    final isInSuperset = supersetGroup != null;
    final supersetColor =
        isInSuperset ? _getColorForSuperset(supersetGroup) : null;

    // Determine border radius based on superset position
    BorderRadius cardBorderRadius;
    if (isInSuperset) {
      switch (supersetPosition) {
        case 'first':
          cardBorderRadius = const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          );
          break;
        case 'last':
          cardBorderRadius = const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );
          break;
        case 'middle':
          cardBorderRadius = BorderRadius.circular(4);
          break;
        default:
          cardBorderRadius = BorderRadius.circular(16);
      }
    } else {
      cardBorderRadius = BorderRadius.circular(16);
    }

    final cardWidget = InkWell(
      onTap: () => _navigateToExerciseDetail(exercise),
      borderRadius: cardBorderRadius,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: cardBorderRadius,
          border: Border.all(
            color: isInSuperset
                ? supersetColor!.withOpacity(0.3)
                : AppTheme.textSecondary.withOpacity(0.1),
            width: isInSuperset ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Superset label for first exercise in superset
            if (isInSuperset && supersetPosition == 'first') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: supersetColor!.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SUPERSET',
                  style: TextStyle(
                    color: supersetColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    color: AppTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cleanExerciseName(exercise.name),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                      ),
                    ),
                    if (exercise.equipment.isNotEmpty)
                      Text(
                        exercise.equipment,
                        style: TextStyle(
                          fontSize: 14,
                            color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (bestSet != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.success.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                      'Best: ${_formatWeight(bestSet.weight)} $_weightUnit × ${bestSet.reps}',
                    style: TextStyle(
                        color: AppTheme.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
            if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note,
                      color: AppTheme.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        exercise.notes!,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          if (allSets.isNotEmpty) ...[
            Text(
              'Sets (${allSets.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allSets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final set = allSets[index];
                  // Use the database isPR flag directly
                  final isActualPR = set.isPR;
                final usesPlates = _exerciseUsesPlates(exercise.equipment);
                
                // Check if plate config exists for this specific weight
                if (usesPlates) {
                  return FutureBuilder<bool>(
                      future: hasPlateConfig(exercise.name,
                          weight: set.weight, useLbs: _showWeightInLbs),
                    builder: (context, snapshot) {
                      final hasConfig = snapshot.data ?? false;
                      return _buildSetRow(set, index + 1, isActualPR, exercise, hasConfig);
                    },
                  );
                }
                return _buildSetRow(set, index + 1, isActualPR, exercise, false);
              },
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                      color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No sets for this exercise',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      ),
    );
    
    // Wrap in superset visual indicator if part of a superset
    if (isInSuperset) {
      return Padding(
        padding: EdgeInsets.only(
          bottom:
              supersetPosition == 'last' || supersetPosition == 'only' ? 16 : 2,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: supersetColor!,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: cardWidget,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: cardWidget,
    );
  }

  Widget _buildSetRow(ExerciseSet set, int setNumber, bool isActualPR, Exercise exercise, bool hasPlateConfigSaved) {
    final volume = set.weight * set.reps;
    final canShowPlates = _exerciseUsesPlates(exercise.equipment);
    final showPlateIndicator = canShowPlates && hasPlateConfigSaved;
    
    final rowContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: isActualPR
            ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1)
            : showPlateIndicator
                ? Border.all(color: AppTheme.accent.withOpacity(0.3), width: 1)
                : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                set.setType != SetType.normal
                    ? _getSetTypeDisplay(set.setType)
                    : setNumber.toString(),
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Text(
                  '${_formatWeight(set.weight)} $_weightUnit',
                  style: TextStyle(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  ' × ',
                  style: TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${set.reps} reps',
                  style: TextStyle(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                // Plate indicator for barbell exercises (only if config saved)
                if (showPlateIndicator) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 12,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${volume.toStringAsFixed(0)} $_weightUnit',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isActualPR)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PR',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    // Wrap with InkWell if plate config exists for this weight
    if (showPlateIndicator) {
      return InkWell(
        onTap: () => _showPlateViewer(exercise, set.weight),
        borderRadius: BorderRadius.circular(8),
        child: rowContent,
      );
    }

    return rowContent;
  }
}