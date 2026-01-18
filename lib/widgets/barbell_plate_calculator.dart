import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mental_warior/services/database_services.dart';
import 'package:mental_warior/services/plate_bar_customization_service.dart';

/// A visual barbell and plate selector widget for calculating weights
class BarbellPlateCalculator extends StatefulWidget {
  final double initialWeight;
  final bool useLbs;
  final Function(double) onWeightChanged;
  final VoidCallback? onClose;
  final String? exerciseName; // For saving/loading plate config per exercise
  final String? equipment; // Equipment type to determine default bar

  const BarbellPlateCalculator({
    super.key,
    required this.initialWeight,
    required this.useLbs,
    required this.onWeightChanged,
    this.onClose,
    this.exerciseName,
    this.equipment,
  });

  @override
  State<BarbellPlateCalculator> createState() => _BarbellPlateCalculatorState();
}

class _BarbellPlateCalculatorState extends State<BarbellPlateCalculator> {
  // Bar types with their weights
  late List<BarType> _barTypes;
  late BarType _selectedBar;

  // Plate counts (how many of each plate on each side)
  late Map<double, int> _plateCounts;

  // Available plate weights
  late List<PlateInfo> _availablePlates;

  // Track loading state
  bool _isLoading = true;

  late final VoidCallback _customizationListener;

  // Theme colors
  final Color _backgroundColor = const Color(0xFF1A1B1E);
  final Color _surfaceColor = const Color(0xFF26272B);
  final Color _primaryColor = const Color(0xFF3F8EFC);
  final Color _textPrimaryColor = Colors.white;
  final Color _textSecondaryColor = const Color(0xFFBBBBBB);

  String _normalizeBarShape(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'olympic';
    if (v == 'olympic') return 'olympic';
    if (v == 'ez') return 'ez';
    if (v == 'dumbbell') return 'dumbbell';
    if (v == 'standard' || v == 'barbell' || v == 'straight') return 'olympic';
    if (v.contains('ez')) return 'ez';
    if (v.contains('dumb')) return 'dumbbell';
    return 'olympic';
  }

  String _shapeForSelectedBar() {
    // Prefer the explicit shape stored on the selected bar.
    final explicit = _selectedBar.shape;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit;
    }

    // Fall back to name heuristics for older/default data.
    final name = _selectedBar.name.trim().toLowerCase();
    if (name == 'no bar') return 'olympic';
    if (name.contains('dumbbell') || name.contains('dumb bell'))
      return 'dumbbell';
    if (name.contains('ez') || name.contains('e-z')) return 'ez';
    return 'olympic';
  }

  IconData _iconForCustomBar({required String name, required String shape}) {
    final normalizedName = name.trim().toLowerCase();
    if (normalizedName == 'no bar') return Icons.not_interested;

    switch (_normalizeBarShape(shape)) {
      case 'dumbbell':
        return Icons.fitness_center;
      case 'ez':
        return Icons.fitness_center;
      case 'olympic':
      default:
        return Icons.fitness_center;
    }
  }

  @override
  void initState() {
    super.initState();
    _customizationListener = () {
      if (!mounted) return;
      _reloadCustomizationsAndRecalc();
    };
    PlateBarCustomizationService.customizationUpdatedNotifier
        .addListener(_customizationListener);

    _initializePlatesAndBars();
    // Load custom plates first, then calculate - this happens in _loadCustomPlatesAndBars now
  }

  @override
  void didUpdateWidget(covariant BarbellPlateCalculator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the user switched kg/lbs while the calculator is open, keep the
    // current total weight and simply recalculate the plate breakdown using
    // the new unit's catalogs.
    if (oldWidget.useLbs != widget.useLbs) {
      _handleUnitSwitch(oldUseLbs: oldWidget.useLbs, newUseLbs: widget.useLbs);
    }
  }

  Future<void> _handleUnitSwitch(
      {required bool oldUseLbs, required bool newUseLbs}) async {
    final currentTotalWeight = _calculateTotalWeight();
    final currentShape = _normalizeBarShape(_shapeForSelectedBar());

    await _loadCustomPlatesAndBars();
    if (!mounted) return;

    // Pick a sensible equivalent bar after reload.
    final preferredName = currentShape == 'dumbbell'
        ? 'Dumbbell'
        : currentShape == 'ez'
            ? 'EZ Curl Bar'
            : 'Olympic Bar';
    final nextSelected = _barTypes.firstWhere(
      (b) => b.name == preferredName,
      orElse: () => _getDefaultBarForEquipment(),
    );

    setState(() {
      _selectedBar = nextSelected;
      _plateCounts = {for (var plate in _availablePlates) plate.weight: 0};
    });

    // Recalculate plates for the same overall weight.
    _calculatePlatesFromWeight(currentTotalWeight);
    _updateWeight();
  }

  @override
  void dispose() {
    PlateBarCustomizationService.customizationUpdatedNotifier
        .removeListener(_customizationListener);
    super.dispose();
  }

  Future<void> _reloadCustomizationsAndRecalc() async {
    await _loadCustomPlatesAndBars();

    if (!mounted) return;
    // Keep the user's current target if possible.
    final currentTotalWeight = _calculateTotalWeight();
    setState(() {
      _plateCounts = {for (var plate in _availablePlates) plate.weight: 0};
      // Keep currently selected bar if it still exists; otherwise pick default.
      final stillExists = _barTypes.any((b) => b.name == _selectedBar.name);
      _selectedBar = stillExists
          ? _barTypes.firstWhere((b) => b.name == _selectedBar.name)
          : _getDefaultBarForEquipment();
    });

    _calculatePlatesFromWeight(currentTotalWeight);
    _updateWeight();
  }

  Future<void> _loadSavedConfigOrCalculate() async {
    if (widget.exerciseName != null && widget.exerciseName!.isNotEmpty) {
      // Try to load saved plate config for this exercise at this specific weight
      final savedConfig = await ExercisePlateConfigService().getPlateConfig(
          widget.exerciseName!,
          weight: widget.initialWeight,
          useLbs: widget.useLbs);

      if (savedConfig != null) {
        try {
          // Restore bar type
          final barTypeName = savedConfig['barType'] as String;
          final matchingBar = _barTypes.firstWhere(
            (bar) => bar.name == barTypeName,
            orElse: () => _barTypes.first,
          );

          // Restore plate counts
          final plateCountsJson = savedConfig['plateCounts'] as String;
          final Map<String, dynamic> decodedCounts =
              jsonDecode(plateCountsJson);
          final Map<double, int> restoredCounts = {};

          decodedCounts.forEach((key, value) {
            restoredCounts[double.parse(key)] = value as int;
          });

          setState(() {
            _selectedBar = matchingBar;
            // Merge restored counts with current plate weights
            for (var plate in _availablePlates) {
              _plateCounts[plate.weight] = restoredCounts[plate.weight] ?? 0;
            }
            _isLoading = false;
          });

          // Notify parent of the loaded weight
          final loadedWeight = _calculateTotalWeight();
          widget.onWeightChanged(loadedWeight);
          return;
        } catch (e) {
          print('Error loading saved plate config: $e');
        }
      }
    }

    // No saved config found, calculate from initial weight
    _calculatePlatesFromWeight(widget.initialWeight);
    setState(() {
      _isLoading = false;
    });

    // Notify parent of the calculated weight (may differ from initial due to plate rounding)
    final calculatedWeight = _calculateTotalWeight();
    widget.onWeightChanged(calculatedWeight);
  }

  Future<void> _savePlateConfig() async {
    if (widget.exerciseName != null && widget.exerciseName!.isNotEmpty) {
      // Convert plate counts to JSON-compatible format
      final Map<String, int> plateCountsForJson = {};
      _plateCounts.forEach((key, value) {
        plateCountsForJson[key.toString()] = value;
      });

      // Save with the current total weight as the key
      final totalWeight = _calculateTotalWeight();
      await ExercisePlateConfigService().setPlateConfig(
        widget.exerciseName!,
        totalWeight,
        _selectedBar.name,
        jsonEncode(plateCountsForJson),
        widget.useLbs,
      );
    }
  }

  void _initializePlatesAndBars() {
    _barTypes = _getDefaultBarTypes();
    _availablePlates = _getDefaultPlates();
    _selectedBar = _getDefaultBarForEquipment();
    _plateCounts = {for (var plate in _availablePlates) plate.weight: 0};

    // Load custom plates first, then calculate plates from weight
    _loadCustomPlatesAndBars();
  }

  Future<void> _loadCustomPlatesAndBars() async {
    final unit = widget.useLbs ? 'lbs' : 'kg';
    try {
      final service = PlateBarCustomizationService();
      await service.ensureTablesExist();

      final customPlates = await service.getCustomPlates(unit);
      final customBars = await service.getCustomBars(unit);

      final plates = customPlates.isNotEmpty
          ? customPlates
              .map((p) => PlateInfo(
                    weight: p.weight,
                    color: Color(p.color),
                    label: p.label,
                  ))
              .toList()
          : _getDefaultPlates();

      // Ensure plates are heaviest->lightest for greedy selection + visuals.
      plates.sort((a, b) => b.weight.compareTo(a.weight));

      final bars = customBars.isNotEmpty
          ? customBars
              .map((b) => BarType(
                    name: b.name,
                    weight: b.weight,
                    icon: _iconForCustomBar(
                      name: b.name,
                      shape: b.shape,
                    ),
                    shape: _normalizeBarShape(b.shape),
                  ))
              .toList()
          : _getDefaultBarTypes();

      // Keep a stable UX ordering; defaults first if present.
      bars.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;

      
      setState(() {
        _barTypes = bars;
        _availablePlates = plates;

        // If the currently selected bar disappeared, re-pick a sensible default.
        final stillExists = _barTypes.any((b) => b.name == _selectedBar.name);
        if (!stillExists) {
          _selectedBar = _getDefaultBarForEquipment();
        } else {
          _selectedBar =
              _barTypes.firstWhere((b) => b.name == _selectedBar.name);
        }

        // Reset plate counts to 0 for new plate list
        _plateCounts = {for (var plate in _availablePlates) plate.weight: 0};
      });
      
      // After loading custom plates, now load saved config or calculate from initial weight
      _loadSavedConfigOrCalculate();
    } catch (e) {
      // Fall back silently to defaults if anything goes wrong.
      // Still try to load/calculate even if custom plates failed
      _loadSavedConfigOrCalculate();
    }
  }

  List<BarType> _getDefaultBarTypes() {
    if (widget.useLbs) {
      return [
        BarType(
            name: 'Olympic Bar',
            weight: 45,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'EZ Curl Bar',
            weight: 25,
            icon: Icons.fitness_center,
            shape: 'ez'),
        BarType(
            name: 'Trap Bar',
            weight: 55,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'Smith Machine',
            weight: 20,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'Dumbbell',
            weight: 5,
            icon: Icons.fitness_center,
            shape: 'dumbbell'),
        BarType(
            name: 'No Bar',
            weight: 0,
            icon: Icons.not_interested,
            shape: 'olympic'),
      ];
    }

    return [
      BarType(
          name: 'Olympic Bar',
          weight: 20,
          icon: Icons.fitness_center,
          shape: 'olympic'),
      BarType(
          name: 'EZ Curl Bar',
          weight: 10,
          icon: Icons.fitness_center,
          shape: 'ez'),
      BarType(
          name: 'Trap Bar',
          weight: 25,
          icon: Icons.fitness_center,
          shape: 'olympic'),
      BarType(
          name: 'Smith Machine',
          weight: 10,
          icon: Icons.fitness_center,
          shape: 'olympic'),
      BarType(
          name: 'Dumbbell',
          weight: 2.5,
          icon: Icons.fitness_center,
          shape: 'dumbbell'),
      BarType(
          name: 'No Bar',
          weight: 0,
          icon: Icons.not_interested,
          shape: 'olympic'),
    ];
  }

  List<PlateInfo> _getDefaultPlates() {
    if (widget.useLbs) {
      return [
        PlateInfo(weight: 45, color: const Color(0xFFE53935), label: '45'),
        PlateInfo(weight: 35, color: const Color(0xFFFFEB3B), label: '35'),
        PlateInfo(weight: 25, color: const Color(0xFF4CAF50), label: '25'),
        PlateInfo(weight: 10, color: const Color(0xFF2196F3), label: '10'),
        PlateInfo(weight: 5, color: const Color(0xFFFF9800), label: '5'),
        PlateInfo(weight: 2.5, color: const Color(0xFF9C27B0), label: '2.5'),
      ];
    }

    return [
      PlateInfo(weight: 25, color: const Color(0xFFE53935), label: '25'),
      PlateInfo(weight: 20, color: const Color(0xFF2196F3), label: '20'),
      PlateInfo(weight: 15, color: const Color(0xFFFFEB3B), label: '15'),
      PlateInfo(weight: 10, color: const Color(0xFF4CAF50), label: '10'),
      PlateInfo(weight: 5, color: const Color(0xFFFF9800), label: '5'),
      PlateInfo(weight: 2.5, color: const Color(0xFF9C27B0), label: '2.5'),
      PlateInfo(weight: 1.25, color: const Color(0xFF607D8B), label: '1.25'),
    ];
  }

  // Determine the default bar based on exercise equipment
  BarType _getDefaultBarForEquipment() {
    final equipment = widget.equipment?.toLowerCase() ?? '';

    if (equipment.contains('dumbbell') || equipment.contains('dumb bell')) {
      return _barTypes.firstWhere(
        (bar) => bar.name == 'Dumbbell',
        orElse: () => _barTypes.first,
      );
    } else if (equipment.contains('e-z curl') ||
        equipment.contains('ez curl') ||
        equipment.contains('ez-curl')) {
      return _barTypes.firstWhere(
        (bar) => bar.name == 'EZ Curl Bar',
        orElse: () => _barTypes.first,
      );
    } else if (equipment.contains('trap bar')) {
      return _barTypes.firstWhere(
        (bar) => bar.name == 'Trap Bar',
        orElse: () => _barTypes.first,
      );
    } else if (equipment.contains('smith')) {
      return _barTypes.firstWhere(
        (bar) => bar.name == 'Smith Machine',
        orElse: () => _barTypes.first,
      );
    }

    // Default to Olympic Bar
    return _barTypes.first;
  }

  void _calculatePlatesFromWeight(double targetWeight) {
    // Reset plate counts
    _plateCounts = {for (var plate in _availablePlates) plate.weight: 0};

    // Use equipment-based default bar selection
    _selectedBar = _getDefaultBarForEquipment();

    // Calculate remaining weight per side
    double remainingPerSide = (targetWeight - _selectedBar.weight) / 2;

    // Handle case where bar weight exceeds target (shouldn't happen normally)
    if (remainingPerSide < 0) {
      remainingPerSide = 0;
    }

    // Greedy algorithm to select plates
    for (var plate in _availablePlates) {
      while (remainingPerSide >= plate.weight) {
        _plateCounts[plate.weight] = (_plateCounts[plate.weight] ?? 0) + 1;
        remainingPerSide -= plate.weight;
      }
    }
  }

  double _calculateTotalWeight() {
    double plateWeight = 0;
    for (var plate in _availablePlates) {
      plateWeight += (plate.weight * (_plateCounts[plate.weight] ?? 0) * 2);
    }
    return _selectedBar.weight + plateWeight;
  }

  void _updateWeight() {
    final newWeight = _calculateTotalWeight();
    widget.onWeightChanged(newWeight);
    // Save the plate config whenever weight changes
    _savePlateConfig();
  }

  void _incrementPlate(double plateWeight) {
    setState(() {
      _plateCounts[plateWeight] = (_plateCounts[plateWeight] ?? 0) + 1;
    });
    _updateWeight();
  }

  void _decrementPlate(double plateWeight) {
    setState(() {
      if ((_plateCounts[plateWeight] ?? 0) > 0) {
        _plateCounts[plateWeight] = (_plateCounts[plateWeight] ?? 0) - 1;
      }
    });
    _updateWeight();
  }

  void _selectBar(BarType bar) {
    setState(() {
      _selectedBar = bar;
    });
    _updateWeight();
  }

  void _clearAllPlates() {
    setState(() {
      _plateCounts = {for (var plate in _availablePlates) plate.weight: 0};
    });
    _updateWeight();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching saved config
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final totalWeight = _calculateTotalWeight();
    final unit = widget.useLbs ? 'lbs' : 'kg';

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(totalWeight, unit),

          // Main Barbell Visualization - PROMINENT
          _buildLargeBarbellVisualization(),

          // Bar Type Selector
          _buildBarTypeSelector(unit),

          const SizedBox(height: 16),

          // Plate Selector - Compact
          _buildPlateSelector(unit),

          const SizedBox(height: 12),

          // Info message about customization
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _textSecondaryColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: _textSecondaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customize plate weights and bar types in Settings',
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(double totalWeight, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: _primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Weight',
                    style: TextStyle(
                      color: _textSecondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_formatWeight(totalWeight)} $unit',
                    style: TextStyle(
                      color: _textPrimaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: _textSecondaryColor, size: 20),
                onPressed: _clearAllPlates,
                tooltip: 'Clear plates',
                visualDensity: VisualDensity.compact,
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: Icon(Icons.close, color: _textSecondaryColor, size: 20),
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeBarbellVisualization() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Bar name label
          Text(
            _selectedBar.name,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${_formatWeight(_selectedBar.weight)} ${widget.useLbs ? 'lbs' : 'kg'}',
            style: TextStyle(
              color: _textSecondaryColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Large Barbell Visual
          SizedBox(
            height: 120,
            child: _buildDetailedBarbell(),
          ),

          const SizedBox(height: 16),

          // Weight per side indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Each side: ${_formatWeight((_calculateTotalWeight() - _selectedBar.weight) / 2)} ${widget.useLbs ? 'lbs' : 'kg'}',
              style: TextStyle(
                color: _textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBarbell() {
    final List<Widget> leftPlates = [];
    final List<Widget> rightPlates = [];

    // Build plates from heaviest to lightest (closest to center to edge)
    for (var plate in _availablePlates) {
      final count = _plateCounts[plate.weight] ?? 0;
      for (int i = 0; i < count; i++) {
        leftPlates.add(_buildLargePlateVisual(plate));
        rightPlates.insert(0, _buildLargePlateVisual(plate));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left end cap (collar area)
                _buildEndCap(isLeft: true),

                // Left sleeve
                _buildSleeve(isLeft: true),

                // Left plates
                ...leftPlates,

                // Left collar
                _buildCollar(),

                // Bar center (knurled grip area)
                _buildBarCenter(),

                // Right collar
                _buildCollar(),

                // Right plates
                ...rightPlates,

                // Right sleeve
                _buildSleeve(isLeft: false),

                // Right end cap
                _buildEndCap(isLeft: false),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEndCap({required bool isLeft}) {
    return Container(
      width: 8,
      height: 16,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Colors.grey[500]!,
            Colors.grey[700]!,
          ],
        ),
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(4) : Radius.zero,
          right: !isLeft ? const Radius.circular(4) : Radius.zero,
        ),
      ),
    );
  }

  Widget _buildSleeve({required bool isLeft}) {
    return Container(
      width: 30,
      height: 12,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[600]!,
            Colors.grey[400]!,
            Colors.grey[600]!,
          ],
        ),
      ),
    );
  }

  Widget _buildCollar() {
    return Container(
      width: 6,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildBarCenter() {
    final shape = _normalizeBarShape(_shapeForSelectedBar());
    final isEZBar = shape == 'ez';
    final isDumbbell = shape == 'dumbbell';

    if (isEZBar) {
      return SizedBox(
        width: 100,
        height: 24,
        child: CustomPaint(
          painter: EZBarPainter(),
          size: const Size(100, 24),
        ),
      );
    }

    if (isDumbbell) {
      return SizedBox(
        width: 60,
        height: 20,
        child: CustomPaint(
          painter: DumbbellHandlePainter(),
          size: const Size(60, 20),
        ),
      );
    }

    return Container(
      width: 80,
      height: 14,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey[500]!,
            Colors.grey[300]!,
            Colors.grey[500]!,
          ],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(
        painter: KnurlPatternPainter(),
      ),
    );
  }

  Widget _buildLargePlateVisual(PlateInfo plate) {
    // Calculate dimensions based on weight
    final maxWeight = _availablePlates.first.weight;
    final heightFactor = 0.5 + (0.5 * (plate.weight / maxWeight));
    final height = 90.0 * heightFactor;
    final width = 12.0 + (plate.weight / maxWeight) * 4;

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            plate.color.withOpacity(0.9),
            plate.color,
            plate.color.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Colors.black.withOpacity(0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: plate.color.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: const Offset(1, 0),
          ),
        ],
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            plate.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarTypeSelector(String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten, color: _textSecondaryColor, size: 14),
              const SizedBox(width: 6),
              Text(
                'Bar Type',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _barTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final bar = _barTypes[index];
                final isSelected = _selectedBar == bar;

                return GestureDetector(
                  onTap: () => _selectBar(bar),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor : _backgroundColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _primaryColor
                            : _textSecondaryColor.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bar.name,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : _textSecondaryColor,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatWeight(bar.weight)} $unit',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : _textSecondaryColor.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlateSelector(String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: _textSecondaryColor, size: 14),
              const SizedBox(width: 6),
              Text(
                'Add Plates (per side)',
                style: TextStyle(
                  color: _textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Horizontal scrollable plate buttons
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _availablePlates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final plate = _availablePlates[index];
                return _buildCompactPlateButton(plate, unit);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPlateButton(PlateInfo plate, String unit) {
    final count = _plateCounts[plate.weight] ?? 0;
    final hasPlates = count > 0;

    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasPlates ? plate.color : _textSecondaryColor.withOpacity(0.15),
          width: hasPlates ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Plate indicator with count
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: hasPlates ? plate.color : plate.color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    plate.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (hasPlates)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: _backgroundColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Add/Remove buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniButton(
                icon: Icons.remove,
                onTap: count > 0 ? () => _decrementPlate(plate.weight) : null,
              ),
              const SizedBox(width: 4),
              _buildMiniButton(
                icon: Icons.add,
                onTap: () => _incrementPlate(plate.weight),
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isEnabled
              ? (isPrimary ? _primaryColor.withOpacity(0.2) : _surfaceColor)
              : _surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isEnabled
              ? (isPrimary ? _primaryColor : _textSecondaryColor)
              : _textSecondaryColor.withOpacity(0.3),
        ),
      ),
    );
  }

  String _formatWeight(double weight) {
    if (weight == weight.truncateToDouble()) {
      return weight.toInt().toString();
    }
    return weight
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

/// Custom painter for knurl pattern on bar grip
class KnurlPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!.withOpacity(0.5)
      ..strokeWidth = 0.5;

    // Draw diagonal lines for knurl pattern
    for (double i = 0; i < size.width; i += 4) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + 4, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(i + 4, 0),
        Offset(i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for EZ Curl Bar with characteristic wavy shape
class EZBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final barThickness = 7.0;

    // Create the EZ bar path with angled grip sections
    final path = Path();

    // Start from left side
    path.moveTo(0, centerY - barThickness / 2);

    // Straight section (left)
    path.lineTo(size.width * 0.1, centerY - barThickness / 2);

    // First angled section going down (left grip)
    path.lineTo(size.width * 0.2, centerY + barThickness * 0.8);

    // Angled section going back up
    path.lineTo(size.width * 0.35, centerY - barThickness * 0.8);

    // Center section (straight)
    path.lineTo(size.width * 0.65, centerY - barThickness * 0.8);

    // Angled section going down (right grip)
    path.lineTo(size.width * 0.8, centerY + barThickness * 0.8);

    // Angled section going back up
    path.lineTo(size.width * 0.9, centerY - barThickness / 2);

    // Straight section (right)
    path.lineTo(size.width, centerY - barThickness / 2);

    // Bottom path (reverse direction)
    path.lineTo(size.width, centerY + barThickness / 2);
    path.lineTo(size.width * 0.9, centerY + barThickness / 2);
    path.lineTo(size.width * 0.8, centerY + barThickness * 1.6);
    path.lineTo(size.width * 0.65, centerY + barThickness * 0.0);
    path.lineTo(size.width * 0.35, centerY + barThickness * 0.0);
    path.lineTo(size.width * 0.2, centerY + barThickness * 1.6);
    path.lineTo(size.width * 0.1, centerY + barThickness / 2);
    path.lineTo(0, centerY + barThickness / 2);

    path.close();

    // Draw gradient fill
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    barPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.grey[300]!,
        Colors.grey[500]!,
        Colors.grey[400]!,
      ],
    ).createShader(rect);

    canvas.drawPath(path, barPaint);

    // Draw outline
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[700]!
      ..strokeWidth = 0.5;

    canvas.drawPath(path, outlinePaint);

    // Add knurl pattern on the angled grip sections
    final knurlPaint = Paint()
      ..color = Colors.grey[600]!.withOpacity(0.4)
      ..strokeWidth = 0.5;

    // Left grip knurling
    for (double i = size.width * 0.12; i < size.width * 0.33; i += 3) {
      final t = (i - size.width * 0.1) / (size.width * 0.25);
      final y1 = centerY - barThickness / 2 + t * barThickness * 1.3;
      final y2 = y1 + barThickness * 0.8;
      canvas.drawLine(Offset(i, y1), Offset(i + 2, y2), knurlPaint);
    }

    // Right grip knurling
    for (double i = size.width * 0.67; i < size.width * 0.88; i += 3) {
      final t = (i - size.width * 0.65) / (size.width * 0.25);
      final y1 = centerY - barThickness * 0.8 + t * barThickness * 1.3;
      final y2 = y1 + barThickness * 0.8;
      canvas.drawLine(Offset(i, y1), Offset(i + 2, y2), knurlPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for dumbbell handle visualization
class DumbbellHandlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final handleHeight = 10.0;
    final knurlHeight = 14.0;

    // Draw the thin bar sections on left and right
    final barPaint = Paint()..style = PaintingStyle.fill;

    final barGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.grey[300]!,
        Colors.grey[500]!,
        Colors.grey[400]!,
      ],
    );

    // Left thin section
    barPaint.shader = barGradient.createShader(Rect.fromLTWH(
        0, centerY - handleHeight / 2, size.width * 0.2, handleHeight));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            0, centerY - handleHeight / 2, size.width * 0.2, handleHeight),
        const Radius.circular(2),
      ),
      barPaint,
    );

    // Right thin section
    barPaint.shader = barGradient.createShader(Rect.fromLTWH(size.width * 0.8,
        centerY - handleHeight / 2, size.width * 0.2, handleHeight));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.8, centerY - handleHeight / 2,
            size.width * 0.2, handleHeight),
        const Radius.circular(2),
      ),
      barPaint,
    );

    // Draw the knurled grip section (center, thicker)
    final knurlGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.grey[400]!,
        Colors.grey[600]!,
        Colors.grey[500]!,
      ],
    );

    barPaint.shader = knurlGradient.createShader(Rect.fromLTWH(
        size.width * 0.15,
        centerY - knurlHeight / 2,
        size.width * 0.7,
        knurlHeight));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, centerY - knurlHeight / 2,
            size.width * 0.7, knurlHeight),
        const Radius.circular(3),
      ),
      barPaint,
    );

    // Add knurl pattern
    final knurlPaint = Paint()
      ..color = Colors.grey[700]!.withOpacity(0.4)
      ..strokeWidth = 0.5;

    for (double i = size.width * 0.2; i < size.width * 0.8; i += 4) {
      canvas.drawLine(
        Offset(i, centerY - knurlHeight / 2 + 2),
        Offset(i + 2, centerY + knurlHeight / 2 - 2),
        knurlPaint,
      );
    }

    // Draw outline
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.grey[700]!
      ..strokeWidth = 0.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, centerY - knurlHeight / 2,
            size.width * 0.7, knurlHeight),
        const Radius.circular(3),
      ),
      outlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Model for bar type information
class BarType {
  final String name;
  final double weight;
  final IconData icon;
  final String? shape;

  BarType({
    required this.name,
    required this.weight,
    required this.icon,
    this.shape,
  });
}

/// Model for plate information
class PlateInfo {
  final double weight;
  final Color color;
  final String label;

  PlateInfo({
    required this.weight,
    required this.color,
    required this.label,
  });
}

/// Shows the barbell plate calculator as a bottom sheet
Future<double?> showBarbellPlateCalculator({
  required BuildContext context,
  required double initialWeight,
  required bool useLbs,
  String? exerciseName, // For saving/loading plate config per exercise
  String? equipment, // Equipment type to determine default bar
}) async {
  double? selectedWeight;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF26272B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: BarbellPlateCalculator(
                  initialWeight: initialWeight,
                  useLbs: useLbs,
                  exerciseName: exerciseName,
                  equipment: equipment,
                  onWeightChanged: (weight) {
                    selectedWeight = weight;
                  },
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            // Apply button
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F8EFC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Weight',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return selectedWeight;
}

/// Shows the barbell plate view in read-only mode (for viewing saved configs)
Future<void> showBarbellPlateViewer({
  required BuildContext context,
  required String exerciseName,
  required bool useLbs,
  required double weight, // The specific weight to look up
}) async {
  final unit = useLbs ? 'lbs' : 'kg';

  // Check if there's a saved config for this exercise at this weight
  final savedConfig = await ExercisePlateConfigService()
      .getPlateConfig(exerciseName, weight: weight, useLbs: useLbs);

  if (savedConfig == null) {
    // No saved config, show a message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved plate configuration for this weight'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    return;
  }

  if (!context.mounted) return;

  List<PlateInfo>? customPlates;
  List<BarType>? customBars;
  try {
    final service = PlateBarCustomizationService();
    await service.ensureTablesExist();
    final plates = await service.getCustomPlates(unit);
    final bars = await service.getCustomBars(unit);

    if (plates.isNotEmpty) {
      customPlates = plates
          .map((p) => PlateInfo(
                weight: p.weight,
                color: Color(p.color),
                label: p.label,
              ))
          .toList();
    }

    if (bars.isNotEmpty) {
      customBars = bars
          .map((b) => BarType(
                name: b.name,
                weight: b.weight,
                icon: IconData(b.iconCodePoint, fontFamily: 'MaterialIcons'),
                shape: b.shape,
              ))
          .toList();
    }
  } catch (_) {
    customPlates = null;
    customBars = null;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF26272B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: BarbellPlateViewer(
                  exerciseName: exerciseName,
                  useLbs: useLbs,
                  savedConfig: savedConfig,
                  availablePlatesOverride: customPlates,
                  barTypesOverride: customBars,
                ),
              ),
            ),
            // Close button
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 8,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Check if an exercise has a saved plate configuration at a specific weight
Future<bool> hasPlateConfig(String exerciseName,
    {double? weight, bool? useLbs}) async {
  return await ExercisePlateConfigService()
      .hasPlateConfig(exerciseName, weight: weight, useLbs: useLbs);
}

/// A read-only view of the barbell and plates
class BarbellPlateViewer extends StatelessWidget {
  final String exerciseName;
  final bool useLbs;
  final Map<String, dynamic> savedConfig;
  final List<PlateInfo>? availablePlatesOverride;
  final List<BarType>? barTypesOverride;

  const BarbellPlateViewer({
    super.key,
    required this.exerciseName,
    required this.useLbs,
    required this.savedConfig,
    this.availablePlatesOverride,
    this.barTypesOverride,
  });

  // Theme colors
  static const Color _backgroundColor = Color(0xFF1A1B1E);
  static const Color _surfaceColor = Color(0xFF26272B);
  static const Color _primaryColor = Color(0xFF3F8EFC);
  static const Color _textPrimaryColor = Colors.white;
  static const Color _textSecondaryColor = Color(0xFFBBBBBB);

  String _normalizeBarShape(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return 'olympic';
    if (v == 'olympic') return 'olympic';
    if (v == 'ez') return 'ez';
    if (v == 'dumbbell') return 'dumbbell';
    if (v == 'standard' || v == 'barbell' || v == 'straight') return 'olympic';
    if (v.contains('ez')) return 'ez';
    if (v.contains('dumb')) return 'dumbbell';
    return 'olympic';
  }

  String _shapeForBar(BarType bar) {
    final explicit = bar.shape;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit;
    }

    final name = bar.name.trim().toLowerCase();
    if (name.contains('dumbbell') || name.contains('dumb bell'))
      return 'dumbbell';
    if (name.contains('ez') || name.contains('e-z')) return 'ez';
    return 'olympic';
  }

  String _cleanExerciseName(String name) {
    return name
        .replaceAll(RegExp(r'##API_ID:[^#]+##'), '')
        .replaceAll('##CUSTOM##', '')
        .replaceAll(RegExp(r'##CUSTOM:[^#]+##'), '')
        .trim();
  }

  List<BarType> _getBarTypes() {
    if (useLbs) {
      return [
        BarType(
            name: 'Olympic Bar',
            weight: 45,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'EZ Curl Bar',
            weight: 25,
            icon: Icons.fitness_center,
            shape: 'ez'),
        BarType(
            name: 'Trap Bar',
            weight: 55,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'Smith Machine',
            weight: 20,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'Dumbbell',
            weight: 5,
            icon: Icons.fitness_center,
            shape: 'dumbbell'),
        BarType(
            name: 'No Bar',
            weight: 0,
            icon: Icons.not_interested,
            shape: 'olympic'),
      ];
    } else {
      return [
        BarType(
            name: 'Olympic Bar',
            weight: 20,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'EZ Curl Bar',
            weight: 10,
            icon: Icons.fitness_center,
            shape: 'ez'),
        BarType(
            name: 'Trap Bar',
            weight: 25,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'Smith Machine',
            weight: 10,
            icon: Icons.fitness_center,
            shape: 'olympic'),
        BarType(
            name: 'Dumbbell',
            weight: 2.5,
            icon: Icons.fitness_center,
            shape: 'dumbbell'),
        BarType(
            name: 'No Bar',
            weight: 0,
            icon: Icons.not_interested,
            shape: 'olympic'),
      ];
    }
  }

  List<PlateInfo> _getAvailablePlates() {
    if (useLbs) {
      return [
        PlateInfo(weight: 45, color: const Color(0xFFE53935), label: '45'),
        PlateInfo(weight: 35, color: const Color(0xFFFFEB3B), label: '35'),
        PlateInfo(weight: 25, color: const Color(0xFF4CAF50), label: '25'),
        PlateInfo(weight: 10, color: const Color(0xFF2196F3), label: '10'),
        PlateInfo(weight: 5, color: const Color(0xFFFF9800), label: '5'),
        PlateInfo(weight: 2.5, color: const Color(0xFF9C27B0), label: '2.5'),
      ];
    } else {
      return [
        PlateInfo(weight: 25, color: const Color(0xFFE53935), label: '25'),
        PlateInfo(weight: 20, color: const Color(0xFF2196F3), label: '20'),
        PlateInfo(weight: 15, color: const Color(0xFFFFEB3B), label: '15'),
        PlateInfo(weight: 10, color: const Color(0xFF4CAF50), label: '10'),
        PlateInfo(weight: 5, color: const Color(0xFFFF9800), label: '5'),
        PlateInfo(weight: 2.5, color: const Color(0xFF9C27B0), label: '2.5'),
        PlateInfo(weight: 1.25, color: const Color(0xFF607D8B), label: '1.25'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final barTypes = (barTypesOverride != null && barTypesOverride!.isNotEmpty)
        ? List<BarType>.from(barTypesOverride!)
        : _getBarTypes();
    final availablePlates =
        (availablePlatesOverride != null && availablePlatesOverride!.isNotEmpty)
            ? List<PlateInfo>.from(availablePlatesOverride!)
            : _getAvailablePlates();
    final unit = useLbs ? 'lbs' : 'kg';

    // Parse saved config
    final barTypeName = savedConfig['barType'] as String;
    final selectedBar = barTypes.firstWhere(
      (bar) => bar.name == barTypeName,
      orElse: () => barTypes.first,
    );

    final plateCountsJson = savedConfig['plateCounts'] as String;
    final Map<String, dynamic> decodedCounts = jsonDecode(plateCountsJson);
    final Map<double, int> plateCounts = {};
    decodedCounts.forEach((key, value) {
      plateCounts[double.parse(key)] = value as int;
    });

    // Ensure plates list contains any weights from saved config.
    for (final weight in plateCounts.keys) {
      final exists = availablePlates.any((p) => p.weight == weight);
      if (!exists) {
        availablePlates.add(
          PlateInfo(
            weight: weight,
            color: Colors.grey[600]!,
            label: _formatWeight(weight),
          ),
        );
      }
    }

    // Keep plates sorted from heaviest to lightest.
    availablePlates.sort((a, b) => b.weight.compareTo(a.weight));

    // Calculate total weight
    double plateWeight = 0;
    for (var plate in availablePlates) {
      plateWeight += (plate.weight * (plateCounts[plate.weight] ?? 0) * 2);
    }
    final totalWeight = selectedBar.weight + plateWeight;

    // Get plates on one side
    List<PlateInfo> platesOnSide = [];
    for (var plate in availablePlates) {
      final count = plateCounts[plate.weight] ?? 0;
      for (int i = 0; i < count; i++) {
        platesOnSide.add(plate);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility,
                            color: _textSecondaryColor, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'Plate Configuration',
                          style: TextStyle(
                            color: _textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _cleanExerciseName(exerciseName),
                      style: const TextStyle(
                        color: _textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryColor, width: 1),
                  ),
                  child: Text(
                    '${_formatWeight(totalWeight)} $unit',
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barbell visualization
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: SizedBox(
              height: 120,
              child: Center(
                child:
                    _buildBarbell(platesOnSide, availablePlates, selectedBar),
              ),
            ),
          ),

          // Bar type info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: _primaryColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  selectedBar.name,
                  style: const TextStyle(
                    color: _textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_formatWeight(selectedBar.weight)} $unit',
                  style: const TextStyle(
                    color: _textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Plates breakdown
          if (platesOnSide.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plates (per side)',
                    style: TextStyle(
                      color: _textSecondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availablePlates
                        .where((plate) => (plateCounts[plate.weight] ?? 0) > 0)
                        .map((plate) => _buildPlateChip(
                            plate, plateCounts[plate.weight] ?? 0, unit))
                        .toList(),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        color: _textSecondaryColor, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Bar only, no plates',
                      style: TextStyle(
                        color: _textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBarbell(List<PlateInfo> platesOnSide,
      List<PlateInfo> availablePlates, BarType selectedBar) {
    final shape = _normalizeBarShape(_shapeForBar(selectedBar));
    final isEZBar = shape == 'ez';
    final isDumbbell = shape == 'dumbbell';

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final barWidth = maxWidth * 0.35;
        final sleeveWidth = maxWidth * 0.25;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left plates
            SizedBox(
              width: sleeveWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 8,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(4),
                      ),
                    ),
                  ),
                  Container(width: 20, height: 20, color: Colors.grey[500]),
                  ...platesOnSide.reversed.map(
                      (plate) => _buildPlateWidget(plate, availablePlates)),
                  Container(
                    width: 6,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            // Center bar - EZ bar, Dumbbell, or regular
            if (isEZBar)
              SizedBox(
                width: barWidth,
                height: 24,
                child: CustomPaint(
                  painter: EZBarPainter(),
                  size: Size(barWidth, 24),
                ),
              )
            else if (isDumbbell)
              SizedBox(
                width: barWidth,
                height: 20,
                child: CustomPaint(
                  painter: DumbbellHandlePainter(),
                  size: Size(barWidth, 20),
                ),
              )
            else
              Container(
                width: barWidth,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[600]!,
                      Colors.grey[400]!,
                      Colors.grey[600]!
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: CustomPaint(
                    painter: KnurlPatternPainter(),
                    size: Size(barWidth, 16),
                  ),
                ),
              ),

            // Right plates
            SizedBox(
              width: sleeveWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ...platesOnSide.map(
                      (plate) => _buildPlateWidget(plate, availablePlates)),
                  Container(width: 20, height: 20, color: Colors.grey[500]),
                  Container(
                    width: 8,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlateWidget(PlateInfo plate, List<PlateInfo> availablePlates) {
    final maxPlateWeight = availablePlates.first.weight;
    final heightRatio = 0.4 + (plate.weight / maxPlateWeight) * 0.6;
    final height = 80 * heightRatio;

    return Container(
      width: 8,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: plate.color,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black26, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPlateChip(PlateInfo plate, int count, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: plate.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: plate.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: plate.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${plate.label} $unit',
            style: const TextStyle(
              color: _textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '×$count',
            style: TextStyle(
              color: plate.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double weight) {
    return weight
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}
