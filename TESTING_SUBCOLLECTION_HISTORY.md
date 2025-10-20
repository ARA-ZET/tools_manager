# Testing Guide - Tool Subcollection History

## Overview

This guide walks through testing the new tool subcollection history feature to ensure it works correctly and displays data properly.

## Pre-Test Setup

### 1. Clean Build (Optional but Recommended)

```bash
flutter clean
flutter pub get
```

### 2. Run the App

```bash
# For web (camera requires HTTPS in production)
flutter run -d chrome

# For mobile
flutter run

# For specific device
flutter devices
flutter run -d <device-id>
```

### 3. Login as Admin

Use the default admin credentials:

- Email: `richardatclm@gmail.com`
- Password: `Admin123!`

---

## Test Plan

### Test 1: New Tool Checkout (Subcollection Write)

**Objective:** Verify that checking out a tool creates entries in the tool subcollection.

**Steps:**

1. **Navigate to Tools screen**

   - Tap "Tools" in bottom navigation

2. **Select an available tool**

   - Tap on any tool with "Available" status
   - Note the tool ID (e.g., T2973)

3. **Go to Scan screen**

   - Tap "Scan" in bottom navigation
   - Tap "Manual Entry" or scan the tool's QR code
   - Enter tool ID if using manual entry

4. **Check out the tool**

   - Select a staff member from the list
   - Tap "Check Out"
   - Wait for success message

5. **Verify console logs**

Expected output:

```
✅ Tool subcollection history created: tools/{toolId}/history/10-2025 (1 transactions)
✅ Tool history created: tool_history/10-2025/days/20 (1 transactions)
```

6. **Check Firestore Console**
   - Open Firebase Console → Firestore
   - Navigate to: `tools/{toolId}/history/10-2025`
   - Verify document exists with:
     - `monthKey: "10-2025"`
     - `transactions: [...]` array with 1 entry
   - Verify transaction contains:
     - `id`
     - `action: "checkout"`
     - `byStaffUid`
     - `assignedToStaffUid`
     - `timestamp`
     - `metadata` with names

**✅ Pass Criteria:**

- Console logs show subcollection write
- Firestore document exists
- Transactions array contains checkout entry
- Metadata includes readable names

---

### Test 2: Tool Detail - History Tab (Subcollection Read)

**Objective:** Verify that the tool detail screen reads from the subcollection.

**Steps:**

1. **Open tool detail screen**

   - From Tools list, tap on the tool you just checked out

2. **View Details tab**

   - Verify instant fields are displayed:
     - "Assigned To: [Staff Name]"
     - "Job Code: [Job Code]"
     - "Assigned By: [Admin Name]"
     - "Checked Out: [Timestamp]"

3. **Switch to History tab**

   - Tap "History" tab

4. **Verify console logs**

Expected output:

```
📊 Loading history from tool subcollection for tool: {toolId}
📊 Querying tool {toolId} history for 3 months
  ✅ Found 1 transactions for 10-2025
  ⚠️ No history for month 09-2025
  ⚠️ No history for month 08-2025
✅ Loaded 1 transactions for tool {toolId}
```

5. **Verify UI shows history**
   - Should see checkout entry card with:
     - "Check Out" title
     - Timestamp
     - "Assigned to: [Staff Name]"
     - "Processed by: [Admin Name]"

**✅ Pass Criteria:**

- Console shows querying 3 months (current + 2 previous)
- History card displays with readable names
- No error messages
- Loading completes in < 1 second

---

### Test 3: Check In Tool (Second Subcollection Entry)

**Objective:** Verify check-in creates second entry in subcollection array.

**Steps:**

1. **Go to Scan screen**

   - Scan or manually enter the same tool

2. **Check in the tool**

   - Select "Check In" (or scan while tool is checked out)
   - Tap "Check In" button
   - Wait for success message

3. **Verify console logs**

Expected output:

```
✅ Tool subcollection history created: tools/{toolId}/history/10-2025 (2 transactions)
✅ Tool history created: tool_history/10-2025/days/20 (2 transactions)
```

4. **Check Firestore Console**

   - Navigate to: `tools/{toolId}/history/10-2025`
   - Verify `transactions` array now has 2 entries:
     - First: `action: "checkout"`
     - Second: `action: "checkin"`

5. **Return to tool detail screen**
   - History tab should now show 2 entries
   - Most recent (checkin) should be at top

**✅ Pass Criteria:**

- Console shows 2 transactions in subcollection
- Firestore shows 2 entries in array
- History tab displays both entries
- Checkin appears above checkout (newest first)

---

### Test 4: Batch Operations (Batch ID Tracking)

**Objective:** Verify batch operations include batchId in subcollection.

**Steps:**

1. **Enable batch mode**

   - In Scan screen, tap batch mode toggle

2. **Scan multiple tools**

   - Scan 3-5 different tools
   - They should accumulate in the batch list

3. **Batch checkout**

   - Select a staff member
   - Tap "Batch Check Out"
   - Wait for success

4. **Verify console logs**

Expected output for each tool:

```
✅ Tool subcollection history created: tools/{toolId}/history/10-2025 (X transactions)
🏷️ Batch ID: BATCH_1729512345000
```

5. **Check Firestore Console**

   - Open any of the batched tools: `tools/{toolId}/history/10-2025`
   - Verify latest transaction has:
     - `batchId: "BATCH_..."`
     - Same batchId across all tools in the batch

6. **Check tool detail screens**
   - Open each batched tool
   - Go to History tab
   - Verify batch entry shows: "Batch: BATCH\_..."

**✅ Pass Criteria:**

- All batched tools have same batchId
- Console logs show batch ID
- Firestore documents contain batchId field
- History UI displays batch information

---

### Test 5: Legacy Tool Fallback

**Objective:** Verify fallback works for tools without subcollection history.

**Steps:**

1. **Find or create an old tool**

   - Look for a tool that existed before subcollections
   - Or temporarily rename a tool's history subcollection in Firestore

2. **Open tool detail screen**

   - Navigate to the old tool

3. **Switch to History tab**

4. **Verify console logs**

Expected output:

```
📊 Loading history from tool subcollection for tool: {toolId}
⚠️ No subcollection history, trying legacy...
✅ Loaded X entries from legacy system
```

5. **Verify UI**
   - History should still display (from legacy source)
   - Or show empty state if truly no history

**✅ Pass Criteria:**

- No errors or crashes
- Graceful fallback to legacy system
- UI shows available data or empty state
- Clear console logs explaining fallback

---

### Test 6: Real-Time Updates (Streaming)

**Objective:** Verify history updates in real-time (future enhancement).

**Note:** Current implementation uses FutureBuilder, not streams. This test is for future reference.

**Steps:**

1. **Open tool detail on one device/tab**

   - View History tab

2. **Check out tool from another device/tab**

   - Use different device or browser tab

3. **Refresh history**
   - Tap refresh button on first device
   - Should show new entry

**✅ Pass Criteria:**

- Manual refresh shows new entries
- No errors when refreshing
- (Future: automatic updates without refresh)

---

### Test 7: Performance Testing

**Objective:** Measure history loading performance.

**Steps:**

1. **Create tool with many transactions**

   - Check out and check in same tool 10-20 times
   - This creates ~20-40 entries in subcollection

2. **Open tool detail screen**

   - Note loading time for Details tab (should be instant)

3. **Switch to History tab**

   - Note loading time
   - Should be < 500ms

4. **Compare with old tools**
   - Open old tool (legacy system)
   - Note loading time
   - Likely 2-5 seconds

**✅ Pass Criteria:**

- Details tab: < 100ms (instant)
- History tab (subcollection): < 500ms
- History tab (legacy): 2-5 seconds
- Subcollection is clearly faster

---

### Test 8: Error Handling

**Objective:** Verify graceful error handling.

**Steps:**

1. **Disconnect from internet**

   - Turn off WiFi/data

2. **Open tool detail screen**

   - Details tab should show cached data
   - History tab should show error or cached data

3. **Reconnect**

   - History should load successfully

4. **Test with invalid tool ID**
   - Manually create tool with bad ID
   - Open detail screen
   - Should show empty history, not crash

**✅ Pass Criteria:**

- No crashes
- User-friendly error messages
- Retry functionality works
- Graceful degradation when offline

---

## Firestore Console Verification

### Check Tool Subcollection Structure

**Navigate to:**

```
tools/{toolId}/history/10-2025
```

**Expected Structure:**

```javascript
{
  monthKey: "10-2025",
  transactions: [
    {
      id: "1729512345678",
      action: "checkout",
      byStaffUid: "xyz789",
      assignedToStaffUid: "xyz789",
      batchId: "BATCH_1729512345000",
      timestamp: Timestamp(2025-10-20 08:30:00),
      metadata: {
        staffName: "John Doe",
        toolName: "Makita Drill",
        adminName: "Admin Smith"
      }
    }
  ],
  updatedAt: Timestamp
}
```

### Check Global History Structure

**Navigate to:**

```
tool_history/10-2025/days/20
```

**Expected Structure:**

```javascript
{
  monthKey: "10-2025",
  dayKey: "20",
  date: "2025-10-20",
  transactions: [
    {
      id: "1729512345678",
      toolRef: DocumentReference(tools/T2973_uid),
      toolId: "T2973_uid",
      action: "checkout",
      // ... same fields as tool subcollection
    }
  ],
  updatedAt: Timestamp
}
```

---

## Common Issues & Solutions

### Issue: "No history found"

**Possible Causes:**

- Tool was never checked out
- Subcollection writes failed
- Wrong tool ID being queried

**Solution:**

- Check out the tool first
- Verify Firestore rules allow reads
- Check console for write errors

---

### Issue: "Loading forever"

**Possible Causes:**

- Network issues
- Firestore offline
- Query permissions

**Solution:**

- Check internet connection
- Verify Firestore rules
- Check Firebase project status

---

### Issue: "Showing old data"

**Possible Causes:**

- Cache not cleared
- Multiple tabs/devices
- Firestore offline persistence

**Solution:**

- Tap refresh button
- Clear app data
- Hot restart app

---

### Issue: "Console shows errors"

**Possible Causes:**

- Firestore rules blocking access
- Network errors
- Invalid data format

**Solution:**

- Check Firestore rules
- Verify Firebase configuration
- Check data structure in Firestore

---

## Performance Benchmarks

### Expected Performance

**Tool Detail - Details Tab:**

- Load time: < 100ms
- Firestore reads: 0 (uses instant fields)
- User experience: Instant

**Tool Detail - History Tab (Subcollection):**

- Load time: 200-500ms
- Firestore reads: 3 (3 months)
- User experience: Fast

**Tool Detail - History Tab (Legacy):**

- Load time: 2-5 seconds
- Firestore reads: 100-1000+
- User experience: Slow but functional

**Audit Screen:**

- Load time: 500-1000ms
- Firestore reads: 30 (30 days)
- User experience: Good

---

## Sign-Off Checklist

### Functionality

- [ ] Checkout creates subcollection entry
- [ ] Checkin creates subcollection entry
- [ ] Tool detail screen loads history
- [ ] History displays readable names
- [ ] Batch operations include batchId
- [ ] Legacy fallback works

### Performance

- [ ] Details tab loads instantly (< 100ms)
- [ ] History tab loads quickly (< 500ms)
- [ ] Subcollection faster than legacy
- [ ] No performance degradation

### Data Integrity

- [ ] Firestore structure matches spec
- [ ] Transaction arrays contain correct data
- [ ] Metadata includes names
- [ ] Timestamps are accurate
- [ ] Batch IDs match across tools

### Error Handling

- [ ] No crashes on errors
- [ ] Graceful fallback to legacy
- [ ] User-friendly error messages
- [ ] Retry functionality works
- [ ] Offline handling works

### Console Logs

- [ ] Write operations logged
- [ ] Read operations logged
- [ ] Errors logged clearly
- [ ] Performance metrics visible

---

## Next Steps After Testing

1. **If all tests pass:**

   - Mark feature as production-ready
   - Update user documentation
   - Train staff on new features
   - Monitor Firestore usage

2. **If tests fail:**

   - Document issues
   - Check console logs
   - Verify Firestore structure
   - Review code changes
   - Retry after fixes

3. **Performance tuning:**
   - Monitor Firestore reads
   - Adjust query limits if needed
   - Consider caching strategies
   - Optimize if issues found

---

**Testing Status:** Ready  
**Last Updated:** October 20, 2025  
**Critical Tests:** 8  
**Expected Duration:** 30-45 minutes
