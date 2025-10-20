# Versfeld Tool Manager - AI Coding Agent Instructions

## Project Overview

Flutter/Firebase tool management system for workshop QR code-based tool tracking with role-based access control (Admin/Supervisor/Worker). Built with Provider state management, go_router navigation, and custom Mallon design system (white/black/green palette).

## Architecture Patterns

### Provider-Based Data Management

**Critical**: All data flows through cached providers—never query Firestore directly in widgets.

```dart
// ✅ Correct: Use providers
Consumer<ToolsProvider>(
  builder: (context, toolsProvider, child) {
    return ListView(children: toolsProvider.availableTools.map(...));
  },
)

// ❌ Wrong: Direct Firestore queries
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('tools').snapshots(),
  ...
)
```

**Four Core Providers** (see `lib/main.dart`):

1. `AuthProvider` - Authentication + role checking (always initialized first)
2. `ToolsProvider` - Real-time tools cache (all users)
3. `StaffProvider` - Staff data (admin-only, lazy initialized based on role)
4. `TransactionsProvider` - Audit history (admin/supervisor, lazy initialized)

**Provider Initialization Order** (`main.dart`):

- AuthProvider listens to auth state changes
- After auth → `_initializeProviders()` conditionally activates role-gated providers
- Use `isAdmin`/`isSupervisor` getters from AuthProvider to gate features

### Role-Based Access Control

**Three User Roles** (defined in `models/staff.dart`):

- **Admin**: Full system access, manage tools/staff, CRUD operations
- **Supervisor**: Authorize checkouts, view audit logs, batch operations
- **Worker**: Scan tools, view available tools, personal history only

**Check permissions via AuthProvider getters**:

```dart
final authProvider = context.read<AuthProvider>();
if (authProvider.isAdmin) { /* show admin UI */ }
if (authProvider.canAuthorizeCheckouts) { /* show checkout button */ }
```

**Firestore Security**: Role enforcement happens in `firestore.rules` via `getUserRole()` helper. Rules prevent privilege escalation and validate operations server-side.

### Navigation Architecture

**go_router with ShellRoute** (`lib/core/routing/app_router.dart`):

- Login route outside shell (no navigation bar)
- Main shell wraps dashboard/scan/tools/staff/audit/consumables with persistent bottom nav
- Auth redirect in `_handleRedirect()`: unauthenticated → `/login`, authenticated → `/dashboard`
- Router reactivity via `refreshListenable: authProvider`

**Route disabled**: Tool detail routes commented out—screens navigate via `Navigator.push()` with Tool objects, not route params.

### QR Code Scanning

**Platform-specific implementation** (`lib/services/camera_service.dart`, `lib/widgets/tool_scanner.dart`):

- **Mobile**: `mobile_scanner` package with torch/camera switching
- **Web**: HTML5 camera API (requires HTTPS in production)
- **Fallback**: Manual tool ID input always available

**QR Format**: `TOOL#<uniqueId>` (e.g., `TOOL#T1234`) or raw ID lookup in database.

**Batch Mode**: Toggle in `scan_provider.dart` accumulates multiple scans before submission.

## Key Conventions

### Mallon Design System

**Theme**: `lib/core/theme/mallon_theme.dart` defines colors/typography. Do NOT hardcode colors.

```dart
// ✅ Use theme colors
color: Theme.of(context).colorScheme.primary  // Green
color: MallonColors.primaryGreen              // Explicit green

// ❌ Don't hardcode
color: Colors.green  // Wrong!
```

**Status indicators**: Use `MallonWidgets.statusChip(status: 'available')` for consistent tool status display.

### Data Models

**Tool** (`models/tool.dart`):

- `uniqueId`: Physical QR label ID (e.g., "T1234")
- `qrPayload`: Scanned value ("TOOL#T1234")
- `status`: "available" | "checked_out"
- `currentHolder`: DocumentReference to staff member (nullable)

**Staff** (`models/staff.dart`):

- `uid`: Firestore doc ID (matches Firebase Auth UID)
- `role`: Enum (admin/supervisor/worker) with permission methods
- `jobCode`: Human-readable employee ID

**Tool History** (`models/tool_history.dart`):

- `action`: "checkout" | "checkin"
- `by`: DocumentReference to staff who performed action
- `supervisor`: DocumentReference to authorizing supervisor (if required)
- `batchId`: Groups batch operations

### Firebase Patterns

**Document References**: Store relationships as `DocumentReference`, not string IDs. Use `.id` property only for display.

```dart
// ✅ Correct
tool.currentHolder  // DocumentReference?
await tool.currentHolder?.get()  // Fetch related staff doc

// ❌ Wrong
tool.currentHolderId  // Don't store plain string IDs
```

**Timestamps**: Use `Timestamp.fromDate(DateTime.now())` for Firestore, convert back with `.toDate()`.

**Read from cache**: Providers maintain in-memory maps (`_toolsById`, `_staffByUid`) for O(1) lookups—use these instead of repeated Firestore reads.

## Development Workflows

### Running the App

```bash
# Mobile
flutter run                          # Debug mode with hot reload
flutter run --release                # Release mode for camera testing

# Web (camera requires HTTPS in production)
flutter run -d chrome                # Local development
flutter run -d web-server --web-port 8080  # LAN testing

# Deploy web to Firebase Hosting (for camera support)
flutter build web --release
firebase deploy --only hosting
```

### Firebase Operations

```bash
# Update Firestore rules
firebase deploy --only firestore:rules

# Update Firebase Functions (if any)
firebase deploy --only functions

# View logs
firebase functions:log
```

### Database Initialization

**Default Admin**: `lib/services/admin_initialization_service.dart` auto-creates admin on first launch:

- Email: `richardatclm@gmail.com`
- Password: `Admin123!`
- Job Code: `ADMIN001`

**Change this immediately in production!**

## Common Patterns

### Adding a New Screen

1. Create screen in `lib/screens/<name>_screen.dart`
2. Add route to `app_router.dart` ShellRoute
3. Add navigation item to `MainBottomNavigation` (if main tab)
4. Gate access via `authProvider.isAdmin` checks if role-restricted

### Updating Tool Status

```dart
// Always use ToolsProvider, never direct Firestore updates
final toolsProvider = context.read<ToolsProvider>();
await toolsProvider.updateToolStatus(
  tool.id,
  'checked_out',
  currentHolder: staffRef,
);
```

### Creating Transaction History

```dart
// Record every checkout/checkin
await historyService.createToolHistory(
  toolRef: tool.reference,
  action: 'checkout',
  by: authProvider.user!.uid,
  assignedTo: selectedStaff.uid,
  batchId: scanProvider.batchId,  // If batch mode
);
```

### Error Handling in Providers

All providers implement:

- `isLoading`: Show loading indicator
- `hasError`: Display error state
- `errorMessage`: User-friendly error text
- `retry()`: Reload data after error

```dart
if (provider.isLoading) return CircularProgressIndicator();
if (provider.hasError) return ErrorWidget(
  message: provider.errorMessage,
  onRetry: provider.retry,
);
```

## Critical Files

- **Entry Point**: `lib/main.dart` - Provider setup and initialization order
- **Routing**: `lib/core/routing/app_router.dart` - All navigation logic
- **Auth State**: `lib/providers/auth_provider.dart` - User role management
- **Data Models**: `lib/models/{tool,staff,tool_history}.dart`
- **Security**: `firestore.rules` - Server-side permission enforcement
- **Theme**: `lib/core/theme/mallon_theme.dart` - Design system
- **Services**: `lib/services/` - Firestore CRUD operations (provider layer only)

## Testing & Debugging

### Camera Testing

- Web camera requires HTTPS (deploy to Firebase Hosting or use ngrok)
- Mobile camera works in debug mode
- Always implement manual input fallback

### Auth Debugging

- Use `auth_debug_screen.dart` to inspect user roles
- Check Firestore `staff` collection for role assignment
- Verify `isActive: true` in staff document

### Provider Debugging

```dart
// Add listeners to debug state changes
authProvider.addListener(() {
  print('Auth changed: ${authProvider.staffData?.role}');
});
```

## Documentation References

- **Provider System**: `PROVIDER_SYSTEM.md` - Migration guide and patterns
- **Camera Integration**: `CAMERA_INTEGRATION.md` - Platform-specific setup
- **Firestore Setup**: `docs/FIRESTORE_SETUP.md` - Security rules explanation
- **README**: Full feature list and data model schemas

## Do NOT

- Query Firestore directly from widgets (use providers)
- Hardcode colors (use `MallonTheme`/`MallonColors`)
- Skip role checks (always gate admin/supervisor features)
- Store string IDs instead of DocumentReferences
- Deploy web without HTTPS (camera won't work)
- Modify `firestore.rules` without testing in Firebase Console
- Create tool transactions without history entries (audit trail)
