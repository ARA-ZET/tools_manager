# versfeld

# Versfeld Tool Manager

A comprehensive Flutter application for managing workshop tools via QR code scanning. Built with Firebase backend, featuring role-based access control and real-time tool tracking.

## 🚀 Features

### Core Functionality

- **QR Code Scanning**: Scan tools for quick checkout/checkin (mobile + web support)
- **Batch Operations**: Scan multiple tools at once for bulk assignments
- **Real-time Tracking**: Live tool availability and location tracking
- **Role-based Access**: Admin, Supervisor, and Worker permission levels
- **Audit Trail**: Complete history of all tool transactions
- **Responsive Design**: Mobile-first design that works beautifully on web

### User Roles & Permissions

#### 🔴 Admin Users

- Full system access and configuration
- Manage tools: create, edit, delete
- Manage staff: add users, assign roles
- View all audit logs and analytics
- Configure system settings

#### 🟡 Supervisor Users

- Authorize tool checkouts and checkins
- View all tools and staff information
- Create batch operations
- Access audit logs and reports
- Cannot modify tool metadata or manage admins

#### 🟢 Worker Users

- Scan and checkout/checkin tools
- View available tools and basic staff info
- Access personal tool history
- Cannot modify tool information or access admin features

## 🛠 Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **State Management**: Provider
- **Routing**: go_router
- **QR Scanning**: mobile_scanner (mobile), manual input (web)
- **Theme**: Custom Mallon design system (white/black/green)

## 📱 Screens & Navigation

### Authentication

- `/login` - Firebase email/password authentication

### Main Application

- `/dashboard` - Overview stats and quick actions
- `/scan` - QR scanner with single/batch modes
- `/tools` - Tool management and search
- `/tool/:id` - Individual tool details and history
- `/staff` - Staff management (admin/supervisor)
- `/audit` - Activity logs and reports (supervisor+)
- `/settings` - User preferences and system config

## 🗃 Data Models

### Tool

```dart
{
  id: String,
  uniqueId: String,        // QR code identifier (e.g., "T1234")
  name: String,
  brand: String,
  model: String,
  num: String,
  images: List<String>,    // Firebase Storage URLs
  qrPayload: String,       // "TOOL#T1234"
  status: String,          // "available" | "checked_out"
  currentHolder: DocumentReference?,
  meta: Map<String, dynamic>,
  createdAt: DateTime,
  updatedAt: DateTime
}
```

### Staff

```dart
{
  uid: String,             // Firebase Auth UID
  fullName: String,
  jobCode: String,
  role: String,            // "admin" | "supervisor" | "worker"
  teamId: String?,
  photoUrl: String?,
  email: String,
  isActive: bool,
  createdAt: DateTime,
  updatedAt: DateTime,
  lastSignIn: DateTime?
}
```

### Tool History

```dart
{
  id: String,
  toolRef: DocumentReference,
  action: String,          // "checkout" | "checkin"
  by: DocumentReference,   // Staff who performed action
  supervisor: DocumentReference?,
  assignedTo: DocumentReference?,
  timestamp: DateTime,
  notes: String?,
  location: String?,       // GPS or text location
  batchId: String?,        // For batch operations
  metadata: Map<String, dynamic>
}
```

## 🔐 Security Rules

Firestore security rules implement role-based access control:

- **Authentication Required**: All operations require valid Firebase Auth
- **Active Users Only**: Users must have `isActive: true` in staff collection
- **Role Validation**: Permissions checked against staff document role field
- **Data Integrity**: Tool status updates limited to specific fields
- **Audit Protection**: History entries cannot be deleted (except by admin)

## 🚦 Getting Started

### Prerequisites

- Flutter SDK (>=3.9.2)
- Firebase project with Authentication, Firestore, and Storage enabled
- IDE with Flutter support (VS Code, Android Studio)

### 🔐 Security Setup (IMPORTANT - Read First!)

**Before cloning or pushing to GitHub**, secure your Firebase configuration:

1. **Review Security Documentation**

   ```bash
   # Read the comprehensive security guide
   cat docs/SECURITY_SETUP.md
   ```

2. **For New Developers Cloning the Repo**

   - Firebase configuration files are NOT included in the repository
   - You need to set up your own Firebase project OR
   - Request configuration files from the project administrator

   **Quick Setup:**

   ```bash
   # Option A: Use FlutterFire CLI (Recommended)
   dart pub global activate flutterfire_cli
   flutterfire configure

   # Option B: Manual Setup
   cp lib/firebase_options.dart.template lib/firebase_options.dart
   cp android/app/google-services.json.template android/app/google-services.json
   cp ios/Runner/GoogleService-Info.plist.template ios/Runner/GoogleService-Info.plist
   # Then fill in your Firebase configuration values
   ```

3. **Before Pushing to GitHub**

   ```bash
   # Run security check script
   ./scripts/security_check.sh

   # This verifies:
   # - Sensitive files are NOT tracked by Git
   # - .gitignore is properly configured
   # - Template files are in place
   ```

📚 **Detailed Guides:**

- [Security Setup Guide](docs/SECURITY_SETUP.md) - Complete security configuration
- [GitHub Setup Guide](docs/GITHUB_SETUP.md) - Push to GitHub safely

### Firebase Setup

1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication with Email/Password provider
3. Create Firestore database in production mode
4. Enable Firebase Storage
5. Configure Firebase for your Flutter app:
   ```bash
   # Using FlutterFire CLI (recommended)
   flutterfire configure
   ```
6. Deploy the included `firestore.rules` to your Firebase project
   ```bash
   firebase deploy --only firestore:rules
   ```

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/versfeld.git
cd versfeld

# Set up Firebase configuration (see Security Setup above)

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Initial Setup

1. Create your first admin user through Firebase Console
2. Add the user to the `staff` collection with role: "admin"
3. Use the admin account to add tools and additional staff members

## 📋 Usage Examples

### QR Code Format

Tools use the format: `TOOL#<uniqueId>`
Example: `TOOL#T1234`

### Single Tool Checkout

1. Navigate to Scanner screen
2. Scan tool QR code or enter ID manually
3. Select "Check Out" and assign to staff member
4. Transaction recorded in tool_history

### Batch Operations

1. Toggle "Batch Mode" in Scanner
2. Scan multiple tool QR codes
3. Select "Submit" and choose assignee
4. All tools checked out simultaneously with shared batch ID

### Tool Management (Admin)

1. Navigate to Tools screen
2. Use search and filters to find tools
3. Tap "+" to add new tools
4. Tap any tool to view details and edit

---

**Made with ❤️ for efficient workshop management**

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
