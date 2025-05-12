import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';

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
  late List<Map<String, dynamic>> _exercises = [];
  late List<String> _bodyParts;
  late List<String> _equipmentTypes;

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
        final rawBody = (m['bodyPart'] as String?) ?? '';
        final rawEquip = (m['equipment'] as String?) ?? '';
        return {
          'name': m['name'] ?? '',
          'type': capitalizeWords(rawBody),
          'equipment': capitalizeWords(rawEquip),
          'description': (m['instructions'] as List<dynamic>? ?? []).join('\n'),
          'id': m['id'] ?? '',
          'imageUrl': m['gifUrl'] ?? '',
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
      _exercises = [];
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
                labelText: 'Body Part',
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
                      selectedEquipment == 'None' ? '' : selectedEquipment,
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

              // Body part filter
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
                return ListTile(
                  title: Text(exercise['name'] ?? 'Unnamed Exercise'),
                  subtitle: Text(
                    '${exercise['equipment'] ?? 'No Equipment'} • ${exercise['type'] ?? 'No Type'}',
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        _getColorForType(exercise['type'] ?? 'No Type'),
                    child: Text(
                      (exercise['name'] ?? 'X')[0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, {
                      'name': exercise['name'] ?? 'Unnamed Exercise',
                      'equipment': exercise['equipment'] ?? 'No Equipment',
                      'type': exercise['type'] ?? 'No Type',
                      'description':
                          exercise['description'] ?? 'No description available',
                      'apiId': exercise['id'] ?? '', // Add the API ID from exercises_data.dart
                    });
                  },
                  // Show description on long press or with an expansion panel
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
        return Colors.green;
      case 'arms':
        return Colors.orange;
      case 'shoulders':
        return Colors.purple;
      case 'core':
        return Colors.teal;
      case 'all':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }
}
