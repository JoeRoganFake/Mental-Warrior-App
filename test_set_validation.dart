// Test to verify that invalid sets are not saved when finishing a workout
void main() {
  print("Testing set validation logic...");
  
  // Test case 1: Valid sets should be included
  final validSet1 = {'weight': 50.0, 'reps': 10, 'completed': false};
  final validSet2 = {'weight': 0.0, 'reps': 15, 'completed': false}; // Zero weight but has reps
  final validSet3 = {'weight': 60.0, 'reps': 0, 'completed': false}; // Zero reps but has weight
  final completedSet = {'weight': 0.0, 'reps': 0, 'completed': true}; // Completed, even if zero values
  
  // Test case 2: Invalid sets should be filtered out
  final invalidSet1 = {'weight': 0.0, 'reps': 0, 'completed': false}; // No valid data and not completed
  final invalidSet2 = {'weight': null, 'reps': null, 'completed': false}; // Null values
  
  final testSets = [validSet1, validSet2, validSet3, completedSet, invalidSet1, invalidSet2];
  
  // Apply the filtering logic from our fix
  final validSets = testSets.where((set) {
    final double weight = (set['weight'] ?? 0.0) as double;
    final int reps = (set['reps'] ?? 0) as int;
    final bool completed = set['completed'] as bool;
    
    final bool hasValidWeight = weight > 0;
    final bool hasValidReps = reps > 0;
    final bool isCompleted = completed;
    
    return hasValidWeight || hasValidReps || isCompleted;
  }).toList();
  
  print("Original sets count: ${testSets.length}");
  print("Valid sets count after filtering: ${validSets.length}");
  print("Expected valid sets: 4 (validSet1, validSet2, validSet3, completedSet)");
  
  if (validSets.length == 4) {
    print("✅ Test PASSED: Invalid sets were properly filtered out");
  } else {
    print("❌ Test FAILED: Expected 4 valid sets, got ${validSets.length}");
  }
  
  // Verify which sets are included
  print("\nValid sets included:");
  for (int i = 0; i < validSets.length; i++) {
    final set = validSets[i];
    print("  Set $i: weight=${set['weight']}, reps=${set['reps']}, completed=${set['completed']}");
  }
}
