import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/create_exercise_page.dart';
import 'package:mental_warior/services/database_services.dart';

class ExerciseBrowsePage extends StatefulWidget {
  final bool embedded;

  const ExerciseBrowsePage({super.key, this.embedded = false});

  @override
  ExerciseBrowsePageState createState() => ExerciseBrowsePageState();
}

class ExerciseBrowsePageState extends State<ExerciseBrowsePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedBodyPart = 'All';
  String _selectedEquipment = 'All';
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _customExercises = [];
  List<String> _bodyParts = ['All'];
  List<String> _equipmentTypes = ['All'];

  // Helper function to clean exercise names from markers
  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
  }

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
          'isCustom': false,
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
        _bodyParts = ['All'];
        _equipmentTypes = ['All'];
      });
    }
  }

  void _loadCustomExercises() async {
    try {
      final customExerciseService = CustomExerciseService();
      // Only load non-hidden exercises for search/browse
      final customExercises = await customExerciseService.getCustomExercises(includeHidden: false);

      setState(() {
        _customExercises = customExercises;
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

  List<Map<String, dynamic>> get _filteredExercises {
    List<Map<String, dynamic>> result = [..._exercises, ..._customExercises];

    if (_selectedBodyPart != 'All') {
      result = result.where((exercise) {
        return exercise['type'] != null &&
            exercise['type'] == _selectedBodyPart;
      }).toList();
    }

    if (_selectedEquipment != 'All') {
      result = result.where((exercise) {
        return exercise['equipment'] != null &&
            exercise['equipment'] == _selectedEquipment;
      }).toList();
    }

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

  void _viewExerciseDetails(Map<String, dynamic> exercise) {
    final apiId = exercise['apiId'] ?? exercise['id'];
    if (apiId.toString().startsWith('custom_')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomExerciseDetailPage(
            exerciseId: exercise['id'].toString().trim(),
            exerciseName: exercise['name'],
            exerciseEquipment: exercise['equipment'] ?? '',
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseDetailPage(
            exerciseId: exercise['id'].toString().trim(),
          ),
          settings: RouteSettings(
            arguments: {
              'exerciseName': exercise['name'],
              'exerciseEquipment': exercise['equipment'] ?? '',
              'isTemporary': false,
            },
          ),
        ),
      );
    }
  }

  Future<void> _openCreateExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateExercisePage(),
      ),
    );

    if (!mounted) return;

    if (result is Map<String, dynamic>) {
      setState(() {
        final existingIndex =
            _customExercises.indexWhere((e) => e['id'] == result['id']);
        if (existingIndex >= 0) {
          _customExercises[existingIndex] = result;
        } else {
          _customExercises.add(result);
        }
        _updateFilterLists();
      });

      final name = (result['name'] ?? 'Custom exercise').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created "$name"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
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
          
          const SizedBox(height: 8),
          
          // Exercises list
          Expanded(
            child: _filteredExercises.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                        const Icon(Icons.fitness_center,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                    'No exercises found',
                    style: TextStyle(fontSize: 18),
                  ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _openCreateExercise,
                          icon: const Icon(Icons.add),
                          label: const Text('Create a custom exercise'),
                        ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = _filteredExercises[index];
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      _cleanExerciseName(exercise['name'] ?? 'Unnamed Exercise'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (_cleanExerciseName(exercise['name'] ?? 'X'))[0],
                          style: const TextStyle(
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
                        // Custom exercise indicator
                        if (exercise['isCustom'] ?? false)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
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
                        // View details arrow
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                    onTap: () => _viewExerciseDetails(exercise),
                  ),
                );
              },
            ),
          ),
        ],
    );

    // If embedded, return just the body content with a FAB overlay
    if (widget.embedded) {
      return Stack(
        children: [
          bodyContent,
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _openCreateExercise,
              tooltip: 'Create custom exercise',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      );
    }

    // Otherwise, return full Scaffold with AppBar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Exercises'),
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateExercise,
        tooltip: 'Create custom exercise',
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
