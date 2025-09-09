import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class WorkoutCompletionPage extends StatefulWidget {
  final Workout workout;
  final int workoutNumber; // Total count of completed workouts

  const WorkoutCompletionPage({
    super.key,
    required this.workout,
    required this.workoutNumber,
  });

  @override
  _WorkoutCompletionPageState createState() => _WorkoutCompletionPageState();
}

class _WorkoutCompletionPageState extends State<WorkoutCompletionPage>
    with TickerProviderStateMixin {
  late AnimationController _starsAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _starsAnimation;
  late Animation<double> _contentAnimation;

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1A1A);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFFFF9500);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFB3B3B3);

  @override
  void initState() {
    super.initState();
    
    // Play fanfare sound
    _playFanfareSound();
    
    // Initialize animations
    _starsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _starsAnimation = CurvedAnimation(
      parent: _starsAnimationController,
      curve: Curves.elasticOut,
    );
    
    _contentAnimation = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    // Start animations
    _starsAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _starsAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  // Play fanfare sound when workout is completed
  void _playFanfareSound() async {
    // Create a new player per fanfare to allow multiple replays
    final player = AudioPlayer();
    try {
      await player.setSource(AssetSource('audio/fanfare chime.mp3'));
      await player.setReleaseMode(ReleaseMode.release);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.0); // Full volume for celebration

      // Set audio context to avoid interrupting background music
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));

      await player.resume();
      // Dispose player once playback completes
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('Error playing fanfare: $e');
      player.dispose();
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _getFormattedDate() {
    final date = DateTime.parse(widget.workout.date);
    final formatter = DateFormat('EEEE, MMMM d, y \'at\' h:mm a');
    
    return formatter.format(date);
  }

  // Calculate workout statistics
  Map<String, dynamic> _calculateWorkoutStats() {
    int totalSets = 0;
    int completedSets = 0;
    int totalPRs = 0;
    double totalWeight = 0;
    ExerciseSet? bestSet;
    double maxWeight = 0;
    
    for (var exercise in widget.workout.exercises) {
      for (var set in exercise.sets) {
        // Count all completed sets regardless of weight/reps values
        if (set.completed) {
          totalSets++;
          completedSets++;
          totalWeight += set.weight * set.reps;
          
          // Count PRs
          if (set.isPR) {
            totalPRs++;
          }
          
          // Find best set (highest weight)
          if (set.weight > maxWeight) {
            maxWeight = set.weight;
            bestSet = set;
          }
        }
      }
    }
    
    return {
      'totalSets': totalSets,
      'completedSets': completedSets,
      'totalWeight': totalWeight,
      'bestSet': bestSet,
      'maxWeight': maxWeight,
      'totalPRs': totalPRs,
    };
  }

  Widget _buildStarsRow() {
    return AnimatedBuilder(
      animation: _starsAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _starsAnimation.value,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Small stars
              Transform.rotate(
                angle: -0.2,
                child: Icon(
                  Icons.star_rate,
                  size: 20,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              
              // Large star
              Icon(
                Icons.star_rate,
                size: 35,
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              
              // Main large star
              Icon(
                Icons.star_rate,
                size: 50,
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              
              // Large star
              Icon(
                Icons.star_rate,
                size: 35,
                color: _primaryColor,
              ),
              const SizedBox(width: 8),
              
              // Small stars
              Transform.rotate(
                angle: 0.2,
                child: Icon(
                  Icons.star_rate,
                  size: 20,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkoutSummaryCard(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workout title
          Text(
            widget.workout.name,
            style: TextStyle(
              color: _textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          
          // Date and time
          Text(
            _getFormattedDate(),
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          
          // Sets and Best set headers
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sets',
                  style: TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Best set',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // List all exercises in compact format - show all exercises with completed sets
          ...widget.workout.exercises.where((exercise) {
            // Include exercises that have at least one completed set
            return exercise.sets.any((set) => set.completed);
          }).map((exercise) {
            // Count all completed sets
            final completedSets =
                exercise.sets.where((set) => set.completed)
                .length;
            
            // Find best set among completed sets (highest weight)
            final completedSetsList =
                exercise.sets.where((set) => set.completed)
                .toList();

            final bestSet = completedSetsList.isNotEmpty
                ? completedSetsList
                    .reduce((a, b) => a.weight > b.weight ? a : b)
                : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$completedSets × ${exercise.name}',
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (bestSet != null)
                    Row(
                      children: [
                        Text(
                          '${bestSet.weight.toStringAsFixed(bestSet.weight % 1 == 0 ? 0 : 1)} kg × ${bestSet.reps}',
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 16,
                          ),
                        ),
                        if (bestSet.isPR) ...[
                          const SizedBox(width: 4),
                          Text(
                            '[F]',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            );
          }).toList(),
          
          const SizedBox(height: 20),
          
          // Summary stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Duration
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: _textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(widget.workout.duration),
                    style: TextStyle(
                      color: _textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Total weight
              Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 20,
                    color: _textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(stats['totalWeight'] as double).toStringAsFixed(0)} kg',
                    style: TextStyle(
                      color: _textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // PRs
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 20,
                    color: _textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${stats['totalPRs']} PRs',
                    style: TextStyle(
                      color: _textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateWorkoutStats();
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _textPrimaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: _textPrimaryColor),
            onPressed: () {
              // TODO: Implement sharing functionality
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Stars animation
              _buildStarsRow(),
              const SizedBox(height: 24),
              
              // Congratulations text
              AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _contentAnimation.value)),
                    child: Opacity(
                      opacity: _contentAnimation.value,
                      child: Column(
                        children: [
                          Text(
                            'Congratulations!',
                            style: TextStyle(
                              color: _textPrimaryColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'That\'s workout ${widget.workoutNumber}!',
                            style: TextStyle(
                              color: _textSecondaryColor,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              
              // Workout summary card
              AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 50 * (1 - _contentAnimation.value)),
                    child: Opacity(
                      opacity: _contentAnimation.value,
                      child: _buildWorkoutSummaryCard(stats),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              
              // Continue button
              AnimatedBuilder(
                animation: _contentAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - _contentAnimation.value)),
                    child: Opacity(
                      opacity: _contentAnimation.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate back to the main workouts page by popping until we reach the root
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
