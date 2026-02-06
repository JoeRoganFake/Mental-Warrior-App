import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/plate_bar_customization_service.dart';
import 'package:mental_warior/services/background_task_manager.dart';
import 'package:mental_warior/services/reminder_service.dart';
import 'package:mental_warior/utils/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = true;

  // Workout settings values
  int _weeklyWorkoutGoal = 5;
  int _defaultRestTimer = 90;
  bool _autoStartRestTimer = true;
  bool _vibrateOnRestComplete = true;
  bool _keepScreenOn = true;
  bool _confirmFinishWorkout = true;
  bool _showWeightInLbs = false;
  bool _useMeasurementInInches = false;
  String _prDisplayMode = 'random';
  List<String> _pinnedExercises = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _settingsService.getAllSettings();
      setState(() {
        _weeklyWorkoutGoal = settings['weeklyWorkoutGoal'];
        _defaultRestTimer = settings['defaultRestTimer'];
        _autoStartRestTimer = settings['autoStartRestTimer'];
        _vibrateOnRestComplete = settings['vibrateOnRestComplete'];
        _keepScreenOn = settings['keepScreenOn'];
        _confirmFinishWorkout = settings['confirmFinishWorkout'];
        _showWeightInLbs = settings['showWeightInLbs'];
        _useMeasurementInInches = settings['useMeasurementInInches'];
        _prDisplayMode = settings['prDisplayMode'];
        _pinnedExercises = List<String>.from(settings['pinnedExercises']);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(Future<void> Function() saveFn) async {
    try {
      await saveFn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Setting saved'),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving setting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error saving setting'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accent.withOpacity(0.15),
                  AppTheme.background,
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: AppTheme.displayLarge.copyWith(
                              height: 1.2,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Customize your experience',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadSettings,
                      icon: Icon(Icons.refresh_rounded, color: AppTheme.accent),
                      iconSize: 24,
                      tooltip: 'Reload settings',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meditation Section
                _buildSectionHeader('Meditation', Icons.self_improvement),
                const SizedBox(height: 12),
                _buildSettingsCard([
                  _buildSettingsTile(
                    'Sound & Music',
                    'Background audio settings',
                    Icons.music_note_outlined,
                    onTap: () {},
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    'Guided Voice',
                    'Change the voice for guided meditation',
                    Icons.record_voice_over,
                    onTap: () {
                      // TODO: Implement guided voice selection
                    },
                  ),
                ]),
                const SizedBox(height: 40),

                // Workout Section
                _buildSectionHeader('Workout', Icons.fitness_center),
                const SizedBox(height: 16),
                
                // Goals
                _buildSubsectionHeader('Goals', Icons.flag_outlined),
                _buildSettingsCard([
                  _buildWeeklyGoalTile(),
                ]),
                const SizedBox(height: 20),

                // Rest Timer
                _buildSubsectionHeader('Rest Timer', Icons.timer_outlined),
                _buildSettingsCard([
                  _buildRestTimerTile(),
                  _buildDivider(),
                  _buildSwitchTile(
                    'Auto-start Timer',
                    'Start rest timer automatically after completing a set',
                    _autoStartRestTimer,
                    (value) async {
                      setState(() => _autoStartRestTimer = value);
                      await _saveSetting(() =>
                          _settingsService.setAutoStartRestTimer(value));
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    'Vibrate',
                    'Vibrate when rest timer completes',
                    _vibrateOnRestComplete,
                    (value) async {
                      setState(() => _vibrateOnRestComplete = value);
                      await _saveSetting(() =>
                          _settingsService.setVibrateOnRestComplete(value));
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // Units
                _buildSubsectionHeader('Units', Icons.straighten_outlined),
                _buildSettingsCard([
                  _buildWeightUnitTile(),
                  _buildDivider(),
                  _buildMeasurementUnitTile(),
                ]),
                const SizedBox(height: 20),

                // Workout Session
                _buildSubsectionHeader(
                    'Workout Session', Icons.play_circle_outline),
                _buildSettingsCard([
                  _buildSwitchTile(
                    'Keep Screen On',
                    'Prevent screen from sleeping during workout',
                    _keepScreenOn,
                    (value) async {
                      setState(() => _keepScreenOn = value);
                      await _saveSetting(
                          () => _settingsService.setKeepScreenOn(value));
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    'Confirm Finish Workout',
                    'Show confirmation before finishing workout',
                    _confirmFinishWorkout,
                    (value) async {
                      setState(() => _confirmFinishWorkout = value);
                      await _saveSetting(() =>
                          _settingsService.setConfirmFinishWorkout(value));
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // Personal Records
                _buildSubsectionHeader(
                    'Personal Records', Icons.emoji_events_outlined),
                _buildSettingsCard([
                  _buildPRDisplayModeTile(),
                  if (_prDisplayMode == 'pinned') ...[
                    _buildDivider(),
                    _buildActionTile(
                      'Manage Pinned Exercises',
                      '${_pinnedExercises.length} exercise${_pinnedExercises.length != 1 ? 's' : ''} pinned',
                      Icons.push_pin,
                      () => _showManagePinnedExercisesDialog(),
                    ),
                  ],
                ]),
                const SizedBox(height: 20),

                // Plate Calculator
                _buildSubsectionHeader(
                    'Plate Calculator', Icons.fitness_center),
                _buildSettingsCard([
                  _buildActionTile(
                    'Custom Plates & Bars',
                    'Customize plate weights, colors, and bar types',
                    Icons.tune,
                    () => _navigateToPlateBarCustomization(),
                  ),
                ]),
                const SizedBox(height: 20),

                // Data
                _buildSubsectionHeader('Data', Icons.storage_outlined),
                _buildSettingsCard([
                  _buildActionTile(
                    'Export Workout Data',
                    'Save your workouts to a file',
                    Icons.upload_outlined,
                    () => _showExportDialog(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    'Import Workout Data',
                    'Restore workouts from a file',
                    Icons.download_outlined,
                    () => _importWorkoutData(),
                  ),
                  _buildDivider(),
                  _buildActionTile(
                    'Clear All Workout History',
                    'Delete all workout records',
                    Icons.delete_forever_outlined,
                    () => _showClearHistoryDialog(),
                    isDestructive: true,
                  ),
                ]),
                const SizedBox(height: 40),

                // General Section
                _buildSectionHeader('General', Icons.tune_outlined),
                const SizedBox(height: 16),
                _buildSettingsCard([
                  
                  _buildDivider(),
                  _buildActionTile(
                    'Test Reminder Notifications',
                    'Manually check for due reminders now',
                    Icons.notification_add_outlined,
                    () => _testReminderNotifications(),
                  ),
                  _buildDivider(),
                  _buildSettingsTile(
                    'About App',
                    'Version 1.0.0',
                    Icons.info_outlined,
                    onTap: () => _navigateToAboutApp(),
                  ),
                ]),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: AppTheme.accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: AppTheme.labelLarge.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent.withOpacity(0.7), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      color: AppTheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.borderRadiusMd,
        side: BorderSide(
          color: AppTheme.surfaceBorder.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppTheme.borderRadiusMd,
          boxShadow: AppTheme.shadowMd,
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: AppTheme.surfaceBorder.withOpacity(0.4),
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppTheme.accent.withOpacity(0.1),
        highlightColor: AppTheme.accent.withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.accent,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: AppTheme.accent,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          height: 1.3,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
      activeTrackColor: AppTheme.accent.withOpacity(0.3),
      inactiveThumbColor: AppTheme.textTertiary,
      inactiveTrackColor: AppTheme.surfaceBorder.withOpacity(0.3),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor:
            (isDestructive ? AppTheme.error : AppTheme.accent).withOpacity(0.1),
        highlightColor: (isDestructive ? AppTheme.error : AppTheme.accent)
            .withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isDestructive ? AppTheme.error : AppTheme.textSecondary)
                  .withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDestructive ? AppTheme.error : AppTheme.accent,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: AppTheme.bodyMedium.copyWith(
              color: isDestructive ? AppTheme.error : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: AppTheme.accent,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyGoalTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showWeeklyGoalDialog,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppTheme.accent.withOpacity(0.1),
        highlightColor: AppTheme.accent.withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            'Weekly Workout Goal',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            '$_weeklyWorkoutGoal workouts per week',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_weeklyWorkoutGoal',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestTimerTile() {
    final minutes = _defaultRestTimer ~/ 60;
    final seconds = _defaultRestTimer % 60;
    final displayTime = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds sec';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showRestTimerDialog,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppTheme.accent.withOpacity(0.1),
        highlightColor: AppTheme.accent.withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            'Default Rest Time',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'Time between sets',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayTime,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightUnitTile() {
    final currentUnit = _showWeightInLbs ? 'lbs' : 'kg';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showWeightUnitDialog,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppTheme.accent.withOpacity(0.1),
        highlightColor: AppTheme.accent.withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            'Weight Unit',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'Unit for displaying weight',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentUnit,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementUnitTile() {
    final currentUnit = _useMeasurementInInches ? 'in' : 'cm';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showMeasurementUnitDialog,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppTheme.accent.withOpacity(0.1),
        highlightColor: AppTheme.accent.withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            'Body Measurement Unit',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            'Unit for body measurements',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentUnit,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPRDisplayModeTile() {
    final displayText = _prDisplayMode == 'random'
        ? 'Random Daily'
        : _prDisplayMode == 'pinned'
            ? 'Pinned Exercises'
            : 'None';
    final subtitle = _prDisplayMode == 'random'
        ? '5 random PRs that change daily'
        : _prDisplayMode == 'pinned'
            ? 'Show PRs for specific exercises'
            : 'PRs hidden on workout page';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPRDisplayModeDialog,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppTheme.accent.withOpacity(0.1),
        highlightColor: AppTheme.accent.withOpacity(0.08),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            'PR Display Mode',
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayText,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showWeeklyGoalDialog() {
    int tempGoal = _weeklyWorkoutGoal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text('Weekly Workout Goal', style: AppTheme.headlineSmall),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How many workouts per week?',
                    style: AppTheme.bodyMedium
                        .copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle,
                            color: AppTheme.accent, size: 36),
                        onPressed: tempGoal > 1
                            ? () => setDialogState(() => tempGoal--)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tempGoal.toString(),
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.add_circle,
                            color: AppTheme.accent, size: 36),
                        onPressed: tempGoal < 14
                            ? () => setDialogState(() => tempGoal++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() => _weeklyWorkoutGoal = tempGoal);
                    await _saveSetting(() =>
                        _settingsService.setWeeklyWorkoutGoal(tempGoal));
                    Navigator.pop(context);
                  },
                  style:
                      ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRestTimerDialog() {
    int tempSeconds = _defaultRestTimer;
    final presets = [30, 60, 90, 120, 180, 300];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text('Default Rest Time', style: AppTheme.headlineSmall),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatRestTime(tempSeconds),
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: tempSeconds.toDouble(),
                    min: 15,
                    max: 600,
                    divisions: 39,
                    activeColor: AppTheme.accent,
                    onChanged: (value) {
                      setDialogState(() => tempSeconds = value.round());
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Quick Select',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((seconds) {
                      final isSelected = tempSeconds == seconds;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => tempSeconds = seconds),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                ? AppTheme.accent
                                : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatRestTime(seconds),
                            style: TextStyle(
                              color:
                                  isSelected
                                  ? Colors.white
                                  : AppTheme.textTertiary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() => _defaultRestTimer = tempSeconds);
                    await _saveSetting(() =>
                        _settingsService.setDefaultRestTimer(tempSeconds));
                    Navigator.pop(context);
                  },
                  style:
                      ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatRestTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0 && secs > 0) {
      return '$minutes:${secs.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$secs sec';
    }
  }

  void _showWeightUnitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Weight Unit', style: AppTheme.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitOption(
                'Kilograms (kg)',
                'Metric system',
                !_showWeightInLbs,
                () {
                  Navigator.pop(context);
                  if (_showWeightInLbs) {
                    _showConversionPrompt(
                      fromUnit: 'lbs',
                      toUnit: 'kg',
                      isWeight: true,
                      onConvert: () async {
                        setState(() => _showWeightInLbs = false);
                        await _saveSetting(() =>
                            _settingsService.setShowWeightInLbs(false));
                      },
                      onDisplayOnly: () async {
                        setState(() => _showWeightInLbs = false);
                        await _saveSetting(() =>
                            _settingsService.setShowWeightInLbs(false));
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildUnitOption(
                'Pounds (lbs)',
                'Imperial system',
                _showWeightInLbs,
                () {
                  Navigator.pop(context);
                  if (!_showWeightInLbs) {
                    _showConversionPrompt(
                      fromUnit: 'kg',
                      toUnit: 'lbs',
                      isWeight: true,
                      onConvert: () async {
                        setState(() => _showWeightInLbs = true);
                        await _saveSetting(() =>
                            _settingsService.setShowWeightInLbs(true));
                      },
                      onDisplayOnly: () async {
                        setState(() => _showWeightInLbs = true);
                        await _saveSetting(() =>
                            _settingsService.setShowWeightInLbs(true));
                      },
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMeasurementUnitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title:
              Text('Body Measurement Unit', style: AppTheme.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitOption(
                'Centimeters (cm)',
                'Metric system',
                !_useMeasurementInInches,
                () {
                  Navigator.pop(context);
                  if (_useMeasurementInInches) {
                    _showConversionPrompt(
                      fromUnit: 'in',
                      toUnit: 'cm',
                      isWeight: false,
                      onConvert: () async {
                        setState(() => _useMeasurementInInches = false);
                        await _saveSetting(() => _settingsService
                            .setUseMeasurementInInches(false));
                      },
                      onDisplayOnly: () async {
                        setState(() => _useMeasurementInInches = false);
                        await _saveSetting(() => _settingsService
                            .setUseMeasurementInInches(false));
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildUnitOption(
                'Inches (in)',
                'Imperial system',
                _useMeasurementInInches,
                () {
                  Navigator.pop(context);
                  if (!_useMeasurementInInches) {
                    _showConversionPrompt(
                      fromUnit: 'cm',
                      toUnit: 'in',
                      isWeight: false,
                      onConvert: () async {
                        setState(() => _useMeasurementInInches = true);
                        await _saveSetting(() =>
                            _settingsService.setUseMeasurementInInches(true));
                      },
                      onDisplayOnly: () async {
                        setState(() => _useMeasurementInInches = true);
                        await _saveSetting(() =>
                            _settingsService.setUseMeasurementInInches(true));
                      },
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConversionPrompt({
    required String fromUnit,
    required String toUnit,
    required bool isWeight,
    required VoidCallback onConvert,
    required VoidCallback onDisplayOnly,
  }) {
    final conversionType = isWeight ? 'weight' : 'body measurement';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Convert Existing Data?', style: AppTheme.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'re changing from $fromUnit to $toUnit.',
                style: AppTheme.bodyMedium
                    .copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to:',
                style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _convertExistingData(fromUnit, toUnit, isWeight);
                  onConvert();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Convert all data',
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recalculate all existing $conversionType values to $toUnit',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onDisplayOnly();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBorder,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.text_fields, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change display only',
                              style: AppTheme.bodyMedium
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keep existing values, just change the unit label',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _convertExistingData(
      String fromUnit, String toUnit, bool isWeight) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(width: 16),
            Text('Converting data...',
                style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );

    try {
      final measurementService = MeasurementService();

      if (isWeight) {
        if (fromUnit == 'kg' && toUnit == 'lbs') {
          await measurementService.convertMeasurements('kg', 'lbs', 2.20462);
          await _convertWorkoutWeights(2.20462, 'lbs');
        } else if (fromUnit == 'lbs' && toUnit == 'kg') {
          await measurementService.convertMeasurements('lbs', 'kg', 0.453592);
          await _convertWorkoutWeights(0.453592, 'kg');
        }
      } else {
        if (fromUnit == 'cm' && toUnit == 'in') {
          await measurementService.convertMeasurements('cm', 'in', 0.393701);
        } else if (fromUnit == 'in' && toUnit == 'cm') {
          await measurementService.convertMeasurements('in', 'cm', 2.54);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All data converted to $toUnit'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting data: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _convertWorkoutWeights(double factor, String newUnit) async {
    final workoutService = WorkoutService();
    await workoutService.convertAllWorkoutWeights(factor, newUnit);
  }

  Widget _buildUnitOption(
      String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
              ? AppTheme.accent.withOpacity(0.2)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall
                        .copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.accent, size: 24),
          ],
        ),
      ),
    );
  }

  void _showPRDisplayModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('PR Display Mode', style: AppTheme.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitOption(
                'Random Daily',
                '5 random PRs that change every day',
                _prDisplayMode == 'random',
                () async {
                  setState(() {
                    _prDisplayMode = 'random';
                    _pinnedExercises.clear();
                  });
                  await _saveSetting(
                      () => _settingsService.setPrDisplayMode('random'));
                  await _saveSetting(() => _settingsService.setPinnedExercises([]));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _buildUnitOption(
                'Pinned Exercises',
                'Show specific exercises you choose',
                _prDisplayMode == 'pinned',
                () async {
                  setState(() => _prDisplayMode = 'pinned');
                  await _saveSetting(
                      () => _settingsService.setPrDisplayMode('pinned'));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _buildUnitOption(
                'None',
                'Don\'t show PRs on workout page',
                _prDisplayMode == 'none',
                () async {
                  setState(() {
                    _prDisplayMode = 'none';
                    _pinnedExercises.clear();
                  });
                  await _saveSetting(
                      () => _settingsService.setPrDisplayMode('none'));
                  await _saveSetting(() => _settingsService.setPinnedExercises([]));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showManagePinnedExercisesDialog() async {
    final workoutService = WorkoutService();
    final workouts = await workoutService.getWorkouts();

    final Set<String> allExercises = {};
    for (var workout in workouts) {
      for (var exercise in workout.exercises) {
        final cleanName = exercise.name
            .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
            .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
            .trim();
        if (cleanName.isNotEmpty) {
          allExercises.add(cleanName);
        }
      }
    }

    if (allExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exercises found in workout history')),
      );
      return;
    }

    final sortedExercises = allExercises.toList()..sort();
    final tempPinned = List<String>.from(_pinnedExercises);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  children: [
                    // Header with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accent.withOpacity(0.15),
                            AppTheme.accent.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.push_pin,
                                  color: AppTheme.accent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pin Your Exercises',
                                      style: AppTheme.headlineSmall.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${tempPinned.length}/5 selected',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Progress indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: tempPinned.length / 5,
                              minHeight: 6,
                              backgroundColor: AppTheme.surfaceBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Select up to 5 exercises to display on your PRs widget',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Exercise list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: sortedExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = sortedExercises[index];
                          final isPinned = tempPinned.contains(exercise);
                          final isDisabled = tempPinned.length >= 5 && !isPinned;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isDisabled
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          if (isPinned) {
                                            tempPinned.remove(exercise);
                                          } else {
                                            if (tempPinned.length < 5) {
                                              tempPinned.add(exercise);
                                            }
                                          }
                                        });
                                      },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isPinned
                                        ? AppTheme.accent.withOpacity(0.12)
                                        : isDisabled
                                            ? AppTheme.surfaceBorder
                                                .withOpacity(0.2)
                                            : AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isPinned
                                          ? AppTheme.accent.withOpacity(0.4)
                                          : AppTheme.surfaceBorder,
                                      width: isPinned ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isPinned
                                                ? AppTheme.accent
                                                : AppTheme.textSecondary,
                                            width: 2,
                                          ),
                                          color: isPinned
                                              ? AppTheme.accent
                                              : Colors.transparent,
                                        ),
                                        child: isPinned
                                            ? Icon(
                                                Icons.check,
                                                size: 12,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          exercise,
                                          style: AppTheme.bodyMedium.copyWith(
                                            color: isDisabled
                                                ? AppTheme.textSecondary
                                                : AppTheme.textPrimary,
                                            fontWeight: isPinned
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (isPinned)
                                        Icon(
                                          Icons.push_pin,
                                          size: 16,
                                          color: AppTheme.accent,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppTheme.textSecondary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() => _pinnedExercises = tempPinned);
                                await _saveSetting(() =>
                                    _settingsService
                                        .setPinnedExercises(tempPinned));
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Save',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Export Workout Data', style: AppTheme.headlineSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose export format:',
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              _buildExportOption(
                'JSON Format',
                'Structured data format, easy to re-import',
                Icons.code,
                () {
                  Navigator.pop(context);
                  _exportWorkoutData('json');
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                'CSV Format',
                'Spreadsheet format for Excel/Google Sheets',
                Icons.table_chart,
                () {
                  Navigator.pop(context);
                  _exportWorkoutData('csv');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportOption(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceBorder.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppTheme.accent, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _exportWorkoutData(String format) async {
    // Request storage permission first
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we don't need storage permission for app-specific directories
      // But for older versions, we need to request it
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    const Text('Storage permission is required to export data'),
                backgroundColor: AppTheme.error,
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
      }
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(width: 16),
            Text('Exporting workout data...', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );

    try {
      final workoutService = WorkoutService();
      final workouts = await workoutService.getWorkouts();

      if (workouts.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No workout data to export'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      String fileContent;
      String fileName;
      String mimeType;
      final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());

      if (format == 'json') {
        fileContent = _generateJsonExport(workouts);
        fileName = 'mental_warrior_workouts_$timestamp.json';
        mimeType = 'application/json';
      } else {
        fileContent = _generateCsvExport(workouts);
        fileName = 'mental_warrior_workouts_$timestamp.csv';
        mimeType = 'text/csv';
      }

      // Use app's documents directory which is always accessible
      Directory directory;
      if (Platform.isAndroid) {
        // For Android, use the app's external files directory
        // This is accessible without special permissions
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Create a "Downloads" or "Exports" folder in the app's directory
          directory = Directory('${externalDir.path}/Exports');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } else {
          // Fallback to app documents directory
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        final downloadsDir = await getDownloadsDirectory();
        directory = downloadsDir ?? await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsString(fileContent);
      
      // Debug: Verify file was written
      final fileExists = await file.exists();
      final fileSize = await file.length();
      debugPrint('Export file created: $fileExists');
      debugPrint('Export file path: ${file.path}');
      debugPrint('Export file size: $fileSize bytes');

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Automatically trigger share dialog to save to Downloads
        try {
          final result = await Share.shareXFiles(
            [XFile(file.path, mimeType: mimeType)],
            subject: 'Mental Warrior Workout Data',
            text: 'Export from Mental Warrior - $fileName',
          );

          debugPrint('Share result: ${result.status}');

          if (mounted) {
            if (result.status == ShareResultStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$fileName saved successfully'),
                  backgroundColor: AppTheme.accent,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if (result.status == ShareResultStatus.dismissed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Export cancelled'),
                  backgroundColor: AppTheme.textSecondary,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error sharing file: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File created at: ${file.path}'),
                backgroundColor: AppTheme.accent,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      debugPrint('Error exporting workout data: $e');
    }
  }

  String _generateJsonExport(List<dynamic> workouts) {
    final exportData = {
      'export_date': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'total_workouts': workouts.length,
      'workouts': workouts.map((workout) {
        return {
          'id': workout.id,
          'name': workout.name,
          'date': workout.date,
          'duration': workout.duration,
          'exercises': workout.exercises.map((exercise) {
            return {
              'id': exercise.id,
              'name': exercise.name,
              'equipment': exercise.equipment,
              'notes': exercise.notes,
              'superset_group': exercise.supersetGroup,
              'finished': exercise.finished,
              'sets': exercise.sets.map((set) {
                return {
                  'set_number': set.setNumber,
                  'weight': set.weight,
                  'reps': set.reps,
                  'rest_time': set.restTime,
                  'completed': set.completed,
                  'is_pr': set.isPR,
                  'set_type': set.setType.toString().split('.').last,
                  'volume': set.volume,
                };
              }).toList(),
            };
          }).toList(),
        };
      }).toList(),
    };

    return JsonEncoder.withIndent('  ').convert(exportData);
  }

  String _generateCsvExport(List<dynamic> workouts) {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln(
        'Workout ID,Workout Date,Workout Name,Duration (min),Exercise Name,Equipment,Set Number,Weight,Reps,Rest Time (sec),Completed,Is PR,Set Type,Volume,Notes');
    
    // CSV Data
    for (var workout in workouts) {
      final durationMin = (workout.duration / 60).toStringAsFixed(1);
      
      for (var exercise in workout.exercises) {
        for (var set in exercise.sets) {
          final row = [
            workout.id.toString(),
            workout.date,
            _escapeCsv(workout.name),
            durationMin,
            _escapeCsv(exercise.name),
            _escapeCsv(exercise.equipment),
            set.setNumber.toString(),
            set.weight.toString(),
            set.reps.toString(),
            set.restTime.toString(),
            set.completed ? 'Yes' : 'No',
            set.isPR ? 'Yes' : 'No',
            set.setType.toString().split('.').last,
            set.volume.toStringAsFixed(1),
            _escapeCsv(exercise.notes ?? ''),
          ];
          buffer.writeln(row.join(','));
        }
      }
    }
    
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }



  // ==================== IMPORT METHODS ====================

  Future<void> _importWorkoutData() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final extension = fileName.split('.').last.toLowerCase();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.accent),
              const SizedBox(height: 16),
              Text('Importing workout data...', style: AppTheme.bodyMedium),
            ],
          ),
        ),
      );

      int importedCount = 0;

      if (extension == 'json') {
        importedCount = await _importFromJson(file);
      } else if (extension == 'csv') {
        importedCount = await _importFromCsv(file);
      } else {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorDialog(
            'Unsupported file format. Please use JSON or CSV files.');
        return;
      }

      Navigator.of(context).pop(); // Close loading dialog

      if (importedCount > 0) {
        _showImportSuccessDialog(importedCount);
      } else {
        _showErrorDialog('No workout data found in the file.');
      }
    } catch (e) {
      debugPrint('Error importing workout data: $e');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Close loading dialog if still open
      }
      _showErrorDialog('Failed to import workout data: ${e.toString()}');
    }
  }

  Future<int> _importFromJson(File file) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!data.containsKey('workouts')) {
        throw Exception('Invalid JSON format: missing "workouts" field');
      }

      final workouts = data['workouts'] as List<dynamic>;
      final workoutService = WorkoutService();
      int importedCount = 0;

      for (var workoutData in workouts) {
        try {
          // Insert workout
          final workoutId = await workoutService.addWorkout(
            workoutData['name'] ?? 'Imported Workout',
            workoutData['date'] ?? DateTime.now().toString().split(' ')[0],
            workoutData['duration'] ?? 0,
          );

          // Insert exercises
          if (workoutData.containsKey('exercises')) {
            final exercises = workoutData['exercises'] as List<dynamic>;

            for (var exerciseData in exercises) {
              final exerciseId = await workoutService.addExercise(
                workoutId,
                exerciseData['name'] ?? 'Unknown Exercise',
                exerciseData['equipment'] ?? 'Unknown',
                notes: exerciseData['notes'],
                supersetGroup: exerciseData['superset_group'],
              );

              // Mark exercise as finished if specified
              if (exerciseData['finished'] == true) {
                final db = await DatabaseService.instance.database;
                await db.update(
                  'exercises',
                  {'finished': 1},
                  where: 'id = ?',
                  whereArgs: [exerciseId],
                );
              }

              // Insert sets
              if (exerciseData.containsKey('sets')) {
                final sets = exerciseData['sets'] as List<dynamic>;

                for (var setData in sets) {
                  final setId = await workoutService.addSet(
                    exerciseId,
                    setData['set_number'] ?? 1,
                    (setData['weight'] ?? 0.0).toDouble(),
                    setData['reps'] ?? 0,
                    setData['rest_time'] ?? 90,
                    setType: setData['set_type'] ?? 'normal',
                  );

                  // Mark set as completed if specified
                  if (setData['completed'] == true) {
                    await workoutService.updateSetStatus(setId, true);
                  }
                }
              }
            }
          }

          importedCount++;
        } catch (e) {
          debugPrint('Error importing workout: $e');
          // Continue with next workout
        }
      }

      return importedCount;
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      throw Exception('Invalid JSON format: ${e.toString()}');
    }
  }

  Future<int> _importFromCsv(File file) async {
    try {
      final content = await file.readAsString();
      final lines =
          content.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        throw Exception('CSV file is empty');
      }

      // Skip header row
      if (lines.length < 2) {
        throw Exception('CSV file has no data rows');
      }

      final workoutService = WorkoutService();
      final Map<String, int> workoutIds = {}; // Map workout key to workoutId
      final Map<String, int> exerciseIds = {}; // Map exercise key to exerciseId
      int importedCount = 0;

      for (int i = 1; i < lines.length; i++) {
        try {
          final row = _parseCsvRow(lines[i]);
          if (row.length < 14)
            continue; // Skip incomplete rows (now includes workout ID)

          final originalWorkoutId = row[0]; // Original workout ID from export
          final workoutDate = row[1];
          final workoutName = row[2];
          final workoutDuration = int.tryParse(row[3]) ?? 0;
          final exerciseName = row[4];
          final equipment = row[5];
          final setNumber = int.tryParse(row[6]) ?? 1;
          final weight = double.tryParse(row[7]) ?? 0.0;
          final reps = int.tryParse(row[8]) ?? 0;
          final restTime = int.tryParse(row[9]) ?? 90;
          final completed = row[10].toLowerCase() == 'yes' || row[10] == '1';
          final setType = row[12].isNotEmpty ? row[12] : 'normal';
          final notes = row.length > 14 ? row[14] : null;

          // Create unique keys using original workout ID to differentiate workouts on same day
          final workoutKey = '$originalWorkoutId|$workoutDate|$workoutName';
          final exerciseKey = '$workoutKey|$exerciseName|$equipment';

          // Insert workout if not exists
          if (!workoutIds.containsKey(workoutKey)) {
            final workoutId = await workoutService.addWorkout(
              workoutName,
              workoutDate,
              workoutDuration,
            );
            workoutIds[workoutKey] = workoutId;
          }

          // Insert exercise if not exists
          if (!exerciseIds.containsKey(exerciseKey)) {
            final exerciseId = await workoutService.addExercise(
              workoutIds[workoutKey]!,
              exerciseName,
              equipment,
              notes: notes,
            );
            exerciseIds[exerciseKey] = exerciseId;
          }

          // Insert set
          final setId = await workoutService.addSet(
            exerciseIds[exerciseKey]!,
            setNumber,
            weight,
            reps,
            restTime,
            setType: setType,
          );

          // Mark set as completed if specified
          if (completed) {
            await workoutService.updateSetStatus(setId, true);
          }
        } catch (e) {
          debugPrint('Error importing CSV row ${i + 1}: $e');
          // Continue with next row
        }
      }

      importedCount = workoutIds.length;
      return importedCount;
    } catch (e) {
      debugPrint('Error parsing CSV: $e');
      throw Exception('Invalid CSV format: ${e.toString()}');
    }
  }

  List<String> _parseCsvRow(String row) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < row.length; i++) {
      final char = row[i];

      if (char == '"') {
        if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
          // Escaped quote
          current.write('"');
          i++; // Skip next quote
        } else {
          // Toggle quote mode
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // Field separator
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    // Add last field
    result.add(current.toString());

    return result;
  }

  void _showImportSuccessDialog(int count) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.accent, size: 28),
              const SizedBox(width: 12),
              Text('Import Successful', style: AppTheme.headlineSmall),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully imported $count workout${count != 1 ? 's' : ''} from the file.',
                style:
                    AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your workout history has been updated.',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.accent, size: 28),
              const SizedBox(width: 12),
              Text('Import Failed', style: AppTheme.headlineSmall),
            ],
          ),
          content: Text(
            message,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _testReminderNotifications() async {
    try {
      final reminderService = ReminderService();
      final taskService = TaskService();
      final now = DateTime.now();
      
      // Get all reminders from database (not just due ones)
      final db = await DatabaseService.instance.database;
      final allReminders = await db.query('reminders', orderBy: 'dueDateTime ASC');
      
      // Get due reminders
      final dueReminders = await reminderService.checkDueReminders();
      
      // Build detailed info string
      final buffer = StringBuffer();
      buffer.writeln('🕐 CURRENT TIME');
      buffer.writeln('${now.toString()}');
      buffer.writeln('');
      buffer.writeln('📊 REMINDER DATABASE STATUS');
      buffer.writeln('Total reminders in database: ${allReminders.length}');
      buffer.writeln('Due reminders (ready to send): ${dueReminders.length}');
      buffer.writeln('');
      
      if (allReminders.isEmpty) {
        buffer.writeln('ℹ️ No reminders found in database.');
        buffer.writeln('Create a task with a reminder to test notifications.');
      } else {
        buffer.writeln('📋 ALL REMINDERS IN DATABASE:');
        buffer.writeln('${'─' * 50}');
        
        for (int i = 0; i < allReminders.length; i++) {
          final reminder = allReminders[i];
          final taskId = reminder['taskId'] as int;
          final reminderValue = reminder['reminderValue'] as int;
          final reminderUnit = reminder['reminderUnit'] as String;
          final reminderTime = reminder['reminderTime'] as String;
          final dueDateTime = DateTime.parse(reminder['dueDateTime'] as String);
          final notificationSent = (reminder['notificationSent'] as int) == 1;
          
          // Get task details
          String taskLabel = 'Unknown Task';
          String taskDeadline = 'No deadline';
          try {
            final tasks = await taskService.getTasks();
            final task = tasks.firstWhere((t) => t.id == taskId);
            taskLabel = task.label;
            taskDeadline = task.deadline.isNotEmpty ? task.deadline : 'No deadline';
          } catch (e) {
            // Task not found or error
          }
          
          final isDue = dueDateTime.isBefore(now) || dueDateTime.isAtSameMomentAs(now);
          final timeUntilDue = dueDateTime.difference(now);
          final timeUntilDueStr = timeUntilDue.isNegative 
              ? 'OVERDUE by ${timeUntilDue.abs().inMinutes} min' 
              : 'Due in ${timeUntilDue.inMinutes} min';
          
          buffer.writeln('');
          buffer.writeln('Reminder #${i + 1}:');
          buffer.writeln('  ID: ${reminder['id']}');
          buffer.writeln('  Task: $taskLabel (ID: $taskId)');
          buffer.writeln('  Task Deadline: $taskDeadline');
          buffer.writeln('  Reminder: $reminderValue $reminderUnit before $reminderTime');
          buffer.writeln('  Due DateTime: ${dueDateTime.toString()}');
          buffer.writeln('  Status: ${isDue ? '✅ DUE NOW' : '⏳ PENDING'}');
          buffer.writeln('  Time Until Due: $timeUntilDueStr');
          buffer.writeln('  Notification Sent: ${notificationSent ? 'YES' : 'NO'}');
          buffer.writeln('  ${isDue && !notificationSent ? '🔔 WILL SEND NOTIFICATION' : ''}');
        }
      }
      
      final detailedInfo = buffer.toString();
      
      // Print to console
      print('\n${'=' * 60}');
      print('MANUAL REMINDER CHECK TEST');
      print('=' * 60);
      print(detailedInfo);
      print('=' * 60);
      print('\nExecuting reminder check callback...\n');
      
      // Show detailed dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reminder Check Details',
                    style: AppTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(maxHeight: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      detailedInfo,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  
                  // Show processing dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.surface,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.accent),
                          const SizedBox(height: 16),
                          Text(
                            'Sending notifications...',
                            style: AppTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                  
                  try {
                    // Run the reminder check callback
                    await BackgroundTaskManager.checkRemindersCallback();
                    
                    if (mounted) {
                      Navigator.pop(context); // Close processing dialog
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            dueReminders.isEmpty
                                ? 'No due reminders to send'
                                : '${dueReminders.length} notification(s) sent!',
                          ),
                          backgroundColor: AppTheme.accent,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // Close processing dialog
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppTheme.error,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  dueReminders.isEmpty ? 'OK' : 'Send Notifications (${dueReminders.length})',
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Error in test reminder notifications: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reminder info: $e'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }









  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Clear All Workout History?',
              style: AppTheme.headlineSmall),
          content: Text(
            'This will permanently delete all your workout records, active sessions, and temporary data. This action cannot be undone.',
            style:
                AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () async {
                Navigator.pop(context);
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppTheme.surface,
                    content: Row(
                      children: [
                        CircularProgressIndicator(color: AppTheme.accent),
                        const SizedBox(width: 16),
                        Text('Clearing workout history...',
                            style: TextStyle(color: AppTheme.textPrimary)),
                      ],
                    ),
                  ),
                );

                try {
                  final workoutService = WorkoutService();
                  await workoutService.clearAllWorkoutHistory();
                  
                  if (mounted) {
                    Navigator.pop(context); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('All workout history cleared successfully'),
                        backgroundColor: AppTheme.accent,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error clearing history: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                  debugPrint('Error clearing workout history: $e');
                }
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToPlateBarCustomization() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PlateBarCustomizationPage(),
      ),
    );
  }

  void _navigateToAboutApp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutAppPage(),
      ),
    );
  }

  // Notification settings navigation removed
}

class PlateBarCustomizationPage extends StatelessWidget {
  const PlateBarCustomizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlateBarCustomizationPageImpl();
  }
}

class _PlateBarCustomizationPageImpl extends StatefulWidget {
  const _PlateBarCustomizationPageImpl();

  @override
  State<_PlateBarCustomizationPageImpl> createState() =>
      _PlateBarCustomizationPageImplState();
}

class _PlateBarCustomizationPageImplState
    extends State<_PlateBarCustomizationPageImpl>
    with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final PlateBarCustomizationService _customizationService =
      PlateBarCustomizationService();

  bool _isLoading = true;
  bool _useLbs = false;

  late final TabController _tabController;
  late final VoidCallback _customizationListener;

  List<CustomPlate> _plates = const [];
  List<CustomBar> _bars = const [];

  String get _unit => _useLbs ? 'lbs' : 'kg';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _customizationListener = () {
      if (mounted) _load();
    };
    PlateBarCustomizationService.customizationUpdatedNotifier
        .addListener(_customizationListener);
    _load();
  }

  @override
  void dispose() {
    PlateBarCustomizationService.customizationUpdatedNotifier
        .removeListener(_customizationListener);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _customizationService.ensureTablesExist();
    final useLbs = await _settingsService.getShowWeightInLbs();
    final plates =
        await _customizationService.getCustomPlates(useLbs ? 'lbs' : 'kg');
    final bars =
        await _customizationService.getCustomBars(useLbs ? 'lbs' : 'kg');
    if (!mounted) return;
    setState(() {
      _useLbs = useLbs;
      _plates = plates;
      _bars = bars;
      _isLoading = false;
    });
  }

  Future<void> _resetCurrentTabToDefaults() async {
    final unit = _unit;
    final isPlates = _tabController.index == 0;
    final title = isPlates ? 'Reset plates?' : 'Reset bars?';
    final message = isPlates
        ? 'This removes all custom plates for $unit.'
        : 'This removes all custom bars for $unit.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (isPlates) {
      await _customizationService.resetPlatesToDefaults(unit);
    } else {
      await _customizationService.resetBarsToDefaults(unit);
    }

    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isPlates
            ? 'Plates reset to defaults ($unit)'
            : 'Bars reset to defaults ($unit)'),
      ),
    );
  }

  Future<void> _addPlate() async {
    final result = await _showPlateDialog(context, unit: _unit);
    if (result == null) return;
    await _customizationService.addCustomPlate(
      weight: result.weight,
      color: result.color.value,
      label: _formatWeightLabel(result.weight),
      unit: _unit,
      isDefault: false,
    );
  }

  Future<void> _editPlate(CustomPlate plate) async {
    final result =
        await _showPlateDialog(context, unit: _unit, existing: plate);
    if (result == null) return;
    await _customizationService.updateCustomPlate(
      id: plate.id,
      weight: result.weight,
      color: result.color.value,
      label: _formatWeightLabel(result.weight),
    );
  }

  Future<void> _deletePlate(CustomPlate plate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title:
            const Text('Delete plate?', style: TextStyle(color: Colors.white)),
        content: Text('Delete ${_formatNumber(plate.weight)} $_unit plate?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _customizationService.deleteCustomPlate(plate.id);
  }

  Future<void> _addBar() async {
    final result = await _showBarDialog(context, unit: _unit);
    if (result == null) return;
    await _customizationService.addCustomBar(
      name: result.name,
      weight: result.weight,
      iconCodePoint:
          _barIconCodePointFor(name: result.name, shape: result.shape),
      shape: result.shape,
      unit: _unit,
      isDefault: false,
    );
  }

  Future<void> _editBar(CustomBar bar) async {
    if (bar.name.trim().toLowerCase() == 'no bar') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('"No Bar" cannot be edited.')),
      );
      return;
    }
    final result = await _showBarDialog(context, unit: _unit, existing: bar);
    if (result == null) return;
    await _customizationService.updateCustomBar(
      id: bar.id,
      name: result.name,
      weight: result.weight,
      iconCodePoint:
          _barIconCodePointFor(name: result.name, shape: result.shape),
      shape: result.shape,
    );
  }

  Future<void> _deleteBar(CustomBar bar) async {
    if (bar.name.trim().toLowerCase() == 'no bar') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('"No Bar" cannot be deleted.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete bar?', style: TextStyle(color: Colors.white)),
        content: Text('Delete ${bar.name} ($_unit)?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _customizationService.deleteCustomBar(bar.id);
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _useLbs ? 'lbs' : 'kg';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(200),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accent.withOpacity(0.15),
                  AppTheme.background,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar with back button
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: AppTheme.accent, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        tooltip: 'Reset to defaults',
                        onPressed:
                            _isLoading ? null : _resetCurrentTabToDefaults,
                        icon: Icon(Icons.restart_alt,
                            color: AppTheme.accent, size: 24),
                      ),
                    ],
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize Plates & Bars',
                        style: AppTheme.displayLarge.copyWith(
                          fontSize: 24,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adjust weights, colors, and bar types for your workouts',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.accent,
                    labelColor: AppTheme.accent,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(text: 'Plates ($unitLabel)'),
                      Tab(text: 'Bars ($unitLabel)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isLoading ? null : _buildCustomFAB(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlatesTab(),
                _buildBarsTab(),
              ],
            ),
    );
  }

  Widget _buildCustomFAB() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        splashColor: AppTheme.accent.withOpacity(0.2),
        highlightColor: AppTheme.accent.withOpacity(0.15),
        onTap: () {
          if (_tabController.index == 0) {
            _addPlate();
          } else {
            _addBar();
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(
              color: AppTheme.accent.withOpacity(0.6),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(100),
            boxShadow: AppTheme.shadowMd,
          ),
          child: Icon(
            Icons.add_rounded,
            color: AppTheme.accent,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildPlatesTab() {
    if (_plates.isEmpty) {
      return _buildEmptyState(
        icon: Icons.circle,
        title: 'Loading plates...',
        subtitle: 'If this persists, tap reset to defaults.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _plates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final plate = _plates[index];
        final color = Color(plate.color);
        return Card(
          color: AppTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppTheme.surfaceBorder.withOpacity(0.6),
              width: 1,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.shadowMd,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                splashColor: AppTheme.accent.withOpacity(0.1),
                highlightColor: AppTheme.accent.withOpacity(0.08),
                onTap: () => _editPlate(plate),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_formatNumber(plate.weight)} $_unit',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Color: ${plate.label}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () => _editPlate(plate),
                            icon: Icon(Icons.edit_rounded,
                                color: AppTheme.accent, size: 20),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deletePlate(plate),
                            icon: Icon(Icons.delete_outline,
                                color: AppTheme.error, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarsTab() {
    if (_bars.isEmpty) {
      return _buildEmptyState(
        icon: Icons.fitness_center,
        title: 'Loading bars...',
        subtitle: 'If this persists, tap reset to defaults.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _bars.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bar = _bars[index];
        final isNoBar = bar.name.trim().toLowerCase() == 'no bar';
        final icon = IconData(
          _barIconCodePointFor(name: bar.name, shape: bar.shape),
          fontFamily: 'MaterialIcons',
        );
        return Card(
          color: AppTheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppTheme.surfaceBorder.withOpacity(0.6),
              width: 1,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.shadowMd,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                splashColor: AppTheme.accent.withOpacity(0.1),
                highlightColor: AppTheme.accent.withOpacity(0.08),
                onTap: isNoBar ? null : () => _editBar(bar),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: AppTheme.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bar.name,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatNumber(bar.weight)} $_unit',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isNoBar)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _editBar(bar),
                              icon: Icon(Icons.edit_rounded,
                                  color: AppTheme.accent, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _deleteBar(bar),
                              icon: Icon(Icons.delete_outline,
                                  color: AppTheme.error, size: 20),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Unit is controlled by Settings → Weight Unit.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\\.$'), '');
  }
}

class _PlateDialogResult {
  final double weight;
  final Color color;

  const _PlateDialogResult({
    required this.weight,
    required this.color,
  });
}

Future<_PlateDialogResult?> _showPlateDialog(
  BuildContext context, {
  required String unit,
  CustomPlate? existing,
}) async {
  final surfaceColor = const Color(0xFF26272B);
  final primaryColor = const Color(0xFF3F8EFC);

  final weightController = TextEditingController(
    text: existing != null ? existing.weight.toString() : '',
  );
  Color selectedColor =
      existing != null ? Color(existing.color) : const Color(0xFFE53935);

  final presetColors = <Color>[
    const Color(0xFFE53935),
    const Color(0xFF2196F3),
    const Color(0xFF4CAF50),
    const Color(0xFFFFEB3B),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF607D8B),
    Colors.white,
  ];

  return showDialog<_PlateDialogResult>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            title: Text(
              existing == null ? 'Add Plate' : 'Edit Plate',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Weight ($unit)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color',
                    style: TextStyle(color: Colors.grey[300]),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presetColors.map((c) {
                    final selected = c.value == selectedColor.value;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedColor = c),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? primaryColor : Colors.black26,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[400])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () {
                  final weight = double.tryParse(weightController.text.trim());
                  if (weight == null || weight <= 0) {
                    setDialogState(() => error = 'Enter a valid weight.');
                    return;
                  }
                  Navigator.pop(
                    context,
                    _PlateDialogResult(weight: weight, color: selectedColor),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatWeightLabel(double weight) {
  if (weight == weight.truncateToDouble()) return weight.toInt().toString();
  return weight
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\\.$'), '');
}

class _BarDialogResult {
  final String name;
  final double weight;
  final String shape;

  const _BarDialogResult({
    required this.name,
    required this.weight,
    required this.shape,
  });
}

int _barIconCodePointFor({required String name, required String shape}) {
  final normalizedName = name.trim().toLowerCase();
  if (normalizedName == 'no bar') return Icons.not_interested.codePoint;
  if (normalizedName == 'dumbbell') return Icons.fitness_center.codePoint;

  switch (shape) {
    case 'dumbbell':
      return Icons.fitness_center.codePoint;
    case 'ez':
      return Icons.fitness_center.codePoint;
    case 'olympic':
    default:
      return Icons.fitness_center.codePoint;
  }
}

Future<_BarDialogResult?> _showBarDialog(
  BuildContext context, {
  required String unit,
  CustomBar? existing,
}) async {
  final surfaceColor = const Color(0xFF26272B);
  final primaryColor = const Color(0xFF3F8EFC);

  final nameController = TextEditingController(text: existing?.name ?? '');
  final weightController = TextEditingController(
    text: existing != null ? existing.weight.toString() : '',
  );

  String _normalizeBarShape(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'olympic';
    if (v == 'standard' || v == 'barbell' || v == 'straight') return 'olympic';
    if (v == 'olympic') return 'olympic';
    if (v == 'ez curl' || v == 'ez-curl' || v == 'e-z' || v == 'e-z curl') {
      return 'ez';
    }
    if (v == 'trap' || v == 'trap bar' || v == 'hex') return 'olympic';
    if (v == 'smith' || v == 'smith machine') return 'olympic';
    if (v == 'dumb bell') return 'dumbbell';
    if (v == 'none') return 'olympic';

    const allowed = <String>{'olympic', 'ez', 'dumbbell'};
    if (allowed.contains(v)) return v;
    return 'olympic';
  }

  String shape = _normalizeBarShape(existing?.shape);
  final shapes = <String>['olympic', 'ez', 'dumbbell'];

  return showDialog<_BarDialogResult>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            title: Text(
              existing == null ? 'Add Bar' : 'Edit Bar',
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Weight ($unit)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: shape,
                    dropdownColor: surfaceColor,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Shape',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: shapes
                        .map((s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setDialogState(() => shape = v);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[400])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setDialogState(() => error = 'Enter a name.');
                    return;
                  }
                  final weight = double.tryParse(weightController.text.trim());
                  if (weight == null || weight < 0) {
                    setDialogState(() => error = 'Enter a valid weight.');
                    return;
                  }
                  Navigator.pop(
                    context,
                    _BarDialogResult(name: name, weight: weight, shape: shape),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

class AboutAppPage extends StatelessWidget {
  const AboutAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About App',
          style: AppTheme.headlineMedium,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // App Icon & Name
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accent.withOpacity(0.2),
                      AppTheme.accent.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.accent.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.fitness_center,
                  size: 60,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Mental Warrior',
                style: AppTheme.displaySmall.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Version 1.0.0',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Build 1',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 40),

              // About Section
              Card(
                color: AppTheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadiusMd,
                  side: BorderSide(
                    color: AppTheme.surfaceBorder.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mental Warrior is your personal fitness companion designed to help you track workouts, monitor habits, and achieve your fitness goals. With intelligent reminders and detailed analytics, stay motivated on your journey.',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Features Section
              Card(
                color: AppTheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadiusMd,
                  side: BorderSide(
                    color: AppTheme.surfaceBorder.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Features',
                        style: AppTheme.labelLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        icon: Icons.fitness_center,
                        title: 'Workout Tracking',
                        description: 'Log exercises, sets, & reps with ease',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.notifications_active,
                        title: 'Smart Reminders',
                        description: 'Get reminded about upcoming tasks',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.equalizer,
                        title: 'Analytics',
                        description: 'Track progress with detailed statistics',
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(
                        icon: Icons.settings,
                        title: 'Customization',
                        description: 'Personalize plates, bars, & settings',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info Section
              Card(
                color: AppTheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppTheme.borderRadiusMd,
                  side: BorderSide(
                    color: AppTheme.surfaceBorder.withOpacity(0.6),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('App Version', '1.0.0'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Build', '1'),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          'Platform', Platform.isAndroid ? 'Android' : 'iOS'),
                      const SizedBox(height: 12),
                      _buildInfoRow('Release Date', 'February 2026'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// NotificationSettingsPage and related widgets removed
