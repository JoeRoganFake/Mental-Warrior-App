import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mental_warior/widgets/barbell_plate_calculator.dart';
import 'package:mental_warior/utils/app_theme.dart';

// Helper class to represent exercise history entries
class ExerciseHistoryEntry {
  final String workoutName;
  final String date;
  final List<ExerciseSet> sets;
  final String? notes; // Add notes field

  ExerciseHistoryEntry({
    required this.workoutName,
    required this.date,
    required this.sets,
    this.notes,
  });
}

class ExerciseDetailPage extends StatefulWidget {
  final String exerciseId; // API ID

  const ExerciseDetailPage({Key? key, required this.exerciseId})
      : super(key: key);

  @override
  _ExerciseDetailPageState createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage>
    with SingleTickerProviderStateMixin {
  final ExerciseStickyNoteService _stickyNoteService =
      ExerciseStickyNoteService();
  Map<String, dynamic>? _exercise;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  List<dynamic>? _exercisesList;
  bool _didInitialLoad = false;
  late TabController _tabController;
  List<ExerciseHistoryEntry> _exerciseHistory = [];
  bool _isLoadingHistory = false;
  String? _stickyNote;
  bool _showWeightInLbs = false;
  String get _weightUnit => _showWeightInLbs ? 'lbs' : 'kg';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Just load the JSON data in initState, but don't try to access any context
    _exercisesList = json.decode(exercisesJson) as List<dynamic>;
    
    // Load weight unit setting
    _loadWeightUnit();
    
    // Add listener to reload history when switching to History, Charts, or Records tab
    _tabController.addListener(() {
      if (_tabController.index == 1 ||
          _tabController.index == 2 ||
          _tabController.index == 3) {
        // Reload history when viewing History (index 1), Charts (index 2), or Records (index 3) tab
        _loadExerciseHistory();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWeightUnit() async {
    final useLbs = await SettingsService().getShowWeightInLbs();
    if (mounted) {
      setState(() => _showWeightInLbs = useLbs);
    }
  }

  // Helper method to check if an exercise uses plates (barbell, ez-curl bar, trap bar, smith machine)
  bool _exerciseUsesPlates(String? equipment) {
    if (equipment == null) return false;
    final lowerEquipment = equipment.toLowerCase();
    return lowerEquipment.contains('barbell') ||
        lowerEquipment.contains('e-z curl') ||
        lowerEquipment.contains('ez curl') ||
        lowerEquipment.contains('trap bar') ||
        lowerEquipment.contains('smith') ||
        lowerEquipment.contains('dumbbell');
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

  // Helper method to get set type label

  // Show plate viewer for a specific weight
  Future<void> _showPlateViewer(double weight) async {
    if (_exercise == null) return;
    final exerciseName = _exercise!['name']?.toString() ?? '';
    if (exerciseName.isEmpty) return;

    await showBarbellPlateViewer(
      context: context,
      exerciseName: exerciseName,
      useLbs: _showWeightInLbs,
      weight: weight,
    );
  }

  // Helper method to find exercises by name
  void _tryFindExerciseByName(List<dynamic> list, String nameToFind) {
    // First, try exact matches
    for (var e in list.cast<Map<String, dynamic>>()) {
      final String? name = e['name'] as String?;
      if (name != null && name.toLowerCase() == nameToFind.toLowerCase()) {
        _exercise = e;
        return;
      }
    }

    // If no exact match, try contains
    for (var e in list.cast<Map<String, dynamic>>()) {
      final String? name = e['name'] as String?;
      if (name != null &&
          (nameToFind.toLowerCase().contains(name.toLowerCase()) ||
              name.toLowerCase().contains(nameToFind.toLowerCase()))) {
        _exercise = e;
        return;
      }
    }

    // If still not found, try removing any API ID markers from the name
    final nameWithoutApiId =
        nameToFind.replaceAll(RegExp(r'##API_ID:[^#]+##'), '').trim();
    if (nameWithoutApiId != nameToFind) {
      _tryFindExerciseByName(list, nameWithoutApiId);
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Log the route arguments for debugging
    final Map<String, dynamic>? args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    print('Route arguments in didChangeDependencies:');
    if (args != null) {
      print('  exerciseName: ${args['exerciseName']}');
      print('  exerciseEquipment: ${args['exerciseEquipment']}');
      print('  isTemporary: ${args['isTemporary']}');
    } else {
      print('  No route arguments available');
    }
    
    // Only process once when dependencies are first available
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      // Load exercise data first (includes sticky note)
      _loadExerciseData().then((_) {
        // Then load history after exercise data is ready
        _loadExerciseHistory();
      });
    }
  }
  
  Future<void> _loadExerciseData() async {
    if (_exercisesList == null) return;
    
    final List<dynamic> list = _exercisesList!;
    try {
      final String currentExerciseId =
          widget.exerciseId.trim(); // Trim passed ID
      
      // Check if we have explicit information about whether this is a temporary exercise
      final Map<String, dynamic>? args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      final bool isTemporaryFromArgs = args != null &&
          args.containsKey('isTemporary') &&
          args['isTemporary'] == true;

      // Also check ID format as a backup detection method
      bool isNegativeId = false;
      try {
        final int idAsInt = int.parse(currentExerciseId);
        isNegativeId = idAsInt < 0;
      } catch (e) {
        // Not a valid integer, so not a negative ID
        isNegativeId = false;
      }
      
      // Use both sources of information
      final bool isTemporary = isTemporaryFromArgs || isNegativeId;
      
      print('🎯 Loading exercise: ID="$currentExerciseId", Temp=$isTemporary');
      
      // Strategy 1: If we have route arguments with exercise name, try that first
      if (args != null && args.containsKey('exerciseName')) {
        final String exerciseName = args['exerciseName'] as String;
        print('  Strategy 1: Searching by name "$exerciseName"');
        _tryFindExerciseByName(list, exerciseName);
        
        if (_exercise != null && _exercise!.isNotEmpty) {
          print('  ✅ Found by name: ${_exercise!['name']}');
          return; // Success, exit early
        }
      }
      
      // Strategy 2: Try to find by API ID if the exercise ID looks like an API ID
      if (!isTemporary &&
          currentExerciseId.isNotEmpty &&
          !currentExerciseId.contains('##API_ID:')) {
        print('  Strategy 2: Searching by API ID "$currentExerciseId"');
        _exercise = list.cast<Map<String, dynamic>>().firstWhere(
          (e) {
            final String? idFromData = e['id'] as String?;
            return idFromData != null && idFromData.trim() == currentExerciseId;
          },
          orElse: () => <String, dynamic>{},
        );

        if (_exercise != null && _exercise!.isNotEmpty) {
          print('  ✅ Found by API ID: ${_exercise!['name']}');
          return; // Success, exit early
        }
      }

      // Strategy 3: Handle exercises with API ID markers in the exercise ID
      if (currentExerciseId.contains('##API_ID:')) {
        print('  Strategy 3: Extracting API ID from markers');
        final RegExp apiIdRegex = RegExp(r'##API_ID:([^#]+)##');
        final Match? match = apiIdRegex.firstMatch(currentExerciseId);
        final String extractedApiId =
            match?.group(1)?.trim() ?? currentExerciseId;

        print('  Extracted API ID: "$extractedApiId"');

        // Try to find exercise with the extracted API ID
        _exercise = list.cast<Map<String, dynamic>>().firstWhere(
          (e) {
            final String? idFromData = e['id'] as String?;
            return idFromData != null && idFromData.trim() == extractedApiId;
          },
          orElse: () => <String, dynamic>{},
        );

        if (_exercise != null && _exercise!.isNotEmpty) {
          print('  ✅ Found by extracted API ID: ${_exercise!['name']}');
          return; // Success, exit early
        }
      }

      // Strategy 4: Special handling for temporary exercises
      if (isTemporary) {
        print('  Strategy 4: Handling temporary exercise');

        if (args != null &&
            args.containsKey('exerciseEquipment') &&
            args['exerciseEquipment'] != null &&
            args['exerciseEquipment'].toString().isNotEmpty) {
          final String equipment = args['exerciseEquipment'] as String;
          print('  Searching by equipment: "$equipment"');
          
          // Find first exercise with matching equipment
          for (var e in list.cast<Map<String, dynamic>>()) {
            if (e['equipment'] != null &&
                (e['equipment'] as String).toLowerCase() ==
                    equipment.toLowerCase()) {
              _exercise = e;
              print('  ✅ Found by equipment: ${_exercise!['name']}');
              return;
            }
          }
        }
        
        // Use a default exercise as fallback for temporary exercises
        print('  Using default fallback for temporary exercise');
        _exercise = list.cast<Map<String, dynamic>>().firstWhere(
            (e) =>
                e['name'] != null &&
                (e['name'] as String).toLowerCase().contains('push-up'), 
          orElse: () => list.cast<Map<String, dynamic>>().first
        );
        
        if (_exercise != null && _exercise!.isNotEmpty) {
          print('  ✅ Using fallback: ${_exercise!['name']}');
          return;
        }
      }

      // Strategy 5: Final fallback - try name-based lookup with the current exercise ID
      print('  Strategy 5: Final name-based lookup');
      _tryFindExerciseByName(list, currentExerciseId);
      
      if (_exercise != null && _exercise!.isNotEmpty) {
        print('  ✅ Found by final lookup: ${_exercise!['name']}');
      } else {
        print('  ❌ All strategies failed');

        // Absolute final fallback - use the first available exercise to prevent crashes
        if (list.isNotEmpty) {
          _exercise = list.cast<Map<String, dynamic>>().first;
          print('  🆘 Using first available exercise: ${_exercise!['name']}');
        }
      }
      
      if (_exercise != null && _exercise!.isEmpty) {
        _exercise = null; // if the map is empty (exercise not found), set to null
      }
      
      // Load sticky note if exercise is found (before setState to avoid delay)
      if (_exercise != null && _exercise!['name'] != null) {
        final stickyNote = await _stickyNoteService
            .getStickyNote(_exercise!['name'] as String);
        _stickyNote = stickyNote;
        print('📌 Sticky note loaded: ${stickyNote ?? "(none)"}');
      }

      // Update state once with both exercise and sticky note
      if (mounted) {
        setState(() {
          // State updated
        });
      }
    } catch (e) {
      print('❌ Error loading exercise "${widget.exerciseId}": $e');
      // Emergency fallback - use the first exercise to prevent crashes
      if (_exercisesList != null && _exercisesList!.isNotEmpty) {
        _exercise = _exercisesList!.cast<Map<String, dynamic>>().first;
        print('🆘 Using first exercise due to error: ${_exercise!['name']}');
      } else {
        _exercise = null;
      }
    }
  }
  
  // Load exercise history from database
  Future<void> _loadExerciseHistory() async {
    if (_exercise == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final workoutService = WorkoutService();
      final workouts = await workoutService.getWorkouts();

      // Get the clean exercise name without API ID markers
      final String exerciseName = _exercise!['name']
          .toString()
          .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
          .trim();

      List<ExerciseHistoryEntry> history = [];

      for (final workout in workouts) {
        for (final exercise in workout.exercises) {
          // Check if this exercise matches our target exercise name
          final String cleanExerciseName =
              exercise.name.replaceAll(RegExp(r'##API_ID:[^#]+##'), '').trim();

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
                sets: exercise.sets, // Include all sets from finished workouts
                notes: exercise.notes, // Include notes
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
    // Display exercise details from local JSON
    final exercise = _exercise;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF26272B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
            // Remove API ID marker if present
            exercise?['name'] != null
                ? exercise!['name']
                    .toString()
                    .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
                    .trim()
              : 'Exercise Details',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: exercise != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'ABOUT'),
                  Tab(text: 'HISTORY'),
                  Tab(text: 'CHARTS'),
                  Tab(text: 'RECORDS'),
                ],
              )
            : null,
      ),
      body: exercise == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Exercise not found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This might be a custom or temporary exercise',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Exercise ID: ${widget.exerciseId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(exercise),
                _buildHistoryTab(),
                _buildChartsTab(),
                _buildRecordsTab(),
              ],
            ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> exercise) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((exercise['images'] as List?)?.isNotEmpty ?? false)
            Column(
              children: [
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF1A1B1E),
                    border: Border.all(
                      color: Colors.grey[800]!,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: (exercise['images'] as List).length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final String imagePath =
                            (exercise['images'] as List)[index];
                        return Container(
                          color: const Color(0xFF1A1B1E),
                          child: Image.network(
                            'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$imagePath',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF3F8EFC),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  'Error loading image: $error for $imagePath');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 48, color: Colors.red[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Unable to load image',
                                      style: TextStyle(
                                        color: Colors.red[400],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          // Force a rebuild
                                        });
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3F8EFC),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if ((exercise['images'] as List).length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        (exercise['images'] as List).length,
                        (index) => Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentImageIndex
                                ? const Color(0xFF3F8EFC)
                                : Colors.grey[700],
                            boxShadow: index == _currentImageIndex
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF3F8EFC)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          // Sticky Note Section
          if (_stickyNote != null && _stickyNote!.isNotEmpty)
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withValues(alpha: 0.15),
                        Colors.amber.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.push_pin,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Sticky Note',
                            style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _stickyNote!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          // Primary Muscles with card styling
          _buildInfoCard(
            icon: Icons.fitness_center,
            title: 'Primary Muscles',
            content: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var muscle in (exercise['primaryMuscles'] as List? ?? []))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          muscle,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
          if ((exercise['secondaryMuscles'] as List?)?.isNotEmpty ?? false)
            _buildInfoCard(
              icon: Icons.fitness_center_outlined,
              title: 'Secondary Muscles',
              content: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var muscle in (exercise['secondaryMuscles'] as List))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center_outlined,
                            size: 16,
                            color: Colors.orange[300],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            muscle,
                            style: TextStyle(
                              color: Colors.orange[300],
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
          const SizedBox(height: 16),
          // Additional Exercise Information
          _buildInfoCard(
            icon: Icons.category,
            title: 'Equipment & Details',
            content: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                // Mechanic Chip
                if (exercise['mechanic'] != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.engineering,
                          size: 16,
                          color: Colors.purple[300],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          exercise['mechanic'],
                          style: TextStyle(
                            color: Colors.purple[300],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Equipment Chip
                if (exercise['equipment'] != null &&
                    exercise['equipment'] != '')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_gymnastics,
                          size: 16,
                          color: Colors.green[300],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          exercise['equipment'],
                          style: TextStyle(
                            color: Colors.green[300],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Force Chip
                if (exercise['force'] != null && exercise['force'] != '')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.amber[300],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          exercise['force'],
                          style: TextStyle(
                            color: Colors.amber[300],
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
          const SizedBox(height: 24),
          // Instructions
          _buildInfoCard(
            icon: Icons.list_alt,
            title: 'Instructions',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List<String>.from(exercise['instructions'] ?? [])
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
                              step,
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
                color: Color(0xFFBDBDBD),
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
                      const Color(0xFF3F8EFC).withValues(alpha: 0.1),
                      const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.history,
                  size: 64,
                  color: Colors.grey[500],
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
                      const Color(0xFF3F8EFC).withValues(alpha: 0.1),
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
                Color(0xFF1E1E1E),
                Color(0xFF1A1A1A),
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
                color: Colors.black.withValues(alpha: 0.3),
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
                            const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                            const Color(0xFF3F8EFC).withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3F8EFC).withValues(alpha: 0.3),
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
                        Colors.grey[800]!,
                        Colors.grey[800]!.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Display notes if available
                if (historyEntry.notes != null &&
                    historyEntry.notes!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F8EFC).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3F8EFC).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.note,
                          color: Color(0xFF3F8EFC),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            historyEntry.notes!,
                            style: const TextStyle(
                              color: Colors.white,
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

                // Sets information with improved design
                ...historyEntry.sets.asMap().entries.map((entry) {
                  final setIndex = entry.key;
                  final set = entry.value;
                  final oneRM = _calculateOneRM(set.weight, set.reps);
                  final equipment = _exercise?['equipment']?.toString();
                  final usesPlates = _exerciseUsesPlates(equipment);
                  final exerciseName = _exercise?['name']?.toString() ?? '';

                  return FutureBuilder<bool>(
                    future: usesPlates
                        ? hasPlateConfig(exerciseName,
                            weight: set.weight, useLbs: _showWeightInLbs)
                        : Future.value(false),
                    builder: (context, snapshot) {
                      final hasConfig = snapshot.data ?? false;
                      
                      return GestureDetector(
                        onTap: hasConfig ? () => _showPlateViewer(set.weight) : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey[850]!.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasConfig 
                                  ? const Color(0xFF3F8EFC).withValues(alpha: 0.4)
                                  : Colors.grey[800]!,
                              width: hasConfig ? 1.5 : 1,
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
                                      const Color(0xFF3F8EFC).withValues(alpha: 0.2),
                                      const Color(0xFF3F8EFC).withValues(alpha: 0.1),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF3F8EFC)
                                        .withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                          child: Center(
                            child: Text(
                                    set.setType != SetType.normal
                                        ? _getSetTypeDisplay(set.setType)
                                        : '${setIndex + 1}',
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
                                '${set.weight} $_weightUnit',
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
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '1RM',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[300],
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '$oneRM $_weightUnit',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green[300],
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Plate view indicator (only if config exists)
                        if (hasConfig) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3F8EFC).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF3F8EFC).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              size: 16,
                              color: Color(0xFF3F8EFC),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartsTab() {
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
              'Loading exercise data...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFBDBDBD),
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
                      const Color(0xFF3F8EFC).withValues(alpha: 0.1),
                      const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.bar_chart,
                  size: 64,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Data Available',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete and save workouts with this exercise to see your progress charts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Prepare chart data
    Map<String, List<FlSpot>> chartData = _prepareChartData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildChartCard(
            title: 'Best Set (Est. 1RM)',
            data: chartData['oneRM']!,
            color: const Color(0xFF3F8EFC),
            unit: _weightUnit,
          ),
          const SizedBox(height: 20),
          _buildChartCard(
            title: 'Best Set (Max Weight)',
            data: chartData['maxWeight']!,
            color: const Color(0xFFFF6B6B),
            unit: _weightUnit,
          ),
          const SizedBox(height: 20),
          _buildChartCard(
            title: 'Total Volume',
            data: chartData['totalVolume']!,
            color: const Color(0xFF4ECDC4),
            unit: _weightUnit,
          ),
          const SizedBox(height: 20),
          _buildChartCard(
            title: 'Best Set (Reps)',
            data: chartData['maxReps']!,
            color: const Color(0xFFFFE66D),
            unit: 'reps',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Map<String, List<FlSpot>> _prepareChartData() {
    List<FlSpot> oneRMData = [];
    List<FlSpot> maxWeightData = [];
    List<FlSpot> totalVolumeData = [];
    List<FlSpot> maxRepsData = [];

    for (int i = 0; i < _exerciseHistory.length; i++) {
      final historyEntry = _exerciseHistory[i];

      // Calculate metrics for this workout
      double bestOneRM = 0;
      double bestWeight = 0;
      int bestReps = 0;
      double totalVolume = 0;

      for (var set in historyEntry.sets) {
        // Calculate 1RM
        double oneRM = _calculateOneRM(set.weight, set.reps).toDouble();
        if (oneRM > bestOneRM) bestOneRM = oneRM;

        // Max weight
        if (set.weight > bestWeight) bestWeight = set.weight;

        // Max reps
        if (set.reps > bestReps) bestReps = set.reps;

        // Total volume
        totalVolume += set.weight * set.reps;
      }

      // Add data points (x = index, y = value)
      // We reverse the index so most recent is on the right
      double x = (_exerciseHistory.length - 1 - i).toDouble();
      oneRMData.add(FlSpot(x, bestOneRM));
      maxWeightData.add(FlSpot(x, bestWeight));
      totalVolumeData.add(FlSpot(x, totalVolume));
      maxRepsData.add(FlSpot(x, bestReps.toDouble()));
    }

    return {
      'oneRM': oneRMData,
      'maxWeight': maxWeightData,
      'totalVolume': totalVolumeData,
      'maxReps': maxRepsData,
    };
  }

  Widget _buildChartCard({
    required String title,
    required List<FlSpot> data,
    required Color color,
    required String unit,
  }) {
    // Find min and max values for better chart scaling
    double minY = data.isEmpty
        ? 0
        : data.map((spot) => spot.y).reduce((a, b) => a < b ? a : b);
    double maxY = data.isEmpty
        ? 100
        : data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    // Add some padding to the y-axis
    double yPadding = (maxY - minY) * 0.1;
    if (yPadding == 0) yPadding = 10;
    minY = (minY - yPadding).clamp(0, double.infinity);
    maxY = maxY + yPadding;

    return Container(
      padding: const EdgeInsets.all(20),
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
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (data.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b).toStringAsFixed(unit == 'reps' ? 0 : 1)} $unit',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: data.isEmpty
                ? Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: data,
                          isCurved: true,
                          color: color,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: color,
                                strokeWidth: 2,
                                strokeColor: const Color(0xFF26272B),
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            interval: (maxY - minY) / 4,
                            getTitlesWidget: (value, meta) {
                              // Format large numbers with K suffix
                              String label;
                              if (value >= 1000) {
                                label = '${(value / 1000).toStringAsFixed(1)}K';
                              } else {
                                label = value.toStringAsFixed(0);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              int index =
                                  (_exerciseHistory.length - 1 - value.toInt());
                              if (index < 0 ||
                                  index >= _exerciseHistory.length) {
                                return const Text('');
                              }

                              // Show fewer labels if there are many data points
                              if (_exerciseHistory.length > 10) {
                                // Only show every nth label
                                int step = (_exerciseHistory.length / 5).ceil();
                                if (value.toInt() % step != 0 &&
                                    value.toInt() != 0 &&
                                    value.toInt() !=
                                        _exerciseHistory.length - 1) {
                                  return const Text('');
                                }
                              }

                              final date =
                                  DateTime.parse(_exerciseHistory[index].date);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${date.month}/${date.day}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY - minY) / 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[800]!.withValues(alpha: 0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey[800]!.withValues(alpha: 0.5),
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: Colors.grey[800]!.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) =>
                              color.withValues(alpha: 0.9),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toStringAsFixed(unit == 'reps' ? 0 : 1)} $unit',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
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

  Widget _buildRecordsTab() {
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
              'Loading records...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFBDBDBD),
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
                      const Color(0xFF3F8EFC).withValues(alpha: 0.1),
                      const Color(0xFF3F8EFC).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Records Yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete and save workouts with this exercise to track your personal records.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate personal records
    double maxVolumeAdded = 0;
    int maxReps = 0;
    double maxWeightAdded = 0;
    int totalReps = 0;
    double totalWeightAdded = 0;
    int bestOneRM = 0;
    double prWeight = 0;
    int prReps = 0;

    for (var historyEntry in _exerciseHistory) {
      double sessionVolume = 0;
      for (var set in historyEntry.sets) {
        sessionVolume += set.weight * set.reps;
        totalWeightAdded += set.weight * set.reps;
        totalReps += set.reps;

        if (set.reps > maxReps) {
          maxReps = set.reps;
        }
        if (set.weight > maxWeightAdded) {
          maxWeightAdded = set.weight;
        }
        
        // Calculate 1RM for PR tracking
        int oneRM = _calculateOneRM(set.weight, set.reps);
        if (oneRM > bestOneRM) {
          bestOneRM = oneRM;
          prWeight = set.weight;
          prReps = set.reps;
        }
      }
      if (sessionVolume > maxVolumeAdded) {
        maxVolumeAdded = sessionVolume;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current PR Section (Featured)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF9500).withValues(alpha: 0.15),
                  const Color(0xFFFF9500).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Color(0xFFFF9500),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CURRENT PR',
                      style: TextStyle(
                        color: Color(0xFFFF9500),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$bestOneRM',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _weightUnit,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Est. 1RM',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    prWeight > 0
                        ? '${prWeight.toStringAsFixed(prWeight.truncateToDouble() == prWeight ? 0 : 1)} $_weightUnit × $prReps reps'
                        : '$prReps reps',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Personal Records Section
          Container(
            padding: const EdgeInsets.all(20),
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
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PERSONAL RECORDS',
                      style: TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRecordItem(
                  'Max volume added',
                  '+${maxVolumeAdded.round()} kg',
                ),
                const SizedBox(height: 16),
                _buildRecordItem(
                  'Max reps',
                  '$maxReps kg',
                ),
                const SizedBox(height: 16),
                _buildRecordItem(
                  'Max weight added',
                  '+${maxWeightAdded.round()} kg',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Lifetime Stats Section
          Container(
            padding: const EdgeInsets.all(20),
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
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F8EFC),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'LIFETIME STATS',
                      style: TextStyle(
                        color: Color(0xFFBDBDBD),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildRecordItem(
                  'Total reps',
                  '$totalReps reps',
                ),
                const SizedBox(height: 16),
                _buildRecordItem(
                  'Total weight added',
                  '+${totalWeightAdded.round()} kg',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
