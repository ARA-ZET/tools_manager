# Authentication History System

## Overview

The Authentication History System tracks all authentication-related events (logins, logouts, account creation, approvals) with timestamps and metadata for audit purposes.

## Architecture

### Data Structure

#### Auth History Entry

Located at: `staff/{uid}/authHistory/{historyId}`

```dart
{
  "uid": "firebase_auth_uid",
  "type": "login" | "logout" | "accountCreated" | "accountApproved" | "accountRejected" | "passwordReset" | "sessionExpired",
  "timestamp": Timestamp,
  "ipAddress": String? (optional),
  "deviceInfo": String? (e.g., "Web Browser", "iOS", "Android"),
  "userAgent": String? (optional),
  "metadata": Map<String, dynamic>? (optional additional context)
}
```

### Event Types

| Event Type        | Description                   | When Recorded                                       |
| ----------------- | ----------------------------- | --------------------------------------------------- |
| `login`           | User successfully signed in   | After authentication completes and staff data loads |
| `logout`          | User signed out               | When user explicitly signs out                      |
| `accountCreated`  | New account registered        | During registration process                         |
| `accountApproved` | Admin approved pending user   | When admin approves a pending user                  |
| `accountRejected` | Admin rejected pending user   | When admin rejects a pending user                   |
| `passwordReset`   | Password reset requested      | When user requests password reset                   |
| `sessionExpired`  | Session expired automatically | When auth session times out                         |

## User/Staff Database Synchronization

### Registration Flow

1. **User Signs Up** (`register_screen.dart`):

   - Creates Firebase Auth account
   - Creates entry in `pending_users` collection
   - Records `accountCreated` event in auth history
   - Signs out immediately

2. **Admin Approves** (`user_approval_service.dart`):

   - Creates staff record with:
     - `uid`: Firebase Auth UID (document ID)
     - `firebaseAuthUid`: Link to Firebase Auth UID
     - `hasAuthAccount`: true
   - Updates `pending_users` status to "approved"
   - Records `accountApproved` event in auth history

3. **User Logs In** (`auth_provider.dart`):
   - Firebase Auth authentication
   - Loads staff data using UID
   - Records `login` event in auth history
   - Updates `lastSignIn` timestamp in staff document

### Login Flow

Every login performs:

1. Firebase Authentication
2. Load staff record by UID
3. **Record login event** in `staff/{uid}/authHistory`
4. **Update `lastSignIn`** field in staff document
5. Set authentication status

### Logout Flow

Every logout performs:

1. **Record logout event** in `staff/{uid}/authHistory`
2. Clear local authentication state
3. Sign out from Firebase Auth

## Implementation

### Core Services

#### `AuthHistoryService`

Location: `lib/services/auth_history_service.dart`

Key methods:

```dart
// Record any auth event
Future<void> recordAuthEvent({
  required String uid,
  required AuthEventType type,
  String? ipAddress,
  String? deviceInfo,
  String? userAgent,
  Map<String, dynamic>? metadata,
})

// Quick methods
Future<void> recordLogin(String uid, {Map<String, dynamic>? metadata})
Future<void> recordLogout(String uid, {Map<String, dynamic>? metadata})

// Query methods
Stream<List<AuthHistoryEntry>> getAuthHistory(String uid, {int? limit})
Future<List<AuthHistoryEntry>> getRecentAuthEvents(String uid)
Future<int> getLoginCount(String uid)
Future<DateTime?> getLastLogin(String uid)

// Maintenance
Future<void> cleanupOldHistory(String uid, {int daysToKeep = 90})
```

#### `UserApprovalService` (Updated)

Location: `lib/services/user_approval_service.dart`

The `approveUser()` method now:

- Links `firebaseAuthUid` to staff record
- Sets `hasAuthAccount = true`
- Records `accountApproved` event

#### `AuthProvider` (Updated)

Location: `lib/providers/auth_provider.dart`

The `_initializeAuth()` method now:

- Records login event after staff data loads
- Records logout event before clearing user data
- Updates are automatic via Firebase auth state listener

## Firestore Security Rules

```javascript
match /staff/{staffId} {
  // Staff document rules...

  // Auth history subcollection
  match /authHistory/{historyId} {
    // System can always create entries (for tracking)
    allow create: if isAuthenticated();

    // Admins can read all auth history
    allow read: if isAdmin();

    // Users can read their own auth history
    allow read: if isOwner(staffId);

    // Supervisors can read for audit purposes
    allow read: if isSupervisor();

    // Nobody can update or delete (immutable audit log)
    allow update, delete: if false;
  }
}
```

## Usage Examples

### Display User's Auth History

```dart
final authHistoryService = AuthHistoryService();

// Get recent events stream
Stream<List<AuthHistoryEntry>> historyStream =
  authHistoryService.getAuthHistory(userId, limit: 20);

// Build UI
StreamBuilder<List<AuthHistoryEntry>>(
  stream: historyStream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();

    final events = snapshot.data!;
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          leading: Icon(_getIconForEventType(event.type)),
          title: Text(event.displayText),
          subtitle: Text(event.timestamp.toString()),
          trailing: event.deviceInfo != null
            ? Chip(label: Text(event.deviceInfo!))
            : null,
        );
      },
    );
  },
)
```

### Get Login Statistics

```dart
final authHistoryService = AuthHistoryService();

// Total login count
int loginCount = await authHistoryService.getLoginCount(userId);

// Last login time
DateTime? lastLogin = await authHistoryService.getLastLogin(userId);

// Recent activity
List<AuthHistoryEntry> recentEvents =
  await authHistoryService.getRecentAuthEvents(userId);
```

### Clean Up Old History

```dart
// Clean up history older than 90 days (default)
await authHistoryService.cleanupOldHistory(userId);

// Custom retention period (keep 30 days)
await authHistoryService.cleanupOldHistory(userId, daysToKeep: 30);
```

## Data Flow Diagram

```
┌─────────────────┐
│  Registration   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│ Firebase Auth   │─────▶│ pending_users    │
│ Account Created │      │ Collection       │
└────────┬────────┘      └──────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│ authHistory/{uid}/              │
│ Event: "accountCreated"         │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ Admin Approves  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────────────┐
│ staff/{uid}     │◀─────│ Links:                   │
│ Document        │      │ - uid = firebaseAuthUid  │
│ Created         │      │ - hasAuthAccount = true  │
└────────┬────────┘      └──────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│ authHistory/{uid}/              │
│ Event: "accountApproved"        │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  User Logs In   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│ authHistory/{uid}/              │
│ Event: "login"                  │
│                                 │
│ staff/{uid}                     │
│ lastSignIn updated              │
└─────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ User Logs Out   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│ authHistory/{uid}/              │
│ Event: "logout"                 │
└─────────────────────────────────┘
```

## Benefits

1. **Complete Audit Trail**: Track all authentication events with timestamps
2. **Security Monitoring**: Detect unusual login patterns or unauthorized access attempts
3. **User Analytics**: Understand user engagement and session patterns
4. **Compliance**: Meet audit requirements for access tracking
5. **Debugging**: Troubleshoot authentication issues with detailed history
6. **User Transparency**: Users can view their own login history

## Best Practices

1. **Automatic Recording**: All auth events are recorded automatically by the system
2. **Immutable Records**: Auth history entries cannot be modified or deleted (except by cleanup)
3. **Privacy Considerations**: IP addresses and user agents are optional to protect privacy
4. **Performance**: Use pagination when displaying history (limit queries)
5. **Storage Management**: Regularly clean up old history (default: 90 days retention)
6. **Error Handling**: Auth history recording failures don't break the auth flow

## Future Enhancements

- [ ] Add IP address tracking (requires backend service)
- [ ] Geolocation tracking for login events
- [ ] Suspicious activity alerts
- [ ] Session duration tracking
- [ ] Multi-device session management
- [ ] Export auth history to CSV/PDF
- [ ] Dashboard with login analytics
- [ ] Email notifications for new logins
