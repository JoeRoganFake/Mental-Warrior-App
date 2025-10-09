import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/create_exercise_page.dart';
import 'package:mental_warior/services/database_services.dart';

class ExerciseSelectionPage extends StatefulWidget {
  const ExerciseSelectionPage({super.key});

  @override
  ExerciseSelectionPageState createState() => ExerciseSelectionPageState();
}

class ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedBodyPart = 'All';
  String _selectedEquipment = 'All';
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _customExercises = [];
  List<String> _bodyParts = [
    'All'
  ]; // Initialize with 'All' to avoid LateInitializationError
  List<String> _equipmentTypes = [
    'All'
  ]; // Initialize with 'All' to avoid LateInitializationError
  
  // Track selected exercises for multiple selection
  final Set<String> _selectedExercises = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadExercisesFromJson();
    _loadCustomExercises();

    // Listen for custom exercise updates
    CustomExerciseService.customExercisesUpdatedNotifier
        .addListener(_loadCustomExercises);
  }

  void _loadExercisesFromJson() {
    try {
      final List<dynamic> exercisesList =
          json.decode(exercisesJson) as List<dynamic>;
      // Helper to Title Case words
      String capitalizeWords(String s) => s
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
          .join(' ');
      _exercises = exercisesList.map((e) {
        final m = e as Map<String, dynamic>;
        final primaryMuscle =
            ((m['primaryMuscles'] as List?)?.isNotEmpty ?? false)
                ? (m['primaryMuscles'] as List).first as String
                : '';
        final rawEquip = (m['equipment'] as String?) ?? 'None';
        return {
          'name': m['name'] ?? 'None',
          'type': capitalizeWords(primaryMuscle),
          'equipment': capitalizeWords(rawEquip),
          'description': (m['instructions'] as List<dynamic>? ?? []).join('\n'),
          'id': m['id'] ?? '',
          'imageUrl': (m['images'] as List?)?.isNotEmpty ?? false
              ? 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/${(m['images'] as List).first}'
              : '',
          'secondaryMuscles': m['secondaryMuscles'] ?? [],
          'isCustom': false, // Mark built-in exercises
        };
      }).toList();
      // Populate dynamic filter lists
      final bodySet = _exercises.map((e) => e['type'] as String).toSet();
      final equipSet = _exercises.map((e) => e['equipment'] as String).toSet();
      _bodyParts = ['All', ...bodySet.toList()..sort()];
      _equipmentTypes = ['All', ...equipSet.toList()..sort()];
    } catch (e) {
      debugPrint('Error loading local exercises: $e');
      setState(() {
        _exercises = [];
        // Ensure we have default values even if loading fails
        _bodyParts = ['All'];
        _equipmentTypes = ['All'];
      });
    }
  }

  void _loadCustomExercises() async {
    try {
      final customExerciseService = CustomExerciseService();
      final customExercises = await customExerciseService.getCustomExercises();

      setState(() {
        _customExercises = customExercises;
        // Update filter lists to include custom exercise types and equipment
        _updateFilterLists();
      });
    } catch (e) {
      debugPrint('Error loading custom exercises: $e');
      setState(() {
        _customExercises = [];
      });
    }
  }

  void _updateFilterLists() {
    // Combine built-in and custom exercises for filter lists
    final allExercises = [..._exercises, ..._customExercises];
    final bodySet = allExercises.map((e) => e['type'] as String).toSet();
    final equipSet = allExercises.map((e) => e['equipment'] as String).toSet();
    _bodyParts = ['All', ...bodySet.toList()..sort()];
    _equipmentTypes = ['All', ...equipSet.toList()..sort()];
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    CustomExerciseService.customExercisesUpdatedNotifier
        .removeListener(_loadCustomExercises);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  // Helper method to create a unique key for each exercise
  String _getExerciseKey(Map<String, dynamic> exercise) {
    return '${exercise['name']}_${exercise['equipment']}';
  }

  // Toggle exercise selection
  void _toggleExerciseSelection(Map<String, dynamic> exercise) {
    setState(() {
      final key = _getExerciseKey(exercise);
      if (_selectedExercises.contains(key)) {
        _selectedExercises.remove(key);
      } else {
        _selectedExercises.add(key);
      }
    });
  }

  List<Map<String, dynamic>> get _filteredExercises {
    // Combine built-in and custom exercises
    List<Map<String, dynamic>> result = [..._exercises, ..._customExercises];

    // Filter by body part if not set to "All"
    if (_selectedBodyPart != 'All') {
      result = result.where((exercise) {
        return exercise['type'] != null &&
            exercise['type'] == _selectedBodyPart;
      }).toList();
    }

    // Filter by equipment if not set to "All"
    if (_selectedEquipment != 'All') {
      result = result.where((exercise) {
        return exercise['equipment'] != null &&
            exercise['equipment'] == _selectedEquipment;
      }).toList();
    }

    // Then apply text search filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((exercise) {
        return (exercise['name'] != null &&
                exercise['name']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery)) ||
            (exercise['description'] != null &&
                exercise['description']
                    .toString()
                    .toLowerCase()
                    .contains(_searchQuery));
      }).toList();
    }

    return result;
  }

  void _navigateToCreateExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateExercisePage(),
      ),
    );

    // If an exercise was created, return it to the parent page
    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  void _showCustomExerciseOptions(Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Exercise'),
                onTap: () {
                  Navigator.pop(context);
                  _editCustomExercise(exercise);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Exercise',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteCustomExercise(exercise);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  if (exercise['description'] != null &&
                      exercise['description'].isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(exercise['description']),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _editCustomExercise(Map<String, dynamic> exercise) async {
    // Navigate to create exercise page with existing data for editing
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateExercisePage(
          editMode: true,
          exerciseData: exercise,
        ),
      ),
    );

    // If exercise was updated, reload custom exercises
    if (result != null) {
      _loadCustomExercises();
    }
  }

  void _confirmDeleteCustomExercise(Map<String, dynamic> exercise) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Exercise'),
          content: Text(
              'Are you sure you want to delete "${exercise['name']}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteCustomExercise(exercise);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCustomExercise(Map<String, dynamic> exercise) async {
    try {
      final customExerciseService = CustomExerciseService();
      await customExerciseService.deleteCustomExercise(exercise['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exercise "${exercise['name']}" deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Remove from selected exercises if it was selected
      final exerciseKey = _getExerciseKey(exercise);
      if (_selectedExercises.contains(exerciseKey)) {
        setState(() {
          _selectedExercises.remove(exerciseKey);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete exercise: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedExercises.isEmpty
            ? 'Select Exercises'
            : '${_selectedExercises.length} selected'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // Primary muscle filter
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: _bodyParts.map((bodyPart) {
                    final isSelected = _selectedBodyPart == bodyPart;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(bodyPart),
                        selected: isSelected,
                        selectedColor:
                            _getColorForType(bodyPart).withOpacity(0.7),
                        onSelected: (selected) {
                          setState(() {
                            _selectedBodyPart = bodyPart;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Equipment filter
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: _equipmentTypes.map((equipment) {
                    final isSelected = _selectedEquipment == equipment;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(equipment),
                        selected: isSelected,
                        selectedColor: Colors.blue.withOpacity(0.7),
                        onSelected: (selected) {
                          setState(() {
                            _selectedEquipment = equipment;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _filteredExercises.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No exercises found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Custom Exercise'),
                    onPressed: _navigateToCreateExercise,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                final isSelected =
                    _selectedExercises.contains(_getExerciseKey(exercise));
                
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? BorderSide(
                            color:
                                _getColorForType(exercise['type'] ?? 'No Type'),
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  color: isSelected
                      ? _getColorForType(exercise['type'] ?? 'No Type')
                          .withOpacity(0.1)
                      : null,
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      exercise['name'] ?? 'Unnamed Exercise',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${exercise['equipment'] ?? 'No Equipment'} • ${exercise['type'] ?? 'No Type'}',
                    ),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getColorForType(exercise['type'] ?? 'No Type'),
                            _getColorForType(exercise['type'] ?? 'No Type')
                                .withOpacity(0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                _getColorForType(exercise['type'] ?? 'No Type')
                                    .withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (exercise['name'] ?? 'X')[0],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Checkbox for multiple selection
                        Checkbox(
                          value: _selectedExercises
                              .contains(_getExerciseKey(exercise)),
                          onChanged: (bool? value) {
                            _toggleExerciseSelection(exercise);
                          },
                          activeColor:
                              _getColorForType(exercise['type'] ?? 'No Type'),
                        ),
                        // Info button for built-in exercises with API details
                        if (exercise['id'] != null &&
                            exercise['id'].toString().isNotEmpty &&
                            !(exercise['isCustom'] ?? false))
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.info_outline,
                                color: Theme.of(context).primaryColor,
                              ),
                              tooltip: 'View exercise details',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExerciseDetailPage(
                                      exerciseId:
                                          exercise['id'].toString().trim(),
                                    ),
                                    settings: RouteSettings(
                                      arguments: {
                                        'exerciseName': exercise['name'],
                                        'exerciseEquipment':
                                            exercise['equipment'] ?? '',
                                        'isTemporary': false, // These are API exercises, not temporary
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        // Custom exercise indicator
                        if (exercise['isCustom'] ?? false)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.orange.shade700,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Custom',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      // Toggle selection on tap instead of immediately returning
                      _toggleExerciseSelection(exercise);
                    },
                    // Show description on long press for built-in exercises,
                    // or show options menu for custom exercises
                    onLongPress: () {
                      if (exercise['isCustom'] ?? false) {
                        _showCustomExerciseOptions(exercise);
                      } else if (exercise['description'] != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(exercise['description']),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Add selected exercises button
          if (_selectedExercises.isNotEmpty)
            Container(
              margin: EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.extended(
                heroTag: "add_selected_exercises", // Unique hero tag
                onPressed: () {
                  // Return selected exercises from both built-in and custom exercises
                  final allExercises = [..._exercises, ..._customExercises];
                  final selectedExercisesList = allExercises
                      .where((exercise) => _selectedExercises
                          .contains(_getExerciseKey(exercise)))
                      .map((exercise) => {
                            'name': exercise['name'],
                            'equipment': exercise['equipment'],
                            'type': exercise['type'],
                            'description': exercise['description'],
                            'apiId': exercise['apiId'] ?? exercise['id'] ?? '',
                            'isCustom': exercise['isCustom'] ?? false,
                          })
                      .toList();
                  Navigator.pop(context, selectedExercisesList);
                },
                backgroundColor: Theme.of(context).primaryColor,
                icon: Icon(Icons.add),
                label: Text(
                    'Add ${_selectedExercises.length} Exercise${_selectedExercises.length == 1 ? '' : 's'}'),
              ),
            ),
          // Add custom exercise button
          FloatingActionButton(
            heroTag: "add_custom_exercise", // Unique hero tag
            onPressed: _navigateToCreateExercise,
            child: const Icon(Icons.add),
            tooltip: 'Add custom exercise',
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String? type) {
    if (type == null) {
      return Colors.grey;
    }

    switch (type.toLowerCase()) {
      case 'chest':
        return Colors.red;
      case 'back':
        return Colors.blue;
      case 'legs':
      case 'quadriceps':
      case 'hamstrings':
      case 'calves':
      case 'glutes':
        return Colors.green;
      case 'arms':
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return Colors.orange;
      case 'shoulders':
      case 'delts':
        return Colors.purple;
      case 'core':
      case 'abdominals':
      case 'abs':
        return Colors.teal;
      case 'all':
        return Colors.grey.shade700;
      case 'neck':
        return Colors.brown;
      case 'adductors':
        return Colors.lightGreen;
      case 'traps':
      case 'lats':
        return Colors.indigo;
      case 'cardio':
        return Colors.red[300]!;
      default:
        return Colors.grey;
    }
  }
}
