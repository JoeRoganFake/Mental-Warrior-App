import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/workout_edit_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadWorkout();
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
      final validSets =
          exercise.sets.where((set) => set.weight > 0 && set.reps > 0).toList();

      if (validSets.isNotEmpty) {
        // Find the maximum volume among all sets in this exercise
        double maxVolume = validSets
            .map((set) => set.weight * set.reps)
            .reduce((a, b) => a > b ? a : b);

        // Check if any set is marked as PR in database with max volume
        bool hasDatabasePRWithMaxVolume = validSets
            .any((set) => set.isPR && (set.weight * set.reps) == maxVolume);

        if (hasDatabasePRWithMaxVolume) {
          // If there's a database PR with max volume, only count those
          for (final set in validSets) {
            final volume = set.weight * set.reps;
            if (set.isPR && volume == maxVolume) {
              totalPRs++;
            }
          }
        } else {
          // If no database PR has max volume, count all sets with max volume as PRs
          // This handles newly added sets that should be PRs but haven't been flagged yet
          for (final set in validSets) {
            final volume = set.weight * set.reps;
            if (volume == maxVolume) {
              totalPRs++;
            }
          }
        }
      }
    }
    return totalPRs;
  }

  void _editWorkout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutEditPage(
          key: ValueKey(
              'edit_${widget.workoutId}_${DateTime.now().millisecondsSinceEpoch}'),
          workoutId: widget.workoutId,
        ),
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
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
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
                        color: _textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Workout not found',
                        style: TextStyle(
                          fontSize: 20,
                          color: _textPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The workout you\'re looking for doesn\'t exist.',
                        style: TextStyle(
                          fontSize: 16,
                          color: _textSecondaryColor,
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
      backgroundColor: _surfaceColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _textPrimaryColor),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh, color: _textPrimaryColor),
          onPressed: _loadWorkout,
        ),
        IconButton(
          icon: Icon(Icons.edit, color: _textPrimaryColor),
          onPressed: _editWorkout,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _workout!.name,
          style: TextStyle(
            color: _textPrimaryColor,
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
                _primaryColor.withOpacity(0.8),
                _accentColor.withOpacity(0.6),
                _surfaceColor,
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
                    color: _textPrimaryColor.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _textPrimaryColor.withOpacity(0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_workout!.duration),
                      style: TextStyle(
                        color: _textPrimaryColor.withOpacity(0.9),
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withOpacity(0.2),
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
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.repeat,
                  label: 'Sets',
                  value: totalSets.toString(),
                  color: _accentColor,
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
                  value: '${totalVolume.toStringAsFixed(0)} kg',
                  color: _successColor,
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
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExercisesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exercises',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _workout!.exercises.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final exercise = _workout!.exercises[index];
            return _buildExerciseCard(exercise);
          },
        ),
      ],
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    final allSets = exercise.sets.toList(); // Show all sets
    final validSets = exercise.sets
        .where((set) => set.weight > 0 && set.reps > 0)
        .toList(); // For calculations only
    final bestSet = validSets.isNotEmpty
        ? validSets
            .reduce((a, b) => 
            (a.weight * a.reps) > (b.weight * b.reps) ? a : b)
        : null;

    // Calculate which sets are actually PRs based on volume and database flags
    Set<int> actualPRSetIds = {};
    if (validSets.isNotEmpty) {
      // Find the maximum volume among all sets in this exercise
      double maxVolume = validSets
          .map((set) => set.weight * set.reps)
          .reduce((a, b) => a > b ? a : b);

      // Check if any set is marked as PR in database with max volume
      bool hasDatabasePRWithMaxVolume = validSets
          .any((set) => set.isPR && (set.weight * set.reps) == maxVolume);

      if (hasDatabasePRWithMaxVolume) {
        // If there's a database PR with max volume, only show those
        for (final set in validSets) {
          final volume = set.weight * set.reps;
          if (set.isPR && volume == maxVolume) {
            actualPRSetIds.add(set.id);
          }
        }
      } else {
        // If no database PR has max volume, show all sets with max volume as PRs
        // This handles newly added sets that should be PRs but haven't been flagged yet
        for (final set in validSets) {
          final volume = set.weight * set.reps;
          if (volume == maxVolume) {
            actualPRSetIds.add(set.id);
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _textSecondaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                    if (exercise.equipment.isNotEmpty)
                      Text(
                        exercise.equipment,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondaryColor,
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
                    color: _successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _successColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Best: ${_formatWeight(bestSet.weight)} kg × ${bestSet.reps}',
                    style: TextStyle(
                      color: _successColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (allSets.isNotEmpty) ...[
            Text(
              'Sets (${allSets.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimaryColor,
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
                final isActualPR = actualPRSetIds.contains(set.id);
                return _buildSetRow(set, index + 1, isActualPR);
              },
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _textSecondaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _textSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No sets for this exercise',
                    style: TextStyle(
                      color: _textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetRow(ExerciseSet set, int setNumber, bool isActualPR) {
    final volume = set.weight * set.reps;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: isActualPR
            ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1)
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
                setNumber.toString(),
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
                  '${_formatWeight(set.weight)} kg',
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
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${volume.toStringAsFixed(0)} kg',
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
  }
}