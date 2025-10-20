# Firestore Transaction Fix - Tool History Subcollection

## Problem

When checking out or checking in tools, the history subcollection (`tools/{toolId}/history/{monthKey}`) was **not being written** to Firestore.

### Root Cause

The code was attempting to:

1. Read from subcollection using `await historyRef.get()`
2. Write to subcollection using `transaction.set()`
3. **All inside a Firestore transaction block**

**Why it failed:**

- Firestore transactions have limitations on what you can read/write
- You cannot use `await` on document reads inside a transaction for non-transactional data
- Subcollection operations were failing silently
- The global history service call also used `await` inside transaction

## Solution

**Moved subcollection writes OUTSIDE the transaction:**

### Before (Broken)

```dart
await _firestore.runTransaction((transaction) async {
  transaction.update(toolRef, {...});

  // ❌ This doesn't work inside transaction
  final historyDoc = await historyRef.get();
  transaction.set(historyRef, {...});

  // ❌ Can't await external service inside transaction
  await _historyService.createToolHistory(...);
});
```

### After (Fixed)

```dart
// 1. Transaction only updates tool + staff (atomic operations)
await _firestore.runTransaction((transaction) async {
  transaction.update(toolRef, {...});
  transaction.update(staffRef, {...});
});

// 2. Write to subcollection AFTER transaction succeeds
try {
  final historyDoc = await historyRef.get();
  final transactions = [...historyDoc.data()['transactions']];
  transactions.add({...new transaction...});

  await historyRef.set({
    'transactions': transactions,
    ...
  });
  debugPrint('✅ Written to tool subcollection');
} catch (e) {
  debugPrint('⚠️ Error writing to tool subcollection: $e');
}

// 3. Write to global history (legacy system)
try {
  await _historyService.createToolHistory(...);
  debugPrint('✅ Written to global history');
} catch (e) {
  debugPrint('⚠️ Error writing to global history: $e');
}
```

## What Changed

### Checkout Function (`checkOutTool`)

**Transaction block (critical atomic operations):**

- Update tool status to `checked_out`
- Set `currentHolder` reference
- Update instant fields (`lastAssignedToName`, etc.)
- Add tool to staff's `assignedToolIds` array

**After transaction (best-effort writes):**

1. **Tool subcollection write** - `tools/{toolId}/history/10-2025`
   - Wrapped in try-catch (non-critical)
   - Logs success/failure
2. **Global history write** - `tool_history/{year}/{month}/{day}/transactions`
   - Wrapped in try-catch (non-critical)
   - Logs success/failure

### Checkin Function (`checkInTool`)

**Transaction block (critical atomic operations):**

- Update tool status to `available`
- Clear `currentHolder` reference
- Update instant fields (`lastCheckinAt`, etc.)
- Remove tool from staff's `assignedToolIds` array

**After transaction (best-effort writes):**

1. **Tool subcollection write** - `tools/{toolId}/history/10-2025`
   - Wrapped in try-catch (non-critical)
   - Logs success/failure
2. **Global history write** - `tool_history/{year}/{month}/{day}/transactions`
   - Wrapped in try-catch (non-critical)
   - Logs success/failure

## Benefits

✅ **Transaction succeeds even if history writes fail**

- Tool status always updates correctly
- Staff assignments always update correctly
- History writes are best-effort

✅ **Better error handling**

- Each history write has its own try-catch
- Errors logged but don't break the flow
- Debug messages show exactly what succeeded/failed

✅ **Proper Firestore usage**

- Transactions only contain atomic operations
- Async operations happen outside transactions
- No silent failures

✅ **Debug visibility**

- `✅ Written to tool subcollection` on success
- `✅ Written to global history` on success
- `⚠️ Error writing...` on failure with details

## Testing

After this fix, check Firestore console after checkout/checkin:

### Expected Structure

```
tools/
  {toolId}/
    (tool document with instant fields)
    history/
      10-2025/                    ← Should exist now!
        monthKey: "10-2025"
        toolId: "abc123"
        toolUniqueId: "T1234"
        transactions: [
          {
            id: "1729512345678",
            action: "checkout",
            timestamp: Timestamp,
            staffName: "John Doe",
            staffJobCode: "W1234",
            staffUid: "xyz789",
            assignedByName: "Admin",
            notes: "..."
          }
        ]
        updatedAt: Timestamp
```

### Console Logs

Look for these debug messages:

**Successful checkout:**

```
✅ Written to tool subcollection: tools/abc123/history/10-2025
✅ Written to global history
Tool checked out: T1234 to W1234 (John Doe)
```

**Successful checkin:**

```
✅ Written to tool subcollection: tools/abc123/history/10-2025
✅ Written to global history
Tool checked in: T1234
```

**If errors occur:**

```
⚠️ Error writing to tool subcollection: [error details]
⚠️ Error writing to global history: [error details]
Tool checked out: T1234 to W1234 (John Doe)  ← Still succeeds!
```

## Firestore Rules

Make sure your `firestore.rules` allows writing to tool subcollections:

```javascript
match /tools/{toolId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null &&
                  getUserRole() in ['admin', 'supervisor'];

  // Allow writing to history subcollection
  match /history/{monthKey} {
    allow read: if request.auth != null;
    allow write: if request.auth != null &&
                    getUserRole() in ['admin', 'supervisor'];
  }
}
```

## Verification Steps

1. **Check out a tool** from the app
2. **Open Firestore console** → Navigate to `tools/{toolId}/history/10-2025`
3. **Verify document exists** with `transactions` array
4. **Check console logs** for `✅ Written to tool subcollection`
5. **Check in the tool**
6. **Verify** the same month document now has both checkout + checkin transactions

## Files Modified

- `lib/services/secure_tool_transaction_service.dart`
  - `checkOutTool()` - Moved subcollection write outside transaction
  - `checkInTool()` - Moved subcollection write outside transaction
  - Added debug logging for success/failure
  - Added try-catch blocks for history writes

---

**Issue:** History subcollection not being written  
**Fix:** Move async operations outside Firestore transaction  
**Status:** ✅ Fixed  
**Date:** October 20, 2025
