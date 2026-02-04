import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mental_warior/main.dart';
import 'package:mental_warior/pages/home.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/models/habits.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'package:mental_warior/widgets/level_up_animation.dart';
import 'package:mental_warior/widgets/xp_gain_bubble.dart';

class MeditationCountdownScreen extends StatefulWidget {
  static MeditationCountdownScreenState? currentState;
  final int duration;
  final String mode;

  const MeditationCountdownScreen({
    super.key,
    required this.duration,
    required this.mode,
  });

  @override
  MeditationCountdownScreenState createState() =>
      MeditationCountdownScreenState();
}

class MeditationCountdownScreenState extends State<MeditationCountdownScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late int remainingSeconds;
  Timer? uiTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final habits = HabitService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool isPaused = false;
  bool isTerminateDialogOpen = false;
  bool _alarmPlayed = false;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    MeditationCountdownScreen.currentState = this;
    WidgetsBinding.instance.addObserver(this);
    remainingSeconds = widget.duration * 60;

    // Initialize animation controller
    _progressController = AnimationController(
      duration: Duration(seconds: widget.duration * 60),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));

    // Delay initialization to allow UI rendering
    Future.delayed(Duration(milliseconds: 100), () {
      _initForegroundTask();
      _startUITimer();
      _initializeNotifications();
      _progressController.forward(); // Start the smooth animation
    });
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'meditation_channel',
        channelName: 'Meditation Timer',
        channelDescription: 'Shows meditation progress',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
          autoRunOnBoot: false,
          allowWifiLock: false,
          eventAction: ForegroundTaskEventAction.nothing()),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
    );

    // Start the foreground task asynchronously
    _startForegroundTask();
  }

  Future<void> _startForegroundTask() async {
    // Save data asynchronously
    await Future.wait([
      FlutterForegroundTask.saveData(
          key: 'remainingSeconds', value: remainingSeconds),
      FlutterForegroundTask.saveData(key: 'isPaused', value: isPaused),
    ]);

    // Start or restart the foreground service
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Meditation In Progress',
        notificationText:
            '${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
        callback: startCallback,
      );
    }
  }

  Future<void> stopForegroundTask() async {
    await FlutterForegroundTask.stopService();
  }

  void _startUITimer() {
    _updateUITimer();
    uiTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      await _updateUITimer();
    });
  }

  Future<void> _updateUITimer() async {
    if (isPaused) return;

    // Fetch the remaining time asynchronously with fractional seconds
    final time =
        await FlutterForegroundTask.getData<int>(key: 'remainingSeconds') ??
            remainingSeconds;

    if (mounted) {
      setState(() {
        remainingSeconds = time;
      });
    }

    // Handle timer completion
    if (remainingSeconds <= 0 && !_alarmPlayed) {
      _alarmPlayed = true;
      playAlarm();
      showFinishedNotification();
      stopForegroundTask();
    }
  }

  @override
  void dispose() {
    uiTimer?.cancel();
    _progressController.dispose();
    stopForegroundTask();
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  void showFinishedNotification() async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Finished Timer',
      channelDescription: 'Timer has finished',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      ongoing: false,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'finish',
          'Finish',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      1,
      'Meditation Finished',
      'You have completed ${widget.mode} meditation',
      platformDetails,
    );
  }

  void pauseTimer() async {
    await FlutterForegroundTask.saveData(key: 'isPaused', value: true);
    _progressController.stop(); // Pause the animation
    setState(() {
      isPaused = true;
    });
  }

  void resumeTimer() async {
    await FlutterForegroundTask.saveData(key: 'isPaused', value: false);
    _progressController.forward(); // Resume the animation
    setState(() {
      isPaused = false;
    });
  }

  void terminateMeditation() {
    if (!mounted) return;
    pauseTimer();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
      (Route<dynamic> route) => false,
    );
    flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> playAlarm() async {
    await _audioPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ),
    );
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(
      AssetSource('audio/time_up_samsung.mp3'),
      volume: 1.0,
    );

    Future.delayed(Duration(minutes: 1), () {
      _audioPlayer.stop();
    });
  }

  void completeMeditation() async {
    // Get all habits to check available labels
    final allHabits = await habits.getHabits();
    print(
        'All habits: ${allHabits.map((h) => '${h.label} (status: ${h.status})').toList()}');

    // Try to find meditation habit with case-insensitive search
    var meditationHabit = allHabits.firstWhere(
      (h) => h.label.toLowerCase() == 'meditation',
      orElse: () => allHabits.firstWhere(
        (h) => h.label.toLowerCase().contains('meditation'),
        orElse: () => Habit(id: -1, label: '', status: -1, description: ''),
      ),
    );

    print(
        'Found meditation habit: ${meditationHabit.label} (id: ${meditationHabit.id}, status: ${meditationHabit.status})');

    bool habitCompleted = false;
    if (meditationHabit.id != -1 && meditationHabit.status == 0) {
      await habits.updateHabitStatus(meditationHabit.id, 1);
      // Notify listeners that habits have been updated
      DatabaseService.habitsUpdatedNotifier.value =
          !DatabaseService.habitsUpdatedNotifier.value;
      habitCompleted = true;
      print('Meditation habit marked as completed!');
    } else {
      print('Meditation habit not found or already completed');
    }

    // Award XP based on meditation duration
    final xpService = XPService();
    final xpResult = await xpService.addMeditationXP(widget.duration);

    if (mounted) {
      // Show habit completion notification if habit was marked
      if (habitCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Meditation habit completed!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        // Small delay to show snackbar before navigation
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Show XP gain bubble
      showXPGainBubble(context, xpResult['xpGained']);

      // Show level up animation if leveled up
      if (xpResult['didLevelUp'] == true) {
        showLevelUpAnimation(
          context,
          newLevel: xpResult['newLevel'],
          newRank: xpResult['userXP'].rank,
          xpGained: xpResult['xpGained'],
        );
        // Delay navigation to show animation
        await Future.delayed(const Duration(milliseconds: 2500));
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false,
      );
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  void updateFromTaskHandler(int newTime) {
    if (mounted) {
      setState(() {
        remainingSeconds = newTime;
      });
      if (newTime <= 0 && !_alarmPlayed) {
        _alarmPlayed = true;
        playAlarm();
        showFinishedNotification();
        stopForegroundTask();
      }
    }
  }

  void showTerminateConfirmationDialog() {
    if (isTerminateDialogOpen) return;

    isTerminateDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusLg),
          title: Text(
            'End Session?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to end this meditation session early?',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                isTerminateDialogOpen = false;
                Navigator.of(context).pop();
              },
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMd),
              ),
              onPressed: () {
                isTerminateDialogOpen = false;
                Navigator.of(context).pop();
                terminateMeditation();
              },
              child: Text(
                'End Session',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (remainingSeconds > 0) {
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          title: Text("Meditation", style: AppTheme.headlineMedium),
          centerTitle: true,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        body: Container(
          decoration: AppTheme.gradientBackground(),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Meditation mode indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.15),
                        borderRadius: AppTheme.borderRadiusFull,
                        border:
                            Border.all(color: AppTheme.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.mode.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Timer circle
                    Center(
                      child: RepaintBoundary(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow effect
                            Container(
                              width: 340,
                              height: 340,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withOpacity(0.2),
                                    blurRadius: 60,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            // Progress ring
                            SizedBox(
                              width: 320,
                              height: 320,
                              child: AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return CircularProgressIndicator(
                                    backgroundColor: AppTheme.surfaceBorder,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.accent),
                                    value: _progressAnimation.value,
                                    strokeWidth: 10,
                                    strokeCap: StrokeCap.round,
                                  );
                                },
                              ),
                            ),
                            // Time display
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${(remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(remainingSeconds % 60).toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 2,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  remainingSeconds > 0
                                      ? "remaining"
                                      : "complete",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 64),

                    // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (remainingSeconds > 0) ...[
                      // Pause/Resume button
                      _buildControlButton(
                        icon: isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: isPaused ? AppTheme.success : AppTheme.warning,
                        onPressed: isPaused ? resumeTimer : pauseTimer,
                        label: isPaused ? "Resume" : "Pause",
                      ),
                      const SizedBox(width: 32),
                      // Stop button
                      _buildControlButton(
                        icon: Icons.stop_rounded,
                        color: AppTheme.error,
                        onPressed: showTerminateConfirmationDialog,
                        label: "Stop",
                      ),
                    ] else ...[
                      // Complete button
                      _buildControlButton(
                        icon: Icons.check_rounded,
                        color: AppTheme.success,
                        onPressed: completeMeditation,
                        label: "Complete",
                        large: true,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
        ));
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    bool large = false,
  }) {
    final size = large ? 72.0 : 56.0;
    final iconSize = large ? 36.0 : 28.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4), width: 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(size / 2),
              child: Center(
                child: Icon(icon, color: color, size: iconSize),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MeditationTaskHandler());
}

class MeditationTaskHandler extends TaskHandler {
  Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    await _executeTimerLogic();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      await _executeTimerLogic();
    });
  }

  Future<void> _executeTimerLogic() async {
    final storedSeconds =
        await FlutterForegroundTask.getData<int>(key: 'remainingSeconds') ?? 0;
    final isPaused =
        await FlutterForegroundTask.getData<bool>(key: 'isPaused') ?? false;

    if (!isPaused && storedSeconds > 0) {
      final newTime = storedSeconds - 1;

      if (MeditationCountdownScreen.currentState != null &&
          MeditationCountdownScreen.currentState!.mounted) {
        MeditationCountdownScreen.currentState!.updateFromTaskHandler(newTime);
      }

      await Future.wait([
        FlutterForegroundTask.saveData(key: 'remainingSeconds', value: newTime),
        FlutterForegroundTask.updateService(
          notificationTitle: 'Meditation In Progress',
          notificationText:
              '${(newTime ~/ 60).toString().padLeft(2, '0')}:${(newTime % 60).toString().padLeft(2, '0')}',
        ),
      ]);

      if (newTime <= 0) {
        _timer?.cancel();
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer?.cancel();
    await FlutterForegroundTask.clearAllData();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }
}

void _initializeNotifications() {
  final InitializationSettings initializationSettings =
      InitializationSettings();

  flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    if (response.actionId == 'finish') {
      if (MeditationCountdownScreen.currentState != null &&
          MeditationCountdownScreen.currentState!.mounted) {
        MeditationCountdownScreen.currentState!.completeMeditation();
      }
    }
  });
}
