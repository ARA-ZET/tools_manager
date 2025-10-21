# Audit Screen - Inline Detail Expansion

## Overview

Updated the audit screen to display both batch and individual activity details inline using expansion instead of modal dialogs for better UX and consistency.

## Changes Made

### Individual Activity Items (`_ActivityItem`)

**Before:**

- StatelessWidget with no interaction
- All information displayed inline in the card
- Notes truncated if long
- No way to see additional details

**After:**

- StatefulWidget with expand/collapse functionality
- Expand button in trailing position
- When expanded, shows comprehensive transaction details:
  - **Transaction Details Section** (white card with border):
    - Tool name
    - Brand and model (if available)
    - Staff assignment (who performed it)
    - Action type (CHECKOUT/CHECKIN)
    - Timestamp (formatted date and time)
    - Batch ID (if part of batch operation)
    - Notes (full text if available)
- Color-coded by action type
- Notes truncated in collapsed state, full in expanded state

### Batch Group Items (`_BatchGroupItem`)

**Before:**

- Had two buttons in trailing: info button (ⓘ) + expand/collapse button
- Info button opened a modal dialog with batch details
- Expand button only showed the tool list

**After:**

- Single expand/collapse button in trailing
- When expanded, shows comprehensive batch details inline:
  - **Batch Details Section** (white card with border):
    - Batch ID
    - Action (CHECKOUT/CHECKIN)
    - Tools Count
    - Staff assignment (who performed it)
    - Timestamp (formatted date and time)
  - **Tools List Section**:
    - Numbered list (1, 2, 3...) of all tools in the batch
    - Each tool shows:
      - Tool name
      - Brand and model (if available)
      - Action icon (output/input)
    - Individual white cards with borders for better readability

### Individual Activity Items (`_ActivityItem`)

**Before:**

- Had onTap handler that opened a modal dialog with transaction details

**After:**

- Removed onTap handler for consistency
- Individual items now display all information inline in the card:
  - Tool name
  - Staff name
  - Timestamp (relative format)
  - Notes (if any)
  - Batch badge (if part of batch)

### Removed Code

- `_showBatchDetail()` method - No longer needed, details shown inline
- `_showActivityDetail()` method - Removed for consistency
- `_DetailRow` widget - Was only used by dialogs

## Visual Improvements

### Individual Activity Expansion

```
┌─────────────────────────────────────────────┐
│ 🟢 CHECKOUT - Cordless Drill                │
│ by John Smith                               │
│ 2 hours ago                            [v]  │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ ℹ️ Transaction Details                  │ │
│ │                                         │ │
│ │ 🔧 Tool                                 │ │
│ │    Cordless Drill                       │ │
│ │                                         │ │
│ │ 🏷️  Brand & Model                       │ │
│ │    Bosch Professional 18V               │ │
│ │                                         │ │
│ │ 👤 Assigned To                          │ │
│ │    John Smith                           │ │
│ │                                         │ │
│ │ 🔄 Action                               │ │
│ │    CHECKOUT                             │ │
│ │                                         │ │
│ │ 🕒 Timestamp                            │ │
│ │    20/10/2025 at 14:30                  │ │
│ │                                         │ │
│ │ 📝 Notes                                │ │
│ │    Needed for workshop repair           │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Batch Expansion

```
┌─────────────────────────────────────────────┐
│ 🟢 BATCH CHECKOUT - 5 tools                 │
│ by John Smith                               │
│ 2 hours ago                            [v]  │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ ℹ️ Batch Details                        │ │
│ │                                         │ │
│ │ 🏷️  Batch ID                            │ │
│ │    batch_xyz123                         │ │
│ │                                         │ │
│ │ 📦 Action                               │ │
│ │    CHECKOUT                             │ │
│ │                                         │ │
│ │ 🔧 Tools Count                          │ │
│ │    5 tools                              │ │
│ │                                         │ │
│ │ 👤 Assigned To                          │ │
│ │    John Smith                           │ │
│ │                                         │ │
│ │ 🕒 Timestamp                            │ │
│ │    20/10/2025 at 14:30                  │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ 🔧 Tools in This Batch (5)                  │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ [1]  Drill                          →   │ │
│ │      Bosch Professional                 │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ [2]  Hammer                         →   │ │
│ │      Stanley 16oz                       │ │
│ └─────────────────────────────────────────┘ │
│ ...                                         │
└─────────────────────────────────────────────┘
```

## Benefits

1. **Better UX**: No need to open/close dialogs - all info visible with one click
2. **Consistency**: Both individual and batch items now use the same expansion pattern
3. **Cleaner Code**: Removed unused dialog methods and widgets
4. **Better Readability**:
   - Numbered tools in batch (1, 2, 3...)
   - Structured detail rows for individual items
   - Color-coded sections
   - Better spacing and visual hierarchy
5. **Mobile Friendly**: Scrollable inline content instead of nested dialogs
6. **Smart Truncation**: Notes are truncated when collapsed, full text when expanded

## Color Coding

- **Checkout** batches: Orange/amber tones (`MallonColors.checkedOut`)
- **Checkin** batches: Green tones (`MallonColors.available`)
- Icons and borders use the action's color for visual consistency

## Date: October 20, 2025
