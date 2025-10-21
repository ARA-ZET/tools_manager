import 'package:flutter/material.dart';

/// Measurement units for consumables
enum MeasurementUnit {
  // Liquids
  liters,
  milliliters,

  // Length
  meters,
  centimeters,

  // Count
  pieces,
  sheets,
  rolls,

  // Weight
  kilograms,
  grams,

  // Area
  squareMeters,
}

/// Extension methods for MeasurementUnit
extension MeasurementUnitExtension on MeasurementUnit {
  /// Get display name for the unit
  String get displayName {
    switch (this) {
      case MeasurementUnit.liters:
        return 'Liters';
      case MeasurementUnit.milliliters:
        return 'Milliliters';
      case MeasurementUnit.meters:
        return 'Meters';
      case MeasurementUnit.centimeters:
        return 'Centimeters';
      case MeasurementUnit.pieces:
        return 'Pieces';
      case MeasurementUnit.sheets:
        return 'Sheets';
      case MeasurementUnit.rolls:
        return 'Rolls';
      case MeasurementUnit.kilograms:
        return 'Kilograms';
      case MeasurementUnit.grams:
        return 'Grams';
      case MeasurementUnit.squareMeters:
        return 'Square Meters';
    }
  }

  /// Get short abbreviation
  String get abbreviation {
    switch (this) {
      case MeasurementUnit.liters:
        return 'L';
      case MeasurementUnit.milliliters:
        return 'ml';
      case MeasurementUnit.meters:
        return 'm';
      case MeasurementUnit.centimeters:
        return 'cm';
      case MeasurementUnit.pieces:
        return 'pcs';
      case MeasurementUnit.sheets:
        return 'sheets';
      case MeasurementUnit.rolls:
        return 'rolls';
      case MeasurementUnit.kilograms:
        return 'kg';
      case MeasurementUnit.grams:
        return 'g';
      case MeasurementUnit.squareMeters:
        return 'm²';
    }
  }

  /// Get icon for the unit
  IconData get icon {
    switch (this) {
      case MeasurementUnit.liters:
      case MeasurementUnit.milliliters:
        return Icons.water_drop;
      case MeasurementUnit.meters:
      case MeasurementUnit.centimeters:
        return Icons.straighten;
      case MeasurementUnit.pieces:
        return Icons.apps;
      case MeasurementUnit.sheets:
        return Icons.description;
      case MeasurementUnit.rolls:
        return Icons.circle;
      case MeasurementUnit.kilograms:
      case MeasurementUnit.grams:
        return Icons.scale;
      case MeasurementUnit.squareMeters:
        return Icons.crop_square;
    }
  }

  /// Get category of measurement
  String get category {
    switch (this) {
      case MeasurementUnit.liters:
      case MeasurementUnit.milliliters:
        return 'Volume';
      case MeasurementUnit.meters:
      case MeasurementUnit.centimeters:
        return 'Length';
      case MeasurementUnit.pieces:
      case MeasurementUnit.sheets:
      case MeasurementUnit.rolls:
        return 'Count';
      case MeasurementUnit.kilograms:
      case MeasurementUnit.grams:
        return 'Weight';
      case MeasurementUnit.squareMeters:
        return 'Area';
    }
  }

  /// Check if unit allows decimal values
  bool get allowsDecimals {
    switch (this) {
      case MeasurementUnit.liters:
      case MeasurementUnit.milliliters:
      case MeasurementUnit.meters:
      case MeasurementUnit.centimeters:
      case MeasurementUnit.kilograms:
      case MeasurementUnit.grams:
      case MeasurementUnit.squareMeters:
        return true;
      case MeasurementUnit.pieces:
      case MeasurementUnit.sheets:
      case MeasurementUnit.rolls:
        return false;
    }
  }
}

/// Helper functions for MeasurementUnit
class MeasurementUnitHelper {
  /// Convert string to MeasurementUnit
  static MeasurementUnit fromString(String value) {
    return MeasurementUnit.values.firstWhere(
      (unit) => unit.name == value,
      orElse: () => MeasurementUnit.pieces,
    );
  }

  /// Get all units for a category
  static List<MeasurementUnit> getUnitsForCategory(String category) {
    return MeasurementUnit.values
        .where((unit) => unit.category == category)
        .toList();
  }

  /// Get default unit for a consumable category
  static MeasurementUnit getDefaultUnitForCategory(String consumableCategory) {
    final category = consumableCategory.toLowerCase();

    if (category.contains('glue') ||
        category.contains('adhesive') ||
        category.contains('stain') ||
        category.contains('finish') ||
        category.contains('oil') ||
        category.contains('spirit')) {
      return MeasurementUnit.liters;
    }

    if (category.contains('tape') || category.contains('string')) {
      return MeasurementUnit.meters;
    }

    if (category.contains('paper') || category.contains('sheet')) {
      return MeasurementUnit.sheets;
    }

    if (category.contains('roll')) {
      return MeasurementUnit.rolls;
    }

    return MeasurementUnit.pieces;
  }

  /// Format quantity with unit
  static String formatQuantity(double quantity, MeasurementUnit unit) {
    if (unit.allowsDecimals) {
      // Remove trailing zeros for decimals
      final formatted = quantity.toStringAsFixed(2);
      final trimmed = formatted.replaceAll(RegExp(r'\.?0+$'), '');
      return '$trimmed ${unit.abbreviation}';
    } else {
      return '${quantity.toInt()} ${unit.abbreviation}';
    }
  }
}
