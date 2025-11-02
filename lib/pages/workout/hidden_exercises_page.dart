import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';

class HiddenExercisesPage extends StatefulWidget {
  const HiddenExercisesPage({Key? key}) : super(key: key);

  @override
  _HiddenExercisesPageState createState() => _HiddenExercisesPageState();
}

class _HiddenExercisesPageState extends State<HiddenExercisesPage> {
  final CustomExerciseService _customExerciseService = CustomExerciseService();
  List<Map<String, dynamic>> _hiddenExercises = [];
  bool _isLoading = true;

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _cardColor = const Color(0xFF303136);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);

  @override
  void initState() {
    super.initState();
    _loadHiddenExercises();
  }

  Future<void> _loadHiddenExercises() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final exercises = await _customExerciseService.getHiddenCustomExercises();
      setState(() {
        _hiddenExercises = exercises;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading hidden exercises: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unhideExercise(int exerciseId, String exerciseName) async {
    try {
      await _customExerciseService.unhideCustomExercise(exerciseId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$exerciseName" restored to search'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Reload the list
      await _loadHiddenExercises();
    } catch (e) {
      print('Error unhiding exercise: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring exercise: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewExerciseDetails(Map<String, dynamic> exercise) {
    final String exerciseId = exercise['apiId'] ?? 'custom_${exercise['id']}';
    final String exerciseName = exercise['name'] ?? '';
    final String exerciseEquipment = exercise['equipment'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomExerciseDetailPage(
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          exerciseEquipment: exerciseEquipment,
        ),
      ),
    ).then((_) {
      // Reload when returning from detail page
      _loadHiddenExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Hidden Exercises',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _surfaceColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            )
          : _hiddenExercises.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHiddenExercises,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _hiddenExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _hiddenExercises[index];
                      return _buildExerciseCard(exercise);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.2),
                    Colors.orange.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: const Icon(
                Icons.visibility_off,
                size: 64,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Hidden Exercises',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimaryColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Exercises you hide from search will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _textSecondaryColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withValues(alpha: 0.15),
                    _primaryColor.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Hidden exercises remain in workout history',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final String name = exercise['name'] ?? 'Unknown';
    final String equipment = exercise['equipment'] ?? 'None';
    final String muscleGroup = exercise['type'] ?? 'Unknown';
    final int exerciseId = exercise['id'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _cardColor,
            _surfaceColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _viewExerciseDetails(exercise),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Exercise icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withValues(alpha: 0.3),
                        Colors.orange.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.visibility_off,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Exercise info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 14,
                            color: _textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            muscleGroup,
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.sports_gymnastics,
                            size: 14,
                            color: _textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            equipment,
                            style: TextStyle(
                              fontSize: 14,
                              color: _textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Unhide button
                IconButton(
                  icon: const Icon(
                    Icons.visibility,
                    color: Colors.green,
                  ),
                  tooltip: 'Restore to search',
                  onPressed: () => _unhideExercise(exerciseId, name),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
