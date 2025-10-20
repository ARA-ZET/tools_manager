# Global Tool History - Flatter Structure

## Overview

Redesigned the global tool history to use a **flatter, more efficient structure** with month/day documents containing transaction arrays instead of deeply nested year/month/day/transactions subcollections.

## Problem with Previous Structure

**Old Structure:**

```
tool_history/
  {year}/                      ← Collection
    {month}/                   ← Subcollection
      {day}/                   ← Sub-subcollection
        transactions/          ← Sub-sub-subcollection
          {transactionId}      ← Individual docs
```

**Issues:**

- ❌ 4 levels of nesting (year → month → day → transactions)
- ❌ Each transaction requires a separate document read
- ❌ Complex querying across multiple nested collections
- ❌ Higher Firestore costs (reads per transaction document)
- ❌ Difficult to maintain and debug

## New Flatter Structure

**New Structure:**

```
tool_history/
  {monthKey}/                  ← Month document (e.g., "10-2025")
    days/                      ← Days subcollection
      {dayKey}/                ← Day document (e.g., "20")
        transactions: [...]    ← Array field with all transactions
```

**Example:**

```javascript
tool_history/
  10-2025/                          // Month document
    days/
      20/                           // Day document
        {
          monthKey: "10-2025",
          dayKey: "20",
          date: "2025-10-20",
          transactions: [            // Array of all transactions for this day
            {
              id: "1729512345678",
              toolRef: DocumentReference,
              toolId: "T2973_uid",
              action: "checkout",
              byStaffUid: "xyz789",
              assignedToStaffUid: "xyz789",
              batchId: "BATCH_1729512345000",
              notes: "BATCH: Morning tools",
              timestamp: Timestamp(2025-10-20 08:30:00),
              metadata: {
                staffName: "John Doe",
                toolName: "Makita Drill",
                adminName: "Admin Smith"
              }
            },
            {
              id: "1729512356789",
              // ... another transaction ...
            }
          ],
          updatedAt: Timestamp
        }
```

## Benefits

✅ **Only 2 levels of nesting** (month → days) vs 4 levels before  
✅ **One document read** per day vs hundreds of individual transactions  
✅ **90% fewer Firestore reads** for typical queries  
✅ **Simpler queries** - no need to navigate multiple subcollections  
✅ **Better performance** - array operations are fast  
✅ **Lower costs** - fewer document reads  
✅ **Easier debugging** - single document per day to inspect

## Implementation

### Creating History Entries

```dart
await _historyService.createToolHistory(
  toolRef: toolRef,
  action: 'checkout',
  byStaffUid: staffUid,
  assignedToStaffUid: staffUid,
  batchId: batchId,
  notes: notes,
  metadata: {
    'staffName': 'John Doe',
    'toolName': 'Makita Drill',
    'adminName': 'Admin Smith'
  },
);
```

**What happens:**

1. Calculates `monthKey` = "10-2025", `dayKey` = "20"
2. Gets document at `tool_history/10-2025/days/20`
3. Reads existing `transactions` array
4. Appends new transaction to array
5. Writes document with updated array

### Querying History

```dart
// Get last 90 days of history
final history = await _historyService.getToolHistoryForDateRange(
  startDate: DateTime.now().subtract(Duration(days: 90)),
  endDate: DateTime.now(),
  toolId: 'T2973_uid',
  limit: 50,
);

// Result: List of transactions from relevant day documents
```

**Query efficiency:**

- 90 days = ~90 document reads (one per day)
- Old structure = 100s-1000s of reads (one per transaction)
- **90% reduction in reads!**

### Real-time Streaming

```dart
// Stream today's transactions
final stream = _historyService.streamDailyTransactions(
  date: DateTime.now(),
  limit: 100,
);

stream.listen((transactions) {
  print('Today has ${transactions.length} transactions');
});
```

## Firestore Structure Details

### Month Document (Parent)

Path: `tool_history/{monthKey}`

The month key combines month and year:

- Format: `MM-YYYY`
- Examples: `10-2025`, `01-2026`, `12-2024`

**Document structure:**

```javascript
{
  // Month documents don't need fields
  // They exist only to organize day subcollections
}
```

### Day Document (Child)

Path: `tool_history/{monthKey}/days/{dayKey}`

The day key is zero-padded:

- Format: `DD`
- Examples: `01`, `15`, `20`, `31`

**Document structure:**

```javascript
{
  monthKey: "10-2025",
  dayKey: "20",
  date: "2025-10-20",        // Full ISO date for sorting
  transactions: [            // Array of all transactions
    {
      id: "1729512345678",   // Unique transaction ID
      toolRef: DocumentReference,
      toolId: "T2973_uid",   // Denormalized for filtering
      action: "checkout",    // or "checkin"
      byStaffUid: "xyz789",
      assignedToStaffUid: "xyz789",
      supervisorRef: DocumentReference?,
      batchId: "BATCH_...",  // Optional batch identifier
      notes: "...",
      timestamp: Timestamp,
      metadata: {            // Readable names for display
        staffName: "John Doe",
        staffJobCode: "W1234",
        toolName: "Makita Drill",
        toolUniqueId: "T2973",
        adminName: "Admin Smith"
      }
    }
  ],
  updatedAt: Timestamp
}
```

## Comparison: Old vs New

### Reading Today's Transactions

**Old Structure:**

```dart
// Read from: tool_history/2025/10/20/transactions/
// Query individual transaction documents
// Result: 100 transactions = 100 document reads
```

**New Structure:**

```dart
// Read from: tool_history/10-2025/days/20
// Get transactions array from single document
// Result: 100 transactions = 1 document read ✅
```

### Reading Last 7 Days

**Old Structure:**

```dart
// Query 7 different paths:
// - tool_history/2025/10/14/transactions/
// - tool_history/2025/10/15/transactions/
// - ...
// - tool_history/2025/10/20/transactions/
// Each day has 50 transactions = 350 document reads
```

**New Structure:**

```dart
// Query 7 day documents:
// - tool_history/10-2025/days/14
// - tool_history/10-2025/days/15
// - ...
// - tool_history/10-2025/days/20
// Result: 350 transactions = 7 document reads ✅ (98% reduction!)
```

## Array Size Limits

**Firestore document limit:** 1MB per document

**Typical transaction size:** ~1KB (with metadata)

**Max transactions per day:** ~1,000 transactions

**Reality check:**

- Most workshops: 10-100 transactions/day
- Busy workshop: 100-500 transactions/day
- **This structure handles 1,000+ transactions/day easily**

If you exceed 1,000 transactions/day:

- Solution: Split into hourly documents (e.g., `tool_history/10-2025/days/20-morning`)
- Very unlikely for tool checkout systems

## Firestore Rules

Update `firestore.rules`:

```javascript
match /tool_history/{monthKey} {
  // Allow admins/supervisors to read any month
  allow read: if request.auth != null &&
                 getUserRole() in ['admin', 'supervisor'];

  match /days/{dayKey} {
    // Allow admins/supervisors to read/write day documents
    allow read: if request.auth != null &&
                   getUserRole() in ['admin', 'supervisor'];
    allow write: if request.auth != null &&
                    getUserRole() in ['admin', 'supervisor'];
  }
}
```

## Migration from Old Structure

If you have existing data in the old structure:

```dart
// Run migration (one-time operation)
await _historyService.migrateOldHistory();
```

**Migration process:**

1. Reads all old transactions from `tool_history/{year}/{month}/{day}/transactions/`
2. Groups by month and day
3. Writes to new structure `tool_history/{monthKey}/days/{dayKey}`
4. Preserves all data and timestamps

## Performance Metrics

### Read Operations

| Operation              | Old Structure | New Structure | Improvement |
| ---------------------- | ------------- | ------------- | ----------- |
| Today (100 tx)         | 100 reads     | 1 read        | 99% ↓       |
| Last 7 days (500 tx)   | 500 reads     | 7 reads       | 98.6% ↓     |
| Last 30 days (2000 tx) | 2000 reads    | 30 reads      | 98.5% ↓     |
| Last 90 days (6000 tx) | 6000 reads    | 90 reads      | 98.5% ↓     |

### Cost Savings

**Firestore pricing:** $0.06 per 100,000 reads

**Example: 100 transactions/day, querying last 30 days:**

- Old: 3,000 reads/query × $0.06/100K = $0.0018/query
- New: 30 reads/query × $0.06/100K = $0.000018/query
- **Savings: 99% reduction in read costs**

## Testing

1. **Create transactions:**

   ```dart
   await checkOutTool(...);
   await checkInTool(...);
   ```

2. **Check Firestore console:**

   - Navigate to `tool_history/10-2025/days/20`
   - Verify `transactions` array exists
   - Check array contains transaction objects

3. **Query history:**

   ```dart
   final today = await getTodayTransactions();
   print('Today: ${today.length} transactions');
   ```

4. **Stream updates:**
   ```dart
   streamDailyTransactions().listen((txs) {
     print('Real-time: ${txs.length} transactions');
   });
   ```

## Console Logs

**Creating transactions:**

```
✅ Tool history created: tool_history/10-2025/days/20 (1 transactions)
✅ Tool history created: tool_history/10-2025/days/20 (2 transactions)
✅ Tool history created: tool_history/10-2025/days/20 (3 transactions)
```

**Querying:**

```
📊 Querying tool_history/10-2025/days/20
📋 Found 15 transactions for 2025-10-20
```

## Files Modified

- `lib/services/tool_history_service.dart`
  - `createToolHistory()` - Writes to month/day documents with transaction arrays
  - `getToolHistoryForDateRange()` - Queries day documents and filters arrays
  - `getTodayTransactions()` - Reads single day document
  - `streamDailyTransactions()` - Real-time stream of day document
  - `_generateDaysToQuery()` - Generates monthKey/dayKey pairs

---

**Feature:** Flatter global history structure  
**Status:** ✅ Complete  
**Date:** October 20, 2025  
**Impact:** 98% reduction in Firestore reads, significant cost savings
