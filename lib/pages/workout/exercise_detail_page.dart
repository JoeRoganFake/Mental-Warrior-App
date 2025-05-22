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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    // Load local exercise data from JSON
    final List<dynamic> list = json.decode(exercisesJson) as List<dynamic>;
    try {
      final String currentExerciseId =
          widget.exerciseId.trim(); // Trim passed ID
      _exercise = list.cast<Map<String, dynamic>>().firstWhere(
        (e) {
          final String? idFromData =
              e['id'] as String?; // Safely cast and access ID
          return idFromData != null &&
              idFromData.trim() == currentExerciseId; // Trim and compare
        },
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );
      if (_exercise!.isEmpty) {
        _exercise =
            null; // if the map is empty (exercise not found), set to null
      }
    } catch (e) {
      _exercise = null; // Catch any error during parsing or lookup
      // For debugging, you might want to print the error:
      // print('Error finding exercise ${widget.exerciseId}: $e');
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
                  : 'Exercise Details')),
      body: exercise == null
          ? const Center(child: Text('Exercise not found.'))
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
