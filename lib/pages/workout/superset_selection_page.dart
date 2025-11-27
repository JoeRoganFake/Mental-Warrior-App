import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';

class SupersetSelectionPage extends StatefulWidget {
  final List<Exercise> exercises;
  final int currentExerciseId;
  final Map<int, String> existingSupersets; // exerciseId -> supersetId
  final Color Function(String supersetId)? getColorForSuperset;

  const SupersetSelectionPage({
    super.key,
    required this.exercises,
    required this.currentExerciseId,
    this.existingSupersets = const {},
    this.getColorForSuperset,
  });

  @override
  State<SupersetSelectionPage> createState() => _SupersetSelectionPageState();
}

class _SupersetSelectionPageState extends State<SupersetSelectionPage> {
  final Set<int> _selectedExerciseIds = {};

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);

  // Default superset colors list (same as workout_session_page)
  static const List<Color> _defaultSupersetColors = [
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFE91E63), // Pink
    Color(0xFF8BC34A), // Light Green
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF009688), // Teal
    Color(0xFF673AB7), // Deep Purple
  ];

  Color _getColorForSuperset(String supersetId) {
    if (widget.getColorForSuperset != null) {
      return widget.getColorForSuperset!(supersetId);
    }
    // Fallback: use same logic as workout_session_page
    final match = RegExp(r'superset_(\d+)').firstMatch(supersetId);
    if (match != null) {
      final index = int.tryParse(match.group(1) ?? '0') ?? 0;
      return _defaultSupersetColors[index % _defaultSupersetColors.length];
    }
    final index = supersetId.hashCode.abs() % _defaultSupersetColors.length;
    return _defaultSupersetColors[index];
  }

  @override
  void initState() {
    super.initState();
    // Pre-select the current exercise
    _selectedExerciseIds.add(widget.currentExerciseId);
  }

  // Helper method to clean exercise names by removing markers
  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        title: Text(
          'Create Superset',
          style: TextStyle(color: _textPrimaryColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: _textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selectedExerciseIds.length >= 2
                ? () {
                    // TODO: Implement superset creation
                    Navigator.pop(context, _selectedExerciseIds.toList());
                  }
                : null,
            child: Text(
              'Create',
              style: TextStyle(
                color: _selectedExerciseIds.length >= 2
                    ? _primaryColor
                    : _textSecondaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _primaryColor.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: _primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Select exercises for superset',
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose 2 or more exercises to group together. Selected: ${_selectedExerciseIds.length}',
                  style: TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Exercise list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.exercises.length,
              itemBuilder: (context, index) {
                final exercise = widget.exercises[index];
                final isSelected = _selectedExerciseIds.contains(exercise.id);
                final existingSuperset = widget.existingSupersets[exercise.id];
                final supersetColor = existingSuperset != null 
                    ? _getColorForSuperset(existingSuperset) 
                    : const Color(0xFFFF9800);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryColor.withOpacity(0.15)
                        : _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _primaryColor
                          : existingSuperset != null
                              ? supersetColor.withOpacity(0.5)
                              : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor.withOpacity(0.3)
                            : existingSuperset != null
                                ? supersetColor.withOpacity(0.15)
                                : _primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        existingSuperset != null ? Icons.link : Icons.fitness_center,
                        color: isSelected 
                            ? _primaryColor 
                            : existingSuperset != null
                                ? supersetColor
                                : _textSecondaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _cleanExerciseName(exercise.name),
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${exercise.sets.length} sets',
                          style: TextStyle(
                            color: _textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                        if (existingSuperset != null)
                          Text(
                            'In superset',
                            style: TextStyle(
                              color: supersetColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedExerciseIds.add(exercise.id);
                          } else {
                            _selectedExerciseIds.remove(exercise.id);
                          }
                        });
                      },
                      activeColor: _primaryColor,
                      checkColor: Colors.white,
                      side: BorderSide(color: _textSecondaryColor),
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedExerciseIds.remove(exercise.id);
                        } else {
                          _selectedExerciseIds.add(exercise.id);
                        }
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
