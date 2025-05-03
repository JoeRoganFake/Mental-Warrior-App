import 'package:flutter/material.dart';

class ExerciseSelectionPage extends StatefulWidget {
  const ExerciseSelectionPage({Key? key}) : super(key: key);

  @override
  _ExerciseSelectionPageState createState() => _ExerciseSelectionPageState();
}

class _ExerciseSelectionPageState extends State<ExerciseSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customExerciseController =
      TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();
  String _searchQuery = '';

  // List of common exercises
  final List<Map<String, String>> _exercises = [
    {'name': 'Bench Press', 'equipment': 'Barbell', 'type': 'Chest'},
    {'name': 'Squat', 'equipment': 'Barbell', 'type': 'Legs'},
    {'name': 'Deadlift', 'equipment': 'Barbell', 'type': 'Back'},
    {'name': 'Pull Up', 'equipment': 'Body Weight', 'type': 'Back'},
    {'name': 'Push Up', 'equipment': 'Body Weight', 'type': 'Chest'},
    {'name': 'Shoulder Press', 'equipment': 'Dumbbell', 'type': 'Shoulders'},
    {'name': 'Bicep Curl', 'equipment': 'Dumbbell', 'type': 'Arms'},
    {'name': 'Tricep Extension', 'equipment': 'Cable', 'type': 'Arms'},
    {'name': 'Leg Press', 'equipment': 'Machine', 'type': 'Legs'},
    {'name': 'Lat Pulldown', 'equipment': 'Cable', 'type': 'Back'},
    {'name': 'Chest Fly', 'equipment': 'Cable', 'type': 'Chest'},
    {'name': 'Leg Extension', 'equipment': 'Machine', 'type': 'Legs'},
    {'name': 'Leg Curl', 'equipment': 'Machine', 'type': 'Legs'},
    {'name': 'Calf Raise', 'equipment': 'Machine', 'type': 'Legs'},
    {'name': 'Plank', 'equipment': 'Body Weight', 'type': 'Core'},
    {'name': 'Russian Twist', 'equipment': 'Body Weight', 'type': 'Core'},
    {'name': 'Crunch', 'equipment': 'Body Weight', 'type': 'Core'},
    {'name': 'Leg Raise', 'equipment': 'Body Weight', 'type': 'Core'},
    {'name': 'Lunge', 'equipment': 'Body Weight', 'type': 'Legs'},
    {
      'name': 'Side Lateral Raise',
      'equipment': 'Dumbbell',
      'type': 'Shoulders'
    },
  ];

  // Equipment options for dropdown
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

  String _selectedEquipment = 'None';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _customExerciseController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<Map<String, String>> get _filteredExercises {
    if (_searchQuery.isEmpty) {
      return _exercises;
    }

    return _exercises.where((exercise) {
      return exercise['name']!.toLowerCase().contains(_searchQuery) ||
          exercise['equipment']!.toLowerCase().contains(_searchQuery) ||
          exercise['type']!.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _showAddCustomExerciseDialog() {
    _customExerciseController.clear();
    _selectedEquipment = 'None';

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
              value: _selectedEquipment,
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
                  setState(() {
                    _selectedEquipment = value;
                  });
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
                      _selectedEquipment == 'None' ? '' : _selectedEquipment,
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
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  title: Text(exercise['name']!),
                  subtitle:
                      Text('${exercise['equipment']} • ${exercise['type']}'),
                  leading: CircleAvatar(
                    backgroundColor: _getColorForType(exercise['type']!),
                    child: Text(
                      exercise['name']![0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, {
                      'name': exercise['name'],
                      'equipment': exercise['equipment'],
                    });
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomExerciseDialog,
        child: const Icon(Icons.add),
        tooltip: 'Add Custom Exercise',
      ),
    );
  }

  Color _getColorForType(String type) {
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
      default:
        return Colors.grey;
    }
  }
}
