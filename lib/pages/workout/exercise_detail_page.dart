import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';
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

class ExerciseDetailPage extends StatefulWidget {
  final String exerciseId; // API ID

  const ExerciseDetailPage({Key? key, required this.exerciseId})
      : super(key: key);

  @override
  _ExerciseDetailPageState createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _exercise;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  List<dynamic>? _exercisesList;
  bool _didInitialLoad = false;
  late TabController _tabController;
  List<ExerciseHistoryEntry> _exerciseHistory = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Just load the JSON data in initState, but don't try to access any context
    _exercisesList = json.decode(exercisesJson) as List<dynamic>;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    super.dispose();
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
      _loadExerciseData();
      _loadExerciseHistory();
      _didInitialLoad = true;
    }
  }
  
  void _loadExerciseData() {
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
      
      // Special handling for temporary exercises
      if (isTemporary) {
            
        if (args != null) {
          // First try to use the exerciseName if available
          if (args.containsKey('exerciseName')) {
            final String exerciseName = args['exerciseName'] as String;
            
            // Try to find by name
            _tryFindExerciseByName(list, exerciseName);
            
            // If found by name, return early
            if (_exercise != null && !_exercise!.isEmpty) {
              return;
            }
          }
          
          // If name didn't work, try equipment as a fallback filter
          if (args.containsKey('exerciseEquipment') && 
              args['exerciseEquipment'] != null && 
              args['exerciseEquipment'].toString().isNotEmpty) {
            
            final String equipment = args['exerciseEquipment'] as String;
            
            // Find first exercise with matching equipment
            for (var e in list.cast<Map<String, dynamic>>()) {
              if (e['equipment'] != null && 
                  (e['equipment'] as String).toLowerCase() == equipment.toLowerCase()) {
                _exercise = e;
                return;
              }
            }
          }
        }
        
        // Use a default exercise as fallback
        _exercise = list.cast<Map<String, dynamic>>().firstWhere(
          (e) => e['name'] != null && (e['name'] as String).contains('Push-up'), 
          orElse: () => list.cast<Map<String, dynamic>>().first
        );
        
        return;
      } 
      // Check if the passed ID is an API ID with markers
      else if (currentExerciseId.contains('##API_ID:')) {
        // Extract the actual API ID from the marker
        final RegExp apiIdRegex = RegExp(r'##API_ID:([^#]+)##');
        final Match? match = apiIdRegex.firstMatch(currentExerciseId);
        final String extractedApiId = match?.group(1)?.trim() ?? currentExerciseId;
        
        // Try to find exercise with the extracted API ID
        _exercise = list.cast<Map<String, dynamic>>().firstWhere(
          (e) {
            final String? idFromData = e['id'] as String?;
            return idFromData != null && idFromData.trim() == extractedApiId;
          },
          orElse: () => <String, dynamic>{},
        );
      } else {
        // Normal ID lookup
        _exercise = list.cast<Map<String, dynamic>>().firstWhere(
          (e) {
            final String? idFromData = e['id'] as String?;
            // Try both direct comparison and string conversion for flexibility
            return idFromData != null && 
                (idFromData.trim() == currentExerciseId || 
                 idFromData.trim() == currentExerciseId.replaceAll('"', ''));
          },
          orElse: () => <String, dynamic>{},
        );
      }
      
      // If exercise not found, try again looking for name matches
      if (_exercise == null || _exercise!.isEmpty) {
        _tryFindExerciseByName(list, currentExerciseId);
      }
      
      if (_exercise != null && _exercise!.isEmpty) {
        _exercise = null; // if the map is empty (exercise not found), set to null
      }
    } catch (e) {
      print('❌ Error finding exercise ${widget.exerciseId}: $e');
      _exercise = null; // Catch any error during parsing or lookup
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
      appBar: AppBar(
        title: Text(
            // Remove API ID marker if present
            exercise?['name'] != null
                ? exercise!['name']
                    .toString()
                    .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
                    .trim()
                : 'Exercise Details'),
        bottom: exercise != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'ABOUT'),
                  Tab(text: 'HISTORY'),
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
              ],
            ),
    );
  }

  Widget _buildAboutTab(Map<String, dynamic> exercise) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((exercise['images'] as List?)?.isNotEmpty ?? false)
            Column(
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PageView.builder(
                      itemCount: (exercise['images'] as List).length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final String imagePath =
                            (exercise['images'] as List)[index];
                        return Image.network(
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
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $error for $imagePath');
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red),
                                  SizedBox(height: 8),
                                  Text('Unable to load image',
                                      style: TextStyle(color: Colors.red)),
                                  SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        // Force a rebuild
                                      });
                                    },
                                    icon: Icon(Icons.refresh),
                                    label: Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                if ((exercise['images'] as List).length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        (exercise['images'] as List).length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: index == _currentImageIndex
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          // Primary Muscles Chips
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Primary Muscles:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var muscle
                      in (exercise['primaryMuscles'] as List? ?? []))
                    Chip(
                      avatar: Icon(Icons.fitness_center, size: 16),
                      label: Text(muscle),
                      backgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      labelStyle:
                          TextStyle(color: Theme.of(context).primaryColor),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Secondary Muscles Chips
          if ((exercise['secondaryMuscles'] as List?)?.isNotEmpty ?? false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secondary Muscles:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (var muscle in (exercise['secondaryMuscles'] as List))
                      Chip(
                        avatar: Icon(Icons.fitness_center_outlined, size: 16),
                        label: Text(muscle),
                        backgroundColor: Colors.orange[100],
                        labelStyle: TextStyle(color: Colors.orange[800]),
                      ),
                  ],
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secondary Muscles:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text('None specified',
                    style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          const SizedBox(height: 16),
          // Additional Exercise Information
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Mechanic Chip
              if (exercise['mechanic'] != null)
                Chip(
                  avatar: Icon(Icons.engineering, size: 16),
                  label: Text(exercise['mechanic']),
                  backgroundColor: Colors.purple[100],
                  labelStyle: TextStyle(color: Colors.purple[800]),
                ),
              // Equipment Chip
              if (exercise['equipment'] != null && exercise['equipment'] != '')
                Chip(
                  avatar: Icon(Icons.sports_gymnastics, size: 16),
                  label: Text(exercise['equipment']),
                  backgroundColor: Colors.green[100],
                  labelStyle: TextStyle(color: Colors.green[800]),
                ),
              // Force Chip
              if (exercise['force'] != null && exercise['force'] != '')
                Chip(
                  avatar: Icon(Icons.arrow_forward, size: 16),
                  label: Text(exercise['force']),
                  backgroundColor: Colors.amber[100],
                  labelStyle: TextStyle(color: Colors.amber[800]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 24),
          const Text(
            'Instructions:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...List<String>.from(exercise['instructions'] ?? []).map(
            // Use original key 'instructions'
            (step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text('• $step', style: const TextStyle(fontSize: 14)),
            ),
          ),
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
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading exercise history...'),
          ],
        ),
      );
    }

    if (_exerciseHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No History Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete and save workouts with this exercise to see your history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'History shows only completed workouts that were saved using "End & Save".',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exerciseHistory.length,
      itemBuilder: (context, index) {
        final historyEntry = _exerciseHistory[index];
        final DateTime date = DateTime.parse(historyEntry.date);
        final String formattedDate =
            '${_getWeekday(date.weekday)}, ${_getMonth(date.month)} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with workout name and date
                Text(
                  historyEntry.workoutName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),

                // Sets performed header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sets Performed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '1RM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Sets data
                ...historyEntry.sets.asMap().entries.map((entry) {
                  final setIndex = entry.key;
                  final set = entry.value;
                  final oneRM = _calculateOneRM(set.weight, set.reps);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${setIndex + 1}  ${set.weight}kg × ${set.reps}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          oneRM.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 14),
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
