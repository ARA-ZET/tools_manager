# Unified Users Collection - Migration Guide

## Overview

The system has been consolidated to use a **single `users` collection** that handles:

- ✅ User registration (pending state)
- ✅ Admin approval workflow
- ✅ Role management (admin, supervisor, worker)
- ✅ User status tracking
- ✅ Authentication history

**Previous:** `users` + `pending_users` (2 collections)  
**Now:** `users` (1 unified collection)

## New Data Structure

### Users Collection Schema

```javascript
users/{uid} {
  // Identity
  uid: "firebase_auth_uid",
  email: "user@example.com",
  displayName: "John Doe",
  firebaseAuthUid: "firebase_auth_uid",  // Links to Firebase Auth

  // Status & Role
  status: "pending" | "approved" | "rejected",
  role: "admin" | "supervisor" | "worker" | null,
  jobCode: "EMP001" | null,
  isActive: true | false,
  hasAuthAccount: true,

  // Timestamps
  createdAt: Timestamp,
  lastSignIn: Timestamp,
  approvedAt: Timestamp | null,
  rejectedAt: Timestamp | null,
  updatedAt: Timestamp,

  // Optional
  rejectionReason: String | null
}
```

## Status Flow

```
Registration → "pending" → Admin Approves → "approved" (isActive: true, role set)
                       ↓
                  Admin Rejects → "rejected" (isActive: false)
```

## Key Changes

### 1. User Registration

**Before:**

- Created in `pending_users` collection
- Separate from user records

**Now:**

- Created in `users` collection with `status: "pending"`
- All fields present but role/jobCode are null
- `isActive: false` until approved

### 2. User Approval

**Before:**

- Updated `pending_users`
- Created separate `staff` record

**Now:**

- Updates `users` collection: status → "approved", sets role/jobCode, isActive → true
- Still creates `staff` record for backward compatibility
- Records approval in auth history

### 3. Role Checking

**Before:**

- Checked `staff` collection for role

**Now:**

- Checks `users` collection first (primary source)
- Falls back to `staff` for backward compatibility
- Firestore rules use `getUserData().role`

### 4. Active User Check

**Before:**

- Checked `staff.isActive`

**Now:**

- Checks `users.status == 'approved' && users.isActive == true`
- Firestore rules validate both conditions

## Migration Impact

### What Changed ✅

| Component        | Before                                    | After                                          |
| ---------------- | ----------------------------------------- | ---------------------------------------------- |
| **Registration** | Creates in `pending_users`                | Creates in `users` with `status: pending`      |
| **Pending List** | Queries `pending_users`                   | Queries `users` where `status == 'pending'`    |
| **Approval**     | Updates `pending_users` + creates `staff` | Updates `users` + creates `staff`              |
| **Role Check**   | Reads from `staff`                        | Reads from `users` (primary)                   |
| **Active Check** | `staff.isActive`                          | `users.status == 'approved' && users.isActive` |
| **Auth History** | Stored in `staff/{uid}/authHistory`       | Still in `staff/{uid}/authHistory`             |

### What Stayed the Same ✅

| Component              | Status                                    |
| ---------------------- | ----------------------------------------- |
| **`staff` Collection** | Still exists for backward compatibility   |
| **Auth History**       | Still stored in `staff/{uid}/authHistory` |
| **Tool Assignment**    | Still uses staff records                  |
| **Firebase Auth**      | No changes                                |
| **Login Flow**         | Works the same                            |

## Code Changes Summary

### UserApprovalService (`lib/services/user_approval_service.dart`)

#### createPendingUser()

```dart
// NOW: Creates in users collection with full structure
await _firestore.collection('users').doc(uid).set({
  'uid': uid,
  'email': email,
  'displayName': displayName,
  'status': 'pending',
  'role': null,
  'jobCode': null,
  'isActive': false,
  // ... other fields
});
```

#### getPendingUsers()

```dart
// NOW: Queries users collection with filter
return _firestore
    .collection('users')
    .where('status', isEqualTo: 'pending')
    .snapshots();
```

#### isUserApproved()

```dart
// NOW: Single check in users collection
final userDoc = await _firestore.collection('users').doc(uid).get();
return data?['status'] == 'approved' && data?['isActive'] == true;
```

#### approveUser()

```dart
// NOW: Updates users collection + creates staff record
await _firestore.collection('users').doc(uid).update({
  'status': 'approved',
  'role': role.value,
  'jobCode': jobCode,
  'isActive': true,
  'approvedAt': FieldValue.serverTimestamp(),
});
// Still creates staff record for compatibility
```

### AuthService (`lib/services/auth_service.dart`)

#### \_createUserDocument()

```dart
// NOW: Creates with full pending structure
final userData = {
  'uid': user.uid,
  'status': 'pending',
  'role': null,
  'isActive': false,
  // ... full structure
};
```

### Firestore Rules (`firestore.rules`)

#### getUserRole()

```dart
function getUserRole() {
  // NOW: Gets role from users collection
  return getUserData().role;
}
```

#### isActiveUser()

```dart
function isActiveUser() {
  // NOW: Checks status and isActive in users collection
  return getUserData().status == 'approved' && getUserData().isActive == true;
}
```

## Firestore Security Rules

### Users Collection Rules

```javascript
match /users/{userId} {
  // Admins can do everything
  allow read, write: if isAdmin();

  // Users can create their own entry during registration
  allow create: if isAuthenticated() &&
                  request.auth.uid == userId &&
                  request.resource.data.status == 'pending';

  // Users can read their own record
  allow read: if isAuthenticated() && request.auth.uid == userId;

  // Users can update lastSignIn
  allow update: if isAuthenticated() &&
                  request.auth.uid == userId &&
                  request.resource.data.diff(resource.data).affectedKeys()
                    .hasOnly(['lastSignIn', 'updatedAt']);
}
```

## Testing the Migration

### 1. Test New User Registration

```dart
1. Sign up new user
2. Check Firestore: users/{uid}
3. Verify:
   - status: "pending"
   - role: null
   - isActive: false
```

### 2. Test User Approval

```dart
1. Admin approves pending user
2. Check Firestore: users/{uid}
3. Verify:
   - status: "approved"
   - role: "worker" (or assigned role)
   - jobCode: "EMP001" (assigned code)
   - isActive: true
   - approvedAt: Timestamp set
4. Check staff/{uid} also created
```

### 3. Test Login

```dart
1. Approved user logs in
2. Check Firestore: users/{uid}
3. Verify:
   - lastSignIn: updated timestamp
```

### 4. Test Rejection

```dart
1. Admin rejects pending user
2. Check Firestore: users/{uid}
3. Verify:
   - status: "rejected"
   - isActive: false
   - rejectedAt: Timestamp set
```

## Benefits of Unified Collection

✅ **Single Source of Truth**: One collection for all user data  
✅ **Simplified Queries**: No need to check multiple collections  
✅ **Better Performance**: Fewer Firestore reads  
✅ **Cleaner Code**: Less complexity in approval logic  
✅ **Atomic Updates**: User status and role updated together  
✅ **Easier Auditing**: All user states in one place  
✅ **Reduced Costs**: Fewer document reads/writes

## Backward Compatibility

### Staff Collection

The `staff` collection is still maintained for:

- Tool assignment tracking
- Auth history subcollection
- Backward compatibility with existing code
- Additional staff-specific features

### Pending Users Collection

The old `pending_users` collection:

- Rules still exist for backward compatibility
- Will be deprecated
- New code should not use it
- Can be safely deleted after confirming migration

## Migration Checklist

- [x] Update UserApprovalService to use users collection
- [x] Update AuthService to create proper user documents
- [x] Update Firestore security rules
- [x] Add getUserData() helper function
- [x] Update role checking logic
- [x] Update active user checking
- [x] Deploy Firestore rules
- [x] Test new user registration
- [x] Test user approval flow
- [x] Test login with approved users
- [ ] Migrate existing pending_users data (if any)
- [ ] Remove old pending_users collection (after migration)
- [ ] Update documentation

## Data Migration Script (Optional)

If you have existing data in `pending_users`, run this migration:

```dart
Future<void> migratePendingUsers() async {
  final firestore = FirebaseFirestore.instance;

  // Get all pending users
  final pendingSnapshot = await firestore
      .collection('pending_users')
      .get();

  for (var doc in pendingSnapshot.docs) {
    final data = doc.data();

    // Create in new users collection
    await firestore.collection('users').doc(doc.id).set({
      'uid': data['uid'],
      'email': data['email'],
      'displayName': data['displayName'],
      'firebaseAuthUid': data['uid'],
      'hasAuthAccount': true,
      'status': data['status'] ?? 'pending',
      'role': data['role'],
      'jobCode': data['jobCode'],
      'isActive': data['status'] == 'approved',
      'createdAt': data['createdAt'],
      'approvedAt': data['approvedAt'],
      'rejectedAt': data['rejectedAt'],
      'lastSignIn': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  print('Migration complete: ${pendingSnapshot.docs.length} users migrated');
}
```

## Next Steps

1. **Test thoroughly** with new user registrations
2. **Monitor Firestore console** for proper data structure
3. **Check auth history** is still recording properly
4. **Verify role-based access** works correctly
5. **Migrate old data** if needed
6. **Remove pending_users** collection after confirming migration

## Status

🎉 **COMPLETE** - Unified users collection deployed and operational!

- ✅ Code updated
- ✅ Firestore rules deployed
- ✅ Security rules validated
- ✅ Backward compatibility maintained
- ✅ Documentation complete

The system now uses a single `users` collection for all user management! 🚀
