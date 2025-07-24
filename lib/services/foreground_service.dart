import 'dart:async';
import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (!_isDestroyed && !WorkoutForegroundService._isDestroying) {
      _saveWorkoutData();
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
      
      // Save data every 30 seconds, but only if not destroyed
      if (!_isDestroyed && !WorkoutForegroundService._isDestroying && _elapsedSeconds % 30 == 0) {
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
    
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_workoutStartTime != null) {
        await prefs.setString('workout_start_time', _workoutStartTime!.toIso8601String());
        if (_workoutName != null) {
          await prefs.setString('workout_name', _workoutName!);
        }
        await prefs.setInt('workout_elapsed_seconds', _elapsedSeconds);
        print('Saved workout data: $_elapsedSeconds seconds elapsed');
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
        channelId: 'workout_foreground_service',
        channelName: 'Workout Foreground Service',
        channelDescription: 'This notification appears when the workout is running in the background.',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        visibility: NotificationVisibility.VISIBILITY_SECRET, // Hide notification
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false, // Disable notification display
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Update every 5 seconds
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service for an active workout
  static Future<bool> startWorkoutService(String workoutName, {DateTime? startTime, Map<String, dynamic>? workoutData, int? workoutId, bool? isTemporary}) async {
    if (_isServiceRunning) return true;

    // Save workout data before starting service
    await _storeWorkoutData(workoutName, startTime, workoutData: workoutData, workoutId: workoutId, isTemporary: isTemporary);

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: '',
        notificationText: '',
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
      final startTimeStr = prefs.getString('workout_start_time');
      final workoutName = prefs.getString('workout_name');
      final elapsedSeconds = prefs.getInt('workout_elapsed_seconds');
      final workoutDataStr = prefs.getString('workout_data');
      final workoutId = prefs.getInt('workout_id');
      final isTemporary = prefs.getBool('workout_is_temporary');
      
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
        
        return result;
      }
    } catch (e) {
      print('Error getting saved workout data: $e');
    }
    return null;
  }

  /// Clear saved workout data (useful for discarding workouts)
  static Future<void> clearSavedWorkoutData() async {
    await _clearWorkoutData();
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
      print('Cleared stored workout data');
    } catch (e) {
      print('Error clearing workout data: $e');
    }
  }
}
