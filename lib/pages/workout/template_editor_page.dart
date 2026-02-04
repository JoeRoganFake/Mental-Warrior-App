import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';
import 'package:mental_warior/utils/app_theme.dart';

class TemplateEditorPage extends StatefulWidget {
  final int? templateId; // If editing an existing template
  final String? initialName;

  const TemplateEditorPage({
    super.key,
    this.templateId,
    this.initialName,
  });

  @override
  TemplateEditorPageState createState() => TemplateEditorPageState();
}

class TemplateEditorPageState extends State<TemplateEditorPage> {
  final TemplateService _templateService = TemplateService();
  final ExerciseRestTimerHistoryService _restTimerHistoryService =
      ExerciseRestTimerHistoryService();
  final TextEditingController _nameController = TextEditingController();
  
  List<TemplateExercise> _exercises = [];
  bool _isLoading = false;
  bool _hasChanges = false;

  // Controllers for set inputs
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};

  // Superset tracking
  int _supersetCounter = 0;
  
  // Superset colors - each superset gets a unique color
  static const List<Color> _supersetColors = [
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

  // Theme colors from AppTheme design system
  
  bool _showWeightInLbs = false;
  int _defaultRestTimer = 90; // Default from settings
  String get _weightUnit => _showWeightInLbs ? 'lbs' : 'kg';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _nameController.text = widget.initialName ?? 'New Template';
    if (widget.templateId != null) {
      _loadTemplate();
    }
  }

  Future<void> _loadSettings() async {
    final settingsService = SettingsService();
    final useLbs = await settingsService.getShowWeightInLbs();
    final defaultRest = await settingsService.getDefaultRestTimer();
    if (mounted) {
      setState(() {
        _showWeightInLbs = useLbs;
        _defaultRestTimer = defaultRest;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    // Dispose all controllers
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _repsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTemplate() async {
    setState(() => _isLoading = true);
    try {
      final template = await _templateService.getTemplate(widget.templateId!);
      if (template != null) {
        setState(() {
          _nameController.text = template.name;
          _exercises = template.exercises;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading template: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }

    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one exercise')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.templateId != null) {
        await _templateService.updateTemplate(
          widget.templateId!,
          _nameController.text.trim(),
          _exercises,
        );
      } else {
        await _templateService.createTemplate(
          _nameController.text.trim(),
          _exercises,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Discard changes?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _addExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseSelectionPage(),
      ),
    );

    if (result != null) {
      // Handle both List and Map return types
      if (result is List) {
        for (final exercise in result) {
          if (exercise is Map<String, dynamic>) {
            final exerciseName = exercise['name'] ?? 'Unknown Exercise';
            // Get saved rest timer for this exercise, or use default
            final savedRestTime =
                await _restTimerHistoryService.getRestTime(exerciseName);
            final restTime = savedRestTime ?? _defaultRestTimer;

            setState(() {
              _hasChanges = true;
              _exercises.add(TemplateExercise(
                name: exerciseName,
                equipment: exercise['equipment'] ?? '',
                sets: [TemplateSet(setNumber: 1, restTime: restTime)],
              ));
            });
          }
        }
      } else if (result is Map<String, dynamic>) {
        final exerciseName = result['name'] ?? 'Unknown Exercise';
        // Get saved rest timer for this exercise, or use default
        final savedRestTime =
            await _restTimerHistoryService.getRestTime(exerciseName);
        final restTime = savedRestTime ?? _defaultRestTimer;

        setState(() {
          _hasChanges = true;
          _exercises.add(TemplateExercise(
            name: exerciseName,
            equipment: result['equipment'] ?? '',
            sets: [TemplateSet(setNumber: 1, restTime: restTime)],
          ));
        });
      }
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _hasChanges = true;
      _exercises.removeAt(index);
    });
  }

  void _addSet(int exerciseIndex) async {
    // Get the saved rest timer value for this exercise, or use existing/default
    final exercise = _exercises[exerciseIndex];
    final savedRestTime =
        await _restTimerHistoryService.getRestTime(exercise.name);
    
    setState(() {
      _hasChanges = true;
      final newSetNumber = exercise.sets.length + 1;
      // Priority: 1) existing sets' rest time, 2) saved rest time, 3) default from settings
      final restTime = exercise.sets.isNotEmpty
          ? exercise.sets.first.restTime
          : (savedRestTime ?? _defaultRestTimer);
      final newSets = List<TemplateSet>.from(exercise.sets)
        ..add(TemplateSet(setNumber: newSetNumber, restTime: restTime));
      _exercises[exerciseIndex] = TemplateExercise(
        name: exercise.name,
        equipment: exercise.equipment,
        sets: newSets,
        supersetGroup: exercise.supersetGroup,
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      _hasChanges = true;
      final exercise = _exercises[exerciseIndex];
      final newSets = List<TemplateSet>.from(exercise.sets)..removeAt(setIndex);
      // Renumber sets
      for (int i = 0; i < newSets.length; i++) {
        newSets[i] = TemplateSet(
          setNumber: i + 1,
          targetReps: newSets[i].targetReps,
          targetWeight: newSets[i].targetWeight,
          restTime: newSets[i].restTime,
        );
      }
      _exercises[exerciseIndex] = TemplateExercise(
        name: exercise.name,
        equipment: exercise.equipment,
        sets: newSets,
        supersetGroup: exercise.supersetGroup,
      );
    });
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    setState(() {
      _hasChanges = true;
      // Adjust newIndex if dragging downward
      if (newIndex >= _exercises.length) {
        newIndex = _exercises.length - 1;
      } else if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Move the exercise in the list
      final exercise = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, exercise);
    });
  }

  // Get a consistent color for a superset based on its ID
  Color _getColorForSuperset(String supersetId) {
    // Extract the number from superset ID (e.g., "superset_0" -> 0)
    final match = RegExp(r'superset_(\d+)').firstMatch(supersetId);
    if (match != null) {
      final index = int.tryParse(match.group(1) ?? '0') ?? 0;
      return _supersetColors[index % _supersetColors.length];
    }
    // Fallback: use hash code to get a consistent index
    final index = supersetId.hashCode.abs() % _supersetColors.length;
    return _supersetColors[index];
  }

  // Create a new superset with another exercise
  void _createSuperset(int exerciseIndex) {
    // Navigate to the superset selection page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TemplateSupersetSelectionPage(
          exercises: _exercises,
          currentExerciseIndex: exerciseIndex,
          getColorForSuperset: _getColorForSuperset,
          cleanExerciseName: _cleanExerciseName,
        ),
      ),
    ).then((result) {
      if (result != null && result is List<int> && result.length >= 2) {
        _linkMultipleExercisesAsSuperset(result);
      }
    });
  }

  void _linkMultipleExercisesAsSuperset(List<int> exerciseIndices) {
    setState(() {
      _hasChanges = true;
      final supersetId = 'superset_$_supersetCounter';
      _supersetCounter++;

      // Update all selected exercises
      for (final index in exerciseIndices) {
        final exercise = _exercises[index];
        _exercises[index] = TemplateExercise(
          name: exercise.name,
          equipment: exercise.equipment,
          sets: exercise.sets,
          supersetGroup: supersetId,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Superset created with ${exerciseIndices.length} exercises')),
    );
  }

  void _removeFromSuperset(int exerciseIndex) {
    final supersetId = _exercises[exerciseIndex].supersetGroup;
    if (supersetId == null) return;

    setState(() {
      _hasChanges = true;
      
      // Remove the exercise from the superset
      final exercise = _exercises[exerciseIndex];
      _exercises[exerciseIndex] = TemplateExercise(
        name: exercise.name,
        equipment: exercise.equipment,
        sets: exercise.sets,
        supersetGroup: null,
      );

      // Check if only one exercise remains in the superset - if so, remove it too
      final remainingInSuperset = <int>[];
      for (int i = 0; i < _exercises.length; i++) {
        if (_exercises[i].supersetGroup == supersetId) {
          remainingInSuperset.add(i);
        }
      }

      if (remainingInSuperset.length == 1) {
        // Only one exercise left, remove it from superset tracking
        final lastExercise = _exercises[remainingInSuperset.first];
        _exercises[remainingInSuperset.first] = TemplateExercise(
          name: lastExercise.name,
          equipment: lastExercise.equipment,
          sets: lastExercise.sets,
          supersetGroup: null,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exercise removed from superset')),
    );
  }

  // Replace exercise with another one (keeping all sets)
  Future<void> _replaceExercise(int exerciseIndex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseSelectionPage(
          singleSelectionMode: true,
        ),
      ),
    );

    if (result != null) {
      // Handle both single exercise and multiple exercise selection
      List<Map<String, dynamic>> selectedExercises = [];

      if (result is List) {
        selectedExercises = result.cast<Map<String, dynamic>>();
      } else if (result is Map) {
        selectedExercises = [Map<String, dynamic>.from(result)];
      }

      // Only use the first selected exercise
      if (selectedExercises.isEmpty) return;

      final newExercise = selectedExercises.first;
      final String newExerciseName = newExercise['name'] as String;
      final String newEquipment = newExercise['equipment'] as String? ?? '';

      // When replacing an exercise, use plain name without any markers
      // This makes the replaced exercise editable like a regular exercise
      String fullExerciseName = newExerciseName;

      setState(() {
        _hasChanges = true;
        final exercise = _exercises[exerciseIndex];
        // Keep all sets, superset group, but update name and equipment
        _exercises[exerciseIndex] = TemplateExercise(
          name: fullExerciseName,
          equipment: newEquipment,
          sets: exercise.sets, // Keep all existing sets
          supersetGroup: exercise.supersetGroup,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Exercise replaced successfully'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.fixed,
        ),
      );
    }
  }

  void _showSetRestDialog(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final currentRestTime = exercise.sets.isNotEmpty ? exercise.sets.first.restTime : 150;
    
    int minutes = currentRestTime ~/ 60;
    int seconds = currentRestTime % 60;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Set Rest Time',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rest time between sets',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minutes
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_drop_up,
                            color: AppTheme.accent, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            if (minutes < 10) minutes++;
                          });
                        },
                      ),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$minutes',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down,
                            color: AppTheme.accent, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            if (minutes > 0) minutes--;
                          });
                        },
                      ),
                      Text('min',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Seconds
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_drop_up,
                            color: AppTheme.accent, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            seconds = (seconds + 15) % 60;
                          });
                        },
                      ),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          seconds.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down,
                            color: AppTheme.accent, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            seconds = (seconds - 15 + 60) % 60;
                          });
                        },
                      ),
                      Text('sec',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () {
                Navigator.pop(context);
                _updateExerciseRestTime(exerciseIndex, minutes * 60 + seconds);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateExerciseRestTime(int exerciseIndex, int restTimeSeconds) {
    setState(() {
      _hasChanges = true;
      final exercise = _exercises[exerciseIndex];
      final newSets = exercise.sets.map((set) => TemplateSet(
        setNumber: set.setNumber,
        targetReps: set.targetReps,
        targetWeight: set.targetWeight,
        restTime: restTimeSeconds,
      )).toList();
      
      _exercises[exerciseIndex] = TemplateExercise(
        name: exercise.name,
        equipment: exercise.equipment,
        sets: newSets,
        supersetGroup: exercise.supersetGroup,
      );
    });
  }

  void _viewExerciseDetails(TemplateExercise exercise) {
    // Check if it's a custom exercise or API exercise
    final customMatch = RegExp(r'##CUSTOM:([^#]+)##').firstMatch(exercise.name);
    final apiMatch = RegExp(r'##API_ID:([^#]+)##').firstMatch(exercise.name);
    
    if (customMatch != null) {
      final customId = customMatch.group(1) ?? '';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomExerciseDetailPage(
            exerciseId: customId,
            exerciseName: _cleanExerciseName(exercise.name),
            exerciseEquipment: exercise.equipment,
          ),
        ),
      );
    } else if (apiMatch != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseDetailPage(
            exerciseId: apiMatch.group(1)!.trim(),
          ),
        ),
      );
    }
  }

  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.keyboard_arrow_down,
                color: AppTheme.textPrimary, size: 28),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          title: TextField(
            controller: _nameController,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.surfaceLight, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.accent, width: 2),
              ),
              filled: true,
              fillColor: AppTheme.surface,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: 'Template Name',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            onChanged: (_) => _hasChanges = true,
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.check,
                  color: _isLoading ? Colors.grey : AppTheme.success),
              label: Text(
                'Save',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : AppTheme.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _isLoading ? null : _saveTemplate,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Exercises list
                  Expanded(
                    child: _exercises.isEmpty
                        ? _buildEmptyState()
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _exercises.length,
                            onReorder: _reorderExercises,
                            itemBuilder: (context, index) {
                              return _buildExerciseCard(index);
                            },
                          ),
                  ),
                ],
              ),
        floatingActionButton: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: _addExercise,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color: AppTheme.accent.withOpacity(0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises yet',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: Icon(Icons.add, color: AppTheme.accent),
            label: Text(
              'Add Your First Exercise',
              style: TextStyle(color: AppTheme.accent),
            ),
            onPressed: _addExercise,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final bool isInSuperset = exercise.supersetGroup != null;
    final Color supersetColor = isInSuperset
        ? _getColorForSuperset(exercise.supersetGroup!)
        : Colors.transparent;
    
    // Get rest time from first set (all sets have same rest time)
    final restTime = exercise.sets.isNotEmpty ? exercise.sets.first.restTime : 150;
    final restMinutes = restTime ~/ 60;
    final restSeconds = restTime % 60;
    
    return Material(
      key: ValueKey(exerciseIndex),
        color: Colors.transparent,
        child: RepaintBoundary(
          child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Superset indicator bar on the left (outside the card)
            if (isInSuperset)
              Container(
                width: 4,
                margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: supersetColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            // Main exercise card
            Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  left: isInSuperset ? 8 : 16,
                  right: 16,
                  top: 8,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                      color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: isInSuperset
                      ? Border.all(color: supersetColor.withOpacity(0.3), width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Superset label banner at top
                    if (isInSuperset)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: supersetColor.withOpacity(0.15),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link, color: supersetColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'SUPERSET',
                              style: TextStyle(
                                color: supersetColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Exercise header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          // Drag handle for reordering
                          ReorderableDragStartListener(
                            index: exerciseIndex,
                                child: Icon(Icons.drag_handle,
                                    color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          // Exercise name (tappable)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _viewExerciseDetails(exercise),
                              child: Text(
                                _cleanExerciseName(exercise.name),
                                style: TextStyle(
                                      color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Options menu
                          PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert,
                                    color: AppTheme.textSecondary),
                            color: Colors.black,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (String value) {
                              if (value == 'delete') {
                                _confirmDeleteExercise(exerciseIndex);
                              } else if (value == 'superset') {
                                _createSuperset(exerciseIndex);
                              } else if (value == 'remove_superset') {
                                _removeFromSuperset(exerciseIndex);
                              } else if (value == 'rest_time') {
                                _showSetRestDialog(exerciseIndex);
                                  } else if (value == 'replace') {
                                    _replaceExercise(exerciseIndex);
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'replace',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.swap_horiz,
                                            color: AppTheme.accent),
                                        title: Text('Replace Exercise',
                                            style: TextStyle(
                                                color: AppTheme.textPrimary)),
                                      ),
                                    ),
                                if (!isInSuperset)
                                  PopupMenuItem<String>(
                                    value: 'superset',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.link,
                                              color: AppTheme.accent),
                                      title: Text('Create Superset',
                                              style: TextStyle(
                                                  color: AppTheme.textPrimary)),
                                    ),
                                  )
                                else
                                  PopupMenuItem<String>(
                                    value: 'remove_superset',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.link_off,
                                              color: AppTheme.warning),
                                      title: Text('Remove from Superset',
                                              style: TextStyle(
                                                  color: AppTheme.textPrimary)),
                                    ),
                                  ),
                                PopupMenuItem<String>(
                                  value: 'rest_time',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.timer,
                                            color: AppTheme.accent),
                                    title: Text('Set Rest Time',
                                            style: TextStyle(
                                                color: AppTheme.textPrimary)),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.delete,
                                            color: AppTheme.error),
                                    title: Text('Delete Exercise',
                                            style: TextStyle(
                                                color: AppTheme.textPrimary)),
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Equipment subtitle
                    if (exercise.equipment.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          exercise.equipment,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ),
                    
                    // Rest time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => _showSetRestDialog(exerciseIndex),
                        child: Row(
                          children: [
                                Icon(Icons.timer,
                                    size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Rest: ${restMinutes > 0 ? '${restMinutes}m ' : ''}${restSeconds}s',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Sets table header
                    if (exercise.sets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'WEIGHT',
                                style: TextStyle(
                                      color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'REPS',
                                style: TextStyle(
                                      color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 44), // Space for delete button
                          ],
                        ),
                      ),
                    
                    // Sets list
                    ...exercise.sets.asMap().entries.map((entry) {
                      return _buildSetRow(exerciseIndex, entry.key, entry.value);
                    }),
                    
                    // Add set button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            exercise.sets.isEmpty ? 'Add First Set' : 'Add Set',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: BorderSide(color: AppTheme.accent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () => _addSet(exerciseIndex),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
        ));
  }

  void _confirmDeleteExercise(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Exercise',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${_cleanExerciseName(exercise.name)}"?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeExercise(exerciseIndex);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exerciseIndex, int setIndex, TemplateSet set) {
    // Create a unique key for this set's controller
    final controllerKey = '${exerciseIndex}_$setIndex';
    
    // Initialize controllers if not exists
    _weightControllers.putIfAbsent(controllerKey, () {
      String initialText = '';
      if (set.targetWeight != null && set.targetWeight! > 0) {
        initialText = set.targetWeight! % 1 == 0
            ? set.targetWeight!.toInt().toString()
            : set.targetWeight.toString();
      }
      return TextEditingController(text: initialText);
    });
    
    _repsControllers.putIfAbsent(controllerKey, () {
      return TextEditingController(
        text: set.targetReps != null ? '${set.targetReps}' : '',
      );
    });

    return Dismissible(
      key: Key('template_set_${exerciseIndex}_$setIndex'),
      direction: _exercises[exerciseIndex].sets.length > 1
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: AppTheme.error,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        _removeSet(exerciseIndex, setIndex);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.textSecondary.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Set number
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${set.setNumber}',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Target weight input
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _weightControllers[controllerKey],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '-',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        _weightUnit,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    _hasChanges = true;
                    final weight = double.tryParse(value);
                    final exercise = _exercises[exerciseIndex];
                    final newSets = List<TemplateSet>.from(exercise.sets);
                    newSets[setIndex] = TemplateSet(
                      setNumber: set.setNumber,
                      targetWeight: weight,
                      targetReps: set.targetReps,
                    );
                    _exercises[exerciseIndex] = TemplateExercise(
                      name: exercise.name,
                      equipment: exercise.equipment,
                      sets: newSets,
                    );
                  },
                ),
              ),
            ),
            
            // Target reps input
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _repsControllers[controllerKey],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '-',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  onChanged: (value) {
                    _hasChanges = true;
                    final reps = int.tryParse(value);
                    final exercise = _exercises[exerciseIndex];
                    final newSets = List<TemplateSet>.from(exercise.sets);
                    newSets[setIndex] = TemplateSet(
                      setNumber: set.setNumber,
                      targetWeight: set.targetWeight,
                      targetReps: reps,
                    );
                    _exercises[exerciseIndex] = TemplateExercise(
                      name: exercise.name,
                      equipment: exercise.equipment,
                      sets: newSets,
                    );
                  },
                ),
              ),
            ),
            
            // Delete set button (only show if more than one set)
            SizedBox(
              width: 44,
              height: 40,
              child: _exercises[exerciseIndex].sets.length > 1
                  ? IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      onPressed: () => _removeSet(exerciseIndex, setIndex),
                      visualDensity: VisualDensity.compact,
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

// Superset selection page for templates (similar to SupersetSelectionPage)
class _TemplateSupersetSelectionPage extends StatefulWidget {
  final List<TemplateExercise> exercises;
  final int currentExerciseIndex;
  final Color Function(String supersetId) getColorForSuperset;
  final String Function(String name) cleanExerciseName;

  const _TemplateSupersetSelectionPage({
    required this.exercises,
    required this.currentExerciseIndex,
    required this.getColorForSuperset,
    required this.cleanExerciseName,
  });

  @override
  State<_TemplateSupersetSelectionPage> createState() => _TemplateSupersetSelectionPageState();
}

class _TemplateSupersetSelectionPageState extends State<_TemplateSupersetSelectionPage> {
  final Set<int> _selectedExerciseIndices = {};

  @override
  void initState() {
    super.initState();
    // Pre-select the current exercise
    _selectedExerciseIndices.add(widget.currentExerciseIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Create Superset',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selectedExerciseIndices.length >= 2
                ? () {
                    Navigator.pop(context, _selectedExerciseIndices.toList());
                  }
                : null,
            child: Text(
              'Create',
              style: TextStyle(
                color: _selectedExerciseIndices.length >= 2
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
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
            color: AppTheme.accent.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Select exercises for superset',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose 2 or more exercises to group together. Selected: ${_selectedExerciseIndices.length}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
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
                final isSelected = _selectedExerciseIndices.contains(index);
                final existingSuperset = exercise.supersetGroup;
                final supersetColor = existingSuperset != null 
                    ? widget.getColorForSuperset(existingSuperset) 
                    : const Color(0xFFFF9800);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent.withOpacity(0.15)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accent
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
                            ? AppTheme.accent.withOpacity(0.3)
                            : existingSuperset != null
                                ? supersetColor.withOpacity(0.15)
                                : AppTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        existingSuperset != null ? Icons.link : Icons.fitness_center,
                        color: isSelected 
                            ? AppTheme.accent 
                            : existingSuperset != null
                                ? supersetColor
                                : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      widget.cleanExerciseName(exercise.name),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
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
                            color: AppTheme.textSecondary,
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
                            _selectedExerciseIndices.add(index);
                          } else {
                            _selectedExerciseIndices.remove(index);
                          }
                        });
                      },
                      activeColor: AppTheme.accent,
                      checkColor: Colors.white,
                      side: BorderSide(color: AppTheme.textSecondary),
                    ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedExerciseIndices.remove(index);
                        } else {
                          _selectedExerciseIndices.add(index);
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
