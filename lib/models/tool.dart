import 'package:cloud_firestore/cloud_firestore.dart';

/// Tool model representing a workshop tool
class Tool {
  final String id;
  final String uniqueId; // Printed on QR label
  final String name;
  final String brand;
  final String model;
  final String num; // Tool number
  final List<String> images; // Firebase Storage URLs
  final String qrPayload; // QR code payload (e.g., "TOOL#SM12345")
  final String status; // "available" | "checked_out"
  final DocumentReference? currentHolder; // Reference to staff member

  // Last assignment tracking (for instant status display)
  final String? lastAssignedToName; // Full name of staff member
  final String? lastAssignedToJobCode; // Job code of staff member
  final String? lastAssignedByName; // Admin who assigned it
  final DateTime? lastAssignedAt; // When it was last checked out
  final DateTime? lastCheckinAt; // When it was last checked in
  final String? lastCheckinByName; // Who returned it

  final Map<String, dynamic> meta; // Additional metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tool({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.brand,
    required this.model,
    required this.num,
    required this.images,
    required this.qrPayload,
    required this.status,
    this.currentHolder,
    this.lastAssignedToName,
    this.lastAssignedToJobCode,
    this.lastAssignedByName,
    this.lastAssignedAt,
    this.lastCheckinAt,
    this.lastCheckinByName,
    required this.meta,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Tool from Firestore document
  factory Tool.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Tool(
      id: doc.id,
      uniqueId: data['uniqueId'] ?? '',
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      model: data['model'] ?? '',
      num: data['num']?.toString() ?? '',
      images: List<String>.from(data['images'] ?? []),
      qrPayload: data['qrPayload'] ?? '',
      status: data['status'] ?? 'available',
      currentHolder: data['currentHolder'] as DocumentReference?,
      lastAssignedToName: data['lastAssignedToName'] as String?,
      lastAssignedToJobCode: data['lastAssignedToJobCode'] as String?,
      lastAssignedByName: data['lastAssignedByName'] as String?,
      lastAssignedAt: (data['lastAssignedAt'] as Timestamp?)?.toDate(),
      lastCheckinAt: (data['lastCheckinAt'] as Timestamp?)?.toDate(),
      lastCheckinByName: data['lastCheckinByName'] as String?,
      meta: Map<String, dynamic>.from(data['meta'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert Tool to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uniqueId': uniqueId,
      'name': name,
      'brand': brand,
      'model': model,
      'num': num,
      'images': images,
      'qrPayload': qrPayload,
      'status': status,
      'currentHolder': currentHolder,
      'lastAssignedToName': lastAssignedToName,
      'lastAssignedToJobCode': lastAssignedToJobCode,
      'lastAssignedByName': lastAssignedByName,
      'lastAssignedAt': lastAssignedAt != null
          ? Timestamp.fromDate(lastAssignedAt!)
          : null,
      'lastCheckinAt': lastCheckinAt != null
          ? Timestamp.fromDate(lastCheckinAt!)
          : null,
      'lastCheckinByName': lastCheckinByName,
      'meta': meta,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Create a copy with updated values
  Tool copyWith({
    String? uniqueId,
    String? name,
    String? brand,
    String? model,
    String? num,
    List<String>? images,
    String? qrPayload,
    String? status,
    DocumentReference? currentHolder,
    String? lastAssignedToName,
    String? lastAssignedToJobCode,
    String? lastAssignedByName,
    DateTime? lastAssignedAt,
    DateTime? lastCheckinAt,
    String? lastCheckinByName,
    Map<String, dynamic>? meta,
    DateTime? updatedAt,
  }) {
    return Tool(
      id: id,
      uniqueId: uniqueId ?? this.uniqueId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      num: num ?? this.num,
      images: images ?? this.images,
      qrPayload: qrPayload ?? this.qrPayload,
      status: status ?? this.status,
      currentHolder: currentHolder ?? this.currentHolder,
      lastAssignedToName: lastAssignedToName ?? this.lastAssignedToName,
      lastAssignedToJobCode:
          lastAssignedToJobCode ?? this.lastAssignedToJobCode,
      lastAssignedByName: lastAssignedByName ?? this.lastAssignedByName,
      lastAssignedAt: lastAssignedAt ?? this.lastAssignedAt,
      lastCheckinAt: lastCheckinAt ?? this.lastCheckinAt,
      lastCheckinByName: lastCheckinByName ?? this.lastCheckinByName,
      meta: meta ?? this.meta,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Check if tool is available for checkout
  bool get isAvailable => status == 'available';

  /// Check if tool is checked out
  bool get isCheckedOut => status == 'checked_out';

  /// Get display name with brand and model
  String get displayName => '$brand $model $name'.trim();

  /// Generate QR payload for this tool
  static String generateQrPayload(String uniqueId) => 'TOOL#$uniqueId';

  @override
  String toString() =>
      'Tool(id: $id, uniqueId: $uniqueId, name: $displayName, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tool && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
