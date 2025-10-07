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

  // Draft system - track pending operations
  final List<Exercise> _pendingExercisesToAdd = [];
  final List<ExerciseSet> _pendingSetsToAdd = [];
  final Set<int> _pendingExercisesToDelete = {};
  final Set<int> _pendingSetsToDelete = {};
  int _nextTempId = -1; // Negative IDs for temporary items

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
    // Always reload the workout data to ensure fresh state
    _loadWorkout();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Note: didChangeDependencies is called multiple times,
    // so we don't reload here to avoid performance issues
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    _workoutDateController.dispose();
    _clearControllers();
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    // Clear any existing state first to ensure complete reset
    _clearControllers();

    // Clear pending operations
    _pendingExercisesToAdd.clear();
    _pendingSetsToAdd.clear();
    _pendingExercisesToDelete.clear();
    _pendingSetsToDelete.clear();
    
    setState(() {
      _isLoading = true;
      _workout = null; // Clear current workout to force complete refresh
      _hasChanges = false; // Reset changes flag
    });

    try {
      // Always reload fresh data from database to prevent stale state
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

    // Clear existing controllers to prevent memory leaks and state persistence
    _clearControllers();

    for (final exercise in _workout!.exercises) {
      for (final set in exercise.sets) {
        // Clear PR flags during editing - they will be recalculated on save
        set.isPR = false;
        
        _weightControllers[set.id] = TextEditingController(
          text: set.weight.toString(),
        );
        _repsControllers[set.id] = TextEditingController(
          text: set.reps.toString(),
        );
      }
    }
  }

  void _clearControllers() {
    // Dispose existing controllers
    for (var controller in _weightControllers.values) {
      controller.dispose();
    }
    for (var controller in _repsControllers.values) {
      controller.dispose();
    }

    // Clear the maps
    _weightControllers.clear();
    _repsControllers.clear();
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  // PR flags are cleared when loading workout and recalculated on save
  // No need for individual PR flag removal during editing

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

  Future<void> _recalculateAllPRsForWorkout() async {
    if (_workout == null) return;

    try {
      // Get all unique exercise names in this workout
      final exerciseNames = _workout!.exercises.map((e) => e.name).toSet();

      // Recalculate PR status for each exercise
      for (final exerciseName in exerciseNames) {
        await _workoutService.recalculatePRStatusForExercise(exerciseName);
      }

      // Update local model with fresh PR status for all exercises
      for (final exerciseName in exerciseNames) {
        await _refreshLocalPRStatus(exerciseName);
      }
    } catch (e) {
      print('Error recalculating PRs for workout: $e');
      // Don't throw error - PR calculation failure shouldn't block save
    }
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

      // 1. Delete pending exercises and their sets
      for (final exerciseId in _pendingExercisesToDelete) {
        await _workoutService.deleteExercise(exerciseId);
      }

      // 2. Delete pending sets
      for (final setId in _pendingSetsToDelete) {
        await _workoutService.deleteSet(setId);
      }

      // 3. Add pending exercises
      final Map<int, int> tempIdToRealId = {};
      for (final tempExercise in _pendingExercisesToAdd) {
        final realExerciseId = await _workoutService.addExercise(
          widget.workoutId,
          tempExercise.name,
          tempExercise.equipment,
        );
        tempIdToRealId[tempExercise.id] = realExerciseId;

        // Update the exercise ID in the local model
        final exerciseIndex =
            _workout!.exercises.indexWhere((e) => e.id == tempExercise.id);
        if (exerciseIndex != -1) {
          _workout!.exercises[exerciseIndex] = Exercise(
            id: realExerciseId,
            workoutId: tempExercise.workoutId,
            name: tempExercise.name,
            equipment: tempExercise.equipment,
            finished: tempExercise.finished,
            sets: _workout!.exercises[exerciseIndex].sets,
          );
        }
      }

      // 4. Add pending sets (with updated exercise IDs)
      final Map<int, int> tempSetIdToRealId = {};
      for (final tempSet in _pendingSetsToAdd) {
        // Get the real exercise ID (might be newly created)
        int realExerciseId = tempSet.exerciseId;
        if (tempIdToRealId.containsKey(tempSet.exerciseId)) {
          realExerciseId = tempIdToRealId[tempSet.exerciseId]!;
        }

        final realSetId = await _workoutService.addSet(
          realExerciseId,
          tempSet.setNumber,
          tempSet.weight,
          tempSet.reps,
          tempSet.restTime,
        );
        tempSetIdToRealId[tempSet.id] = realSetId;

        // Mark set as completed if it has valid weight and reps data
        if (tempSet.weight > 0 && tempSet.reps > 0) {
          await _workoutService.updateSetStatus(realSetId, true);
        }

        // Update the set ID in the local model
        for (final exercise in _workout!.exercises) {
          final setIndex = exercise.sets.indexWhere((s) => s.id == tempSet.id);
          if (setIndex != -1) {
            exercise.sets[setIndex] = ExerciseSet(
              id: realSetId,
              exerciseId: realExerciseId,
              setNumber: tempSet.setNumber,
              weight: tempSet.weight,
              reps: tempSet.reps,
              restTime: tempSet.restTime,
              completed: tempSet.completed,
              isPR: tempSet.isPR,
            );
            break;
          }
        }
      }

      // 5. Update controllers with real IDs
      final Map<int, TextEditingController> newWeightControllers = {};
      final Map<int, TextEditingController> newRepsControllers = {};

      for (final entry in _weightControllers.entries) {
        final tempId = entry.key;
        final controller = entry.value;
        final realId = tempSetIdToRealId[tempId] ?? tempId;
        newWeightControllers[realId] = controller;
      }

      for (final entry in _repsControllers.entries) {
        final tempId = entry.key;
        final controller = entry.value;
        final realId = tempSetIdToRealId[tempId] ?? tempId;
        newRepsControllers[realId] = controller;
      }

      _weightControllers.clear();
      _repsControllers.clear();
      _weightControllers.addAll(newWeightControllers);
      _repsControllers.addAll(newRepsControllers);

      // 6. Update all sets with current values (existing sets only)
      for (final exercise in _workout!.exercises) {
        for (final set in exercise.sets) {
          // Skip sets that are pending deletion or newly added (already saved above)
          if (_pendingSetsToDelete.contains(set.id) ||
              tempSetIdToRealId.containsKey(set.id)) {
            continue;
          }

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

        // Update exercise name if needed (existing exercises only)
        if (!tempIdToRealId.containsKey(exercise.id)) {
          await _workoutService.updateExercise(
            exercise.id,
            exercise.name,
            exercise.equipment,
          );
        }
      }

      // 7. Clear all pending operations
      _pendingExercisesToAdd.clear();
      _pendingSetsToAdd.clear();
      _pendingExercisesToDelete.clear();
      _pendingSetsToDelete.clear();

      // 8. Recalculate PR flags for the entire workout
      // This ensures all PRs are accurate and no conflicts exist
      await _recalculateAllPRsForWorkout();

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

      // Notify the workout list that data has changed
      WorkoutService.workoutsUpdatedNotifier.value =
          !WorkoutService.workoutsUpdatedNotifier.value;

      // Navigate back to details page
      if (mounted) {
        Navigator.pop(
            context); // Just pop back, details page will reload from database
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

    // Note: PR flags will be recalculated for the entire workout when saving
    // No individual PR recalculation here to avoid conflicts
  }

  Future<void> _addExercise() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExerciseSelectionPage(),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>>) {
      // Add multiple exercises to pending list (not database)
      for (final exerciseData in result) {
        final tempExercise = Exercise(
          id: _nextTempId--, // Use negative temp ID
          workoutId: widget.workoutId,
          name: exerciseData['name'],
          equipment: exerciseData['equipment'] ?? '',
          finished: false,
          sets: [],
        );
        
        _pendingExercisesToAdd.add(tempExercise);

        // Add to local model for UI
        setState(() {
          _workout!.exercises.add(tempExercise);
        });
      }
      _markAsChanged();
    } else if (result != null && result is Map<String, dynamic>) {
      // Add single exercise to pending list (not database)
      final tempExercise = Exercise(
        id: _nextTempId--, // Use negative temp ID
        workoutId: widget.workoutId,
        name: result['name'],
        equipment: result['equipment'] ?? '',
        finished: false,
        sets: [],
      );
      
      _pendingExercisesToAdd.add(tempExercise);
      
      setState(() {
        _workout!.exercises.add(tempExercise);
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
      // Create new set with temporary ID (not saved to database yet)
      final tempSetId = _nextTempId--;
      final newSet = ExerciseSet(
        id: tempSetId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        weight: 0.0,
        reps: 0,
        restTime: 150,
        completed: true, // Mark as completed since this is an edit session
        isPR: false,
      );

      // Add to pending list
      _pendingSetsToAdd.add(newSet);

      // Add to local model for UI
      setState(() {
        exercise.sets.add(newSet);
      });

      // Initialize controllers for the new set
      _weightControllers[tempSetId] = TextEditingController(text: '0');
      _repsControllers[tempSetId] = TextEditingController(text: '0');

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
      // Check if this is a temporary set (negative ID) or existing set
      if (setId < 0) {
        // Remove from pending sets to add
        _pendingSetsToAdd.removeWhere((set) => set.id == setId);
      } else {
        // Mark existing set for deletion
        _pendingSetsToDelete.add(setId);
      }
      
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
      // Check if this is a temporary exercise (negative ID) or existing exercise
      if (exerciseId < 0) {
        // Remove from pending exercises to add
        _pendingExercisesToAdd
            .removeWhere((exercise) => exercise.id == exerciseId);
      } else {
        // Mark existing exercise for deletion
        _pendingExercisesToDelete.add(exerciseId);
      }
      
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