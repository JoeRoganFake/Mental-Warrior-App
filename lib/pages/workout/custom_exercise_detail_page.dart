import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/models/workouts.dart';

// Helper class to represent exercise history entries
class ExerciseHistoryEntry {
  final String workoutName;
  final String date;
  final List<ExerciseSet> sets;

  ExerciseHistoryEntry({
    required this.workoutName,
    required this.date,
    required this.sets,
  });
}

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

class _CustomExerciseDetailPageState extends State<CustomExerciseDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _exerciseData;
  bool _isLoading = true;
  late TabController _tabController;
  List<ExerciseHistoryEntry> _exerciseHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExerciseData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadExerciseData() async {
    try {
      print('🔍 Loading custom exercise data for ID: ${widget.exerciseId}');
      final customExerciseService = CustomExerciseService();
      final exercises = await customExerciseService.getCustomExercises();

      print('📦 Retrieved ${exercises.length} custom exercises from database');

      // Debug: Print all exercise IDs
      for (var ex in exercises) {
        print(
            '  - Exercise ID: ${ex['id']}, Name: ${ex['name']}, ApiId: ${ex['apiId']}');
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
        print(
            '❌ No exercise found with ID: ${widget.exerciseId} (searched: $searchId)');
      }

      setState(() {
        _exerciseData = exercise.isNotEmpty ? exercise : null;
        _isLoading = false;
      });
      
      // Load exercise history after we have the exercise data
      if (_exerciseData != null) {
        _loadExerciseHistory();
      }
    } catch (e, stackTrace) {
      print('❌ Error loading custom exercise: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load exercise history from database
  Future<void> _loadExerciseHistory() async {
    if (_exerciseData == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final workoutService = WorkoutService();
      final workouts = await workoutService.getWorkouts();

      // Get the clean exercise name without API ID markers
      String exerciseName = _exerciseData!['name']
          .toString()
          .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
          .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
          .trim();

      List<ExerciseHistoryEntry> history = [];

      for (final workout in workouts) {
        for (final exercise in workout.exercises) {
          // Check if this exercise matches our target exercise name
          String cleanExerciseName = exercise.name
              .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
              .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
              .trim();

          // Try multiple matching strategies for better compatibility
          bool isMatch = false;

          // Exact match (case insensitive)
          if (cleanExerciseName.toLowerCase() == exerciseName.toLowerCase()) {
            isMatch = true;
          }

          // Partial match (either contains the other)
          if (!isMatch &&
              (cleanExerciseName
                      .toLowerCase()
                      .contains(exerciseName.toLowerCase()) ||
                  exerciseName
                      .toLowerCase()
                      .contains(cleanExerciseName.toLowerCase()))) {
            isMatch = true;
          }

          if (isMatch) {
            // Only include exercises from finished workouts in history
            if (exercise.finished) {
              print(
                  '  ✅ Exercise is from a finished workout, adding to history');

              history.add(ExerciseHistoryEntry(
                workoutName: workout.name,
                date: workout.date,
                sets: exercise.sets,
              ));
              print('  ➕ Added to history with ${exercise.sets.length} sets');
            } else {
              print('  ⚠️ Exercise not from a finished workout, skipping');
            }
          }
        }
      }

      // Sort history by date (most recent first)
      history.sort(
          (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

      setState(() {
        _exerciseHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('❌ Error loading exercise history: $e');
      setState(() {
        _isLoadingHistory = false;
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
      backgroundColor: const Color(0xFF1A1B1E),
      appBar: AppBar(
        title: Text(
          cleanAppBarName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF26272B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: _exerciseData != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'ABOUT'),
                  Tab(text: 'HISTORY'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
          : _exerciseData == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'Exercise not found',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load exercise with ID: ${widget.exerciseId}',
                          style: TextStyle(
                            color: Colors.grey[600],
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
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAboutTab(),
                    _buildHistoryTab(),
                  ],
                ),
    );
  }

  Widget _buildAboutTab() {
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
      } else if (secondaryMusclesData is String &&
          secondaryMusclesData.isNotEmpty) {
        secondaryMuscles =
            secondaryMusclesData.split(',').map((s) => s.trim()).toList();
      }
    }

    // Remove empty strings
    secondaryMuscles = secondaryMuscles.where((s) => s.isNotEmpty).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Custom exercise badge with gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                  const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3F8EFC).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F8EFC).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.create,
                      color: Color(0xFF3F8EFC), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Custom Exercise',
                  style: TextStyle(
                    color: Color(0xFF3F8EFC),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Exercise icon with gradient background
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3F8EFC).withValues(alpha: 0.2),
                    const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fitness_center,
                size: 70,
                color: Color(0xFF3F8EFC),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Exercise name with shadow
          Text(
            cleanName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Primary Muscle with improved styling
          _buildInfoCard(
            icon: Icons.fitness_center,
            title: 'Primary Muscle',
            content: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF3F8EFC),
                        Color(0xFF5FA3FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Secondary Muscles
          if (secondaryMuscles.isNotEmpty) ...[
            _buildInfoCard(
              icon: Icons.fitness_center_outlined,
              title: 'Secondary Muscles',
              content: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: secondaryMuscles
                    .map((muscle) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange[400]!,
                                Colors.orange[600]!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.fitness_center_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                muscle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Equipment
          _buildInfoCard(
            icon: Icons.sports_gymnastics,
            title: 'Equipment',
            content: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[400]!,
                        Colors.green[600]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sports_gymnastics,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        equipment,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description/Instructions
          if (description.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildInfoCard(
              icon: Icons.list_alt,
              title: 'Instructions',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: description
                    .split('\n')
                    .where((line) => line.trim().isNotEmpty)
                    .map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 6, right: 12),
                              decoration: const BoxDecoration(
                                color: Color(0xFF3F8EFC),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                step.trim(),
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Info card with enhanced styling
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                  const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F8EFC).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF3F8EFC),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User Created',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use this in your workouts just like any other exercise.',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF26272B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: const Color(0xFF3F8EFC),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF3F8EFC),
            ),
            SizedBox(height: 20),
            Text(
              'Loading exercise history...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_exerciseHistory.isEmpty) {
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
                      const Color(0xFF3F8EFC).withValues(alpha: 0.2),
                      const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No History Found',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete and save workouts with this exercise to see your history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                      const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3F8EFC),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'History is only recorded for finished workouts.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[300],
                          fontWeight: FontWeight.w500,
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

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _exerciseHistory.length,
      itemBuilder: (context, index) {
        final historyEntry = _exerciseHistory[index];
        final DateTime date = DateTime.parse(historyEntry.date);
        final String formattedDate =
            '${_getWeekday(date.weekday)}, ${_getMonth(date.month)} ${date.day}, ${date.year}';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF26272B),
                Color(0xFF1E1F22),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey[800]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Workout name and date header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        historyEntry.workoutName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                            const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3F8EFC).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Color(0xFF3F8EFC),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3F8EFC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey[700]!,
                        Colors.grey[700]!.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sets information with improved design
                ...historyEntry.sets.asMap().entries.map((entry) {
                  final setIndex = entry.key;
                  final set = entry.value;
                  final oneRM = _calculateOneRM(set.weight, set.reps);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1B1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[800]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Set number with gradient
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                                const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF3F8EFC)
                                  .withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${setIndex + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3F8EFC),
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Weight
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weight',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${set.weight} kg',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Reps
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reps',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${set.reps}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 1RM badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green[400]!,
                                Colors.green[600]!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '1RM',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '$oneRM kg',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to calculate 1RM using Epley formula
  int _calculateOneRM(double weight, int reps) {
    if (reps == 1) return weight.round();
    return (weight * (1 + reps / 30.0)).round();
  }

  // Helper methods for date formatting
  String _getWeekday(int weekday) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}