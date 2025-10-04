import 'package:flutter/material.dart';
import 'package:mental_warior/models/workouts.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/pages/workout/exercise_selection_page.dart';

class WorkoutEditPage extends StatefulWidget {
  final int workoutId;

  const WorkoutEditPage({
    super.key,
    required this.workoutId,
  });

  @override
  WorkoutEditPageState createState() => WorkoutEditPageState();
}

class WorkoutEditPageState extends State<WorkoutEditPage> {
  final WorkoutService _workoutService = WorkoutService();
  Workout? _workout;
  bool _isLoading = true;
  bool _hasChanges = false;

  // Controllers for editing
  final Map<int, TextEditingController> _weightControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};
  late TextEditingController _workoutNameController;
  late TextEditingController _workoutDateController;

  // Theme colors (matching workout session page)
  final Color _backgroundColor = const Color(0xFF1A1B1E); // Dark background
  final Color _surfaceColor = const Color(0xFF26272B); // Surface for cards
  final Color _cardColor = const Color(0xFF26272B); // Card color
  final Color _primaryColor = const Color(0xFF3F8EFC); // Blue accent
  final Color _successColor = const Color(0xFF4CAF50); // Green for success
  final Color _dangerColor = const Color(0xFFE53935); // Red for cancel/danger
  final Color _textPrimaryColor = Colors.white; // Main text
  final Color _textSecondaryColor = const Color(0xFFBBBBBB); // Secondary text
  final Color _inputBgColor = const Color(0xFF303136); // Input background

  @override
  void initState() {
    super.initState();
    _workoutNameController = TextEditingController();
    _workoutDateController = TextEditingController();
    _loadWorkout();
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    _workoutDateController.dispose();
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _repsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final workout = await _workoutService.getWorkout(widget.workoutId);
      setState(() {
        _workout = workout;
        _isLoading = false;
      });

      if (_workout != null) {
        _workoutNameController.text = _workout!.name;
        _workoutDateController.text = _workout!.date;
        _initializeControllers();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading workout: $e')),
        );
      }
    }
  }

  void _initializeControllers() {
    if (_workout == null) return;

    for (final exercise in _workout!.exercises) {
      for (final set in exercise.sets) {
        _weightControllers[set.id] = TextEditingController(
          text: set.weight.toString(),
        );
        _repsControllers[set.id] = TextEditingController(
          text: set.reps.toString(),
        );
      }
    }
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _removePRFlagIfSet(ExerciseSet set) {
    if (set.isPR) {
      setState(() {
        set.isPR = false;
      });
    }
  }

  Future<void> _refreshLocalPRStatus(String exerciseName) async {
    if (_workout == null) return;
    
    final db = await DatabaseService.instance.database;
    
    // Get updated PR status for all sets in this exercise
    final result = await db.rawQuery('''
      SELECT es.id, es.isPR
      FROM exercise_sets es
      INNER JOIN exercises e ON es.exerciseId = e.id
      WHERE e.name = ? AND e.workoutId = ?
    ''', [exerciseName, widget.workoutId]);
    
    // Update local model
    setState(() {
      for (final exercise in _workout!.exercises) {
        if (exercise.name == exerciseName) {
          for (final set in exercise.sets) {
            final setData = result.firstWhere(
              (row) => row['id'] == set.id,
              orElse: () => {'isPR': 0},
            );
            set.isPR = (setData['isPR'] as int) == 1;
          }
        }
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_workout == null) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
          ),
        ),
      );

      // Update workout name and date
      await _workoutService.updateWorkout(
        widget.workoutId,
        _workoutNameController.text,
        _workoutDateController.text,
        _workout!.duration, // Keep existing duration
      );

      // Update all sets
      for (final exercise in _workout!.exercises) {
        for (final set in exercise.sets) {
          final weightController = _weightControllers[set.id];
          final repsController = _repsControllers[set.id];

          if (weightController != null && repsController != null) {
            final weight = double.tryParse(weightController.text) ?? set.weight;
            final reps = int.tryParse(repsController.text) ?? set.reps;

            // Update set data in database only if values changed
            if (weight != set.weight || reps != set.reps) {
              await _updateSetData(set.id, weight, reps);
              // Update local model to reflect changes
              set.weight = weight;
              set.reps = reps;
            }
          }
        }

        // Update exercise name if needed
        await _workoutService.updateExercise(
          exercise.id,
          exercise.name,
          exercise.equipment,
        );
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Workout updated successfully'),
            backgroundColor: _successColor,
          ),
        );
      }

      setState(() {
        _hasChanges = false;
      });

      // Navigate back to details page
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate changes were saved
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: _dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _updateSetData(int setId, double weight, int reps) async {
    // Calculate volume for potential PR checking
    final volume = weight * reps;

    // Update the set in the database directly using the database service
    final db = await DatabaseService.instance.database;
    await db.update(
      'exercise_sets',
      {
        'weight': weight,
        'reps': reps,
        'volume': volume,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );

    // Get the exercise name for PR recalculation
    final exerciseResult = await db.rawQuery('''
      SELECT e.name 
      FROM exercise_sets es
      INNER JOIN exercises e ON es.exerciseId = e.id
      WHERE es.id = ?
    ''', [setId]);

    if (exerciseResult.isNotEmpty) {
      final exerciseName = exerciseResult.first['name'] as String;
      // Recalculate PR status for this exercise
      await _workoutService.recalculatePRStatusForExercise(exerciseName);
      
      // Update local model with new PR status
      await _refreshLocalPRStatus(exerciseName);
    }
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseSelectionPage(),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>>) {
      // Add multiple exercises
      for (final exerciseData in result) {
        final exerciseId = await _workoutService.addExercise(
          widget.workoutId,
          exerciseData['name'],
          exerciseData['equipment'] ?? '',
        );
        
        // Add to local model
        final newExercise = Exercise(
          id: exerciseId,
          workoutId: widget.workoutId,
          name: exerciseData['name'],
          equipment: exerciseData['equipment'] ?? '',
          finished: false,
          sets: [],
        );
        
        setState(() {
          _workout!.exercises.add(newExercise);
        });
      }
      _markAsChanged();
    } else if (result != null && result is Map<String, dynamic>) {
      // Add single exercise
      final exerciseId = await _workoutService.addExercise(
        widget.workoutId,
        result['name'],
        result['equipment'] ?? '',
      );
      
      // Add to local model
      final newExercise = Exercise(
        id: exerciseId,
        workoutId: widget.workoutId,
        name: result['name'],
        equipment: result['equipment'] ?? '',
        finished: false,
        sets: [],
      );
      
      setState(() {
        _workout!.exercises.add(newExercise);
      });
      _markAsChanged();
    }
  }

  Future<void> _addSetToExercise(int exerciseId) async {
    final exerciseIndex = _workout!.exercises.indexWhere((e) => e.id == exerciseId);
    if (exerciseIndex == -1) return;

    final exercise = _workout!.exercises[exerciseIndex];
    final setNumber = exercise.sets.length + 1;

    try {
      // Add set to database
      final setId = await _workoutService.addSet(
        exerciseId,
        setNumber,
        0.0, // Default weight
        0, // Default reps
        150, // Default rest time (2:30)
      );

      // Create new set locally
      final newSet = ExerciseSet(
        id: setId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        weight: 0.0,
        reps: 0,
        restTime: 150,
        completed: false,
        isPR: false,
      );

      // Add to local model
      setState(() {
        exercise.sets.add(newSet);
      });

      // Initialize controllers for the new set
      _weightControllers[setId] = TextEditingController(text: '0');
      _repsControllers[setId] = TextEditingController(text: '0');

      _markAsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding set: $e')),
        );
      }
    }
  }

  Future<void> _deleteSet(int exerciseId, int setId) async {
    try {
      // Delete from database
      await _workoutService.deleteSet(setId);
      
      // Remove from local model
      final exerciseIndex = _workout!.exercises.indexWhere((e) => e.id == exerciseId);
      if (exerciseIndex != -1) {
        final exercise = _workout!.exercises[exerciseIndex];
        final setIndex = exercise.sets.indexWhere((s) => s.id == setId);
        
        setState(() {
          // Remove the set from our local state
          _workout!.exercises[exerciseIndex].sets.removeAt(setIndex);
          
          // Since we can't directly modify the setNumber (it's final), we need to
          // create new set objects with updated set numbers
          if (exercise.sets.length > 0) {
            final List<ExerciseSet> updatedSets = [];
            
            // Create new set objects with correct numbers
            for (int i = 0; i < exercise.sets.length; i++) {
              final oldSet = exercise.sets[i];
              updatedSets.add(ExerciseSet(
                id: oldSet.id,
                exerciseId: oldSet.exerciseId,
                setNumber: i + 1, // New sequential set number
                weight: oldSet.weight,
                reps: oldSet.reps,
                restTime: oldSet.restTime,
                completed: oldSet.completed,
                isPR: oldSet.isPR,
              ));
            }
            
            // Replace the sets list with our updated one
            _workout!.exercises[exerciseIndex].sets.clear();
            _workout!.exercises[exerciseIndex].sets.addAll(updatedSets);
            
            // Update controllers for the renumbered sets
            final Map<int, TextEditingController> newWeightControllers = {};
            final Map<int, TextEditingController> newRepsControllers = {};
            
            for (final set in updatedSets) {
              final oldWeightController = _weightControllers[set.id];
              final oldRepsController = _repsControllers[set.id];
              
              if (oldWeightController != null && oldRepsController != null) {
                newWeightControllers[set.id] = oldWeightController;
                newRepsControllers[set.id] = oldRepsController;
              }
            }
            
            // Update the controller maps
            _weightControllers.clear();
            _repsControllers.clear();
            _weightControllers.addAll(newWeightControllers);
            _repsControllers.addAll(newRepsControllers);
          }
        });
      }
      
      // Remove controllers
      _weightControllers[setId]?.dispose();
      _repsControllers[setId]?.dispose();
      _weightControllers.remove(setId);
      _repsControllers.remove(setId);

      _markAsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting set: $e')),
        );
      }
    }
  }

  Future<void> _deleteExercise(int exerciseId) async {
    try {
      // Delete from database
      await _workoutService.deleteExercise(exerciseId);
      
      // Remove from local model
      final exerciseIndex = _workout!.exercises.indexWhere((e) => e.id == exerciseId);
      if (exerciseIndex != -1) {
        final exercise = _workout!.exercises[exerciseIndex];
        
        // Clean up controllers for all sets in this exercise
        for (final set in exercise.sets) {
          _weightControllers[set.id]?.dispose();
          _repsControllers[set.id]?.dispose();
          _weightControllers.remove(set.id);
          _repsControllers.remove(set.id);
        }
        
        setState(() {
          _workout!.exercises.removeAt(exerciseIndex);
        });
      }
      
      _markAsChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting exercise: $e')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Unsaved Changes',
          style: TextStyle(color: _textPrimaryColor),
        ),
        content: Text(
          'You have unsaved changes. Do you want to discard them?',
          style: TextStyle(color: _textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: _textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Discard',
              style: TextStyle(color: _dangerColor),
            ),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _showEditNameDialog() async {
    final dialogController = TextEditingController(text: _workout!.name);
    String? result;

    try {
      result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardColor,
          title: Text(
            'Edit Workout Name',
            style: TextStyle(color: _textPrimaryColor),
          ),
          content: TextField(
            controller: dialogController,
            style: TextStyle(color: _textPrimaryColor),
            decoration: InputDecoration(
              labelText: 'Workout Name',
              labelStyle: TextStyle(color: _textSecondaryColor),
              filled: true,
              fillColor: _inputBgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: _textSecondaryColor),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, dialogController.text),
              child: Text(
                'Save',
                style: TextStyle(color: _primaryColor),
              ),
            ),
          ],
        ),
      );
    } finally {
      dialogController.dispose();
    }

    if (result != null && result.isNotEmpty && result != _workout!.name) {
      // Update the workout name in the database
      setState(() {
        _workoutNameController.text = result!;
      });
      _markAsChanged();
    }
  }

  Widget _buildEmptyExercisesView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center,
                size: 48,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No exercises yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first exercise to start editing this workout',
              style: TextStyle(
                fontSize: 14,
                color: _textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Exercise'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _surfaceColor,
          elevation: 0,
          title: Text(
            'Edit Workout',
            style: TextStyle(
              color: _textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _textPrimaryColor),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: _saveChanges,
                  style: TextButton.styleFrom(
                    backgroundColor: _primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                ),
              )
            : _workout == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: _textSecondaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Workout not found',
                          style: TextStyle(
                            fontSize: 20,
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Workout header section (similar to session page)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _surfaceColor,
                          border: Border(
                            bottom: BorderSide(
                              color: _textSecondaryColor.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showEditNameDialog(),
                                    child: Text(
                                      _workout!.name,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showEditNameDialog(),
                                  icon: Icon(
                                    Icons.edit,
                                    color: _textSecondaryColor,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _workout!.date,
                              style: TextStyle(
                                fontSize: 16,
                                color: _textSecondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Exercises list
                      Expanded(
                        child: _workout!.exercises.isEmpty
                            ? _buildEmptyExercisesView()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _workout!.exercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = _workout!.exercises[index];
                                  return _buildExerciseCard(exercise);
                                },
                              ),
                      ),
                    ],
                  ),
        floatingActionButton: !_isLoading && _workout != null
            ? FloatingActionButton(
                onPressed: _addExercise,
                backgroundColor: _primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _textSecondaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header (similar to session page)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimaryColor,
                      ),
                    ),
                    if (exercise.equipment.isNotEmpty)
                      Text(
                        exercise.equipment,
                        style: TextStyle(
                          fontSize: 14,
                          color: _textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              // Add set button (similar to session page)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => _addSetToExercise(exercise.id),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: _primaryColor,
                    size: 24,
                  ),
                  tooltip: 'Add Set',
                ),
              ),
              // Menu button
              PopupMenuButton(
                color: _cardColor,
                icon: Icon(Icons.more_vert, color: _textSecondaryColor),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete_exercise',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: _dangerColor),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Exercise',
                          style: TextStyle(color: _dangerColor),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete_exercise') {
                    _deleteExercise(exercise.id);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sets section
          if (exercise.sets.isNotEmpty) ...[
            Text(
              'Sets (${exercise.sets.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            
            // Sets list (similar to session page layout)
            Column(
              children: exercise.sets.asMap().entries.map((entry) {
                final index = entry.key;
                final set = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSetRow(exercise, set, index + 1),
                );
              }).toList(),
            ),
          ] else
            // Empty state for sets
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _textSecondaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _textSecondaryColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _textSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No sets yet',
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addSetToExercise(exercise.id),
                    icon: Icon(Icons.add, color: _primaryColor, size: 18),
                    label: Text(
                      'Add Set',
                      style: TextStyle(color: _primaryColor),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetRow(Exercise exercise, ExerciseSet set, int setNumber) {
    final weightController = _weightControllers[set.id];
    final repsController = _repsControllers[set.id];

    if (weightController == null || repsController == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: set.isPR
            ? Border.all(color: Colors.amber.withOpacity(0.4), width: 1.5)
            : Border.all(color: _textSecondaryColor.withOpacity(0.08), width: 1),
      ),
      child: Column(
        children: [
          // Main set content row
          Row(
            children: [
              // Set number badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    setNumber.toString(),
                    style: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Weight and reps inputs
              Expanded(
                child: Row(
                  children: [
                    // Weight input
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weight',
                            style: TextStyle(
                              color: _textSecondaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: _inputBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TextField(
                              controller: weightController,
                              style: TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: _textSecondaryColor.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _removePRFlagIfSet(set);
                                _markAsChanged();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Reps input
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reps',
                            style: TextStyle(
                              color: _textSecondaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: _inputBgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TextField(
                              controller: repsController,
                              style: TextStyle(
                                color: _textPrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                hintText: '0',
                                hintStyle: TextStyle(
                                  color: _textSecondaryColor.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _removePRFlagIfSet(set);
                                _markAsChanged();
                                // Update local model immediately for responsive UI
                                final reps = int.tryParse(value) ?? 0;
                                set.reps = reps;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // Delete button
              IconButton(
                onPressed: () => _deleteSet(exercise.id, set.id),
                icon: Icon(Icons.delete_outline, color: _dangerColor, size: 18),
                tooltip: 'Delete Set',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          
          // PR badge if applicable
          if (set.isPR)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Personal Record',
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}