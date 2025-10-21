import 'package:cloud_firestore/cloud_firestore.dart';
import 'measurement_unit.dart';

/// Consumable model for inventory management
class Consumable {
  final String id;
  final String uniqueId;
  final String name;
  final String category;
  final String brand;
  final MeasurementUnit unit;
  final double currentQuantity;
  final double minQuantity;
  final double maxQuantity;
  final double unitPrice;
  final String? sku;
  final List<String> images;
  final String qrPayload;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  Consumable({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.category,
    required this.brand,
    required this.unit,
    required this.currentQuantity,
    required this.minQuantity,
    required this.maxQuantity,
    required this.unitPrice,
    this.sku,
    this.images = const [],
    required this.qrPayload,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.metadata,
  });

  /// Create Consumable from Firestore document
  factory Consumable.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Consumable(
      id: doc.id,
      uniqueId: data['uniqueId'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown Consumable',
      category: data['category'] as String? ?? 'Uncategorized',
      brand: data['brand'] as String? ?? '',
      unit: MeasurementUnitHelper.fromString(
        data['unit'] as String? ?? 'pieces',
      ),
      currentQuantity: (data['currentQuantity'] as num?)?.toDouble() ?? 0.0,
      minQuantity: (data['minQuantity'] as num?)?.toDouble() ?? 0.0,
      maxQuantity: (data['maxQuantity'] as num?)?.toDouble() ?? 100.0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      sku: data['sku'] as String?,
      images: (data['images'] as List<dynamic>?)?.cast<String>() ?? [],
      qrPayload: data['qrPayload'] as String? ?? '',
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert Consumable to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'uniqueId': uniqueId,
      'name': name,
      'category': category,
      'brand': brand,
      'unit': unit.name,
      'currentQuantity': currentQuantity,
      'minQuantity': minQuantity,
      'maxQuantity': maxQuantity,
      'unitPrice': unitPrice,
      'sku': sku,
      'images': images,
      'qrPayload': qrPayload,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'metadata': metadata,
    };
  }

  /// Create a copy with updated fields
  Consumable copyWith({
    String? id,
    String? uniqueId,
    String? name,
    String? category,
    String? brand,
    MeasurementUnit? unit,
    double? currentQuantity,
    double? minQuantity,
    double? maxQuantity,
    double? unitPrice,
    String? sku,
    List<String>? images,
    String? qrPayload,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return Consumable(
      id: id ?? this.id,
      uniqueId: uniqueId ?? this.uniqueId,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      unit: unit ?? this.unit,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minQuantity: minQuantity ?? this.minQuantity,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      unitPrice: unitPrice ?? this.unitPrice,
      sku: sku ?? this.sku,
      images: images ?? this.images,
      qrPayload: qrPayload ?? this.qrPayload,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if consumable is low in stock
  bool get isLowStock => currentQuantity <= minQuantity;

  /// Check if consumable is out of stock
  bool get isOutOfStock => currentQuantity <= 0;

  /// Check if consumable is overstocked
  bool get isOverstocked => currentQuantity >= maxQuantity;

  /// Get stock percentage (0-100)
  double get stockPercentage {
    if (maxQuantity <= 0) return 0;
    return (currentQuantity / maxQuantity * 100).clamp(0, 100);
  }

  /// Get stock level status
  StockLevel get stockLevel {
    if (isOutOfStock) return StockLevel.outOfStock;
    if (isLowStock) return StockLevel.low;
    if (isOverstocked) return StockLevel.overstocked;
    return StockLevel.normal;
  }

  /// Get formatted current quantity
  String get formattedCurrentQuantity {
    return MeasurementUnitHelper.formatQuantity(currentQuantity, unit);
  }

  /// Get total inventory value
  double get totalValue => currentQuantity * unitPrice;

  /// Get Firestore document reference
  DocumentReference get reference {
    return FirebaseFirestore.instance.collection('consumables').doc(id);
  }
}

/// Stock level enum
enum StockLevel { outOfStock, low, normal, overstocked }

/// Extension for StockLevel
extension StockLevelExtension on StockLevel {
  String get displayName {
    switch (this) {
      case StockLevel.outOfStock:
        return 'Out of Stock';
      case StockLevel.low:
        return 'Low Stock';
      case StockLevel.normal:
        return 'Normal';
      case StockLevel.overstocked:
        return 'Overstocked';
    }
  }

  /// Get color for stock level
  int get colorValue {
    switch (this) {
      case StockLevel.outOfStock:
        return 0xFFD32F2F; // Red
      case StockLevel.low:
        return 0xFFF57C00; // Orange
      case StockLevel.normal:
        return 0xFF388E3C; // Green
      case StockLevel.overstocked:
        return 0xFF1976D2; // Blue
    }
  }
}
