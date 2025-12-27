import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';
import 'package:mental_warior/pages/workout/exercise_detail_page.dart';
import 'package:mental_warior/pages/workout/custom_exercise_detail_page.dart';

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

  // Theme colors (matching workout_session_page)
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _dangerColor = const Color(0xFFE53935);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);
  final Color _inputBgColor = const Color(0xFF303136);
  
  bool _showWeightInLbs = false;
  String get _weightUnit => _showWeightInLbs ? 'lbs' : 'kg';

  @override
  void initState() {
    super.initState();
    _loadWeightUnit();
    _nameController.text = widget.initialName ?? 'New Template';
    if (widget.templateId != null) {
      _loadTemplate();
    }
  }

  Future<void> _loadWeightUnit() async {
    final useLbs = await SettingsService().getShowWeightInLbs();
    if (mounted) {
      setState(() => _showWeightInLbs = useLbs);
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
        backgroundColor: _surfaceColor,
        title: const Text('Discard changes?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _dangerColor),
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
      setState(() {
        _hasChanges = true;
        
        // Handle both List and Map return types
        if (result is List) {
          for (final exercise in result) {
            if (exercise is Map<String, dynamic>) {
              _exercises.add(TemplateExercise(
                name: exercise['name'] ?? 'Unknown Exercise',
                equipment: exercise['equipment'] ?? '',
                sets: [TemplateSet(setNumber: 1)],
              ));
            }
          }
        } else if (result is Map<String, dynamic>) {
          _exercises.add(TemplateExercise(
            name: result['name'] ?? 'Unknown Exercise',
            equipment: result['equipment'] ?? '',
            sets: [TemplateSet(setNumber: 1)],
          ));
        }
      });
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _hasChanges = true;
      _exercises.removeAt(index);
    });
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      _hasChanges = true;
      final exercise = _exercises[exerciseIndex];
      final newSetNumber = exercise.sets.length + 1;
      // Use rest time from existing sets, or default
      final restTime = exercise.sets.isNotEmpty ? exercise.sets.first.restTime : 150;
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
      if (newIndex > oldIndex) newIndex--;
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

  void _showSetRestDialog(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    final currentRestTime = exercise.sets.isNotEmpty ? exercise.sets.first.restTime : 150;
    
    int minutes = currentRestTime ~/ 60;
    int seconds = currentRestTime % 60;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _surfaceColor,
          title: Text('Set Rest Time', style: TextStyle(color: _textPrimaryColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rest time between sets',
                style: TextStyle(color: _textSecondaryColor),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minutes
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_drop_up, color: _primaryColor, size: 32),
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
                          color: _inputBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$minutes',
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down, color: _primaryColor, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            if (minutes > 0) minutes--;
                          });
                        },
                      ),
                      Text('min', style: TextStyle(color: _textSecondaryColor)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: _textPrimaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Seconds
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_drop_up, color: _primaryColor, size: 32),
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
                          color: _inputBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          seconds.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_drop_down, color: _primaryColor, size: 32),
                        onPressed: () {
                          setDialogState(() {
                            seconds = (seconds - 15 + 60) % 60;
                          });
                        },
                      ),
                      Text('sec', style: TextStyle(color: _textSecondaryColor)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
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
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.keyboard_arrow_down,
                color: _textPrimaryColor, size: 28),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _nameController,
              style: TextStyle(
                color: _textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Template Name',
                hintStyle: TextStyle(
                  color: _textSecondaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              onChanged: (_) => _hasChanges = true,
            ),
          ),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.check, color: _isLoading ? Colors.grey : _successColor),
              label: Text(
                'Save',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : _successColor,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExercise,
          backgroundColor: _primaryColor,
          icon: const Icon(Icons.add),
          label: const Text('Add Exercise'),
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
            color: _textSecondaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No exercises yet',
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: Icon(Icons.add, color: _primaryColor),
            label: Text(
              'Add Your First Exercise',
              style: TextStyle(color: _primaryColor),
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
    
    return RepaintBoundary(
      key: ValueKey(exerciseIndex),
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
                  color: _surfaceColor,
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
                            child: Icon(Icons.drag_handle, color: _textSecondaryColor),
                          ),
                          const SizedBox(width: 12),
                          // Exercise name (tappable)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _viewExerciseDetails(exercise),
                              child: Text(
                                _cleanExerciseName(exercise.name),
                                style: TextStyle(
                                  color: _textPrimaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          // Options menu
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: _textSecondaryColor),
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
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return <PopupMenuEntry<String>>[
                                if (!isInSuperset)
                                  PopupMenuItem<String>(
                                    value: 'superset',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.link, color: _primaryColor),
                                      title: Text('Create Superset',
                                          style: TextStyle(color: _textPrimaryColor)),
                                    ),
                                  )
                                else
                                  PopupMenuItem<String>(
                                    value: 'remove_superset',
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.link_off, color: _warningColor),
                                      title: Text('Remove from Superset',
                                          style: TextStyle(color: _textPrimaryColor)),
                                    ),
                                  ),
                                PopupMenuItem<String>(
                                  value: 'rest_time',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.timer, color: _primaryColor),
                                    title: Text('Set Rest Time',
                                        style: TextStyle(color: _textPrimaryColor)),
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.delete, color: _dangerColor),
                                    title: Text('Delete Exercise',
                                        style: TextStyle(color: _textPrimaryColor)),
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
                          style: TextStyle(color: _textSecondaryColor, fontSize: 12),
                        ),
                      ),
                    
                    // Rest time display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => _showSetRestDialog(exerciseIndex),
                        child: Row(
                          children: [
                            Icon(Icons.timer, size: 14, color: _textSecondaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Rest: ${restMinutes > 0 ? '${restMinutes}m ' : ''}${restSeconds}s',
                              style: TextStyle(color: _textSecondaryColor, fontSize: 12),
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
                                  color: _textSecondaryColor,
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
                                  color: _textSecondaryColor,
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
                            foregroundColor: _primaryColor,
                            side: BorderSide(color: _primaryColor),
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
    );
  }

  void _confirmDeleteExercise(int exerciseIndex) {
    final exercise = _exercises[exerciseIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text('Delete Exercise', style: TextStyle(color: _textPrimaryColor)),
        content: Text(
          'Are you sure you want to delete "${_cleanExerciseName(exercise.name)}"?',
          style: TextStyle(color: _textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondaryColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
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
        color: _dangerColor,
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
              color: _textSecondaryColor.withOpacity(0.1),
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
                color: _primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${set.setNumber}',
                style: TextStyle(
                  color: _primaryColor,
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
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: _inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '-',
                    hintStyle: TextStyle(
                      color: _textSecondaryColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    suffix: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        _weightUnit,
                        style: TextStyle(color: _textSecondaryColor),
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
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: _inputBgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    hintText: '-',
                    hintStyle: TextStyle(
                      color: _textSecondaryColor.withOpacity(0.6),
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
                        color: _dangerColor,
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

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);

  @override
  void initState() {
    super.initState();
    // Pre-select the current exercise
    _selectedExerciseIndices.add(widget.currentExerciseIndex);
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
            onPressed: _selectedExerciseIndices.length >= 2
                ? () {
                    Navigator.pop(context, _selectedExerciseIndices.toList());
                  }
                : null,
            child: Text(
              'Create',
              style: TextStyle(
                color: _selectedExerciseIndices.length >= 2
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
                  'Choose 2 or more exercises to group together. Selected: ${_selectedExerciseIndices.length}',
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
                final isSelected = _selectedExerciseIndices.contains(index);
                final existingSuperset = exercise.supersetGroup;
                final supersetColor = existingSuperset != null 
                    ? widget.getColorForSuperset(existingSuperset) 
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
                      widget.cleanExerciseName(exercise.name),
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
                            _selectedExerciseIndices.add(index);
                          } else {
                            _selectedExerciseIndices.remove(index);
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
