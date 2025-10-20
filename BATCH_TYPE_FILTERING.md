# Batch Type Filtering Implementation

## Overview

Implemented smart batch mode that automatically determines batch type (checkout/checkin) based on the first scanned tool and filters subsequent scans accordingly.

## Changes Made

### 1. ScanProvider Updates (`lib/providers/scan_provider.dart`)

#### New Enum

```dart
enum BatchType { checkout, checkin }
```

#### New State

- `BatchType? _batchType` - Tracks current batch type (null = not set yet)
- Set by first tool scanned in batch mode
- Reset when batch is cleared

#### New Methods

**`setBatchType(BatchType type)`**

- Sets the batch type when first tool is scanned
- Can only be set once per batch
- Logged for debugging

**`canAddToBatch(bool isToolAvailable)`**

- Validates if a tool can be added to current batch
- Rules:
  - If batch type not set → any tool accepted (becomes first tool)
  - If batch is CHECKOUT → only available tools accepted
  - If batch is CHECKIN → only checked out tools accepted
- Returns `true` if tool matches batch type, `false` otherwise

#### New Getters

- `batchType` - Current batch type (null if not set)
- `isBatchTypeSet` - Boolean check if batch type has been determined

### 2. Batch Tool Scan Widget Updates (`lib/widgets/scan/batch_tool_scan_widget.dart`)

#### Tool Validation Logic

Updated `_handleBatchModeResult()` to:

1. Check if tool already in batch (existing logic)
2. **NEW:** Check if tool matches batch type using `canAddToBatch()`
3. Show appropriate error dialog if tool doesn't match
4. Set batch type when first tool is added
5. Add tool to batch if valid

#### Error Dialog for Wrong Type

Shows detailed dialog when scanned tool doesn't match batch type:

- **Title:** "Wrong Tool Type" with warning icon
- **Content:**
  - Explains current batch type
  - Shows tool name and current status
  - Explains why tool was rejected
- **Colors:** Orange warning theme

#### Visual Batch Type Indicator

Updated the instruction area to show:

- **Before first scan:** "Scan multiple tools, then submit batch" (green)
- **After first scan:**
  - "Batch Mode: CHECKOUT" (orange) or "Batch Mode: CHECKIN" (green)
  - "Only available/checked out tools will be added"
  - Icon changes to checkout (↗) or checkin (↙) arrow
  - Text color matches batch type

### 3. Audit Screen Updates (`lib/screens/audit_screen.dart`)

#### Color-Coded Batch Groups

Updated `_BatchGroupItem` to use different colors based on batch type:

**Checkout Batches (Orange/Red theme):**

- Icon background: `MallonColors.checkedOut.withOpacity(0.1)`
- Icon color: `MallonColors.checkedOut`
- Badge background: `MallonColors.checkedOut`
- Expanded list background: `MallonColors.checkedOut.withOpacity(0.1)`
- Expand button color: `MallonColors.checkedOut`

**Checkin Batches (Green theme):**

- Icon background: `MallonColors.available.withOpacity(0.1)`
- Icon color: `MallonColors.available`
- Badge background: `MallonColors.available`
- Expanded list background: `MallonColors.available.withOpacity(0.1)`
- Expand button color: `MallonColors.available`

## User Experience Flow

### Scenario 1: Checkout Batch

1. User scans **available** tool → Batch type set to CHECKOUT
2. UI shows: "Batch Mode: CHECKOUT - Only available tools will be added" (orange)
3. User scans another **available** tool → Added successfully ✅
4. User scans **checked out** tool → Rejected with error dialog ❌
   - Message: "This batch is for checkout (available tools only)"
   - "This tool is already checked out and cannot be checked out again"
5. Audit log shows orange-themed batch group

### Scenario 2: Checkin Batch

1. User scans **checked out** tool → Batch type set to CHECKIN
2. UI shows: "Batch Mode: CHECKIN - Only checked out tools will be added" (green)
3. User scans another **checked out** tool → Added successfully ✅
4. User scans **available** tool → Rejected with error dialog ❌
   - Message: "This batch is for checkin (checked out tools only)"
   - "This tool is available and cannot be checked in"
5. Audit log shows green-themed batch group

## Benefits

### 1. **Prevents User Errors**

- Can't accidentally mix checkout and checkin operations
- Clear visual feedback of batch type
- Immediate validation with helpful error messages

### 2. **Clearer Intent**

- Batch purpose is obvious from first scan
- Color coding makes it easy to identify batch type
- Reduces confusion during busy operations

### 3. **Better Audit Trail**

- Visual distinction in audit log between batch types
- Easy to spot checkout vs checkin batches at a glance
- Maintains consistency with single operation colors

### 4. **Workflow Efficiency**

- Workers don't need to think about batch type
- System automatically enforces correct operations
- Reduced transaction errors and corrections

## Technical Details

### Batch Type Determination

```dart
// Set on first tool addition
if (!scanProvider.isBatchTypeSet) {
  final batchType = tool.isAvailable
      ? BatchType.checkout
      : BatchType.checkin;
  scanProvider.setBatchType(batchType);
}
```

### Validation Logic

```dart
bool canAddToBatch(bool isToolAvailable) {
  if (_batchType == null) return true; // First tool

  if (_batchType == BatchType.checkout && !isToolAvailable) {
    return false; // Checkout batch can't accept checked out tools
  }

  if (_batchType == BatchType.checkin && isToolAvailable) {
    return false; // Checkin batch can't accept available tools
  }

  return true;
}
```

### Batch Type Reset

Batch type is reset to `null` when:

- Batch is cleared (`clearBatch()`)
- Switching from batch to single mode
- After successful batch submission

## Color Scheme

### Checkout Operations (Orange/Red)

- Primary: `MallonColors.checkedOut` (orange/red)
- Background: `MallonColors.checkedOut.withOpacity(0.1)`
- Icon: `Icons.output` (arrow going out)

### Checkin Operations (Green)

- Primary: `MallonColors.available` (green)
- Background: `MallonColors.available.withOpacity(0.1)`
- Icon: `Icons.input` (arrow coming in)

## Testing Scenarios

1. ✅ Start batch with available tool → Should set to CHECKOUT
2. ✅ Start batch with checked out tool → Should set to CHECKIN
3. ✅ Try to add wrong type tool → Should show error dialog
4. ✅ Clear batch → Should reset batch type
5. ✅ Audit log → Should show correct colors for each batch type
6. ✅ Visual indicator → Should show correct mode after first scan
7. ✅ Multiple batches → Each should have independent type tracking

## Future Enhancements

Consider adding:

- Batch type selector before scanning (optional pre-selection)
- Statistics on batch type distribution
- Batch type filter in audit screen
- Batch type indicator in batch list items
- Sound feedback for rejected scans
