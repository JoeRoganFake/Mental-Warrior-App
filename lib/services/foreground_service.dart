import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mental_warior/services/database_services.dart';

// Handler for the foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WorkoutForegroundTaskHandler());
}

class WorkoutForegroundTaskHandler extends TaskHandler {
  Timer? _timer;
  int _elapsedSeconds = 0;
  DateTime? _workoutStartTime;
  String? _workoutName;
  bool _isDestroyed = false; // Flag to track if service is being destroyed

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Workout foreground task started');
    
    // Load saved workout data
    await _loadWorkoutData();
    
    // If we have saved data, use it; otherwise start fresh
    if (_workoutStartTime != null) {
      // Calculate current elapsed time based on saved start time
      _elapsedSeconds = DateTime.now().difference(_workoutStartTime!).inSeconds;
    } else {
      // Fresh start
      _workoutStartTime = timestamp;
      _elapsedSeconds = 0;
    }
    
    // Start the timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimer();
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Save workout data periodically, but only if not destroyed (either locally or globally)
    // and if workout is not marked for discard
    if (!_isDestroyed && !WorkoutForegroundService._isDestroying) {
      _saveWorkoutData(); // This method now includes discard flag checking
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('Workout foreground task destroyed');
    _isDestroyed = true; // Set flag to prevent further saving
    _timer?.cancel();
    _timer = null; // Ensure timer is null
    
    // Clear saved data when service is destroyed normally
    await _clearWorkoutData();
    
    // Reset instance variables to initial state
    _elapsedSeconds = 0;
    _workoutStartTime = null;
    _workoutName = null;
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button presses
    if (id == 'stop_workout') {
      FlutterForegroundTask.stopService();
    }
  }

  void _updateTimer() {
    // Don't update or save if service is being destroyed (either locally or globally)
    if (_isDestroyed || WorkoutForegroundService._isDestroying || _workoutStartTime == null) {
      return;
    }
    
    final now = DateTime.now();
    final newElapsedSeconds = now.difference(_workoutStartTime!).inSeconds;
    
    if (newElapsedSeconds != _elapsedSeconds) {
      _elapsedSeconds = newElapsedSeconds;
      
      // Update notification with current time
      final formattedTime =
          WorkoutForegroundService._formatDuration(_elapsedSeconds);
      final workoutName = _workoutName ?? 'Workout';
      FlutterForegroundTask.updateService(
        notificationTitle: 'Workout in Progress',
        notificationText: '$workoutName • $formattedTime',
      );
      
      // Save data every 60 seconds, but only if not destroyed
      // Note: Main auto-save is now handled by WorkoutSessionPage every 60 seconds
      // This is just a backup save for when the foreground service is running independently
      if (!_isDestroyed &&
          !WorkoutForegroundService._isDestroying &&
          _elapsedSeconds % 60 == 0) {
        _saveWorkoutData();
      }
    }
  }

  Future<void> _loadWorkoutData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startTimeStr = prefs.getString('workout_start_time');
      _workoutName = prefs.getString('workout_name');
      
      if (startTimeStr != null) {
        _workoutStartTime = DateTime.parse(startTimeStr);
        print('Loaded workout data: start time = $_workoutStartTime, name = $_workoutName');
      }
    } catch (e) {
      print('Error loading workout data: $e');
    }
  }

  Future<void> _saveWorkoutData() async {
    // Don't save if service is being destroyed (either locally or globally)
    if (_isDestroyed || WorkoutForegroundService._isDestroying) {
      return;
    }
    
    // Check if workout was marked for discard - don't save discarded workouts
    try {
      final prefs = await SharedPreferences.getInstance();
      final forDiscard = prefs.getBool('workout_for_discard') ?? false;
      if (forDiscard) {
        print('⚠️ Workout marked for discard - skipping save operation');
        return;
      }
    } catch (e) {
      print('❌ Error checking discard flag: $e');
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_workoutStartTime != null) {
        await prefs.setString('workout_start_time', _workoutStartTime!.toIso8601String());
        if (_workoutName != null) {
          await prefs.setString('workout_name', _workoutName!);
        }
        await prefs.setInt('workout_elapsed_seconds', _elapsedSeconds);
        
        // Read workout data to get exercise information for debug message
        String exerciseInfo = "No exercises";
        String workoutStatus = "UNKNOWN";
        String currentExercise = "None";
        String setsProgress = "0/0";
        String restTimer = "No active rest";

        try {
          Map<String, dynamic>? workoutData;
          Map<String, dynamic>? activeWorkoutState;

          // Try to get complete state first (most up-to-date)
          final completeStateStr = prefs.getString('workout_complete_state');
          if (completeStateStr != null) {
            try {
              final completeState = jsonDecode(completeStateStr) as Map<String, dynamic>;
              final activeWorkout = completeState['activeWorkout'] as Map<String, dynamic>?;
              if (activeWorkout != null) {
                activeWorkoutState = activeWorkout;
                workoutData = activeWorkout['workoutData'] as Map<String, dynamic>?;
              }
            } catch (e) {
              print('Error parsing complete state: $e');
            }
          }

          // Fallback to direct workout data if complete state not available
          if (workoutData == null) {
            final workoutDataStr = prefs.getString('workout_data');
            if (workoutDataStr != null) {
              try {
                workoutData = jsonDecode(workoutDataStr) as Map<String, dynamic>;
              } catch (e) {
                print('Error parsing workout data: $e');
              }
            }
          }

          // Extract status information from active workout state
          if (activeWorkoutState != null) {
            final isRunning = activeWorkoutState['isRunning'] as bool? ?? false;
            final currentRestSetId = activeWorkoutState['currentRestSetId'] as int?;
            final restTimeRemaining = activeWorkoutState['restTimeRemaining'] as int? ?? 0;
            final restPaused = activeWorkoutState['restPaused'] as bool? ?? false;

            // Set workout status
            workoutStatus = isRunning ? "ACTIVE" : "PAUSED";

            // Check for active rest timer
            if (currentRestSetId != null && restTimeRemaining > 0) {
              final minutes = restTimeRemaining ~/ 60;
              final seconds = restTimeRemaining % 60;
              final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
              final status = restPaused ? 'PAUSED' : 'RUNNING';
              restTimer = '$timeStr remaining [$status]';
            }
          }

          // Process exercise data - this should match the _serializeWorkoutData structure
          if (workoutData != null) {
            final exercises = workoutData['exercises'] as List?;
            if (exercises != null && exercises.isNotEmpty) {
              // Get exercise names
              final exerciseNames = exercises.map((e) => e['name'] ?? 'Unknown').toList();
              exerciseInfo = "${exercises.length} exercises: ${exerciseNames.join(', ')}";

              // Find current exercise (first incomplete one)
              for (int i = 0; i < exercises.length; i++) {
                final exercise = exercises[i] as Map<String, dynamic>;
                final sets = exercise['sets'] as List? ?? [];
                final incompleteSets = sets.where((s) => !(s['completed'] ?? false)).toList();

                if (incompleteSets.isNotEmpty) {
                  currentExercise = "${exercise['name']} (${sets.length - incompleteSets.length + 1}/${sets.length})";
                  break;
                }
              }

              // Calculate total sets progress
              int totalSets = 0;
              int completedSets = 0;
              for (final exercise in exercises) {
                final sets = (exercise['sets'] as List?) ?? [];
                totalSets += sets.length;
                completedSets += sets.where((s) => s['completed'] ?? false).length;
              }
              setsProgress = "$completedSets/$totalSets";
            }
          }
        } catch (e) {
          exerciseInfo = "Error reading exercises: $e";
        }

        // Print comprehensive debug message to match workout session page format
        print('💾 FOREGROUND AUTO-SAVE');
        print(
            '   Workout ID: workout_${prefs.getInt('workout_id') ?? 'unknown'}_${_workoutStartTime?.millisecondsSinceEpoch ?? 0}');
        print('   Timestamp: ${DateTime.now().toIso8601String()}');
        print('   Service Time: $_elapsedSeconds seconds elapsed');
        print('   Status: $workoutStatus');
        print('   Current Exercise: $currentExercise');
        print('   Sets Progress: $setsProgress completed');
        print('   Rest Timer: $restTimer');
        print('   Exercise Info: $exerciseInfo');
        print('   ─────────────────────────────────────────');
      }
    } catch (e) {
      print('Error saving workout data: $e');
    }
  }

  Future<void> _clearWorkoutData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('workout_start_time');
      await prefs.remove('workout_name');
      await prefs.remove('workout_elapsed_seconds');
      await prefs.remove('workout_data');
      await prefs.remove('workout_id');
      await prefs.remove('workout_is_temporary');
      print('Cleared workout data');
    } catch (e) {
      print('Error clearing workout data: $e');
    }
  }

}

class WorkoutForegroundService {
  static bool _isServiceRunning = false;
  static bool _isDestroying = false; // Flag to track if service is being destroyed

  /// Initialize the foreground service
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId:
            'workout_foreground_service_hidden', // Keep same ID to avoid duplicate channels
        channelName: 'Active Workout',
        channelDescription: 'Shows your current workout progress',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false, // Disable notification display
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(60000), // Update every 60 seconds
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service for an active workout
  static Future<bool> startWorkoutService(String workoutName, {DateTime? startTime, Map<String, dynamic>? workoutData, int? workoutId, bool? isTemporary}) async {
    if (_isServiceRunning) {
      // If service is already running, just update the notification
      final elapsedSeconds = startTime != null
          ? DateTime.now().difference(startTime).inSeconds
          : 0;
      final formattedTime = _formatDuration(elapsedSeconds);
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Workout in Progress',
        notificationText: '$workoutName • $formattedTime',
      );
      return true;
    }

    // Save workout data before starting service
    await _storeWorkoutData(workoutName, startTime, workoutData: workoutData, workoutId: workoutId, isTemporary: isTemporary);

    try {
      final formattedTime = _formatDuration(0);
      await FlutterForegroundTask.startService(
        notificationTitle: 'Workout in Progress',
        notificationText: '$workoutName • $formattedTime',
        callback: startCallback,
      );
      
      _isServiceRunning = true;
      return true;
    } catch (e) {
      print('Failed to start foreground service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  static Future<bool> stopWorkoutService() async {
    if (!_isServiceRunning) return true;

    try {
      _isDestroying = true; // Set destroying flag before stopping
      await FlutterForegroundTask.stopService();
      _isServiceRunning = false;
      // Clear workout data when manually stopping
      await _clearWorkoutData();
      _isDestroying = false; // Reset flag after successful stop
      return true;
    } catch (e) {
      print('Failed to stop foreground service: $e');
      _isDestroying = false; // Reset flag on error too
      return false;
    }
  }

  /// Check if the service is currently running
  static bool get isServiceRunning => _isServiceRunning;

  /// Get saved workout data if any exists
  static Future<Map<String, dynamic>?> getSavedWorkoutData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if workout was marked for discard
      final forDiscard = prefs.getBool('workout_for_discard') ?? false;
      if (forDiscard) {
        print(
            '⚠️ Workout was marked for discard, clearing data and returning null');
        await clearSavedWorkoutData();
        return null;
      }
      
      final startTimeStr = prefs.getString('workout_start_time');
      final workoutName = prefs.getString('workout_name');
      final elapsedSeconds = prefs.getInt('workout_elapsed_seconds');
      final workoutDataStr = prefs.getString('workout_data');
      final workoutId = prefs.getInt('workout_id');
      final isTemporary = prefs.getBool('workout_is_temporary');
      final completeStateStr = prefs.getString('workout_complete_state');
      
      if (startTimeStr != null && workoutName != null) {
        final result = {
          'start_time': DateTime.parse(startTimeStr),
          'workout_name': workoutName,
          'elapsed_seconds': elapsedSeconds ?? 0,
        };
        
        // Add additional data if available
        if (workoutDataStr != null) {
          try {
            result['workout_data'] = jsonDecode(workoutDataStr);
          } catch (e) {
            print('Error decoding workout data: $e');
          }
        }
        if (workoutId != null) {
          result['workout_id'] = workoutId;
        }
        if (isTemporary != null) {
          result['is_temporary'] = isTemporary;
        }
        
        // Add complete state if available for full restoration
        if (completeStateStr != null) {
          try {
            final completeState = jsonDecode(completeStateStr);
            result['complete_state'] = completeState;
          } catch (e) {
            print('Error parsing complete state: $e');
          }
        }
        
        return result;
      }
    } catch (e) {
      print('Error getting saved workout data: $e');
    }
    return null;
  }

  /// Clear saved workout data (useful for discarding workouts)
  static Future<void> clearSavedWorkoutData() async {
    try {
      print('Clearing saved workout data...');
      await _clearWorkoutData();
      print('Successfully cleared saved workout data');
    } catch (e) {
      print('Error in clearSavedWorkoutData: $e');
      // Try to clear manually if the helper method fails
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('workout_start_time');
        await prefs.remove('workout_name');
        await prefs.remove('workout_elapsed_seconds');
        await prefs.remove('workout_data');
        await prefs.remove('workout_id');
        await prefs.remove('workout_is_temporary');
        await prefs.remove('workout_complete_state');
        await prefs.remove('workout_for_discard');
        print('Manually cleared saved workout data after error');
      } catch (manualError) {
        print('Failed to manually clear workout data: $manualError');
      }
    }
  }

  /// Mark workout as discarded to prevent restoration after hot restart
  static Future<void> markWorkoutAsDiscarded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('workout_for_discard', true);
      print('✅ Marked workout as discarded - flag set to prevent restoration');
    } catch (e) {
      print('❌ Error marking workout as discarded: $e');
    }
  }

  /// Update workout data in the foreground service
  static Future<void> updateWorkoutData(
      Map<String, dynamic> workoutData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('workout_data', jsonEncode(workoutData));

      // Also update the complete workout state
      final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
      if (activeWorkout != null) {
        final completeState = {
          'activeWorkout': activeWorkout,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        await prefs.setString(
            'workout_complete_state', jsonEncode(completeState));
      }
    } catch (e) {
      print('Error updating workout data in foreground service: $e');
    }
  }

  static Future<void> _storeWorkoutData(String workoutName, DateTime? startTime, {Map<String, dynamic>? workoutData, int? workoutId, bool? isTemporary}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final workoutStartTime = startTime ?? DateTime.now();
      
      await prefs.setString('workout_start_time', workoutStartTime.toIso8601String());
      await prefs.setString('workout_name', workoutName);
      await prefs.setInt('workout_elapsed_seconds', 0);
      
      // Save additional workout data if provided
      if (workoutData != null) {
        await prefs.setString('workout_data', jsonEncode(workoutData));
      }
      if (workoutId != null) {
        await prefs.setInt('workout_id', workoutId);
      }
      if (isTemporary != null) {
        await prefs.setBool('workout_is_temporary', isTemporary);
      }
      
      // Save complete workout state from active workout notifier for full restoration
      final activeWorkout = WorkoutService.activeWorkoutNotifier.value;
      if (activeWorkout != null) {
        final completeState = {
          'activeWorkout': activeWorkout,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        await prefs.setString(
            'workout_complete_state', jsonEncode(completeState));
      }
      
      print('Stored workout data: $workoutName starting at $workoutStartTime');
    } catch (e) {
      print('Error storing workout data: $e');
    }
  }

  static Future<void> _clearWorkoutData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('workout_start_time');
      await prefs.remove('workout_name');
      await prefs.remove('workout_elapsed_seconds');
      await prefs.remove('workout_data');
      await prefs.remove('workout_id');
      await prefs.remove('workout_is_temporary');
      await prefs
          .remove('workout_complete_state'); // Add complete state removal
      await prefs.remove('workout_for_discard'); // Add discard flag removal
      print('Cleared stored workout data');
    } catch (e) {
      print('Error clearing workout data: $e');
    }
  }

  /// Format duration in MM:SS format
  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
