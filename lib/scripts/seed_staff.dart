import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';

/// Script to seed the database with sample staff data
Future<void> main() async {
  print('🌱 Seeding staff data...');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;
    final staffCollection = firestore.collection('staff');

    // Sample staff data
    final sampleStaff = [
      {
        'uid': 'staff_001',
        'fullName': 'John Smith',
        'jobCode': 'ADM001',
        'role': 'admin',
        'email': 'john.smith@versfeld.com',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'staff_002',
        'fullName': 'Sarah Johnson',
        'jobCode': 'SUP001',
        'role': 'supervisor',
        'email': 'sarah.johnson@versfeld.com',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'staff_003',
        'fullName': 'Mike Wilson',
        'jobCode': 'WRK001',
        'role': 'worker',
        'email': 'mike.wilson@versfeld.com',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'staff_004',
        'fullName': 'Emma Davis',
        'jobCode': 'WRK002',
        'role': 'worker',
        'email': 'emma.davis@versfeld.com',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      {
        'uid': 'staff_005',
        'fullName': 'Robert Brown',
        'jobCode': 'SUP002',
        'role': 'supervisor',
        'email': 'robert.brown@versfeld.com',
        'isActive': false, // Inactive for testing
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    ];

    // Add staff to Firestore
    for (final staffData in sampleStaff) {
      final uid = staffData['uid'] as String;

      // Check if staff member already exists
      final existingDoc = await staffCollection.doc(uid).get();
      if (!existingDoc.exists) {
        // Remove uid from data before saving (it's used as document ID)
        final dataToSave = Map<String, dynamic>.from(staffData);
        dataToSave.remove('uid');

        await staffCollection.doc(uid).set(dataToSave);
        print('✅ Added staff: ${staffData['fullName']} (${staffData['role']})');
      } else {
        print('⚠️  Staff already exists: ${staffData['fullName']}');
      }
    }

    print('\n🎉 Staff seeding completed successfully!');
    print('📊 Total staff: ${sampleStaff.length}');
    print(
      '👤 Admins: ${sampleStaff.where((s) => s['role'] == 'admin').length}',
    );
    print(
      '👥 Supervisors: ${sampleStaff.where((s) => s['role'] == 'supervisor').length}',
    );
    print(
      '🔧 Workers: ${sampleStaff.where((s) => s['role'] == 'worker').length}',
    );
    print(
      '❌ Inactive: ${sampleStaff.where((s) => s['isActive'] == false).length}',
    );
  } catch (e) {
    print('❌ Error seeding staff data: $e');
  }
}
