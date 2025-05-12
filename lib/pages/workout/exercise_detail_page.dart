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

  @override
  void initState() {
    super.initState();
    // Load local exercise data from JSON
    final List<dynamic> list = json.decode(exercisesJson) as List<dynamic>;
    try {
      final String currentExerciseId = widget.exerciseId.trim(); // Trim passed ID
      _exercise = list.cast<Map<String, dynamic>>().firstWhere(
        (e) {
          final String? idFromData = e['id'] as String?; // Safely cast and access ID
          return idFromData != null && idFromData.trim() == currentExerciseId; // Trim and compare
        },
        orElse: () => <String, dynamic>{}, // Return an empty map if not found
      );
      if (_exercise!.isEmpty) {
        _exercise = null; // if the map is empty (exercise not found), set to null
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
      appBar: AppBar(title: Text(exercise?['name'] ?? 'Exercise Details')),
      body: exercise == null
          ? const Center(child: Text('Exercise not found.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((exercise['gifUrl'] as String?)?.isNotEmpty ?? false)
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.grey.shade100,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          exercise['gifUrl'],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                                  SizedBox(height: 8),
                                  Text('Unable to load image', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    Chip(
                        label:
                            Text('Body Part: ${exercise['bodyPart'] ?? ''}')), // Use original key 'bodyPart'
                    Chip(label: Text('Target: ${exercise['target'] ?? ''}')),
                    Chip(
                        label:
                            Text('Equipment: ${exercise['equipment'] ?? ''}')),
                  ]),
                  const Divider(height: 24),
                  const SizedBox(height: 8),
                  Text(
                    'Secondary Muscles: ${List<String>.from(exercise['secondaryMuscles'] ?? []).join(', ')}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...List<String>.from(exercise['instructions'] ?? []).map( // Use original key 'instructions'
                    (step) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('• $step', style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
