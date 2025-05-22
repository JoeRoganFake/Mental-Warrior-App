import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';

class ExerciseSelectionPage extends StatefulWidget {
  const ExerciseSelectionPage({super.key});

  @override
  ExerciseSelectionPageState createState() => ExerciseSelectionPageState();
}

class ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customExerciseController =
      TextEditingController();
  String _searchQuery = '';
  String _selectedBodyPart = 'All';
  String _selectedEquipment = 'All';
  List<Map<String, dynamic>> _exercises = [];
  List<String> _bodyParts = [
    'All'
  ]; // Initialize with 'All' to avoid LateInitializationError
  List<String> _equipmentTypes = [
    'All'
  ]; // Initialize with 'All' to avoid LateInitializationError

  // Equipment options for adding custom exercise
  final List<String> _equipmentOptions = [
    'Barbell',
    'Dumbbell',
    'Machine',
    'Cable',
    'Body Weight',
    'Kettlebell',
    'Resistance Band',
    'Other',
    'None'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadExercisesFromJson();
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

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _customExerciseController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredExercises {
    List<Map<String, dynamic>> result =
        _exercises; // Filter by body part if not set to "All"
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

  void _showAddCustomExerciseDialog() {
    _customExerciseController.clear();
    String selectedEquipment = 'None';
    String selectedType = 'Chest';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customExerciseController,
              decoration: const InputDecoration(
                labelText: 'Exercise Name',
                hintText: 'Enter exercise name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Primary Muscle',
              ),
              items:
                  _bodyParts.where((part) => part != 'All').map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  selectedType = value;
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedEquipment,
              decoration: const InputDecoration(
                labelText: 'Equipment',
              ),
              items: _equipmentOptions.map((String equipment) {
                return DropdownMenuItem<String>(
                  value: equipment,
                  child: Text(equipment),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  selectedEquipment = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final exerciseName = _customExerciseController.text.trim();
              if (exerciseName.isNotEmpty) {
                Navigator.pop(context);
                Navigator.pop(context, {
                  'name': exerciseName,
                  'equipment':
                      selectedEquipment == 'None' ? 'None' : selectedEquipment,
                  'type': selectedType,
                  'description': 'Custom exercise'
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Exercise'),
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
                    onPressed: _showAddCustomExerciseDialog,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                  onTap: () {
                    Navigator.pop(context, {
                      'name': exercise['name'] ?? 'Unnamed Exercise',
                      'equipment': exercise['equipment'] ?? 'No Equipment',
                      'type': exercise['type'] ?? 'No Type',
                      'description':
                          exercise['description'] ?? 'No description available',
                        'apiId': exercise['id'] ??
                            '', // Add the API ID from exercises_data.dart
                    });
                    }, // Show description on long press or with an expansion panel
                  onLongPress: () {
                    if (exercise['description'] != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(exercise['description']),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                    },
                    trailing: exercise['id'] != null
                        ? Container(
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
                                      exerciseId: exercise['id'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomExerciseDialog,
        child: const Icon(Icons.add),
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
