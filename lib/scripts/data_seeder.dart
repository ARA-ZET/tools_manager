import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Sample data seeding script for development and testing
///
/// Run this script to populate your Firestore database with sample data.
/// Make sure to update Firebase configuration before running.
class DataSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seed all sample data
  Future<void> seedAllData() async {
    print('🌱 Starting data seeding...');

    try {
      await seedStaff();
      await seedTools();
      await seedSampleHistory();

      print('✅ Data seeding completed successfully!');
    } catch (e) {
      print('❌ Error seeding data: $e');
      rethrow;
    }
  }

  /// Create sample staff members
  Future<void> seedStaff() async {
    print('👥 Seeding staff members...');

    final staffMembers = [
      {
        'uid': 'admin-001',
        'fullName': 'John Administrator',
        'jobCode': 'ADM001',
        'role': 'admin',
        'email': 'admin@versfeld.com',
        'isActive': true,
        'teamId': null,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'supervisor-001',
        'fullName': 'Sarah Supervisor',
        'jobCode': 'SUP001',
        'role': 'supervisor',
        'email': 'supervisor@versfeld.com',
        'isActive': true,
        'teamId': 'team-alpha',
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker-001',
        'fullName': 'Mike Worker',
        'jobCode': 'WRK001',
        'role': 'worker',
        'email': 'worker1@versfeld.com',
        'isActive': true,
        'teamId': 'team-alpha',
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker-002',
        'fullName': 'Lisa Technician',
        'jobCode': 'WRK002',
        'role': 'worker',
        'email': 'worker2@versfeld.com',
        'isActive': true,
        'teamId': 'team-beta',
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'worker-003',
        'fullName': 'Bob Mechanic',
        'jobCode': 'WRK003',
        'role': 'worker',
        'email': 'worker3@versfeld.com',
        'isActive': false, // Inactive user for testing
        'teamId': 'team-alpha',
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();

    for (final staff in staffMembers) {
      final docRef = _firestore.collection('staff').doc(staff['uid'] as String);
      batch.set(docRef, staff);
    }

    await batch.commit();
    print('✅ Created ${staffMembers.length} staff members');
  }

  /// Create sample tools
  Future<void> seedTools() async {
    print('🔧 Seeding tools...');

    final tools = [
      {
        'uniqueId': 'T1001',
        'name': 'Cordless Drill',
        'brand': 'DeWalt',
        'model': 'DCD771C2',
        'num': '001',
        'images': <String>[],
        'qrPayload': 'TOOL#T1001',
        'status': 'available',
        'currentHolder': null,
        'meta': {
          'category': 'Power Tools',
          'location': 'Workshop A',
          'purchaseDate': '2024-01-15',
          'warranty': '3 years',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uniqueId': 'T1002',
        'name': 'Circular Saw',
        'brand': 'Makita',
        'model': 'HS7601',
        'num': '002',
        'images': <String>[],
        'qrPayload': 'TOOL#T1002',
        'status': 'checked_out',
        'currentHolder': _firestore.doc('staff/worker-001'),
        'meta': {
          'category': 'Power Tools',
          'location': 'Workshop A',
          'purchaseDate': '2024-02-10',
          'warranty': '2 years',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uniqueId': 'T1003',
        'name': 'Socket Set',
        'brand': 'Craftsman',
        'model': 'CMMT12024',
        'num': '003',
        'images': <String>[],
        'qrPayload': 'TOOL#T1003',
        'status': 'available',
        'currentHolder': null,
        'meta': {
          'category': 'Hand Tools',
          'location': 'Workshop B',
          'purchaseDate': '2023-11-20',
          'warranty': '1 year',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uniqueId': 'T1004',
        'name': 'Welding Machine',
        'brand': 'Lincoln Electric',
        'model': 'K2185-1',
        'num': '004',
        'images': <String>[],
        'qrPayload': 'TOOL#T1004',
        'status': 'checked_out',
        'currentHolder': _firestore.doc('staff/worker-002'),
        'meta': {
          'category': 'Welding Equipment',
          'location': 'Workshop C',
          'purchaseDate': '2024-03-05',
          'warranty': '5 years',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uniqueId': 'T1005',
        'name': 'Digital Multimeter',
        'brand': 'Fluke',
        'model': '87V',
        'num': '005',
        'images': <String>[],
        'qrPayload': 'TOOL#T1005',
        'status': 'available',
        'currentHolder': null,
        'meta': {
          'category': 'Measuring Tools',
          'location': 'Electronics Lab',
          'purchaseDate': '2024-01-30',
          'warranty': '3 years',
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    final batch = _firestore.batch();

    for (final tool in tools) {
      final docRef = _firestore.collection('tools').doc();
      batch.set(docRef, tool);
    }

    await batch.commit();
    print('✅ Created ${tools.length} tools');
  }

  /// Create sample tool history
  Future<void> seedSampleHistory() async {
    print('📝 Seeding tool history...');

    // Get some tools for history
    final toolsSnapshot = await _firestore.collection('tools').limit(3).get();
    if (toolsSnapshot.docs.isEmpty) {
      print('⚠️  No tools found, skipping history seeding');
      return;
    }

    final historyEntries = [
      {
        'toolRef': toolsSnapshot.docs[0].reference,
        'action': 'checkout',
        'by': _firestore.doc('staff/worker-001'),
        'supervisor': _firestore.doc('staff/supervisor-001'),
        'assignedTo': _firestore.doc('staff/worker-001'),
        'timestamp': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 2)),
        ),
        'notes': 'Project maintenance work',
        'location': 'Workshop A',
        'batchId': null,
        'metadata': {
          'deviceInfo': 'Flutter App v1.0.0',
          'ipAddress': '192.168.1.100',
        },
      },
      {
        'toolRef': toolsSnapshot.docs[1].reference,
        'action': 'checkin',
        'by': _firestore.doc('staff/worker-002'),
        'supervisor': null,
        'assignedTo': null,
        'timestamp': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 4)),
        ),
        'notes': 'Task completed successfully',
        'location': 'Workshop B',
        'batchId': null,
        'metadata': {
          'deviceInfo': 'Flutter App v1.0.0',
          'ipAddress': '192.168.1.101',
        },
      },
      {
        'toolRef': toolsSnapshot.docs[2].reference,
        'action': 'checkout',
        'by': _firestore.doc('staff/supervisor-001'),
        'supervisor': _firestore.doc('staff/supervisor-001'),
        'assignedTo': _firestore.doc('staff/worker-002'),
        'timestamp': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        'notes': 'Batch checkout for team project',
        'location': 'Workshop C',
        'batchId': 'batch-001',
        'metadata': {'deviceInfo': 'Flutter App v1.0.0', 'batchSize': 3},
      },
    ];

    final batch = _firestore.batch();

    for (final history in historyEntries) {
      final docRef = _firestore.collection('tool_history').doc();
      batch.set(docRef, history);
    }

    await batch.commit();
    print('✅ Created ${historyEntries.length} history entries');
  }

  /// Create sample batch operation
  Future<void> seedSampleBatch() async {
    print('📦 Seeding sample batch...');

    final batch = {
      'createdBy': 'supervisor-001',
      'createdAt': FieldValue.serverTimestamp(),
      'toolIds': ['T1001', 'T1003', 'T1005'],
      'assignedTo': _firestore.doc('staff/worker-001'),
      'notes': 'Weekly maintenance batch',
      'action': 'checkout',
      'metadata': {
        'project': 'Maintenance Week 42',
        'estimatedDuration': '4 hours',
      },
    };

    await _firestore.collection('batches').doc('batch-001').set(batch);
    print('✅ Created sample batch operation');
  }

  /// Create teams for organizing staff
  Future<void> seedTeams() async {
    print('👥 Seeding teams...');

    final teams = [
      {
        'name': 'Alpha Team',
        'description': 'Main maintenance crew',
        'leader': 'supervisor-001',
        'members': ['worker-001', 'worker-003'],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
      {
        'name': 'Beta Team',
        'description': 'Specialized repair team',
        'leader': 'supervisor-001',
        'members': ['worker-002'],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      },
    ];

    final batch = _firestore.batch();

    teams.asMap().forEach((index, team) {
      final docRef = _firestore
          .collection('teams')
          .doc('team-${index == 0 ? 'alpha' : 'beta'}');
      batch.set(docRef, team);
    });

    await batch.commit();
    print('✅ Created ${teams.length} teams');
  }

  /// Clear all data (use with caution!)
  Future<void> clearAllData() async {
    print('🗑️  Clearing all data...');

    final collections = ['staff', 'tools', 'tool_history', 'batches', 'teams'];

    for (final collectionName in collections) {
      final snapshot = await _firestore.collection(collectionName).get();
      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        print(
          '✅ Cleared ${snapshot.docs.length} documents from $collectionName',
        );
      }
    }

    print('✅ All data cleared');
  }
}

/// Main function to run the seeder
///
/// Usage:
/// ```bash
/// flutter run lib/scripts/data_seeder.dart
/// ```
Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final seeder = DataSeeder();

  // Uncomment the operation you want to perform:

  // Seed all sample data
  await seeder.seedAllData();

  // Or seed individual collections:
  // await seeder.seedStaff();
  // await seeder.seedTools();
  // await seeder.seedSampleHistory();
  // await seeder.seedTeams();

  // Clear all data (WARNING: This will delete everything!)
  // await seeder.clearAllData();

  print('🎉 Seeding script completed!');
}

/*
Sample Data Overview:

STAFF MEMBERS:
- John Administrator (admin) - Full system access
- Sarah Supervisor (supervisor) - Can authorize checkouts
- Mike Worker (worker) - Basic tool access
- Lisa Technician (worker) - Team Beta member
- Bob Mechanic (inactive worker) - For testing inactive users

TOOLS:
- T1001: DeWalt Cordless Drill (available)
- T1002: Makita Circular Saw (checked out to Mike)
- T1003: Craftsman Socket Set (available)
- T1004: Lincoln Welding Machine (checked out to Lisa)
- T1005: Fluke Multimeter (available)

TEAMS:
- Alpha Team: Mike, Bob (inactive)
- Beta Team: Lisa

HISTORY:
- Recent checkout/checkin transactions
- Batch operations
- Various timestamps for testing

To use this seeder:
1. Ensure Firebase is properly configured
2. Run: flutter run lib/scripts/data_seeder.dart
3. Check your Firestore console to verify data creation
4. Use the sample credentials to test the app
*/
