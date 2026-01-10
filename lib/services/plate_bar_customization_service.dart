import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'database_services.dart';

// Service for managing custom plates and bars for the plate calculator
class PlateBarCustomizationService {
  // Singleton instance
  static final PlateBarCustomizationService _instance =
      PlateBarCustomizationService._internal();
  factory PlateBarCustomizationService() => _instance;
  PlateBarCustomizationService._internal();

  // Notifier to inform listeners when customization changes
  static final ValueNotifier<bool> customizationUpdatedNotifier =
      ValueNotifier(false);

  // Table & column names for custom plates
  static const String _customPlatesTableName = 'custom_plates';
  static const String _plateIdColumnName = 'id';
  static const String _plateWeightColumnName = 'weight';
  static const String _plateColorColumnName = 'color'; // Stored as int (ARGB)
  static const String _plateLabelColumnName = 'label';
  static const String _plateUnitColumnName = 'unit'; // 'lbs' or 'kg'
  static const String _plateIsDefaultColumnName = 'is_default'; // 0 or 1
  static const String _plateCreatedAtColumnName = 'created_at';

  // Table & column names for custom bars
  static const String _customBarsTableName = 'custom_bars';
  static const String _barIdColumnName = 'id';
  static const String _barNameColumnName = 'name';
  static const String _barWeightColumnName = 'weight';
  static const String _barIconColumnName = 'icon'; // Icon code point
  static const String _barShapeColumnName =
      'shape'; // 'straight', 'ez', 'dumbbell', etc.
  static const String _barUnitColumnName = 'unit'; // 'lbs' or 'kg'
  static const String _barIsDefaultColumnName = 'is_default'; // 0 or 1
  static const String _barCreatedAtColumnName = 'created_at';

  // Create custom plates and bars tables
  Future<void> createCustomizationTables(Database db) async {
    // Custom plates table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_customPlatesTableName (
        $_plateIdColumnName INTEGER PRIMARY KEY AUTOINCREMENT,
        $_plateWeightColumnName REAL NOT NULL,
        $_plateColorColumnName INTEGER NOT NULL,
        $_plateLabelColumnName TEXT NOT NULL,
        $_plateUnitColumnName TEXT NOT NULL,
        $_plateIsDefaultColumnName INTEGER NOT NULL DEFAULT 0,
        $_plateCreatedAtColumnName TEXT NOT NULL
      )
    ''');

    // Custom bars table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_customBarsTableName (
        $_barIdColumnName INTEGER PRIMARY KEY AUTOINCREMENT,
        $_barNameColumnName TEXT NOT NULL,
        $_barWeightColumnName REAL NOT NULL,
        $_barIconColumnName INTEGER NOT NULL,
        $_barShapeColumnName TEXT NOT NULL,
        $_barUnitColumnName TEXT NOT NULL,
        $_barIsDefaultColumnName INTEGER NOT NULL DEFAULT 0,
        $_barCreatedAtColumnName TEXT NOT NULL
      )
    ''');
  }

  // Ensure tables exist
  Future<void> ensureTablesExist() async {
    final db = await DatabaseService.instance.database;
    await createCustomizationTables(db);
  }

  // ========== CUSTOM PLATES OPERATIONS ==========

  // Get all custom plates for a specific unit
  Future<List<CustomPlate>> getCustomPlates(String unit) async {
    final db = await DatabaseService.instance.database;
    // Ensure there is always at least a default set.
    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $_customPlatesTableName WHERE $_plateUnitColumnName = ?',
          [unit],
        )) ??
        0;
    if (totalCount == 0) {
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final plate in _defaultPlatesForUnit(unit)) {
        batch.insert(_customPlatesTableName, {
          _plateWeightColumnName: plate.weight,
          _plateColorColumnName: plate.color,
          _plateLabelColumnName: plate.label,
          _plateUnitColumnName: unit,
          _plateIsDefaultColumnName: 1,
          _plateCreatedAtColumnName: now,
        });
      }
      await batch.commit(noResult: true);
    }

    final results = await db.query(
      _customPlatesTableName,
      where: '$_plateUnitColumnName = ?',
      whereArgs: [unit],
      orderBy: '$_plateWeightColumnName DESC',
    );

    return results.map((map) => CustomPlate.fromMap(map)).toList();
  }

  // Add a custom plate
  Future<int> addCustomPlate({
    required double weight,
    required int color,
    required String label,
    required String unit,
    bool isDefault = false,
  }) async {
    final db = await DatabaseService.instance.database;
    final id = await db.insert(_customPlatesTableName, {
      _plateWeightColumnName: weight,
      _plateColorColumnName: color,
      _plateLabelColumnName: label,
      _plateUnitColumnName: unit,
      _plateIsDefaultColumnName: isDefault ? 1 : 0,
      _plateCreatedAtColumnName: DateTime.now().toIso8601String(),
    });

    customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
    return id;
  }

  // Update a custom plate
  Future<void> updateCustomPlate({
    required int id,
    double? weight,
    int? color,
    String? label,
  }) async {
    final db = await DatabaseService.instance.database;
    final Map<String, dynamic> updates = {};

    if (weight != null) updates[_plateWeightColumnName] = weight;
    if (color != null) updates[_plateColorColumnName] = color;
    if (label != null) updates[_plateLabelColumnName] = label;

    if (updates.isNotEmpty) {
      await db.update(
        _customPlatesTableName,
        updates,
        where: '$_plateIdColumnName = ?',
        whereArgs: [id],
      );
      customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
    }
  }

  // Delete a custom plate
  Future<void> deleteCustomPlate(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      _customPlatesTableName,
      where: '$_plateIdColumnName = ?',
      whereArgs: [id],
    );
    customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
  }

  // Reset plates to defaults for a unit
  Future<void> resetPlatesToDefaults(String unit) async {
    final db = await DatabaseService.instance.database;
    // A true reset should restore the canonical default set, even if the user
    // previously edited or deleted rows that were marked as default.
    await db.delete(
      _customPlatesTableName,
      where: '$_plateUnitColumnName = ?',
      whereArgs: [unit],
    );

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final plate in _defaultPlatesForUnit(unit)) {
      batch.insert(_customPlatesTableName, {
        _plateWeightColumnName: plate.weight,
        _plateColorColumnName: plate.color,
        _plateLabelColumnName: plate.label,
        _plateUnitColumnName: unit,
        _plateIsDefaultColumnName: 1,
        _plateCreatedAtColumnName: now,
      });
    }
    await batch.commit(noResult: true);
    customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
  }

  // ========== CUSTOM BARS OPERATIONS ==========

  // Get all custom bars for a specific unit
  Future<List<CustomBar>> getCustomBars(String unit) async {
    final db = await DatabaseService.instance.database;
    // Ensure there is always at least a default set.
    final totalCount = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM $_customBarsTableName WHERE $_barUnitColumnName = ?',
          [unit],
        )) ??
        0;
    if (totalCount == 0) {
      final batch = db.batch();
      final now = DateTime.now().toIso8601String();
      for (final bar in _defaultBarsForUnit(unit)) {
        batch.insert(_customBarsTableName, {
          _barNameColumnName: bar.name,
          _barWeightColumnName: bar.weight,
          _barIconColumnName: bar.iconCodePoint,
          _barShapeColumnName: bar.shape,
          _barUnitColumnName: unit,
          _barIsDefaultColumnName: 1,
          _barCreatedAtColumnName: now,
        });
      }
      await batch.commit(noResult: true);
    }

    final results = await db.query(
      _customBarsTableName,
      where: '$_barUnitColumnName = ?',
      whereArgs: [unit],
      orderBy: '$_barWeightColumnName DESC',
    );

    return results.map((map) => CustomBar.fromMap(map)).toList();
  }

  // Add a custom bar
  Future<int> addCustomBar({
    required String name,
    required double weight,
    required int iconCodePoint,
    required String shape,
    required String unit,
    bool isDefault = false,
  }) async {
    final db = await DatabaseService.instance.database;
    final id = await db.insert(_customBarsTableName, {
      _barNameColumnName: name,
      _barWeightColumnName: weight,
      _barIconColumnName: iconCodePoint,
      _barShapeColumnName: shape,
      _barUnitColumnName: unit,
      _barIsDefaultColumnName: isDefault ? 1 : 0,
      _barCreatedAtColumnName: DateTime.now().toIso8601String(),
    });

    customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
    return id;
  }

  // Update a custom bar
  Future<void> updateCustomBar({
    required int id,
    String? name,
    double? weight,
    int? iconCodePoint,
    String? shape,
  }) async {
    final db = await DatabaseService.instance.database;
    final Map<String, dynamic> updates = {};

    if (name != null) updates[_barNameColumnName] = name;
    if (weight != null) updates[_barWeightColumnName] = weight;
    if (iconCodePoint != null) updates[_barIconColumnName] = iconCodePoint;
    if (shape != null) updates[_barShapeColumnName] = shape;

    if (updates.isNotEmpty) {
      await db.update(
        _customBarsTableName,
        updates,
        where: '$_barIdColumnName = ?',
        whereArgs: [id],
      );
      customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
    }
  }

  // Delete a custom bar
  Future<void> deleteCustomBar(int id) async {
    final db = await DatabaseService.instance.database;
    await db.delete(
      _customBarsTableName,
      where: '$_barIdColumnName = ?',
      whereArgs: [id],
    );
    customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
  }

  // Reset bars to defaults for a unit
  Future<void> resetBarsToDefaults(String unit) async {
    final db = await DatabaseService.instance.database;
    // A true reset should restore the canonical default set, even if the user
    // previously edited or deleted rows that were marked as default.
    await db.delete(
      _customBarsTableName,
      where: '$_barUnitColumnName = ?',
      whereArgs: [unit],
    );

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final bar in _defaultBarsForUnit(unit)) {
      batch.insert(_customBarsTableName, {
        _barNameColumnName: bar.name,
        _barWeightColumnName: bar.weight,
        _barIconColumnName: bar.iconCodePoint,
        _barShapeColumnName: bar.shape,
        _barUnitColumnName: unit,
        _barIsDefaultColumnName: 1,
        _barCreatedAtColumnName: now,
      });
    }
    await batch.commit(noResult: true);
    customizationUpdatedNotifier.value = !customizationUpdatedNotifier.value;
  }

  List<_DefaultPlateSeed> _defaultPlatesForUnit(String unit) {
    if (unit == 'lbs') {
      return const [
        _DefaultPlateSeed(weight: 45, color: 0xFFE53935, label: '45'),
        _DefaultPlateSeed(weight: 35, color: 0xFFFFEB3B, label: '35'),
        _DefaultPlateSeed(weight: 25, color: 0xFF4CAF50, label: '25'),
        _DefaultPlateSeed(weight: 10, color: 0xFF2196F3, label: '10'),
        _DefaultPlateSeed(weight: 5, color: 0xFFFF9800, label: '5'),
        _DefaultPlateSeed(weight: 2.5, color: 0xFF9C27B0, label: '2.5'),
      ];
    }

    return const [
      _DefaultPlateSeed(weight: 25, color: 0xFFE53935, label: '25'),
      _DefaultPlateSeed(weight: 20, color: 0xFF2196F3, label: '20'),
      _DefaultPlateSeed(weight: 15, color: 0xFFFFEB3B, label: '15'),
      _DefaultPlateSeed(weight: 10, color: 0xFF4CAF50, label: '10'),
      _DefaultPlateSeed(weight: 5, color: 0xFFFF9800, label: '5'),
      _DefaultPlateSeed(weight: 2.5, color: 0xFF9C27B0, label: '2.5'),
      _DefaultPlateSeed(weight: 1.25, color: 0xFF607D8B, label: '1.25'),
    ];
  }

  List<_DefaultBarSeed> _defaultBarsForUnit(String unit) {
    if (unit == 'lbs') {
      return const [
        _DefaultBarSeed(
          name: 'Olympic Bar',
          weight: 45,
          iconCodePoint: 0xe28f, // Icons.fitness_center
          shape: 'olympic',
        ),
        _DefaultBarSeed(
          name: 'EZ Curl Bar',
          weight: 25,
          iconCodePoint: 0xe28f,
          shape: 'ez',
        ),
        _DefaultBarSeed(
          name: 'Trap Bar',
          weight: 55,
          iconCodePoint: 0xe28f,
          shape: 'olympic',
        ),
        _DefaultBarSeed(
          name: 'Smith Machine',
          weight: 20,
          iconCodePoint: 0xe28f,
          shape: 'olympic',
        ),
        _DefaultBarSeed(
          name: 'Dumbbell',
          weight: 5,
          iconCodePoint: 0xe28f,
          shape: 'dumbbell',
        ),
        _DefaultBarSeed(
          name: 'No Bar',
          weight: 0,
          iconCodePoint: 0xe14c, // Icons.not_interested
          shape: 'none',
        ),
      ];
    }

    return const [
      _DefaultBarSeed(
        name: 'Olympic Bar',
        weight: 20,
        iconCodePoint: 0xe28f,
        shape: 'olympic',
      ),
      _DefaultBarSeed(
        name: 'EZ Curl Bar',
        weight: 10,
        iconCodePoint: 0xe28f,
        shape: 'ez',
      ),
      _DefaultBarSeed(
        name: 'Trap Bar',
        weight: 25,
        iconCodePoint: 0xe28f,
        shape: 'olympic',
      ),
      _DefaultBarSeed(
        name: 'Smith Machine',
        weight: 10,
        iconCodePoint: 0xe28f,
        shape: 'olympic',
      ),
      _DefaultBarSeed(
        name: 'Dumbbell',
        weight: 2.5,
        iconCodePoint: 0xe28f,
        shape: 'dumbbell',
      ),
      _DefaultBarSeed(
        name: 'No Bar',
        weight: 0,
        iconCodePoint: 0xe14c,
        shape: 'none',
      ),
    ];
  }
}

class _DefaultPlateSeed {
  final double weight;
  final int color;
  final String label;

  const _DefaultPlateSeed({
    required this.weight,
    required this.color,
    required this.label,
  });
}

class _DefaultBarSeed {
  final String name;
  final double weight;
  final int iconCodePoint;
  final String shape;

  const _DefaultBarSeed({
    required this.name,
    required this.weight,
    required this.iconCodePoint,
    required this.shape,
  });
}

// Custom Plate model
class CustomPlate {
  final int id;
  final double weight;
  final int color; // ARGB color value
  final String label;
  final String unit;
  final bool isDefault;
  final DateTime createdAt;

  CustomPlate({
    required this.id,
    required this.weight,
    required this.color,
    required this.label,
    required this.unit,
    required this.isDefault,
    required this.createdAt,
  });

  factory CustomPlate.fromMap(Map<String, dynamic> map) {
    return CustomPlate(
      id: map['id'] as int,
      weight: map['weight'] as double,
      color: map['color'] as int,
      label: map['label'] as String,
      unit: map['unit'] as String,
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weight': weight,
      'color': color,
      'label': label,
      'unit': unit,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Custom Bar model
class CustomBar {
  final int id;
  final String name;
  final double weight;
  final int iconCodePoint;
  final String shape; // 'straight', 'ez', 'dumbbell', 'trap', etc.
  final String unit;
  final bool isDefault;
  final DateTime createdAt;

  CustomBar({
    required this.id,
    required this.name,
    required this.weight,
    required this.iconCodePoint,
    required this.shape,
    required this.unit,
    required this.isDefault,
    required this.createdAt,
  });

  factory CustomBar.fromMap(Map<String, dynamic> map) {
    return CustomBar(
      id: map['id'] as int,
      name: map['name'] as String,
      weight: map['weight'] as double,
      iconCodePoint: map['icon'] as int,
      shape: map['shape'] as String,
      unit: map['unit'] as String,
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'icon': iconCodePoint,
      'shape': shape,
      'unit': unit,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
