// Example Supabase usage patterns for your IronMind app

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../services/supabase_service.dart';

// ============================================
// AUTHENTICATION EXAMPLES
// ============================================

class AuthExample {
  // Sign up new user
  static Future<void> signUpExample() async {
    try {
      final response = await SupabaseService().signUp(
        'user@example.com',
        'password123',
      );
      print('User signed up: ${response.user?.id}');
    } catch (e) {
      print('Sign up error: $e');
    }
  }

  // Sign in existing user
  static Future<void> signInExample() async {
    try {
      final response = await SupabaseService().signIn(
        'user@example.com',
        'password123',
      );
      print('User signed in: ${response.user?.id}');
    } catch (e) {
      print('Sign in error: $e');
    }
  }

  // Get current user
  static void getCurrentUserExample() {
    final user = SupabaseService().getCurrentUser();
    if (user != null) {
      print('Current user: ${user.email}');
    }
  }

  // Sign out
  static Future<void> signOutExample() async {
    await SupabaseService().signOut();
    print('User signed out');
  }
}

// ============================================
// DATABASE EXAMPLES
// ============================================

class DatabaseExample {
  // Insert workout data
  static Future<void> insertWorkoutExample() async {
    try {
      final response = await SupabaseService().insertIntoTable(
        'workouts',
        {
          'user_id': SupabaseService().getCurrentUser()?.id,
          'exercise_name': 'Bench Press',
          'sets': 4,
          'reps': 8,
          'weight': 185.5,
          'date': DateTime.now().toIso8601String(),
        },
      );
      print('Workout inserted: ${response['id']}');
    } catch (e) {
      print('Insert error: $e');
    }
  }

  // Get user workouts
  static Future<void> getUserWorkoutsExample() async {
    try {
      final userId = SupabaseService().getCurrentUser()?.id;
      if (userId == null) {
        print('User not authenticated');
        return;
      }
      final client = SupabaseService.client;
      
      final response = await client
          .from('workouts')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      
      print('Workouts: $response');
    } catch (e) {
      print('Fetch error: $e');
    }
  }

  // Update workout
  static Future<void> updateWorkoutExample() async {
    try {
      await SupabaseService().updateTable(
        'workouts',
        {'weight': 190.0, 'reps': 10},
        'workout-id-here',
      );
      print('Workout updated');
    } catch (e) {
      print('Update error: $e');
    }
  }

  // Delete workout
  static Future<void> deleteWorkoutExample() async {
    try {
      await SupabaseService().deleteFromTable('workouts', 'workout-id-here');
      print('Workout deleted');
    } catch (e) {
      print('Delete error: $e');
    }
  }
}

// ============================================
// STORAGE EXAMPLES (for profile pictures, etc)
// ============================================

class StorageExample {
  // Upload profile picture
  static Future<void> uploadProfilePictureExample(List<int> imageBytes) async {
    try {
      final userId = SupabaseService().getCurrentUser()?.id;
      if (userId == null) {
        print('User not authenticated');
        return;
      }
      final path = 'profiles/$userId/profile.jpg';
      
      final imageUrl = await SupabaseService().uploadFile(
        'avatars', // bucket name
        path,
        Uint8List.fromList(imageBytes),
      );
      print('Image uploaded: $imageUrl');
    } catch (e) {
      print('Upload error: $e');
    }
  }

  // Delete file
  static Future<void> deleteFileExample() async {
    try {
      await SupabaseService().deleteFile('avatars', 'profiles/user-id/profile.jpg');
      print('File deleted');
    } catch (e) {
      print('Delete error: $e');
    }
  }
}

// ============================================
// REALTIME EXAMPLES
// ============================================

class RealtimeExample {
  // Subscribe to workout changes
  static void subscribeToWorkoutsExample() {
    final channel = SupabaseService().realtimeSubscription('workouts');
    
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        print('Subscribed to workouts');
      }
    });
  }
}

// ============================================
// SETUP GUIDE
// ============================================
/*
✅ Tables created:
   - users (profile info: age, weight, height, goal)
   - workouts (exercise_name, sets, reps, weight, date)
   - nutrition (meal_type, calories, protein, carbs, fats, date)
   - wellness (sleep, stress, energy, mood, date)

✅ RLS policies enabled on all tables:
   - SELECT, INSERT, UPDATE, DELETE where auth.uid() = user_id

Next steps:
3. Create a storage bucket "avatars" for profile pictures (if needed)
4. Use SupabaseService() in your widgets to access Supabase
*/
