# Batch Operations with Tool Subcollection Tracking

## Overview

Enhanced batch checkout and checkin operations to include **batch tracking** in the tool's history subcollection. Each tool's individual history now contains batch information for grouped operations.

## Problem Solved

Previously:

- Batch operations called individual checkout/checkin methods
- Tool subcollections received individual transactions
- **No way to identify which transactions belonged to the same batch**
- Difficult to trace batch operations in per-tool history

## Solution

### 1. Batch ID Generation

Each batch operation now generates a unique batch identifier:

```dart
final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';
// Example: "BATCH_1729512345678"
```

### 2. Enhanced Transaction Data

Tool subcollection transactions now include batch metadata:

```javascript
{
  "id": "1729512345678",
  "action": "checkout",
  "timestamp": Timestamp,
  "staffName": "John Doe",
  "staffJobCode": "W1234",
  "staffUid": "xyz789",
  "assignedByName": "Admin",
  "notes": "BATCH: Batch checkout (BATCH_1729512345678)",
  "batchId": "BATCH_1729512345678",  // ← Batch identifier
  "isBatch": true                      // ← Batch flag
}
```

### 3. Batch Methods Updated

Both `batchCheckOutTools` and `batchCheckInTools` now:

1. Generate a unique batch ID
2. Prefix notes with "BATCH: "
3. Pass batch ID to individual checkout/checkin calls
4. Log batch progress and results

## Implementation Details

### Checkout with Batch Tracking

```dart
Future<bool> checkOutTool({
  required String toolUniqueId,
  required String staffJobCode,
  String? notes,
  String? adminName,
  String? batchId,  // ← New optional parameter
}) async {
  // ... transaction code ...

  // Build transaction data for subcollection
  final transactionData = {
    'id': '${now.millisecondsSinceEpoch}',
    'action': 'checkout',
    'timestamp': Timestamp.now(),
    'staffName': staff.fullName,
    'staffJobCode': staffJobCode,
    'staffUid': staffUid,
    'assignedByName': adminName ?? 'Unknown',
    'notes': notes,
  };

  // Add batch info if present
  if (batchId != null) {
    transactionData['batchId'] = batchId;
    transactionData['isBatch'] = true;
  }

  transactions.add(transactionData);
  // ... write to subcollection ...
}
```

### Batch Checkout Example

```dart
Future<Map<String, bool>> batchCheckOutTools({
  required List<String> toolUniqueIds,
  required String staffJobCode,
  String? notes,
  String? adminName,
}) async {
  // 1. Generate batch ID
  final batchId = 'BATCH_${DateTime.now().millisecondsSinceEpoch}';
  final batchNotes = notes != null
    ? 'BATCH: $notes'
    : 'Batch checkout ($batchId)';

  debugPrint('🔄 Starting batch checkout: $batchId (${toolUniqueIds.length} tools)');

  // 2. Process each tool with batch ID
  for (final toolUniqueId in toolUniqueIds) {
    final success = await checkOutTool(
      toolUniqueId: toolUniqueId,
      staffJobCode: staffJobCode,
      notes: batchNotes,
      adminName: adminName,
      batchId: batchId,  // ← Pass to individual checkout
    );
    results[toolUniqueId] = success;
  }

  // 3. Log completion
  debugPrint('✅ Batch checkout complete: $batchId');

  return results;
}
```

## Firestore Structure

### Tool Subcollection with Batch Info

```
tools/
  T2973_uid/
    (tool document fields)
    history/
      10-2025/
        monthKey: "10-2025"
        toolId: "T2973_uid"
        toolUniqueId: "T2973"
        transactions: [
          {
            id: "1729512345678",
            action: "checkout",
            timestamp: Timestamp(2025-10-20 14:30:00),
            staffName: "John Doe",
            staffJobCode: "W1234",
            staffUid: "xyz789",
            assignedByName: "Admin Smith",
            notes: "BATCH: Morning tool set",
            batchId: "BATCH_1729512345000",  ← Identifies batch
            isBatch: true
          },
          {
            id: "1729512345679",
            action: "checkout",
            timestamp: Timestamp(2025-10-20 14:30:01),
            // ... other tool in same batch ...
            batchId: "BATCH_1729512345000",  ← Same batch ID
            isBatch: true
          }
        ]
        updatedAt: Timestamp
```

## Reading Batch History

The `_getToolSubcollectionHistory` method now includes batch information:

```dart
// Returns transactions with batch metadata
[
  {
    'id': '1729512345678',
    'action': 'checkout',
    'timestamp': Timestamp,
    'notes': 'BATCH: Morning tool set',
    'staffId': 'xyz789',
    'batchId': 'BATCH_1729512345000',  ← Available for grouping
    'isBatch': true,
    'metadata': {
      'staffName': 'John Doe',
      'staffJobCode': 'W1234',
      'adminName': 'Admin Smith'
    }
  },
  // ... more transactions ...
]
```

## Console Logging

### Batch Checkout Logs

```
🔄 Starting batch checkout: BATCH_1729512345000 (3 tools)
✅ Written to tool subcollection: tools/T2973_uid/history/10-2025 (batch: BATCH_1729512345000)
✅ Written to global history
Tool checked out: T2973 to W1234 (John Doe)
✅ Written to tool subcollection: tools/T2974_uid/history/10-2025 (batch: BATCH_1729512345000)
✅ Written to global history
Tool checked out: T2974 to W1234 (John Doe)
✅ Written to tool subcollection: tools/T2975_uid/history/10-2025 (batch: BATCH_1729512345000)
✅ Written to global history
Tool checked out: T2975 to W1234 (John Doe)
✅ Batch checkout complete: BATCH_1729512345000 (3/3 succeeded)
```

### Batch Checkin Logs

```
🔄 Starting batch checkin: BATCH_1729512356000 (3 tools)
✅ Written to tool subcollection: tools/T2973_uid/history/10-2025 (batch: BATCH_1729512356000)
✅ Written to global history
Tool checked in: T2973
✅ Written to tool subcollection: tools/T2974_uid/history/10-2025 (batch: BATCH_1729512356000)
✅ Written to global history
Tool checked in: T2974
✅ Written to tool subcollection: tools/T2975_uid/history/10-2025 (batch: BATCH_1729512356000)
✅ Written to global history
Tool checked in: T2975
✅ Batch checkin complete: BATCH_1729512356000 (3/3 succeeded)
```

## Benefits

✅ **Batch Traceability**: Each tool's history shows which transactions were part of a batch
✅ **Audit Support**: Can identify all tools in a batch operation from any single tool's history
✅ **Better Notes**: Batch operations have clear "BATCH: " prefix in notes
✅ **Flexible Queries**: Can filter/group by `batchId` field
✅ **Backward Compatible**: Non-batch operations work as before (no batchId field)
✅ **Debug Visibility**: Console logs show batch progress and success/failure rates

## Use Cases

### 1. Worker Taking Multiple Tools

```dart
await batchCheckOutTools(
  toolUniqueIds: ['T2973', 'T2974', 'T2975'],
  staffJobCode: 'W1234',
  notes: 'Morning shift tools',
  adminName: 'Admin Smith',
);
// All three tools have batchId: "BATCH_1729512345000"
```

### 2. End of Day Returns

```dart
await batchCheckInTools(
  toolUniqueIds: ['T2973', 'T2974', 'T2975'],
  notes: 'End of shift return',
  adminName: 'Supervisor Jones',
);
// All three tools have batchId: "BATCH_1729512356000"
```

### 3. Audit Trail Query

```dart
// Find all tools checked out in a specific batch
final batch = 'BATCH_1729512345000';

// Query tool history subcollections filtering by batchId
// Can trace entire batch operation across multiple tools
```

## Testing

1. **Perform batch checkout** (3+ tools)
2. **Check console logs** for batch ID and progress
3. **Open Firestore console** → Navigate to any tool's history subcollection
4. **Verify transaction** has `batchId` and `isBatch: true`
5. **Check notes** have "BATCH: " prefix
6. **Verify all tools** in the batch have the same `batchId`
7. **Perform batch checkin**
8. **Verify checkin transactions** also have batch metadata

## Files Modified

- `lib/services/secure_tool_transaction_service.dart`
  - `checkOutTool()` - Added optional `batchId` parameter
  - `checkInTool()` - Added optional `batchId` parameter
  - `batchCheckOutTools()` - Generates and passes batch ID
  - `batchCheckInTools()` - Generates and passes batch ID
  - `_getToolSubcollectionHistory()` - Includes batch metadata in returned data

---

**Feature:** Batch operation tracking in tool subcollections  
**Status:** ✅ Complete  
**Date:** October 20, 2025  
**Impact:** Every batch operation now fully traceable per tool
