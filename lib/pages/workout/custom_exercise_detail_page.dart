import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';

class CustomExerciseDetailPage extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String exerciseEquipment;

  const CustomExerciseDetailPage({
    Key? key,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseEquipment,
  }) : super(key: key);

  @override
  _CustomExerciseDetailPageState createState() => _CustomExerciseDetailPageState();
}

class _CustomExerciseDetailPageState extends State<CustomExerciseDetailPage> {
  // Theme colors consistent with the app
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);
  
  Map<String, dynamic>? _exerciseData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    try {
      print('🔍 Loading custom exercise data for ID: ${widget.exerciseId}');
      final customExerciseService = CustomExerciseService();
      final exercises = await customExerciseService.getCustomExercises();
      
      print('📦 Retrieved ${exercises.length} custom exercises from database');
      
      // Debug: Print all exercise IDs
      for (var ex in exercises) {
        print('  - Exercise ID: ${ex['id']}, Name: ${ex['name']}, ApiId: ${ex['apiId']}');
      }
      
      // Extract the numeric ID from custom_X format if present
      String searchId = widget.exerciseId;
      if (searchId.startsWith('custom_')) {
        searchId = searchId.replaceFirst('custom_', '');
        print('  Extracted numeric ID from custom marker: $searchId');
      }
      
      // Find the exercise with matching ID
      // Try multiple comparison strategies
      final exercise = exercises.firstWhere(
        (e) {
          final eId = e['id'];
          final eApiId = e['apiId'];
          
          // Strategy 1: Compare with original widget ID (might be custom_X)
          if (eApiId.toString() == widget.exerciseId) {
            print('  ✓ Matched by apiId: ${widget.exerciseId}');
            return true;
          }
          
          // Strategy 2: Compare with extracted numeric ID
          if (eId.toString() == searchId) {
            print('  ✓ Matched by numeric ID: $searchId');
            return true;
          }
          
          // Strategy 3: Try int comparison
          try {
            if (int.parse(eId.toString()) == int.parse(searchId)) {
              print('  ✓ Matched by int comparison');
              return true;
            }
          } catch (e) {
            // Ignore parse errors
          }
          
          return false;
        },
        orElse: () => {},
      );
      
      if (exercise.isNotEmpty) {
        print('✅ Found exercise: ${exercise['name']}');
        print('   - Type: ${exercise['type']}');
        print('   - Equipment: ${exercise['equipment']}');
        print('   - Description: ${exercise['description']}');
        print('   - Secondary Muscles: ${exercise['secondaryMuscles']}');
      } else {
        print('❌ No exercise found with ID: ${widget.exerciseId} (searched: $searchId)');
      }
      
      setState(() {
        _exerciseData = exercise.isNotEmpty ? exercise : null;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading custom exercise: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clean the exercise name for display
    String cleanAppBarName = widget.exerciseName
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          cleanAppBarName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _surfaceColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primaryColor),
            )
          : _exerciseData == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: _textSecondaryColor),
                        const SizedBox(height: 16),
                        Text(
                          'Exercise not found',
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load exercise with ID: ${widget.exerciseId}',
                          style: TextStyle(
                            color: _textSecondaryColor,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Go Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildExerciseDetails(),
    );
  }

  Widget _buildExerciseDetails() {
    final exercise = _exerciseData!;
    
    // Clean the exercise name by removing API ID and CUSTOM markers
    String cleanName = exercise['name'] ?? widget.exerciseName;
    cleanName = cleanName
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
    
    final String type = exercise['type'] ?? 'Unknown';
    final String equipment = exercise['equipment'] ?? 'None';
    final String description = exercise['description'] ?? '';
    
    // Handle secondary muscles - they might be a List or a comma-separated string
    List<String> secondaryMuscles = [];
    final secondaryMusclesData = exercise['secondaryMuscles'];
    if (secondaryMusclesData != null) {
      if (secondaryMusclesData is List) {
        secondaryMuscles = secondaryMusclesData.cast<String>();
      } else if (secondaryMusclesData is String && secondaryMusclesData.isNotEmpty) {
        secondaryMuscles = secondaryMusclesData.split(',').map((s) => s.trim()).toList();
      }
    }
    
    // Remove empty strings
    secondaryMuscles = secondaryMuscles.where((s) => s.isNotEmpty).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Custom exercise badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primaryColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, color: _primaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Custom Exercise',
                  style: TextStyle(
                    color: _primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Exercise icon
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center,
                size: 64,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Exercise name
          Text(
            cleanName,
            style: TextStyle(
              color: _textPrimaryColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Primary Muscle/Type
          _buildInfoSection(
            'Primary Muscle',
            [
              Chip(
                avatar: Icon(Icons.fitness_center, size: 16, color: _primaryColor),
                label: Text(type),
                backgroundColor: _primaryColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Secondary Muscles
          if (secondaryMuscles.isNotEmpty) ...[
            _buildInfoSection(
              'Secondary Muscles',
              secondaryMuscles
                  .map((muscle) => Chip(
                        avatar: Icon(
                          Icons.fitness_center_outlined,
                          size: 16,
                          color: Colors.orange[700],
                        ),
                        label: Text(muscle),
                        backgroundColor: Colors.orange[100],
                        labelStyle: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Equipment
          _buildInfoSection(
            'Equipment',
            [
              Chip(
                avatar: Icon(
                  Icons.sports_gymnastics,
                  size: 16,
                  color: Colors.green[700],
                ),
                label: Text(equipment),
                backgroundColor: Colors.green[100],
                labelStyle: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Description
          if (description.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(height: 24),
            Text(
              'Description',
              style: TextStyle(
                color: _textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                description,
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: _primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Custom Exercise',
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This is a user-created exercise. You can use it in your workouts just like any other exercise.',
                  style: TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }
}