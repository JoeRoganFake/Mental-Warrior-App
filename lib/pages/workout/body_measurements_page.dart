import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mental_warior/services/database_services.dart';

class BodyMeasurementsPage extends StatefulWidget {
  final bool embedded;
  
  const BodyMeasurementsPage({super.key, this.embedded = false});

  @override
  State<BodyMeasurementsPage> createState() => _BodyMeasurementsPageState();
}

class _BodyMeasurementsPageState extends State<BodyMeasurementsPage> {
  final MeasurementService _measurementService = MeasurementService();
  final SettingsService _settingsService = SettingsService();
  Map<String, BodyMeasurement> _latestMeasurements = {};
  Map<String, MeasurementProgress> _progress = {};
  bool _isLoading = true;
  bool _useMeasurementInInches = false;
  bool _showWeightInLbs = false;

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _dangerColor = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
    _loadSettings();
    MeasurementService.measurementsUpdatedNotifier.addListener(_onMeasurementsUpdated);
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsUpdated);
  }

  @override
  void dispose() {
    MeasurementService.measurementsUpdatedNotifier.removeListener(_onMeasurementsUpdated);
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onMeasurementsUpdated() {
    _loadMeasurements();
  }

  void _onSettingsUpdated() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final useInches = await _settingsService.getUseMeasurementInInches();
    final useLbs = await _settingsService.getShowWeightInLbs();
    setState(() {
      _useMeasurementInInches = useInches;
      _showWeightInLbs = useLbs;
    });
  }

  Future<void> _loadMeasurements() async {
    setState(() => _isLoading = true);
    try {
      final latest = await _measurementService.getLatestMeasurements();
      final progress = await _measurementService.getProgress();
      setState(() {
        _latestMeasurements = latest;
        _progress = progress;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading measurements: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMeasurements,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header with add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Body Measurements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddMeasurementDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress summary card
          if (_progress.isNotEmpty) ...[
            _buildProgressSummary(),
            const SizedBox(height: 16),
          ],
          
          // Measurements grid
          _buildMeasurementsGrid(),
        ],
      ),
    );
  }

  Widget _buildProgressSummary() {
    // Count improvements vs declines
    int improvements = 0;
    int declines = 0;
    
    for (final entry in _progress.entries) {
      // For waist, body fat - decrease is good
      // For muscles - increase is good
      final isDecreaseGood = entry.key == 'waist' || entry.key == 'body_fat';
      if (entry.value.difference != 0) {
        if (isDecreaseGood) {
          if (entry.value.difference < 0) improvements++;
          else declines++;
        } else {
          if (entry.value.difference > 0) improvements++;
          else declines++;
        }
      }
    }

    return Card(
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Overview',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Improving',
                    improvements.toString(),
                    _successColor,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Declining',
                    declines.toString(),
                    _dangerColor,
                    Icons.trending_down,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Tracked',
                    _latestMeasurements.length.toString(),
                    _primaryColor,
                    Icons.straighten,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Measurements',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...MeasurementService.muscleTypes.map((muscleType) {
          final measurement = _latestMeasurements[muscleType.id];
          final progress = _progress[muscleType.id];
          return _buildMeasurementTile(muscleType, measurement, progress);
        }),
      ],
    );
  }

  Widget _buildMeasurementTile(
    MuscleType muscleType,
    BodyMeasurement? measurement,
    MeasurementProgress? progress,
  ) {
    // Determine if this is a "lower is better" measurement
    final isLowerBetter = muscleType.id == 'waist' || muscleType.id == 'body_fat';
    
    // Determine progress color
    Color? progressColor;
    IconData? progressIcon;
    if (progress != null && progress.difference != 0) {
      final isImproving = isLowerBetter 
          ? progress.difference < 0 
          : progress.difference > 0;
      progressColor = isImproving ? _successColor : _dangerColor;
      progressIcon = progress.difference > 0 ? Icons.arrow_upward : Icons.arrow_downward;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMeasurementHistory(muscleType),
        onLongPress: measurement != null ? () => _showMeasurementOptions(muscleType, measurement) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.straighten,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      muscleType.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (measurement != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(measurement.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      )
                    else
                      Text(
                        'Not measured yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              // Value and progress
              if (measurement != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${measurement.value.toStringAsFixed(1)} ${measurement.unit}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (progress != null && progress.difference != 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(progressIcon, size: 14, color: progressColor),
                          const SizedBox(width: 2),
                          Text(
                            '${progress.difference.abs().toStringAsFixed(1)} ${progress.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: progressColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ] else ...[
                IconButton(
                  onPressed: () => _showAddMeasurementForMuscle(muscleType),
                  icon: Icon(Icons.add_circle_outline, color: _primaryColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMeasurementDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Select Measurement Type',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: MeasurementService.muscleTypes.length,
                    itemBuilder: (context, index) {
                      final muscleType = MeasurementService.muscleTypes[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.straighten, color: _primaryColor),
                        ),
                        title: Text(
                          muscleType.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddMeasurementForMuscle(muscleType);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMeasurementForMuscle(MuscleType muscleType) {
    final valueController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedUnit = muscleType.id == 'weight' 
        ? (_showWeightInLbs ? 'lbs' : 'kg')
        : muscleType.id == 'body_fat' 
            ? '%' 
            : (_useMeasurementInInches ? 'in' : 'cm');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _surfaceColor,
              title: Text(
                'Add ${muscleType.name}',
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Value input
                    TextField(
                      controller: valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Value',
                        labelStyle: const TextStyle(color: Colors.grey),
                        suffixText: selectedUnit,
                        suffixStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF303136),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Unit selector (for applicable measurements)
                    if (muscleType.id != 'body_fat') ...[
                      const Text('Unit', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (muscleType.id == 'weight') ...[
                            _buildUnitChip('kg', selectedUnit, (unit) {
                              setDialogState(() => selectedUnit = unit);
                            }),
                            const SizedBox(width: 8),
                            _buildUnitChip('lbs', selectedUnit, (unit) {
                              setDialogState(() => selectedUnit = unit);
                            }),
                          ] else ...[
                            _buildUnitChip('cm', selectedUnit, (unit) {
                              setDialogState(() => selectedUnit = unit);
                            }),
                            const SizedBox(width: 8),
                            _buildUnitChip('in', selectedUnit, (unit) {
                              setDialogState(() => selectedUnit = unit);
                            }),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Date picker
                    const Text('Date', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF303136),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d, yyyy').format(selectedDate),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Notes
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF303136),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
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
                  onPressed: () async {
                    final valueText = valueController.text.trim();
                    if (valueText.isEmpty) return;
                    
                    final value = double.tryParse(valueText);
                    if (value == null) return;

                    await _measurementService.addMeasurement(
                      muscleType: muscleType.id,
                      value: value,
                      unit: selectedUnit,
                      date: selectedDate,
                      notes: notesController.text.trim().isEmpty 
                          ? null 
                          : notesController.text.trim(),
                    );

                    Navigator.pop(context);
                    _loadMeasurements();
                    
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('${muscleType.name} measurement added')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUnitChip(String unit, String selectedUnit, Function(String) onTap) {
    final isSelected = unit == selectedUnit;
    return GestureDetector(
      onTap: () => onTap(unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : const Color(0xFF303136),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          unit,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showMeasurementHistory(MuscleType muscleType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MeasurementHistoryPage(muscleType: muscleType),
      ),
    );
  }

  void _showMeasurementOptions(MuscleType muscleType, BodyMeasurement measurement) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history, color: Colors.white70),
                title: const Text('View History', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showMeasurementHistory(muscleType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.white70),
                title: const Text('Add New Measurement', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddMeasurementForMuscle(muscleType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Latest', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: _surfaceColor,
                      title: const Text('Delete Measurement?', style: TextStyle(color: Colors.white)),
                      content: Text(
                        'Delete ${muscleType.name} measurement from ${DateFormat('MMM d, yyyy').format(measurement.date)}?',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _measurementService.deleteMeasurement(measurement.id);
                    _loadMeasurements();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Measurement History Page
class MeasurementHistoryPage extends StatefulWidget {
  final MuscleType muscleType;
  
  const MeasurementHistoryPage({super.key, required this.muscleType});

  @override
  State<MeasurementHistoryPage> createState() => _MeasurementHistoryPageState();
}

class _MeasurementHistoryPageState extends State<MeasurementHistoryPage> {
  final MeasurementService _measurementService = MeasurementService();
  final SettingsService _settingsService = SettingsService();
  List<BodyMeasurement> _measurements = [];
  bool _isLoading = true;
  bool _useMeasurementInInches = false;
  bool _showWeightInLbs = false;

  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _dangerColor = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSettings();
    MeasurementService.measurementsUpdatedNotifier.addListener(_loadHistory);
    SettingsService.settingsUpdatedNotifier.addListener(_onSettingsUpdated);
  }

  @override
  void dispose() {
    MeasurementService.measurementsUpdatedNotifier.removeListener(_loadHistory);
    SettingsService.settingsUpdatedNotifier.removeListener(_onSettingsUpdated);
    super.dispose();
  }

  void _onSettingsUpdated() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final useInches = await _settingsService.getUseMeasurementInInches();
    final useLbs = await _settingsService.getShowWeightInLbs();
    setState(() {
      _useMeasurementInInches = useInches;
      _showWeightInLbs = useLbs;
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final measurements = await _measurementService.getMeasurementsForMuscle(widget.muscleType.id);
      setState(() {
        _measurements = measurements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1B1E),
      appBar: AppBar(
        title: Text('${widget.muscleType.name} History'),
        backgroundColor: const Color(0xFF1A1B1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMeasurement(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _measurements.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.straighten, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No measurements yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first ${widget.muscleType.name.toLowerCase()} measurement',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddMeasurement,
            icon: const Icon(Icons.add),
            label: const Text('Add Measurement'),
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    // Calculate progress from previous measurement
    final isLowerBetter = widget.muscleType.id == 'waist' || widget.muscleType.id == 'body_fat';
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _measurements.length + 1, // +1 for chart header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildChartSection();
        }
        
        final measurement = _measurements[index - 1];
        final previousMeasurement = index < _measurements.length ? _measurements[index] : null;
        final isFirstMeasurement = index == _measurements.length; // Last in list = oldest/first
        
        double? difference;
        if (previousMeasurement != null) {
          difference = measurement.value - previousMeasurement.value;
        }

        Color? changeColor;
        IconData? changeIcon;
        if (difference != null && difference != 0) {
          final isImproving = isLowerBetter ? difference < 0 : difference > 0;
          changeColor = isImproving ? _successColor : _dangerColor;
          changeIcon = difference > 0 ? Icons.arrow_upward : Icons.arrow_downward;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: _surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              '${measurement.value.toStringAsFixed(1)} ${measurement.unit}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(measurement.date),
                  style: TextStyle(color: Colors.grey[400]),
                ),
                if (measurement.notes != null && measurement.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      measurement.notes!,
                      style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
            trailing: isFirstMeasurement
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FIRST',
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : (difference != null && difference != 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(changeIcon, size: 16, color: changeColor),
                          Text(
                            '${difference.abs().toStringAsFixed(1)}',
                            style: TextStyle(color: changeColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : null),
            onLongPress: () => _showDeleteDialog(measurement),
          ),
        );
      },
    );
  }

  Widget _buildChartSection() {
    if (_measurements.length < 2) {
      return const SizedBox.shrink();
    }

    // Sort measurements by date for chart
    final sortedMeasurements = List<BodyMeasurement>.from(_measurements)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final first = sortedMeasurements.first;
    final latest = sortedMeasurements.last;
    final change = latest.value - first.value;
    final percentChange = (change / first.value) * 100;
    
    final isLowerBetter = widget.muscleType.id == 'waist' || widget.muscleType.id == 'body_fat';
    final isImproving = isLowerBetter ? change < 0 : change > 0;
    final progressColor = change == 0 ? Colors.grey : (isImproving ? _successColor : _dangerColor);

    // Prepare chart data
    final spots = <FlSpot>[];
    final minDate = sortedMeasurements.first.date.millisecondsSinceEpoch.toDouble();
    
    for (int i = 0; i < sortedMeasurements.length; i++) {
      final m = sortedMeasurements[i];
      final x = (m.date.millisecondsSinceEpoch.toDouble() - minDate) / (1000 * 60 * 60 * 24); // Days from first
      spots.add(FlSpot(x, m.value));
    }

    // Calculate min/max for Y axis
    final values = sortedMeasurements.map((m) => m.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final padding = range > 0 ? range * 0.1 : minValue * 0.1; // Handle same values
    final yMin = (minValue - padding).clamp(0.0, double.infinity);
    final yMax = maxValue + padding;
    final yInterval = (yMax - yMin) > 0 ? (yMax - yMin) / 4 : 1.0; // Ensure non-zero interval

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: _surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Line Chart
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: spots.length > 7 ? (spots.last.x / 5) : null,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            (minDate + value * 1000 * 60 * 60 * 24).toInt()
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: spots.last.x,
                  minY: yMin,
                  maxY: yMax,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: _primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _primaryColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            (minDate + spot.x * 1000 * 60 * 60 * 24).toInt()
                          );
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)} ${latest.unit}\n${date.day}/${date.month}/${date.year}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Progress stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressItem('First', '${first.value.toStringAsFixed(1)} ${first.unit}', Colors.grey),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.grey,
                ),
                _buildProgressItem('Latest', '${latest.value.toStringAsFixed(1)} ${latest.unit}', _primaryColor),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: progressColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    change > 0 ? Icons.trending_up : (change < 0 ? Icons.trending_down : Icons.trending_flat),
                    color: progressColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} ${latest.unit} (${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  void _showAddMeasurement() {
    final valueController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedUnit = widget.muscleType.id == 'weight' 
        ? (_showWeightInLbs ? 'lbs' : 'kg')
        : widget.muscleType.id == 'body_fat' 
            ? '%' 
            : (_useMeasurementInInches ? 'in' : 'cm');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Header with icon
                      Row(
                        children: [
                          Container(
                            
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              IconData(widget.muscleType.icon, fontFamily: 'MaterialIcons'),
                              color: _primaryColor,
                              size: 24,
                        
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Measurement',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  widget.muscleType.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Value input with large display
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Enter Value',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: valueController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    autofocus: true,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0.0',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    selectedUnit,
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Date selector
                      Text(
                        'Date',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: _primaryColor,
                                    surface: _surfaceColor,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            setDialogState(() => selectedDate = date);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.calendar_today, color: _primaryColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE').format(selectedDate),
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMMM d, yyyy').format(selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey[600]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Notes input
                      Text(
                        'Notes (optional)',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Add any notes here...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          filled: true,
                          fillColor: _backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[700]!),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                final valueText = valueController.text.trim();
                                if (valueText.isEmpty) return;
                                
                                final value = double.tryParse(valueText);
                                if (value == null) return;

                                await _measurementService.addMeasurement(
                                  muscleType: widget.muscleType.id,
                                  value: value,
                                  unit: selectedUnit,
                                  date: selectedDate,
                                  notes: notesController.text.trim().isEmpty 
                                      ? null 
                                      : notesController.text.trim(),
                                );

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Save Measurement',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BodyMeasurement measurement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: const Text('Delete Measurement?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete measurement from ${DateFormat('MMM d, yyyy').format(measurement.date)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _measurementService.deleteMeasurement(measurement.id);
    }
  }
}
