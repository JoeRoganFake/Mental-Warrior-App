import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/plate_bar_customization_service.dart';
import 'package:mental_warior/utils/app_theme.dart';

class WorkoutSettingsPage extends StatefulWidget {
  const WorkoutSettingsPage({super.key});

  @override
  State<WorkoutSettingsPage> createState() => _WorkoutSettingsPageState();
}

class _WorkoutSettingsPageState extends State<WorkoutSettingsPage> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  // Current settings values (what's being edited)
  int _weeklyWorkoutGoal = 5;
  int _defaultRestTimer = 90;
  bool _autoStartRestTimer = true;
  bool _vibrateOnRestComplete = true;
  bool _keepScreenOn = true;
  bool _confirmFinishWorkout = true;
  bool _showWeightInLbs = false;
  bool _useMeasurementInInches = false;
  String _prDisplayMode = 'random'; // 'random' or 'pinned'
  List<String> _pinnedExercises = [];

  // Original settings values (to compare for changes)
  int _originalWeeklyWorkoutGoal = 5;
  int _originalDefaultRestTimer = 90;
  bool _originalAutoStartRestTimer = true;
  bool _originalVibrateOnRestComplete = true;
  bool _originalKeepScreenOn = true;
  bool _originalConfirmFinishWorkout = true;
  bool _originalShowWeightInLbs = false;
  bool _originalUseMeasurementInInches = false;
  String _originalPrDisplayMode = 'random';
  List<String> _originalPinnedExercises = [];

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
        // Set current values
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

        // Store original values
        _originalWeeklyWorkoutGoal = _weeklyWorkoutGoal;
        _originalDefaultRestTimer = _defaultRestTimer;
        _originalAutoStartRestTimer = _autoStartRestTimer;
        _originalVibrateOnRestComplete = _vibrateOnRestComplete;
        _originalKeepScreenOn = _keepScreenOn;
        _originalConfirmFinishWorkout = _confirmFinishWorkout;
        _originalShowWeightInLbs = _showWeightInLbs;
        _originalUseMeasurementInInches = _useMeasurementInInches;
        _originalPrDisplayMode = _prDisplayMode;
        _originalPinnedExercises = List<String>.from(_pinnedExercises);

        _hasUnsavedChanges = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  void _checkForChanges() {
    setState(() {
      _hasUnsavedChanges = _weeklyWorkoutGoal != _originalWeeklyWorkoutGoal ||
          _defaultRestTimer != _originalDefaultRestTimer ||
          _autoStartRestTimer != _originalAutoStartRestTimer ||
          _vibrateOnRestComplete != _originalVibrateOnRestComplete ||
          _keepScreenOn != _originalKeepScreenOn ||
          _confirmFinishWorkout != _originalConfirmFinishWorkout ||
          _showWeightInLbs != _originalShowWeightInLbs ||
          _useMeasurementInInches != _originalUseMeasurementInInches ||
          _prDisplayMode != _originalPrDisplayMode ||
          _pinnedExercises.toString() != _originalPinnedExercises.toString();
    });
  }

  Future<void> _saveAllSettings() async {
    setState(() => _isLoading = true);
    try {
      await _settingsService.setWeeklyWorkoutGoal(_weeklyWorkoutGoal);
      await _settingsService.setDefaultRestTimer(_defaultRestTimer);
      await _settingsService.setAutoStartRestTimer(_autoStartRestTimer);
      await _settingsService.setVibrateOnRestComplete(_vibrateOnRestComplete);
      await _settingsService.setKeepScreenOn(_keepScreenOn);
      await _settingsService.setConfirmFinishWorkout(_confirmFinishWorkout);
      await _settingsService.setShowWeightInLbs(_showWeightInLbs);
      await _settingsService.setUseMeasurementInInches(_useMeasurementInInches);
      await _settingsService.setPrDisplayMode(_prDisplayMode);
      await _settingsService.setPinnedExercises(_pinnedExercises);

      // Update original values to match saved values
      _originalWeeklyWorkoutGoal = _weeklyWorkoutGoal;
      _originalDefaultRestTimer = _defaultRestTimer;
      _originalAutoStartRestTimer = _autoStartRestTimer;
      _originalVibrateOnRestComplete = _vibrateOnRestComplete;
      _originalKeepScreenOn = _keepScreenOn;
      _originalConfirmFinishWorkout = _confirmFinishWorkout;
      _originalShowWeightInLbs = _showWeightInLbs;
      _originalUseMeasurementInInches = _useMeasurementInInches;
      _originalPrDisplayMode = _prDisplayMode;
      _originalPinnedExercises = List<String>.from(_pinnedExercises);

      setState(() {
        _hasUnsavedChanges = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved'),
            backgroundColor: AppTheme.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Unsaved Changes', style: AppTheme.headlineSmall),
        content: Text(
          'You have unsaved changes. What would you like to do?',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text('Discard', style: TextStyle(color: AppTheme.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child:
                Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveAllSettings();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false; // Cancel - don't pop
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('Workout Settings', style: AppTheme.headlineSmall),
          backgroundColor: AppTheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () async {
              if (_hasUnsavedChanges) {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            if (_hasUnsavedChanges)
              TextButton.icon(
                onPressed: _saveAllSettings,
                icon: Icon(Icons.save, color: AppTheme.accent),
                label:
                    Text('Save', style: TextStyle(color: AppTheme.accent)),
              ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Goals Section
                  _buildSectionHeader('Goals', Icons.flag_outlined),
                  _buildSettingsCard([
                    _buildWeeklyGoalTile(),
                  ]),
                  const SizedBox(height: 24),

                  // Rest Timer Section
                  _buildSectionHeader('Rest Timer', Icons.timer_outlined),
                  _buildSettingsCard([
                    _buildRestTimerTile(),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Auto-start Timer',
                      'Start rest timer automatically after completing a set',
                      _autoStartRestTimer,
                      (value) {
                        setState(() => _autoStartRestTimer = value);
                        _checkForChanges();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Vibrate',
                      'Vibrate when rest timer completes',
                      _vibrateOnRestComplete,
                      (value) {
                        setState(() => _vibrateOnRestComplete = value);
                        _checkForChanges();
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Units Section
                  _buildSectionHeader('Units', Icons.straighten_outlined),
                  _buildSettingsCard([
                    _buildWeightUnitTile(),
                    _buildDivider(),
                    _buildMeasurementUnitTile(),
                  ]),
                  const SizedBox(height: 24),

                  // Workout Session Section
                  _buildSectionHeader(
                      'Workout Session', Icons.play_circle_outline),
                  _buildSettingsCard([
                    _buildSwitchTile(
                      'Keep Screen On',
                      'Prevent screen from sleeping during workout',
                      _keepScreenOn,
                      (value) {
                        setState(() => _keepScreenOn = value);
                        _checkForChanges();
                      },
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      'Confirm Finish Workout',
                      'Show confirmation before finishing workout',
                      _confirmFinishWorkout,
                      (value) {
                        setState(() => _confirmFinishWorkout = value);
                        _checkForChanges();
                      },
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Personal Records Section
                  _buildSectionHeader(
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
                  const SizedBox(height: 24),

                  // Plate Calculator Section
                  _buildSectionHeader('Plate Calculator', Icons.fitness_center),
                  _buildSettingsCard([
                    _buildActionTile(
                      'Custom Plates & Bars',
                      'Customize plate weights, colors, and bar types',
                      Icons.tune,
                      () => _navigateToPlateBarCustomization(),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Data Section
                  _buildSectionHeader('Data', Icons.storage_outlined),
                  _buildSettingsCard([
                    _buildActionTile(
                      'Export Workout Data',
                      'Save your workouts to a file',
                      Icons.upload_outlined,
                      () => _showComingSoonSnackbar(),
                    ),
                    _buildDivider(),
                    _buildActionTile(
                      'Import Workout Data',
                      'Restore workouts from a file',
                      Icons.download_outlined,
                      () => _showComingSoonSnackbar(),
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
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTheme.labelLarge.copyWith(color: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadiusMd),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: AppTheme.surfaceBorder,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: AppTheme.bodyMedium),
      subtitle: Text(subtitle,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.accent,
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: isDestructive ? AppTheme.error : AppTheme.textSecondary),
      title: Text(
        title,
        style: AppTheme.bodyMedium.copyWith(
            color: isDestructive ? AppTheme.error : AppTheme.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }

  Widget _buildWeeklyGoalTile() {
    return ListTile(
      title: Text('Weekly Workout Goal', style: AppTheme.bodyMedium),
      subtitle: Text(
        '$_weeklyWorkoutGoal workouts per week',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_weeklyWorkoutGoal',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppTheme.textTertiary),
        ],
      ),
      onTap: _showWeeklyGoalDialog,
    );
  }

  Widget _buildRestTimerTile() {
    final minutes = _defaultRestTimer ~/ 60;
    final seconds = _defaultRestTimer % 60;
    final displayTime = minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds sec';

    return ListTile(
      title: Text('Default Rest Time', style: AppTheme.bodyMedium),
      subtitle: Text(
        'Time between sets',
        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayTime,
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
      onTap: _showRestTimerDialog,
    );
  }

  Widget _buildWeightUnitTile() {
    final currentUnit = _showWeightInLbs ? 'Pounds (lbs)' : 'Kilograms (kg)';
    return ListTile(
      title: const Text('Weight Unit', style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Unit for displaying weight',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentUnit,
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
      onTap: _showWeightUnitDialog,
    );
  }

  Widget _buildMeasurementUnitTile() {
    final currentUnit =
        _useMeasurementInInches ? 'Inches (in)' : 'Centimeters (cm)';
    return ListTile(
      title: const Text('Body Measurement Unit',
          style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Unit for body measurements',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentUnit,
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
      onTap: _showMeasurementUnitDialog,
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

    return ListTile(
      title:
          const Text('PR Display Mode', style: TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayText,
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
      onTap: _showPRDisplayModeDialog,
    );
  }

  void _showWeightUnitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title:
              const Text('Weight Unit', style: TextStyle(color: Colors.white)),
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
                    // Changing from lbs to kg
                    _showConversionPrompt(
                      fromUnit: 'lbs',
                      toUnit: 'kg',
                      isWeight: true,
                      onConvert: () {
                        setState(() => _showWeightInLbs = false);
                        _checkForChanges();
                      },
                      onDisplayOnly: () {
                        setState(() => _showWeightInLbs = false);
                        _checkForChanges();
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
                    // Changing from kg to lbs
                    _showConversionPrompt(
                      fromUnit: 'kg',
                      toUnit: 'lbs',
                      isWeight: true,
                      onConvert: () {
                        setState(() => _showWeightInLbs = true);
                        _checkForChanges();
                      },
                      onDisplayOnly: () {
                        setState(() => _showWeightInLbs = true);
                        _checkForChanges();
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
          title: const Text('Body Measurement Unit',
              style: TextStyle(color: Colors.white)),
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
                    // Changing from in to cm
                    _showConversionPrompt(
                      fromUnit: 'in',
                      toUnit: 'cm',
                      isWeight: false,
                      onConvert: () {
                        setState(() => _useMeasurementInInches = false);
                        _checkForChanges();
                      },
                      onDisplayOnly: () {
                        setState(() => _useMeasurementInInches = false);
                        _checkForChanges();
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
                    // Changing from cm to in
                    _showConversionPrompt(
                      fromUnit: 'cm',
                      toUnit: 'in',
                      isWeight: false,
                      onConvert: () {
                        setState(() => _useMeasurementInInches = true);
                        _checkForChanges();
                      },
                      onDisplayOnly: () {
                        setState(() => _useMeasurementInInches = true);
                        _checkForChanges();
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
          title: const Text(
            'Convert Existing Data?',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You\'re changing from $fromUnit to $toUnit.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                'Would you like to:',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              // Option 1: Convert values
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
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Just change display
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onDisplayOnly();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.text_fields, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change display only',
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Keep existing values, just change the unit label',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
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
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
          ],
        );
      },
    );
  }

  Future<void> _convertExistingData(
      String fromUnit, String toUnit, bool isWeight) async {
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
            const Text('Converting data...',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      final measurementService = MeasurementService();

      if (isWeight) {
        // Convert weight measurements and workout data
        if (fromUnit == 'kg' && toUnit == 'lbs') {
          await measurementService.convertMeasurements('kg', 'lbs', 2.20462);
          // Also convert workout weights
          await _convertWorkoutWeights(2.20462, 'lbs');
        } else if (fromUnit == 'lbs' && toUnit == 'kg') {
          await measurementService.convertMeasurements('lbs', 'kg', 0.453592);
          // Also convert workout weights
          await _convertWorkoutWeights(0.453592, 'kg');
        }
      } else {
        // Convert body measurements only
        if (fromUnit == 'cm' && toUnit == 'in') {
          await measurementService.convertMeasurements('cm', 'in', 0.393701);
        } else if (fromUnit == 'in' && toUnit == 'cm') {
          await measurementService.convertMeasurements('in', 'cm', 2.54);
        }
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All data converted to $toUnit'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error converting data: $e'),
            backgroundColor: Colors.red,
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
              isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.grey[800],
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
                      color: isSelected ? AppTheme.accent : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
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

  void _showWeeklyGoalDialog() {
    int tempGoal = _weeklyWorkoutGoal;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Weekly Workout Goal',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'How many workouts per week?',
                    style: TextStyle(color: Colors.grey[400]),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _weeklyWorkoutGoal = tempGoal);
                    _checkForChanges();
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
              title: const Text('Default Rest Time',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current value display
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
                  // Slider
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
                  // Quick presets
                  const Text('Quick Select',
                      style: TextStyle(color: Colors.grey)),
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
                                isSelected ? AppTheme.accent : Colors.grey[800],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatRestTime(seconds),
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.grey[400],
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _defaultRestTimer = tempSeconds);
                    _checkForChanges();
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

  void _showPRDisplayModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('PR Display Mode',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitOption(
                'Random Daily',
                '5 random PRs that change every day',
                _prDisplayMode == 'random',
                () {
                  setState(() {
                    _prDisplayMode = 'random';
                    _pinnedExercises
                        .clear(); // Clear pinned exercises when switching to random
                  });
                  _checkForChanges();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _buildUnitOption(
                'Pinned Exercises',
                'Show specific exercises you choose',
                _prDisplayMode == 'pinned',
                () {
                  setState(() => _prDisplayMode = 'pinned');
                  _checkForChanges();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _buildUnitOption(
                'None',
                'Don\'t show PRs on workout page',
                _prDisplayMode == 'none',
                () {
                  setState(() {
                    _prDisplayMode = 'none';
                    _pinnedExercises.clear();
                  });
                  _checkForChanges();
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
    // Get all unique exercise names from workout history
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
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Pin Exercises',
                  style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select up to 5 exercises to display',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sortedExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = sortedExercises[index];
                          final isPinned = tempPinned.contains(exercise);

                          return CheckboxListTile(
                            title: Text(exercise,
                                style: const TextStyle(color: Colors.white)),
                            value: isPinned,
                            activeColor: AppTheme.accent,
                            onChanged: tempPinned.length >= 5 && !isPinned
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        if (tempPinned.length < 5) {
                                          tempPinned.add(exercise);
                                        }
                                      } else {
                                        tempPinned.remove(exercise);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _pinnedExercises = tempPinned);
                    _checkForChanges();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showComingSoonSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Clear All Workout History?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'This will permanently delete all your workout records. This action cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // TODO: Implement clear history
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Workout history cleared')),
                );
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
}

// Plate & Bar Customization Page - PLACEHOLDER (Full implementation coming)
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
      appBar: AppBar(
        title: Text('Customize Plates & Bars ($unitLabel)',
            style: AppTheme.headlineSmall),
        backgroundColor: AppTheme.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrimary,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Plates'),
            Tab(text: 'Bars'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            onPressed: _isLoading ? null : _resetCurrentTabToDefaults,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.accent,
              onPressed: () {
                if (_tabController.index == 0) {
                  _addPlate();
                } else {
                  _addBar();
                }
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlatesTab(),
                _buildBarsTab(),
              ],
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
      padding: const EdgeInsets.all(16),
      itemCount: _plates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final plate = _plates[index];
        final color = Color(plate.color);
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: ListTile(
            leading: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              '${_formatNumber(plate.weight)} $_unit',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Tap to edit',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _editPlate(plate),
                  icon: Icon(Icons.edit, color: Colors.grey[300]),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _deletePlate(plate),
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ],
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
      padding: const EdgeInsets.all(16),
      itemCount: _bars.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bar = _bars[index];
        final isNoBar = bar.name.trim().toLowerCase() == 'no bar';
        final icon = IconData(
          _barIconCodePointFor(name: bar.name, shape: bar.shape),
          fontFamily: 'MaterialIcons',
        );
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: ListTile(
            leading: Icon(icon, color: Colors.white70),
            title: Text(
              bar.name,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${_formatNumber(bar.weight)} $_unit • ${bar.shape}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: isNoBar ? null : () => _editBar(bar),
                  icon: Icon(
                    Icons.edit,
                    color: isNoBar ? Colors.grey[700] : Colors.grey[300],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: isNoBar ? null : () => _deleteBar(bar),
                  icon: Icon(
                    Icons.delete_outline,
                    color: isNoBar ? Colors.grey[700] : Colors.redAccent,
                  ),
                ),
              ],
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
              'Unit is controlled by Workout Settings → Weight Unit.',
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
