 Custom Exercise Tap Navigation Implementation

## Overview
I've implemented a tap detection system for the `CustomExerciseCard` widget that automatically navigates to the appropriate detail page based on whether the exercise is a custom/temporary exercise or a built-in exercise.

## Changes Made

### 1. Updated CustomExerciseCard Constructor
Added an optional `onTap` callback parameter to allow for custom tap handling:

```dart
class CustomExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback? onAddSet;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;  // NEW: Optional tap callback
  final bool showActions;
  final bool isEditable;
  
  // Constructor updated to include onTap parameter
}
```

### 2. Added Navigation Logic
Created `_handleExerciseTap()` method that:
- Checks if a custom `onTap` callback is provided (takes priority)
- Determines exercise type using existing flags (`_isCustomExercise`, `_isTemporaryExercise`)
- Navigates to appropriate page:
  - **Custom/Temporary exercises** → `CustomExerciseDetailPage`
  - **Built-in exercises** → `ExerciseDetailPage`

```dart
void _handleExerciseTap() {
  if (widget.onTap != null) {
    widget.onTap!();
    return;
  }

  if (_isCustomExercise || _isTemporaryExercise) {
    // Navigate to custom exercise detail page
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => CustomExerciseDetailPage(
        exerciseId: widget.exercise.id.toString(),
        exerciseName: _cleanExerciseName,
        customExerciseData: _customExerciseData,
        isTemporary: _isTemporaryExercise,
      ),
    ));
  } else {
    // Navigate to built-in exercise detail page
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ExerciseDetailPage(
        exerciseId: widget.exercise.id.toString(),
      ),
      settings: RouteSettings(arguments: {
        'exerciseName': widget.exercise.name,
        'exerciseEquipment': widget.exercise.equipment,
        'isTemporary': false,
      }),
    ));
  }
}
```

### 3. Made Card Tappable
Wrapped the main Container in a GestureDetector:

```dart
return GestureDetector(
  onTap: _handleExerciseTap,
  child: Container(
    // ... existing card content
  ),
);
```

### 4. Created CustomExerciseDetailPage
Since the custom exercise detail page was empty, I created a complete implementation with:
- Proper theming consistent with the app
- Exercise information display
- Special handling for temporary exercises
- Placeholder for exercise history
- Edit functionality placeholder

## Exercise Type Detection

The system uses existing logic to determine exercise types:

1. **Custom Exercise**: `widget.exercise.name.contains('##API_ID:custom_')` OR `widget.exercise.id < 0`
2. **Temporary Exercise**: `widget.exercise.id < 0`
3. **Built-in Exercise**: Everything else

## Usage

The tap functionality is now automatically enabled for all `CustomExerciseCard` instances. Users can:

1. **Tap any exercise card** to view details
2. **Custom exercises** will show custom exercise details with edit options
3. **Temporary exercises** will show information about converting to permanent
4. **Built-in exercises** will show the standard exercise detail page with exercise database information

## Flexibility

The implementation maintains flexibility by:
- Allowing custom `onTap` callbacks to override default behavior
- Preserving all existing functionality (edit, delete, add set actions)
- Using existing exercise type detection logic
- Maintaining consistent theming and user experience

The feature is now ready for use and will automatically route users to the appropriate detail page based on the exercise type.
