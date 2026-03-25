import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Auth methods
  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? getCurrentUser() {
    return client.auth.currentUser;
  }

  // Database methods
  Future<List<Map<String, dynamic>>> getFromTable(String tableName) async {
    return await client.from(tableName).select();
  }

  Future<Map<String, dynamic>> insertIntoTable(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    return await client.from(tableName).insert(data).select().single();
  }

  Future<void> updateTable(
    String tableName,
    Map<String, dynamic> data,
    String id,
  ) async {
    await client.from(tableName).update(data).eq('id', id);
  }

  Future<void> deleteFromTable(String tableName, String id) async {
    await client.from(tableName).delete().eq('id', id);
  }

  // Storage methods
  Future<String> uploadFile(
    String bucket,
    String path,
    Uint8List fileBytes,
  ) async {
    await client.storage.from(bucket).uploadBinary(path, fileBytes);
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> deleteFile(String bucket, String path) async {
    await client.storage.from(bucket).remove([path]);
  }

  // Realtime subscriptions
  RealtimeChannel realtimeSubscription(String tableName) {
    return client.channel('public:$tableName').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: tableName,
      callback: (payload) {
        // Handle changes
      },
    );
  }
}
