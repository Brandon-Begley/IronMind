# Supabase Setup Complete! 🚀

Your Flutter IronMind app is now configured with Supabase!

## Quick Start

### 1. **Initialize in Your App**
✅ Already done! Added to `lib/main.dart`

## Create Tables in Supabase Dashboard
Go to: https://supabase.com/dashboard/project/ksbosztywxazcbvmfwpo

✅ **Already created:**
- `users`
- `workouts`
- `nutrition`
- `wellness`

## Enable Row Level Security (RLS)
For each table:
1. Click the table name → Settings
2. Enable "RLS"
3. Add Policy:
   - Type: SELECT, INSERT, UPDATE, DELETE
   - Target role: authenticated
   - Check: `(auth.uid() = user_id)`

### 5. **Use in Your Code**
Import and use:
```dart
import 'services/supabase_service.dart';

// Sign up
await SupabaseService().signUp('user@example.com', 'password');

// Sign in
await SupabaseService().signIn('user@example.com', 'password');

// Get current user
final user = SupabaseService().getCurrentUser();

// Insert a workout
await SupabaseService().insertIntoTable('workouts', {
  'user_id': user.id,
  'exercise_name': 'Bench Press',
  'weight': 185.5,
  'sets': 4,
  'reps': 8,
  'date': DateTime.now().toIso8601String(),
});

// Insert nutrition data
await SupabaseService().insertIntoTable('nutrition', {
  'user_id': user.id,
  'meal_type': 'breakfast',
  'calories': 450,
  'protein': 30,
  'carbs': 45,
  'fats': 15,
  'date': DateTime.now().toIso8601String(),
});

// Insert wellness data
await SupabaseService().insertIntoTable('wellness', {
  'user_id': user.id,
  'sleep': 8,
  'stress': 4,
  'energy': 8,
  'mood': 7,
  'date': DateTime.now().toIso8601String(),
});

// Update user profile
await SupabaseService().updateTable('users', 
  {'age': 28, 'weight': 185.5, 'height': 72, 'goal': 'Build muscle'},
  user.id
);

// Query all workouts
final workouts = await SupabaseService().getFromTable('workouts');

// Delete a workout
await SupabaseService().deleteFromTable('workouts', 'workout-id');
```

## Files Created/Modified

- ✅ `pubspec.yaml` - Added supabase_flutter dependency
- ✅ `lib/config/supabase_config.dart` - Your Supabase credentials
- ✅ `lib/services/supabase_service.dart` - Main service class
- ✅ `lib/services/supabase_examples.dart` - Example code patterns
- ✅ `lib/main.dart` - Initialize Supabase at startup

## Key Service Methods

### Authentication
- `signUp(email, password)` - Register new user
- `signIn(email, password)` - Login user
- `signOut()` - Logout
- `getCurrentUser()` - Get current authenticated user

### Database
- `getFromTable(tableName)` - Fetch all rows
- `insertIntoTable(tableName, data)` - Insert data
- `updateTable(tableName, data, id)` - Update by ID
- `deleteFromTable(tableName, id)` - Delete by ID

### Storage
- `uploadFile(bucket, path, fileBytes)` - Upload file
- `deleteFile(bucket, path)` - Delete file

### Realtime
- `realtimeSubscription(tableName)` - Subscribe to changes

## Next Steps

1. ✅ Tables created
2. ⏳ **Enable RLS policies** on all 4 tables (if not done already)
3. Start using `SupabaseService()` in your widgets
4. Check `supabase_examples.dart` for usage patterns

## Need Help?

- Supabase Docs: https://supabase.com/docs
- Flutter Supabase: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
