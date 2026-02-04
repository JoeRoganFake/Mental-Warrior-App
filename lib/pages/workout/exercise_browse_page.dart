import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/data/exercises_data.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/create_exercise_page.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/utils/app_theme.dart';

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
  bool _showOnlyStarred = false; // Filter to show only starred exercises
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _customExercises = [];
  Set<String> _starredExerciseIds = {}; // Cache of starred exercise IDs
  List<String> _bodyParts = ['All'];
  List<String> _equipmentTypes = ['All'];
  final StarredExercisesService _starredService = StarredExercisesService();

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
    _loadStarredExercises();

    // Listen for custom exercise updates
    CustomExerciseService.customExercisesUpdatedNotifier
        .addListener(_loadCustomExercises);
    
    // Listen for starred exercises updates
    StarredExercisesService.starredExercisesUpdatedNotifier
        .addListener(_loadStarredExercises);
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

  void _loadStarredExercises() async {
    try {
      final starredIds = await _starredService.getStarredExerciseIds();
      setState(() {
        _starredExerciseIds = starredIds;
      });
    } catch (e) {
      debugPrint('Error loading starred exercises: $e');
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
    StarredExercisesService.starredExercisesUpdatedNotifier
        .removeListener(_loadStarredExercises);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Map<String, dynamic>> get _filteredExercises {
    List<Map<String, dynamic>> result = [..._exercises, ..._customExercises];

    // Filter by starred status
    if (_showOnlyStarred) {
      result = result.where((exercise) {
        final exerciseId = exercise['apiId'] ?? exercise['id'];
        final exerciseType = (exercise['isCustom'] ?? false) ? 'custom' : 'api';
        return _starredExerciseIds.contains('${exerciseId}_$exerciseType');
      }).toList();
    }

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

  Future<void> _toggleStarExercise(Map<String, dynamic> exercise) async {
    final exerciseId = (exercise['apiId'] ?? exercise['id']).toString();
    final exerciseType = (exercise['isCustom'] ?? false) ? 'custom' : 'api';
    final exerciseName = exercise['name'].toString();
    final starKey = '${exerciseId}_$exerciseType';

    try {
      if (_starredExerciseIds.contains(starKey)) {
        await _starredService.unstarExercise(exerciseId, exerciseType);
        setState(() {
          _starredExerciseIds.remove(starKey);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Removed ${_cleanExerciseName(exerciseName)} from favorites'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        await _starredService.starExercise(
            exerciseName, exerciseId, exerciseType);
        setState(() {
          _starredExerciseIds.add(starKey);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Added ${_cleanExerciseName(exerciseName)} to favorites'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling star: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    final exerciseId = (exercise['apiId'] ?? exercise['id']).toString();
    final exerciseType = (exercise['isCustom'] ?? false) ? 'custom' : 'api';
    final isStarred =
        _starredExerciseIds.contains('${exerciseId}_$exerciseType');
    final exerciseTypeString = exercise['type'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadiusMd,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          _cleanExerciseName(exercise['name'] ?? 'Unnamed Exercise'),
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${exercise['equipment'] ?? 'No Equipment'} • ${exerciseTypeString ?? 'No Type'}',
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getColorForType(exerciseTypeString).withOpacity(0.15),
            border: Border.all(
              color: _getColorForType(exerciseTypeString).withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              (_cleanExerciseName(exercise['name'] ?? 'X'))[0].toUpperCase(),
              style: TextStyle(
                color: _getColorForType(exerciseTypeString),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star button
            IconButton(
              icon: Icon(
                isStarred ? Icons.star : Icons.star_border,
                color: isStarred ? Colors.amber : AppTheme.textSecondary,
              ),
              onPressed: () => _toggleStarExercise(exercise),
              tooltip: isStarred ? 'Remove from favorites' : 'Add to favorites',
            ),
            // Custom exercise indicator
            if (exercise['isCustom'] ?? false)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Custom',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            // View details arrow
            Icon(Icons.chevron_right, color: AppTheme.textTertiary),
          ],
        ),
        onTap: () => _viewExerciseDetails(exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = _filteredExercises;

    final bodyContent = CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),

        // Favorites filter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showOnlyStarred ? Icons.star : Icons.star_border,
                        size: 18,
                        color: _showOnlyStarred ? Colors.amber : null,
                      ),
                      const SizedBox(width: 4),
                      Text(_showOnlyStarred ? 'Favorites' : 'Show Favorites'),
                    ],
                  ),
                  selected: _showOnlyStarred,
                  selectedColor: Colors.amber.withOpacity(0.3),
                  side: BorderSide.none,
                  onSelected: (selected) {
                    setState(() {
                      _showOnlyStarred = selected;
                    });
                  },
                ),
                if (_showOnlyStarred) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${filteredExercises.length} favorite${filteredExercises.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Primary muscle filter
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _bodyParts.length,
              itemBuilder: (context, index) {
                final bodyPart = _bodyParts[index];
                final isSelected = _selectedBodyPart == bodyPart;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(bodyPart),
                    selected: isSelected,
                    selectedColor: isSelected
                        ? AppTheme.accent.withOpacity(0.2)
                        : Colors.transparent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        _selectedBodyPart = bodyPart;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),

        // Equipment filter
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _equipmentTypes.length,
              itemBuilder: (context, index) {
                final equipment = _equipmentTypes[index];
                final isSelected = _selectedEquipment == equipment;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(equipment),
                    selected: isSelected,
                    selectedColor: isSelected
                        ? AppTheme.accent.withOpacity(0.2)
                        : Colors.transparent,
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color:
                          isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      setState(() {
                        _selectedEquipment = equipment;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // Exercises list
        if (filteredExercises.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center,
                      size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text('No exercises found', style: AppTheme.headlineMedium),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openCreateExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Create a custom exercise'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildExerciseItem(filteredExercises[index]),
              childCount: filteredExercises.length,
            ),
          ),
      ],
    );

    // If embedded, return just the body content with a FAB overlay
    if (widget.embedded) {
      return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
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
        ),
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
    // Using different colors for each body part
    if (type == null) {
      return AppTheme.accent;
    }

    switch (type.toLowerCase()) {
      case 'chest':
        return const Color(0xFFEF5350); // Red
      case 'back':
        return const Color(0xFF42A5F5); // Blue
      case 'legs':
      case 'quadriceps':
      case 'hamstrings':
      case 'calves':
      case 'glutes':
        return const Color(0xFF66BB6A); // Green
      case 'arms':
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return const Color(0xFFFFB74D); // Orange
      case 'shoulders':
      case 'delts':
        return const Color(0xFFAB47BC); // Purple
      case 'core':
      case 'abdominals':
      case 'abs':
        return const Color(0xFF29B6F6); // Cyan
      case 'all':
        return const Color(0xFF9E9E9E); // Grey
      case 'neck':
        return const Color(0xFFA1887F); // Brown
      case 'adductors':
        return const Color(0xFF81C784); // Light Green
      case 'traps':
      case 'lats':
        return const Color(0xFF5C6BC0); // Indigo
      case 'cardio':
        return const Color(0xFFEF5350); // Red
      default:
        return AppTheme.accent;
    }
  }
}
