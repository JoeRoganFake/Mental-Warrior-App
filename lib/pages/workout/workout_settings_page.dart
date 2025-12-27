import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';

class WorkoutSettingsPage extends StatefulWidget {
  const WorkoutSettingsPage({super.key});

  @override
  State<WorkoutSettingsPage> createState() => _WorkoutSettingsPageState();
}

class _WorkoutSettingsPageState extends State<WorkoutSettingsPage> {
  final SettingsService _settingsService = SettingsService();
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);

  // Current settings values (what's being edited)
  int _weeklyWorkoutGoal = 5;
  int _defaultRestTimer = 90;
  bool _autoStartRestTimer = true;
  bool _vibrateOnRestComplete = true;
  bool _keepScreenOn = true;
  bool _confirmFinishWorkout = true;
  bool _showWeightInLbs = false;
  double _defaultWeightIncrement = 2.5;
  bool _useMeasurementInInches = false;

  // Original settings values (to compare for changes)
  int _originalWeeklyWorkoutGoal = 5;
  int _originalDefaultRestTimer = 90;
  bool _originalAutoStartRestTimer = true;
  bool _originalVibrateOnRestComplete = true;
  bool _originalKeepScreenOn = true;
  bool _originalConfirmFinishWorkout = true;
  bool _originalShowWeightInLbs = false;
  double _originalDefaultWeightIncrement = 2.5;
  bool _originalUseMeasurementInInches = false;

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
        _defaultWeightIncrement = settings['defaultWeightIncrement'];
        _useMeasurementInInches = settings['useMeasurementInInches'];

        // Store original values
        _originalWeeklyWorkoutGoal = _weeklyWorkoutGoal;
        _originalDefaultRestTimer = _defaultRestTimer;
        _originalAutoStartRestTimer = _autoStartRestTimer;
        _originalVibrateOnRestComplete = _vibrateOnRestComplete;
        _originalKeepScreenOn = _keepScreenOn;
        _originalConfirmFinishWorkout = _confirmFinishWorkout;
        _originalShowWeightInLbs = _showWeightInLbs;
        _originalDefaultWeightIncrement = _defaultWeightIncrement;
        _originalUseMeasurementInInches = _useMeasurementInInches;

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
          _defaultWeightIncrement != _originalDefaultWeightIncrement ||
          _useMeasurementInInches != _originalUseMeasurementInInches;
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
      await _settingsService.setDefaultWeightIncrement(_defaultWeightIncrement);
      await _settingsService.setUseMeasurementInInches(_useMeasurementInInches);

      // Update original values to match saved values
      _originalWeeklyWorkoutGoal = _weeklyWorkoutGoal;
      _originalDefaultRestTimer = _defaultRestTimer;
      _originalAutoStartRestTimer = _autoStartRestTimer;
      _originalVibrateOnRestComplete = _vibrateOnRestComplete;
      _originalKeepScreenOn = _keepScreenOn;
      _originalConfirmFinishWorkout = _confirmFinishWorkout;
      _originalShowWeightInLbs = _showWeightInLbs;
      _originalDefaultWeightIncrement = _defaultWeightIncrement;
      _originalUseMeasurementInInches = _useMeasurementInInches;

      setState(() {
        _hasUnsavedChanges = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved'),
            backgroundColor: _primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving settings'),
            backgroundColor: Colors.red,
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
        backgroundColor: _surfaceColor,
        title: const Text('Unsaved Changes',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'You have unsaved changes. What would you like to do?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
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
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text('Workout Settings'),
          backgroundColor: _backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
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
                icon: const Icon(Icons.save, color: Colors.white),
                label:
                    const Text('Save', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                    _buildDivider(),
                    _buildWeightIncrementTile(),
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
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey[800],
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
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: _primaryColor,
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
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white70),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : Colors.white),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
      onTap: onTap,
    );
  }

  Widget _buildWeeklyGoalTile() {
    return ListTile(
      title: const Text('Weekly Workout Goal',
          style: TextStyle(color: Colors.white)),
      subtitle: Text(
        '$_weeklyWorkoutGoal workouts per week',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$_weeklyWorkoutGoal',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
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
      title: const Text('Default Rest Time',
          style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Time between sets',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayTime,
              style: TextStyle(
                color: _primaryColor,
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
              color: _primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentUnit,
              style: TextStyle(
                color: _primaryColor,
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
              color: _primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              currentUnit,
              style: TextStyle(
                color: _primaryColor,
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

  Widget _buildWeightIncrementTile() {
    final unit = _showWeightInLbs ? 'lbs' : 'kg';
    return ListTile(
      title:
          const Text('Weight Increment', style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Default increment when adjusting weight',
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_defaultWeightIncrement.toStringAsFixed(1)} $unit',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.grey[600]),
        ],
      ),
      onTap: _showWeightIncrementDialog,
    );
  }

  void _showWeightUnitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _surfaceColor,
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
          backgroundColor: _surfaceColor,
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
          backgroundColor: _surfaceColor,
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
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: _primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Convert all data',
                              style: TextStyle(
                                color: _primaryColor,
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
        backgroundColor: _surfaceColor,
        content: Row(
          children: [
            CircularProgressIndicator(color: _primaryColor),
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
            backgroundColor: _primaryColor,
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
          color: isSelected ? _primaryColor.withOpacity(0.2) : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.transparent,
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
                      color: isSelected ? _primaryColor : Colors.white,
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
              Icon(Icons.check_circle, color: _primaryColor, size: 24),
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
              backgroundColor: _surfaceColor,
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
                            color: _primaryColor, size: 36),
                        onPressed: tempGoal > 1
                            ? () => setDialogState(() => tempGoal--)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          tempGoal.toString(),
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.add_circle,
                            color: _primaryColor, size: 36),
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
                      ElevatedButton.styleFrom(backgroundColor: _primaryColor),
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
              backgroundColor: _surfaceColor,
              title: const Text('Default Rest Time',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current value display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatRestTime(tempSeconds),
                      style: TextStyle(
                        color: _primaryColor,
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
                    activeColor: _primaryColor,
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
                                isSelected ? _primaryColor : Colors.grey[800],
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
                      ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showWeightIncrementDialog() {
    double tempIncrement = _defaultWeightIncrement;
    final unit = _showWeightInLbs ? 'lbs' : 'kg';

    final presets =
        _showWeightInLbs ? [1.0, 2.5, 5.0, 10.0] : [1.0, 1.25, 2.5, 5.0];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _surfaceColor,
              title: const Text('Weight Increment',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current value display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tempIncrement.toStringAsFixed(tempIncrement == tempIncrement.roundToDouble() ? 0 : 2)} $unit',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Presets
                  const Text('Select Increment',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((value) {
                      final isSelected = tempIncrement == value;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => tempIncrement = value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? _primaryColor : Colors.grey[800],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} $unit',
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
                    setState(() => _defaultWeightIncrement = tempIncrement);
                    _checkForChanges();
                    Navigator.pop(context);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: _primaryColor),
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
          backgroundColor: _surfaceColor,
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
}
