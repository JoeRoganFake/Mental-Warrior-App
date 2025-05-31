import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';

class ExerciseDetailPage extends StatefulWidget {
  final String exerciseId; // API ID

  const ExerciseDetailPage({Key? key, required this.exerciseId})
      : super(key: key);

  @override
  _ExerciseDetailPageState createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends State<ExerciseDetailPage> {
  Map<String, dynamic>? _exercise;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  List<dynamic>? _exercisesList;
  bool _didInitialLoad = false;

  @override
  void dispose() {
    _pageController.dispose();
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
  void initState() {
    super.initState();
    // Just load the JSON data in initState, but don't try to access any context
    _exercisesList = json.decode(exercisesJson) as List<dynamic>;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only process once when dependencies are first available
    if (!_didInitialLoad) {
      _loadExerciseData();
      _didInitialLoad = true;
    }
  }
  
  void _loadExerciseData() {
    if (_exercisesList == null) return;
    
    final List<dynamic> list = _exercisesList!;
    try {
      final String currentExerciseId = widget.exerciseId.trim(); // Trim passed ID
      
      // Debug information
      print('Looking for exercise with ID: "$currentExerciseId"');

      // Special handling for negative IDs (temporary exercises)
      if (currentExerciseId.startsWith('-')) {
        print('Negative ID detected, this is a temporary exercise');
        
        // Now we can safely access route arguments in didChangeDependencies
        final Map<String, dynamic>? args = 
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
            
        if (args != null) {
          // First try to use the exerciseName if available
          if (args.containsKey('exerciseName')) {
            final String exerciseName = args['exerciseName'] as String;
            print('Got exercise name from route args: $exerciseName');
            
            // Try to find by name
            _tryFindExerciseByName(list, exerciseName);
            
            // If found by name, return early
            if (_exercise != null && !_exercise!.isEmpty) {
              print('Found exercise by name: ${_exercise!['name']}');
              return;
            }
          }
          
          // If name didn't work, try equipment as a fallback filter
          if (args.containsKey('exerciseEquipment') && 
              args['exerciseEquipment'] != null && 
              args['exerciseEquipment'].toString().isNotEmpty) {
            
            final String equipment = args['exerciseEquipment'] as String;
            print('Trying to find exercise with equipment: $equipment');
            
            // Find first exercise with matching equipment
            for (var e in list.cast<Map<String, dynamic>>()) {
              if (e['equipment'] != null && 
                  (e['equipment'] as String).toLowerCase() == equipment.toLowerCase()) {
                _exercise = e;
                print('Found exercise by equipment: ${_exercise!['name']}');
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
        
        print('Using a default exercise: ${_exercise?['name']}');
        return;
      }
      
      // Check if the passed ID is an API ID with markers
      if (currentExerciseId.contains('##API_ID:')) {
        // Extract the actual API ID from the marker
        final RegExp apiIdRegex = RegExp(r'##API_ID:([^#]+)##');
        final Match? match = apiIdRegex.firstMatch(currentExerciseId);
        final String extractedApiId = match?.group(1)?.trim() ?? currentExerciseId;
        
        print('Extracted API ID: "$extractedApiId"');
        
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
        print('Exercise not found in JSON data for ID: $currentExerciseId');
        _exercise = null; // if the map is empty (exercise not found), set to null
      }
    } catch (e) {
      print('Error finding exercise ${widget.exerciseId}: $e');
      _exercise = null; // Catch any error during parsing or lookup
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
                  : 'Exercise Details')),      body: exercise == null
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
          : SingleChildScrollView(
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
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print(
                                        'Error loading image: $error for $imagePath');
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline,
                                              size: 48, color: Colors.red),
                                          SizedBox(height: 8),
                                          Text('Unable to load image',
                                              style:
                                                  TextStyle(color: Colors.red)),
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
                  const SizedBox(height: 16), // Primary Muscles Chips
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
                              backgroundColor: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                              labelStyle: TextStyle(
                                  color: Theme.of(context).primaryColor),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  
                  // Secondary Muscles Chips
                  if ((exercise['secondaryMuscles'] as List?)?.isNotEmpty ??
                      false)
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
                            for (var muscle
                                in (exercise['secondaryMuscles'] as List))
                              Chip(
                                avatar: Icon(Icons.fitness_center_outlined,
                                    size: 16),
                                label: Text(muscle),
                                backgroundColor: Colors.orange[100],
                                labelStyle:
                                    TextStyle(color: Colors.orange[800]),
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

                  const SizedBox(height: 16), // Additional Exercise Information
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
                      if (exercise['equipment'] != null &&
                          exercise['equipment'] != '')
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
                      child:
                          Text('• $step', style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
