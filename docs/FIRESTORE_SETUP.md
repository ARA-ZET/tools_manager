# Firestore Setup for Tool History

This document explains how to set up Firestore indexes for optimal tool history performance.

## Current Implementation

The app is designed to work without requiring complex Firestore indexes. The tool history feature uses a simplified query approach that:

1. **Fetches all history entries** (with a reasonable limit)
2. **Filters in memory** to show only the specific tool's history
3. **Sorts in memory** by timestamp

This approach works well for small to medium databases and doesn't require any Firestore index configuration.

## For Better Performance (Optional)

If you have a large number of history entries and want real-time updates, you can create a Firestore composite index:

### Create the Index

1. Go to the [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Indexes**
4. Click **Create Index**
5. Configure the index:
   - **Collection ID**: `tool_history`
   - **Fields**:
     - `toolRef` (Ascending)
     - `timestamp` (Descending)
   - **Status**: Enabled

### Index Configuration Details

```
Collection: tool_history
Fields:
  - toolRef: Ascending
  - timestamp: Descending
```

### Alternative: Use Firebase CLI

You can also create the index using the Firebase CLI:

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firestore in your project (if not done)
firebase init firestore

# Deploy the index (add to firestore.indexes.json)
firebase deploy --only firestore:indexes
```

Add this to your `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "tool_history",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "toolRef",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

## Switching to Real-time Updates

Once the index is created, you can modify the `HistoryService` to use the more efficient real-time query:

1. In `lib/services/history_service.dart`, replace the `getToolHistorySimple` method usage
2. Switch back to using `getToolHistoryStream` with the original StreamBuilder
3. This will provide real-time updates when history entries are added/modified

## Current Error Handling

The app gracefully handles Firestore index errors by:

- Detecting index-related error messages
- Showing user-friendly error messages
- Providing retry functionality
- Explaining that database setup is needed

Users can continue using the app even without the index, as the fallback method works perfectly for most use cases.

## Performance Considerations

- **Without Index**: Works for up to ~1000-5000 history entries
- **With Index**: Scales to millions of entries with real-time updates
- **Memory Usage**: In-memory filtering uses minimal memory for typical tool counts
- **Network**: Fetches limited data (1000 entries max) to avoid excessive bandwidth

The current implementation prioritizes ease of setup over performance, making it perfect for small to medium workshops while still being scalable for larger operations.
