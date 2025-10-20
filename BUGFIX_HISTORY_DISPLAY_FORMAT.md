# Bug Fix - History Display Shows "Unknown Staff"

## Issue

**Symptom:** Tool detail screen history tab shows "Unknown Staff" and missing admin names instead of actual staff member names.

**Root Cause:** Data format mismatch between tool subcollection history and the display component.

## Problem

The tool detail screen was updated to read from tool subcollections (`tools/{toolId}/history/{monthKey}`), but the history card widget expected a different data structure.

### Data Structure Mismatch

**Tool Subcollection Format (Flat):**

```javascript
{
  id: "1729512345678",
  action: "checkout",
  timestamp: Timestamp,
  staffName: "John Doe",          // ✅ Direct field
  staffJobCode: "W1234",
  staffUid: "xyz789",
  assignedByName: "Admin Smith",   // ✅ Direct field
  notes: "..."
}
```

**Global History Format (Nested in metadata):**

```javascript
{
  id: "1729512345678",
  action: "checkout",
  timestamp: Timestamp,
  byStaffUid: "xyz789",
  metadata: {                      // ❌ Nested structure
    staffName: "John Doe",
    adminName: "Admin Smith"
  }
}
```

**History Card Expectation (Before Fix):**

```dart
// Only looked for nested format
final staffName = entry['metadata']?['staffName'] ?? 'Unknown Staff';
final adminName = entry['metadata']?['adminName'];
```

**Result:** When reading from tool subcollection (flat format), couldn't find `entry['metadata']['staffName']`, defaulted to "Unknown Staff" ❌

## Solution

Updated `_ReadableHistoryCard` widget to support **both formats** with fallback chain:

### Before (Only Nested):

```dart
final staffName =
    entry['metadata']?['staffName'] ??
    entry['staffId'] ??
    'Unknown Staff';

final adminName = entry['metadata']?['adminName'];
```

**Problem:** Only works with global history format, fails with subcollection format.

### After (Both Formats):

```dart
// Support both formats with priority order:
// 1. Flat (subcollection): entry['staffName']
// 2. Nested (global history): entry['metadata']['staffName']
// 3. Fallback: entry['staffId'] or 'Unknown Staff'

final staffName =
    entry['staffName'] ??                    // ✅ Try flat first
    entry['metadata']?['staffName'] ??       // ✅ Try nested
    entry['staffId'] ??                      // ✅ Try UID fallback
    'Unknown Staff';                         // ✅ Final fallback

final adminName =
    entry['assignedByName'] ??               // ✅ Try flat first
    entry['metadata']?['adminName'] ??       // ✅ Try nested
    entry['metadata']?['admin'];             // ✅ Alt nested field
```

**Result:** Works with both subcollection and global history formats ✅

## Why This Happened

1. **Tool subcollection introduced** - New optimized per-tool history
2. **Different write format** - Subcollection uses flat structure for simplicity
3. **Display not updated** - History card still expected nested metadata format
4. **Result:** "Unknown Staff" displayed even though names were in the data

## Technical Details

### Subcollection Write (Flat Format)

**File:** `lib/services/secure_tool_transaction_service.dart`

```dart
final transactionData = {
  'id': '${now.millisecondsSinceEpoch}',
  'action': 'checkout',
  'timestamp': Timestamp.now(),
  'staffName': staff.fullName,           // Flat
  'staffJobCode': staffJobCode,          // Flat
  'staffUid': staffUid,                  // Flat
  'assignedByName': adminName,           // Flat
  'notes': notes,
};
```

### Global History Write (Nested Format)

**File:** `lib/services/tool_history_service.dart`

```dart
final transactionData = {
  'id': '${now.millisecondsSinceEpoch}',
  'action': 'checkout',
  'timestamp': Timestamp.now(),
  'byStaffUid': staffUid,
  'metadata': {                          // Nested
    'staffName': staff.fullName,
    'adminName': adminName,
  }
};
```

### History Card (Now Supports Both)

**File:** `lib/screens/tool_detail_screen.dart`

```dart
// Checks both formats with fallback chain
final staffName = entry['staffName'] ??           // Subcollection
    entry['metadata']?['staffName'] ??            // Global history
    entry['staffId'] ??                           // UID fallback
    'Unknown Staff';                              // Final default
```

## Impact

### Before Fix:

- ❌ "Unknown Staff" displayed for all subcollection entries
- ❌ Missing admin names
- ❌ Only worked with legacy global history format
- ❌ Poor user experience

### After Fix:

- ✅ Staff names displayed correctly from subcollection
- ✅ Admin names displayed correctly
- ✅ Works with both subcollection and global history
- ✅ Backward compatible with legacy data
- ✅ Proper fallback chain

## Testing

### Test Case 1: New Tool (Subcollection Format)

1. ✅ Check out tool → Creates subcollection entry
2. ✅ Open tool detail → History tab
3. ✅ Verify: "Assigned to: John Doe" (not "Unknown Staff")
4. ✅ Verify: "Processed by: Admin Smith" (not missing)

### Test Case 2: Old Tool (Global History Format)

1. ✅ Tool with legacy global history only
2. ✅ Open tool detail → History tab
3. ✅ Verify: Staff names display correctly
4. ✅ Verify: No regression in legacy data display

### Test Case 3: Mixed Data

1. ✅ Tool with both subcollection and global history
2. ✅ Open tool detail → History tab
3. ✅ Verify: All entries show correct names
4. ✅ Verify: Both formats work seamlessly

## Console Verification

**Before Fix:**

```
📊 Loading history from tool subcollection for tool: 9b7ycgYKqyPTvBFLHxEM
✅ Loaded 2 entries from tool subcollection
[UI displays: "Assigned to: Unknown Staff"]  ❌
```

**After Fix:**

```
📊 Loading history from tool subcollection for tool: 9b7ycgYKqyPTvBFLHxEM
✅ Loaded 2 entries from tool subcollection
[UI displays: "Assigned to: Richard CLM"]  ✅
[UI displays: "Processed by: Richard"]  ✅
```

## Files Modified

**File:** `lib/screens/tool_detail_screen.dart`

- Updated `_ReadableHistoryCard` widget
- Added dual-format support with fallback chain
- Maintains backward compatibility

## Related Issues

This fix also ensures:

- Future format changes are easier to handle
- Multiple data sources can coexist
- Graceful degradation when fields are missing

## Best Practices

### ✅ DO: Support Multiple Formats

```dart
// Check multiple possible field locations
final value = entry['flatField'] ??
    entry['nested']?['field'] ??
    entry['alternateField'] ??
    'Default';
```

### ❌ DON'T: Assume Single Format

```dart
// This breaks if format changes
final value = entry['specificField'];
```

## Why Different Formats?

**Tool Subcollection (Flat):**

- Simpler structure
- Easier to read/write
- Optimized for tool-specific queries
- No unnecessary nesting

**Global History (Nested):**

- Organized metadata
- Consistent with original design
- Backward compatible
- Separates core data from metadata

Both formats are valid - the display layer should handle both gracefully ✅

---

**Bug:** History shows "Unknown Staff"  
**Status:** ✅ Fixed  
**Date:** October 20, 2025  
**Files Modified:** 1  
**Impact:** Medium (display issue, no data loss)  
**Backward Compatible:** Yes  
**Testing:** Verified with both formats
