# User Approval System Documentation

## Overview

The user approval system provides admin-gated access control for new user registrations. This prevents unauthorized users from accessing the system immediately after signup, requiring explicit admin approval before granting system access.

## Architecture

### Three-Stage Approval Workflow

1. **Registration**: User creates Firebase Auth account → Creates pending approval entry → Immediately signed out
2. **Pending State**: User attempts to login → Approval check fails → Access denied
3. **Admin Approval**: Admin assigns job code and role → Creates staff record → User can now login

## Implementation Components

### 1. UserApprovalService (`lib/services/user_approval_service.dart`)

**Purpose**: Manages the complete user approval lifecycle

**Key Methods**:

```dart
// Create pending approval request
Future<void> createPendingUser({
  required String uid,
  required String email,
  String? displayName,
})

// Stream of all pending users
Stream<List<Map<String, dynamic>>> getPendingUsers()

// Check if user is approved (has staff record)
Future<bool> isUserApproved(String uid)

// Approve user and create staff record
Future<void> approveUser({
  required String uid,
  required String email,
  required String displayName,
  required String jobCode,
  required StaffRole role,
})

// Reject pending user
Future<void> rejectUser(String uid, {String? reason})

// Get count of pending approvals (for badges)
Future<int> getPendingUserCount()
```

### 2. Firestore Collection: `pending_users`

**Document Structure**:

```dart
{
  "uid": "firebase_auth_uid",
  "email": "user@example.com",
  "displayName": "User Name",
  "status": "pending" | "approved" | "rejected",
  "createdAt": Timestamp,
  "approvedAt": Timestamp?,  // Set when approved
  "rejectedAt": Timestamp?,  // Set when rejected
  "jobCode": String?,        // Set when approved
  "role": String?,           // Set when approved
  "rejectionReason": String? // Optional rejection reason
}
```

**Firestore Security Rules**:

```javascript
match /pending_users/{userId} {
  // Admins can read all pending users and update their status
  allow read, write: if isAdmin();

  // Users can create their own pending entry during registration
  // Note: This happens BEFORE they have a staff record
  allow create: if isAuthenticated() && request.auth.uid == userId &&
                  request.resource.data.uid == userId &&
                  request.resource.data.status == 'pending';

  // Users can read their own pending status
  allow read: if isAuthenticated() && request.auth.uid == userId;
}
```

### 3. Modified Registration Flow (`lib/screens/register_screen.dart`)

**Before**:

- User registers → Immediately logged in → Full system access

**After**:

```dart
// In _register() method after successful registration:

// Create pending approval entry
await _approvalService.createPendingUser(
  uid: userCredential.user!.uid,
  email: email,
  displayName: displayName,
);

// Immediately sign out the newly registered user
await authProvider.signOut();

// Show pending approval message (orange snackbar)
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Registration successful! Please wait for admin approval before signing in.'),
    backgroundColor: Colors.orange,
  ),
);
```

### 4. Modified Login Flow (`lib/screens/login_screen.dart`)

**Before**:

- User authenticates with Firebase → Full system access

**After**:

```dart
// In _signIn() method after successful authentication:

if (success && user != null) {
  // Check if user is approved (has staff record)
  final isApproved = await _approvalService.isUserApproved(user.uid);

  if (!isApproved) {
    // Sign out immediately if not approved
    await authProvider.signOut();

    // Show pending approval message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your account is pending approval. Please contact an administrator.'),
        backgroundColor: Colors.orange,
      ),
    );
    return; // Prevent navigation to dashboard
  }

  // Continue with normal login flow if approved
  Navigator.pushReplacementNamed(context, '/dashboard');
}
```

### 5. Admin Approval UI (`lib/screens/staff_screen.dart`)

**Tab-Based Interface**:

- **Tab 1: Staff** - Existing staff management functionality
- **Tab 2: Pending Approvals** - New approval management section

**Pending Approvals Tab Features**:

1. **Real-time pending user list** via StreamBuilder
2. **Badge notification** showing pending count on tab label
3. **User cards** with approve/reject actions
4. **Approval dialog** for assigning job code and role

**Approval Dialog**:

```dart
_showApprovalDialog(Map<String, dynamic> pendingUser) {
  // Form with:
  // - User info display (email, name, registration date)
  // - Job code input field (validated 3-10 alphanumeric)
  // - Role dropdown (admin/supervisor/worker)
  // - Approve button → calls approveUser()
}
```

**User Card Widget** (`_PendingUserCard`):

- Shows user avatar with initials
- Displays email and display name
- Shows "Requested X time ago" timestamp
- "PENDING" status badge
- Approve and Reject action buttons

## User Experience Flow

### For New Users

1. **Registration**:

   - Fill out registration form
   - Submit → Account created
   - Orange message: "Please wait for admin approval"
   - Automatically signed out

2. **Login Attempt**:

   - Enter credentials
   - Authenticate successfully with Firebase
   - Approval check fails
   - Automatically signed out
   - Orange message: "Account pending approval"

3. **After Approval**:
   - Login with credentials
   - Approval check passes
   - Redirected to dashboard
   - Full system access granted

### For Admins

1. **Notification**:

   - Staff screen shows "Pending Approvals" tab
   - Badge displays count of pending users
   - Real-time updates when new users register

2. **Review Process**:

   - Navigate to "Pending Approvals" tab
   - View user details (email, name, registration time)
   - Click "Approve" or "Reject"

3. **Approval**:

   - Opens approval dialog
   - Assign job code (e.g., "EMP001")
   - Select role (admin/supervisor/worker)
   - Click "Approve"
   - Staff record created
   - User can now login successfully

4. **Rejection**:
   - Click "Reject" on user card
   - Confirmation dialog appears
   - Confirm rejection
   - User marked as rejected
   - User remains unable to login

## Security Considerations

### Firebase Auth vs. Staff Records

**Important**: Firebase Authentication and staff records are **separate systems**.

- **Firebase Auth**: Handles authentication (login credentials)
- **Staff Collection**: Handles authorization (roles and permissions)

**Approval Gate**: The `isUserApproved()` check creates a mandatory gate between authentication and system access.

### Protection Against Bypass Attempts

1. **Direct Firestore Access**: Blocked by security rules (users can't create their own staff records)
2. **Navigation Tampering**: AuthProvider checks staff record existence before allowing navigation
3. **Token Manipulation**: Server-side Firestore rules validate role claims
4. **Deleted Staff Records**: If staff record is deleted, user loses access on next login

### Data Integrity

- **Job Code Uniqueness**: Validated during approval (prevents duplicates)
- **Email Uniqueness**: Enforced by Firebase Auth
- **Immutable Audit Trail**: Pending user status changes are timestamped and preserved

## Testing Checklist

### Registration Flow

- [ ] User can register with valid credentials
- [ ] User receives orange "pending approval" message
- [ ] User is signed out immediately after registration
- [ ] Pending user entry created in Firestore with status "pending"

### Login Flow (Before Approval)

- [ ] Unapproved user can authenticate with Firebase
- [ ] Approval check fails for unapproved user
- [ ] User is signed out automatically
- [ ] User receives orange "pending approval" message
- [ ] User cannot access dashboard or other screens

### Admin Approval UI

- [ ] Pending Approvals tab appears for admin users
- [ ] Badge shows correct pending count
- [ ] Pending users list updates in real-time
- [ ] User cards display correct information
- [ ] Approval dialog opens when clicking "Approve"
- [ ] Job code validation works (3-10 alphanumeric)
- [ ] Role dropdown shows all options (admin/supervisor/worker)

### Approval Process

- [ ] Approve action creates staff record with correct data
- [ ] Pending user status updated to "approved"
- [ ] ApprovedAt timestamp set correctly
- [ ] Job code and role stored in both collections
- [ ] Success message displayed to admin
- [ ] Pending count decreases by 1

### Rejection Process

- [ ] Reject confirmation dialog appears
- [ ] Reject action updates pending user status to "rejected"
- [ ] RejectedAt timestamp set correctly
- [ ] Rejection reason stored (if provided)
- [ ] User still cannot login after rejection
- [ ] Pending count decreases by 1

### Login Flow (After Approval)

- [ ] Approved user can authenticate with Firebase
- [ ] Approval check passes
- [ ] User redirected to dashboard
- [ ] User has access to role-appropriate features
- [ ] AuthProvider correctly identifies user role

### Security Rules

- [ ] Unapproved users cannot read staff collection
- [ ] Users cannot create their own staff records
- [ ] Only admins can read pending_users collection
- [ ] Users can only read their own pending status
- [ ] Approval/rejection requires admin privileges

## Troubleshooting

### "Account pending approval" message persists after approval

**Cause**: Staff record not created or UID mismatch

**Solution**:

1. Check Firestore `staff` collection for user's UID
2. Verify UID matches Firebase Auth UID
3. Check staff record has `isActive: true`

### Pending users not appearing in admin UI

**Cause**: Security rules blocking access or Firestore indexing delay

**Solution**:

1. Verify user is authenticated as admin
2. Check browser console for Firestore permission errors
3. Ensure Firestore rules deployed correctly
4. Check network tab for failed API calls

### User can't login after approval

**Cause**: Staff record missing required fields

**Solution**:

1. Check staff document has all required fields:
   - uid, email, fullName, jobCode, role, isActive
2. Verify role is one of: "admin", "supervisor", "worker"
3. Ensure isActive is set to true

### Duplicate job codes during approval

**Cause**: Concurrent approvals or validation bypass

**Solution**:

1. StaffService.createStaff() should validate job code uniqueness
2. Add Firestore index on jobCode field
3. Handle errors gracefully in approval dialog

## Future Enhancements

### Potential Improvements

1. **Email Notifications**:

   - Notify admins when new users register
   - Notify users when approved/rejected
   - Send welcome email with setup instructions

2. **Bulk Approval**:

   - Select multiple pending users
   - Batch assign default role (e.g., all workers)
   - CSV import for pre-approved users

3. **Approval Workflow**:

   - Multi-tier approval (supervisor → admin)
   - Automatic approval based on email domain
   - Integration with HR systems

4. **User Self-Service**:

   - Request role change
   - Update profile pending admin approval
   - Password reset without admin intervention

5. **Analytics Dashboard**:

   - Average approval time
   - Rejection rates and reasons
   - Registration trends over time

6. **Rejected User Management**:
   - Delete Firebase Auth account on rejection
   - Temporary ban with expiration
   - Allow re-application after rejection

## Related Documentation

- **Provider System**: `PROVIDER_SYSTEM.md` - State management patterns
- **Firestore Setup**: `docs/FIRESTORE_SETUP.md` - Security rules explanation
- **Authentication**: `lib/providers/auth_provider.dart` - Auth state management
- **Staff Management**: `lib/services/staff_service.dart` - Staff CRUD operations

## Summary

The user approval system successfully prevents unauthorized access by:

1. ✅ Creating a mandatory approval gate between authentication and system access
2. ✅ Providing admins with tools to review and approve/reject registrations
3. ✅ Enforcing role-based access control with job code assignment
4. ✅ Maintaining an audit trail of all approval decisions
5. ✅ Protecting against common bypass attempts via Firestore security rules

This system ensures that only vetted users with assigned roles can access the workshop tool management system, providing essential security for production environments.
