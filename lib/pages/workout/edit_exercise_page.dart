import 'package:flutter/material.dart';
import 'package:mental_warior/utils/app_theme.dart';
import '../../services/database_services.dart';

class EditExercisePage extends StatefulWidget {
  final Map<String, dynamic> exerciseData;

  const EditExercisePage({super.key, required this.exerciseData});

  @override
  State<EditExercisePage> createState() => _EditExercisePageState();
}

class _EditExercisePageState extends State<EditExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();

  String _selectedEquipment = 'None';
  String _selectedPrimaryMuscle = 'Chest';
  final List<String> _selectedSecondaryMuscles = [];
  final List<String> _instructionSteps = [];

  final List<String> _equipmentOptions = const [
    'None',
    'Barbell',
    'Dumbbell',
    'Machine',
    'Cable',
    'Body Weight',
    'Kettlebell',
    'Resistance Band',
    'Other',
  ];

  final List<String> _muscleOptions = const [
    'Chest',
    'Back',
    'Legs',
    'Arms',
    'Shoulders',
    'Core',
    'Quadriceps',
    'Hamstrings',
    'Calves',
    'Glutes',
    'Biceps',
    'Triceps',
    'Forearms',
    'Delts',
    'Abdominals',
    'Neck',
    'Adductors',
    'Traps',
    'Lats',
  ];

  @override
  void initState() {
    super.initState();
    // Prefill from provided data
    final data = widget.exerciseData;
    _nameController.text = (data['name'] ?? '').toString();
    _selectedEquipment = (data['equipment'] ?? 'None').toString();
    _selectedPrimaryMuscle = (data['type'] ?? 'Chest').toString();

    final secondaryMuscles = data['secondaryMuscles'];
    if (secondaryMuscles is List) {
      _selectedSecondaryMuscles.addAll(secondaryMuscles.cast<String>());
    } else if (secondaryMuscles is String && secondaryMuscles.isNotEmpty) {
      _selectedSecondaryMuscles
          .addAll(secondaryMuscles.split(',').map((e) => e.trim()));
    }

    final description = (data['description'] ?? '').toString();
    if (description.isNotEmpty) {
      final steps = description
          .split(RegExp(r'\n+|\r+'))
          .map((s) => s.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
      _instructionSteps.addAll(steps);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _addInstructionStep() {
    if (_instructionController.text.trim().isNotEmpty) {
      setState(() {
        _instructionSteps.add(_instructionController.text.trim());
        _instructionController.clear();
      });
    }
  }

  void _removeInstructionStep(int index) {
    setState(() {
      _instructionSteps.removeAt(index);
    });
  }

  void _editInstructionStep(int index) {
    _instructionController.text = _instructionSteps[index];
    setState(() {
      _instructionSteps.removeAt(index);
    });
  }

  void _toggleSecondaryMuscle(String muscle) {
    setState(() {
      if (_selectedSecondaryMuscles.contains(muscle)) {
        _selectedSecondaryMuscles.remove(muscle);
      } else {
        _selectedSecondaryMuscles.add(muscle);
      }
    });
  }

  void _onSavePressed() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Update Exercise?',
                  style: AppTheme.headlineMedium,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will update the exercise and ALL previous instances in your workout history.',
                style: AppTheme.bodyMedium.copyWith(
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is irreversible',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Updating exercise...',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final customExerciseService = CustomExerciseService();
      final workoutService = WorkoutService();

      // Combine instruction steps into formatted description
      final description = _instructionSteps.isEmpty
          ? ''
          : _instructionSteps
              .asMap()
              .entries
              .map((entry) => '${entry.key + 1}. ${entry.value}')
              .join('\n');

      final exerciseId = widget.exerciseData['id'];
      final oldName = widget.exerciseData['name'].toString();
      final newName = _nameController.text.trim();

      // Update the custom exercise in the database
      await customExerciseService.updateCustomExercise(
        id: exerciseId,
        name: newName,
        equipment: _selectedEquipment,
        type: _selectedPrimaryMuscle,
        description: description,
        secondaryMuscles: _selectedSecondaryMuscles,
      );

      // Update all workout history instances
      final workouts = await workoutService.getWorkouts();
      int updatedCount = 0;

      for (final workout in workouts) {
        for (final exercise in workout.exercises) {
          // Clean exercise name for comparison
          String cleanExerciseName = exercise.name
              .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
              .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
              .trim();

          // Check if this exercise matches the old name
          if (cleanExerciseName.toLowerCase() == oldName.toLowerCase()) {
            // Extract the API ID marker if present
            final apiIdMatch = RegExp(r'##API_ID:([^#]+)##').firstMatch(exercise.name);
            final customIdMatch = RegExp(r'##CUSTOM:([^#]+)##').firstMatch(exercise.name);
            
            String updatedName = newName;
            if (apiIdMatch != null) {
              updatedName = '$newName##API_ID:${apiIdMatch.group(1)}##';
            } else if (customIdMatch != null) {
              updatedName = '$newName##CUSTOM:${customIdMatch.group(1)}##';
            }

            // Update the exercise in the workout
            await workoutService.updateExercise(
              exercise.id,
              updatedName,
              _selectedEquipment,
            );
            updatedCount++;
          }
        }
      }

      // Update active workout if present
      final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
      if (activeWorkout != null) {
        final workoutData = activeWorkout['workoutData'] as Map<String, dynamic>?;
        if (workoutData != null && workoutData['exercises'] != null) {
          final exercises = workoutData['exercises'] as List;
          bool activeWorkoutUpdated = false;
          
          for (var exercise in exercises) {
            String exerciseName = exercise['name'] ?? '';
            // Clean exercise name for comparison
            String cleanExerciseName = exerciseName
                .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
                .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
                .trim();
            
            // Check if this exercise matches the old name
            if (cleanExerciseName.toLowerCase() == oldName.toLowerCase()) {
              // Extract the API ID marker if present
              final apiIdMatch = RegExp(r'##API_ID:([^#]+)##').firstMatch(exerciseName);
              final customIdMatch = RegExp(r'##CUSTOM:([^#]+)##').firstMatch(exerciseName);
              
              String updatedName = newName;
              if (apiIdMatch != null) {
                updatedName = '$newName##API_ID:${apiIdMatch.group(1)}##';
              } else if (customIdMatch != null) {
                updatedName = '$newName##CUSTOM:${customIdMatch.group(1)}##';
              }
              
              exercise['name'] = updatedName;
              exercise['equipment'] = _selectedEquipment;
              activeWorkoutUpdated = true;
            }
          }
          
          if (activeWorkoutUpdated) {
            // Update the notifier to trigger UI refresh
            WorkoutService.activeWorkoutNotifier.value = Map.from(activeWorkout);
          }
        }
      }

      // Update temporary workouts if any
      final tempWorkouts = WorkoutService.tempWorkoutsNotifier.value;
      if (tempWorkouts.isNotEmpty) {
        bool tempWorkoutsUpdated = false;
        
        for (var workoutEntry in tempWorkouts.entries) {
          final workoutData = workoutEntry.value;
          if (workoutData['exercises'] != null) {
            final exercises = workoutData['exercises'] as List;
            
            for (var exercise in exercises) {
              String exerciseName = exercise['name'] ?? '';
              // Clean exercise name for comparison
              String cleanExerciseName = exerciseName
                  .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
                  .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
                  .trim();
              
              // Check if this exercise matches the old name
              if (cleanExerciseName.toLowerCase() == oldName.toLowerCase()) {
                // Extract the API ID marker if present
                final apiIdMatch = RegExp(r'##API_ID:([^#]+)##').firstMatch(exerciseName);
                final customIdMatch = RegExp(r'##CUSTOM:([^#]+)##').firstMatch(exerciseName);
                
                String updatedName = newName;
                if (apiIdMatch != null) {
                  updatedName = '$newName##API_ID:${apiIdMatch.group(1)}##';
                } else if (customIdMatch != null) {
                  updatedName = '$newName##CUSTOM:${customIdMatch.group(1)}##';
                }
                
                exercise['name'] = updatedName;
                exercise['equipment'] = _selectedEquipment;
                tempWorkoutsUpdated = true;
              }
            }
          }
        }
        
        if (tempWorkoutsUpdated) {
          // Update the notifier to trigger UI refresh
          WorkoutService.tempWorkoutsNotifier.value = Map.from(tempWorkouts);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Exercise updated successfully!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (updatedCount > 0)
                        Text(
                          'Updated $updatedCount workout ${updatedCount == 1 ? 'entry' : 'entries'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Wait a moment for the snackbar to show before popping
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          Navigator.of(context).pop(true); // Return to detail page with success
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        String errorMessage = 'An error occurred while updating the exercise';
        if (e.toString().contains('UNIQUE constraint failed')) {
          errorMessage = 'An exercise with this name already exists';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Edit Exercise',
          style: AppTheme.headlineMedium,
        ),
        backgroundColor: AppTheme.surface,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Exercise Name'),
              const SizedBox(height: 8),
              _buildTextFormField(
                controller: _nameController,
                hintText: 'Enter exercise name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an exercise name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Equipment'),
              const SizedBox(height: 8),
              _buildEquipmentSelector(),
              const SizedBox(height: 24),

              _buildSectionTitle('Primary Muscle Group'),
              const SizedBox(height: 8),
              _buildPrimaryMuscleSelector(),
              const SizedBox(height: 24),

              _buildSectionTitle('Secondary Muscle Groups (Optional)'),
              const SizedBox(height: 8),
              _buildSecondaryMuscleSelector(),
              const SizedBox(height: 24),

              _buildSectionTitle('Exercise Instructions (Optional)'),
              const SizedBox(height: 8),
              _buildInstructionsSection(),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _onSavePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.headlineMedium,
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppTheme.textPrimary),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildEquipmentSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _selectedEquipment,
        dropdownColor: AppTheme.surfaceLight,
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        items: _equipmentOptions.map((String equipment) {
          return DropdownMenuItem<String>(
            value: equipment,
            child: Text(equipment),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() {
              _selectedEquipment = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildPrimaryMuscleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _selectedPrimaryMuscle,
        dropdownColor: AppTheme.surfaceLight,
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        items: _muscleOptions.map((String muscle) {
          return DropdownMenuItem<String>(
            value: muscle,
            child: Text(muscle),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            setState(() {
              _selectedPrimaryMuscle = value;
              _selectedSecondaryMuscles.remove(value);
            });
          }
        },
      ),
    );
  }

  Widget _buildSecondaryMuscleSelector() {
    final availableSecondaryMuscles =
        _muscleOptions.where((m) => m != _selectedPrimaryMuscle).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedSecondaryMuscles.isNotEmpty) ...[
            Text(
              'Selected: ${_selectedSecondaryMuscles.join(', ')}',
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableSecondaryMuscles.map((muscle) {
              final isSelected = _selectedSecondaryMuscles.contains(muscle);
              return GestureDetector(
                onTap: () => _toggleSecondaryMuscle(muscle),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent.withOpacity(0.7)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.textSecondary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    muscle,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _instructionController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Enter step instruction...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _addInstructionStep(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: _addInstructionStep,
                  tooltip: 'Add Step',
                ),
              ),
            ],
          ),

          if (_instructionSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Steps (${_instructionSteps.length})',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _instructionSteps.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _instructionSteps.removeAt(oldIndex);
                  _instructionSteps.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                return Container(
                  key: ValueKey('instruction_$index'),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.accent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      _instructionSteps[index],
                      style: AppTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit,
                              color: AppTheme.accent, size: 20),
                          onPressed: () => _editInstructionStep(index),
                          tooltip: 'Edit',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete,
                              color: AppTheme.error, size: 20),
                          onPressed: () => _removeInstructionStep(index),
                          tooltip: 'Delete',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.drag_handle,
                            color: AppTheme.textSecondary, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
            Text(
              'Tip: Long press and drag to reorder steps',
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No instructions added yet',
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
