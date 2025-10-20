import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/tool.dart';
import '../services/tool_service.dart';
import '../firebase_options.dart';

/// Quick test to add a sample tool and verify tools loading
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final toolService = ToolService();

  // Create a test tool
  final testTool = Tool(
    id: '',
    uniqueId: 'T1001',
    name: 'Power Drill',
    brand: 'DeWalt',
    model: 'DCD771C2',
    num: '001',
    images: [],
    qrPayload: 'TOOL#T1001',
    status: 'available',
    currentHolder: null,
    meta: {
      'category': 'power_tool',
      'condition': 'excellent',
      'notes': 'New cordless drill with battery',
    },
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  try {
    print('🔧 Creating test tool...');
    final toolId = await toolService.createTool(testTool);
    print('✅ Test tool created with ID: $toolId');

    // Query tools to verify
    print('📋 Querying all tools...');
    final allTools = await toolService.searchTools('');
    print('📊 Found ${allTools.length} tools in database:');

    for (final tool in allTools) {
      print('  - ${tool.displayName} (${tool.uniqueId}) - ${tool.status}');
    }

    print('🎉 Tool loading test completed successfully!');
  } catch (e) {
    print('❌ Error during test: $e');
  }
}
