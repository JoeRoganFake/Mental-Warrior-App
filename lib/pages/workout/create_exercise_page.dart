import 'package:flutter/material.dart';
import '../../services/database_services.dart';

class CreateExercisePage extends StatefulWidget {
  final bool editMode;
  final Map<String, dynamic>? exerciseData;
  final int? workoutId; // Optional workoutId to add exercise to
  
  const CreateExercisePage({
    super.key,
    this.editMode = false,
    this.exerciseData,
    this.workoutId,
  });

  @override
  CreateExercisePageState createState() => CreateExercisePageState();
}

class CreateExercisePageState extends State<CreateExercisePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  
  String _selectedEquipment = 'None';
  String _selectedPrimaryMuscle = 'Chest';
  final List<String> _selectedSecondaryMuscles = [];
  
  // Equipment options
  final List<String> _equipmentOptions = [
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
  
  // Muscle group options
  final List<String> _muscleOptions = [
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

  // Theme colors consistent with the app
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _dangerColor = const Color(0xFFE53935);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);
  final Color _inputBgColor = const Color(0xFF303136);

  @override
  void initState() {
    super.initState();
    
    // If in edit mode, populate form with existing data
    if (widget.editMode && widget.exerciseData != null) {
      _nameController.text = widget.exerciseData!['name'] ?? '';
      _selectedEquipment = widget.exerciseData!['equipment'] ?? 'None';
      _selectedPrimaryMuscle = widget.exerciseData!['type'] ?? 'Chest';
      
      // Populate secondary muscles if they exist
      final secondaryMuscles = widget.exerciseData!['secondaryMuscles'];
      if (secondaryMuscles is List) {
        _selectedSecondaryMuscles.clear();
        _selectedSecondaryMuscles.addAll(secondaryMuscles.cast<String>());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  void _createExercise() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final customExerciseService = CustomExerciseService();
      
      if (widget.editMode && widget.exerciseData != null) {
        // Update existing custom exercise
        await customExerciseService.updateCustomExercise(
          id: widget.exerciseData!['id'],
          name: _nameController.text.trim(),
          equipment: _selectedEquipment,
          type: _selectedPrimaryMuscle,
          secondaryMuscles: _selectedSecondaryMuscles,
        );
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          Navigator.of(context).pop(true); // Return to previous screen with success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Exercise updated successfully!'),
              backgroundColor: _primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Check if exercise already exists
        final exerciseExists = await customExerciseService.exerciseExists(
          _nameController.text.trim(),
          _selectedEquipment,
        );
        
        if (exerciseExists) {
          if (mounted) {
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('An exercise with this name and equipment already exists'),
                backgroundColor: _dangerColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        
        // Create new custom exercise
        final exerciseId = await customExerciseService.addCustomExercise(
          name: _nameController.text.trim(),
          equipment: _selectedEquipment,
          type: _selectedPrimaryMuscle,
          secondaryMuscles: _selectedSecondaryMuscles,
        );
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          
          // Return the created exercise data for the parent to handle
          final exerciseData = {
            'id': exerciseId,
            'name': _nameController.text.trim(),
            'equipment': _selectedEquipment,
            'type': _selectedPrimaryMuscle,
            'description': '',
            'secondaryMuscles': _selectedSecondaryMuscles,
            'apiId': 'custom_$exerciseId',
            'isCustom': true,
          };
          
          print('📝 CreateExercisePage returning custom exercise data:');
          print('   ID: $exerciseId');
          print('   Name: ${_nameController.text.trim()}');
          print('   API ID: custom_$exerciseId');
          print('   isCustom: true');
          
          // Show success message BEFORE popping to avoid "off screen" error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Exercise created successfully!'),
              backgroundColor: _primaryColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1), // Short duration since we're navigating away
            ),
          );
          
          // Small delay to let snackbar show before popping
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (mounted) {
            Navigator.of(context).pop(exerciseData); // Return exercise data
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        String errorMessage = 'An error occurred while saving the exercise';
        if (e.toString().contains('UNIQUE constraint failed')) {
          errorMessage = 'An exercise with this name already exists';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: _dangerColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getColorForType(String type) {
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
      case 'neck':
        return Colors.brown;
      case 'adductors':
        return Colors.lightGreen;
      case 'traps':
      case 'lats':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.editMode ? 'Edit Exercise' : 'Create Exercise',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _surfaceColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise Name
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

              // Equipment Selection
              _buildSectionTitle('Equipment'),
              const SizedBox(height: 8),
              _buildEquipmentSelector(),
              const SizedBox(height: 24),

              // Primary Muscle Group
              _buildSectionTitle('Primary Muscle Group'),
              const SizedBox(height: 8),
              _buildPrimaryMuscleSelector(),
              const SizedBox(height: 24),

              // Secondary Muscle Groups
              _buildSectionTitle('Secondary Muscle Groups (Optional)'),
              const SizedBox(height: 8),
              _buildSecondaryMuscleSelector(),
              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _createExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    widget.editMode ? 'Update Exercise' : 'Create Exercise',
                    style: const TextStyle(
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
      style: TextStyle(
        color: _textPrimaryColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
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
      style: TextStyle(color: _textPrimaryColor),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: _textSecondaryColor),
        filled: true,
        fillColor: _inputBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _dangerColor, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _dangerColor, width: 2),
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
        color: _inputBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _selectedEquipment,
        dropdownColor: _inputBgColor,
        style: TextStyle(color: _textPrimaryColor),
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
        color: _inputBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: _selectedPrimaryMuscle,
        dropdownColor: _inputBgColor,
        style: TextStyle(color: _textPrimaryColor),
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
              // Remove from secondary muscles if it was selected there
              _selectedSecondaryMuscles.remove(value);
            });
          }
        },
      ),
    );
  }

  Widget _buildSecondaryMuscleSelector() {
    // Get available secondary muscles (excluding the primary muscle)
    final availableSecondaryMuscles = _muscleOptions
        .where((muscle) => muscle != _selectedPrimaryMuscle)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: _inputBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedSecondaryMuscles.isNotEmpty) ...[
            Text(
              'Selected: ${_selectedSecondaryMuscles.join(', ')}',
              style: TextStyle(
                color: _textSecondaryColor,
                fontSize: 14,
              ),
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
                        ? _getColorForType(muscle).withOpacity(0.7)
                        : _surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _getColorForType(muscle)
                          : _textSecondaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    muscle,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _textPrimaryColor,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
}