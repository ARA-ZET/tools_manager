# Tool History Migration Guide

## Overview

The tool history data structure has been migrated from a flat collection to a hierarchical year/month/day structure for better scalability and reduced Firestore read costs.

### Old Structure

```
tool_history_readable/
  └── {transactionId}
```

### New Structure

```
tool_history/
  └── {year}/
      └── {month}/
          └── {day}/
              └── transactions/
                  └── {transactionId}
```

## Benefits

1. **Reduced Read Costs**: Queries only scan relevant month/day documents instead of entire collection
2. **Improved Performance**: Date-based queries are significantly faster
3. **Better Scalability**: Structure scales naturally as history grows
4. **Efficient Archiving**: Easy to archive or delete old data by year/month

## What's Been Updated

### ✅ Completed

1. **ToolHistoryService** (`lib/services/tool_history_service.dart`)

   - `createToolHistory()` - Writes to hierarchical structure
   - `getToolHistoryForDateRange()` - Queries multiple months efficiently
   - `getTodayTransactions()` - Direct path to today's data
   - `getCurrentMonthTransactions()` - Month-level aggregation
   - `streamDailyTransactions()` - Real-time updates for specific date
   - `migrateOldHistory()` - One-time migration from flat to hierarchical

2. **SecureToolTransactionService** (`lib/services/secure_tool_transaction_service.dart`)

   - `checkOutTool()` - Now creates hierarchical history entries
   - `checkInTool()` - Now creates hierarchical history entries
   - `getReadableToolHistory()` - Queries hierarchical structure with 90-day default
   - `getReadableStaffHistory()` - Queries hierarchical structure with 90-day default
   - `getRecentReadableTransactions()` - Uses hierarchical service

3. **TransactionsProvider** (`lib/providers/transactions_provider.dart`)
   - Updated to stream today's transactions in real-time
   - `getToolTransactions()` - Now async, queries hierarchical structure
   - `getStaffTransactions()` - Now async, queries hierarchical structure
   - `getFilteredTransactions()` - Now async, uses hierarchical service
   - `getTransactionStats()` - Now async, uses hierarchical service
   - `getToolStatusFromCache()` - Now async
   - Removed unused `_firestore` and `_transactionService` fields
   - Maintains cache for today's transactions only

### ⚠️ Pending Actions

1. **Run Migration**

   - Call `ToolHistoryService().migrateOldHistory()` to migrate existing data
   - Should be run once before switching to new structure
   - Consider adding a migration button in admin settings

2. **Update Firestore Security Rules** (`firestore.rules`)

   - Add rules for `tool_history/{year}/{month}/{day}/transactions/{transactionId}`
   - Ensure admin-only write access
   - Maintain same permissions as old structure

3. **Update Any Direct Firestore Queries**

   - Search codebase for `tool_history_readable` references
   - Update to use `TransactionsProvider` or `ToolHistoryService`

4. **Test Migration**
   - Test with subset of data first
   - Verify queries return correct results
   - Check real-time streaming still works
   - Validate date range queries

## Migration Process

### Step 1: Deploy New Code

```bash
# Ensure all code changes are deployed
flutter build web --release
firebase deploy --only hosting

# Or for mobile
flutter build apk --release
# Deploy through appropriate channel
```

### Step 2: Run Migration

Option A - Programmatically:

```dart
// In admin settings screen
final historyService = ToolHistoryService();
await historyService.migrateOldHistory(
  batchSize: 500,  // Process in batches
  onProgress: (processed, total) {
    print('Migrated $processed/$total transactions');
  },
);
```

Option B - Firebase Console:

```javascript
// Cloud Function or console script
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

async function migrate() {
  const oldDocs = await db.collection("tool_history_readable").get();

  for (const doc of oldDocs.docs) {
    const data = doc.data();
    const timestamp = data.timestamp.toDate();
    const year = timestamp.getFullYear().toString();
    const month = (timestamp.getMonth() + 1).toString().padStart(2, "0");
    const day = timestamp.getDate().toString().padStart(2, "0");

    await db
      .collection("tool_history")
      .doc(year)
      .collection(month)
      .doc(day)
      .collection("transactions")
      .doc(doc.id)
      .set(data);
  }
}

migrate().then(() => console.log("Migration complete"));
```

### Step 3: Update Security Rules

Add to `firestore.rules`:

```javascript
// Hierarchical tool history - admin only
match /tool_history/{year}/{month}/{day}/transactions/{transactionId} {
  allow read: if isAdmin();
  allow write: if isAdmin();
}

// Helper function (should already exist)
function isAdmin() {
  return get(/databases/$(database)/documents/staff/$(request.auth.uid)).data.role == 'admin';
}
```

Deploy rules:

```bash
firebase deploy --only firestore:rules
```

### Step 4: Verify Migration

1. Check transaction counts match:

```dart
// Old count
final oldSnapshot = await FirebaseFirestore.instance
  .collection('tool_history_readable')
  .count()
  .get();

// New count
final historyService = ToolHistoryService();
final newTransactions = await historyService.getToolHistoryForDateRange(
  startDate: DateTime(2020, 1, 1),
  endDate: DateTime.now(),
);

print('Old: ${oldSnapshot.count}, New: ${newTransactions.length}');
```

2. Spot check specific tools/staff:

```dart
// Test tool history
final toolHistory = await historyService.getToolHistoryForDateRange(
  toolId: 'TOOL_UID_HERE',
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);

// Test staff history
final staffHistory = await historyService.getToolHistoryForDateRange(
  staffUid: 'STAFF_UID_HERE',
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);
```

3. Test real-time streaming:

```dart
final subscription = historyService.streamDailyTransactions(
  date: DateTime.now(),
).listen((transactions) {
  print('Today: ${transactions.length} transactions');
});
```

### Step 5: Cleanup (After Verification)

Only after confirming migration success and testing thoroughly:

```dart
// CAUTION: This deletes old data permanently!
final batch = FirebaseFirestore.instance.batch();
final oldDocs = await FirebaseFirestore.instance
  .collection('tool_history_readable')
  .get();

for (final doc in oldDocs.docs) {
  batch.delete(doc.reference);
}

await batch.commit();
```

## Breaking Changes

### API Changes

Methods that changed from synchronous to asynchronous:

```dart
// OLD
List<Map<String, dynamic>> transactions = provider.getToolTransactions(toolId);

// NEW
List<Map<String, dynamic>> transactions = await provider.getToolTransactions(toolId);
```

```dart
// OLD
Map<String, int> stats = provider.getTransactionStats();

// NEW
Map<String, int> stats = await provider.getTransactionStats();
```

```dart
// OLD
List<Map<String, dynamic>> filtered = provider.getFilteredTransactions(action: 'checkout');

// NEW
List<Map<String, dynamic>> filtered = await provider.getFilteredTransactions(action: 'checkout');
```

### UI Updates Needed

Search for usages of these methods and add `await`:

```bash
# Find all usages
grep -r "getToolTransactions" lib/
grep -r "getStaffTransactions" lib/
grep -r "getFilteredTransactions" lib/
grep -r "getTransactionStats" lib/
grep -r "getToolStatusFromCache" lib/
```

## Query Cost Comparison

### Old Structure

```dart
// Reads ALL documents in collection (~1000 docs)
collection('tool_history_readable')
  .where('toolId', isEqualTo: 'TOOL123')
  .get();
```

### New Structure

```dart
// Only reads documents in relevant months (~30-90 docs)
getToolHistoryForDateRange(
  toolId: 'TOOL123',
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);
```

**Cost Reduction**: ~90% fewer document reads for typical queries

## Monitoring

After migration, monitor:

1. **Firestore Usage**: Check Firebase Console → Firestore → Usage

   - Document reads should decrease significantly
   - Write operations remain the same

2. **Query Performance**: Check average query times

   - Should see faster response for date-range queries
   - Today's transactions (streaming) should be instant

3. **Error Logs**: Monitor for any migration-related errors
   ```bash
   firebase functions:log
   ```

## Rollback Plan

If issues occur, you can temporarily rollback:

1. Keep old `tool_history_readable` collection until fully verified
2. Comment out new hierarchical writes in `SecureToolTransactionService`
3. Revert `TransactionsProvider` to use old collection
4. Keep both structures running in parallel during transition period

## Support

For issues or questions:

- Check Firebase Console for Firestore errors
- Review logs: `firebase functions:log`
- Test queries in Firestore Console Rules Playground
- Contact development team with error details

## Notes

- Migration should be run during low-activity period
- Backup database before migration (Firestore backups in Console)
- Test on development environment first
- Monitor costs for 24-48 hours after migration
- Keep old collection for 1-2 weeks as safety backup
