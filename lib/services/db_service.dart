import 'package:supabase_flutter/supabase_flutter.dart';

/// DatabaseService — Supabase CRUD wrapper (v2 API)
///
/// KEY FIXES (v2 breaking changes):
/// - Removed .execute() — no longer exists in supabase_flutter ^2.x
/// - Removed response.error checks — v2 throws PostgrestException on failure
/// - All queries now return data directly (List/Map) instead of a response object
/// - Added try/catch with PostgrestException for proper error handling
/// - Added upsert, fetchById, fetchByUser helpers for common patterns
class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ──────────────────────────── READ ────────────────────────────

  /// Fetch all rows from [tableName].
  Future<List<Map<String, dynamic>>> fetchData(String tableName) async {
    try {
      // v2: .select() returns List<Map<String, dynamic>> directly
      final data = await _supabase.from(tableName).select();
      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      throw Exception('Fetch error ($tableName): ${e.message}');
    }
  }

  /// Fetch a single row by its [id].
  Future<Map<String, dynamic>?> fetchById(String tableName, String id) async {
    try {
      final data = await _supabase
          .from(tableName)
          .select()
          .eq('id', id)
          .maybeSingle(); // returns null if not found (no throw)
      return data;
    } on PostgrestException catch (e) {
      throw Exception('FetchById error ($tableName): ${e.message}');
    }
  }

  /// Fetch rows belonging to the currently authenticated user.
  /// Requires a `user_id` column in the table.
  Future<List<Map<String, dynamic>>> fetchByUser(String tableName) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final data = await _supabase
          .from(tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      throw Exception('FetchByUser error ($tableName): ${e.message}');
    }
  }

  // ──────────────────────────── CREATE ──────────────────────────

  /// Insert a row into [tableName].
  /// Automatically attaches the current user's id if not present.
  Future<Map<String, dynamic>> insertData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Auto-attach user_id so Row Level Security (RLS) policies work
    final payload = {
      ...data,
      'user_id': userId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      // v2: .insert() returns the inserted row when .select() is chained
      final inserted = await _supabase
          .from(tableName)
          .insert(payload)
          .select()
          .single();
      return inserted;
    } on PostgrestException catch (e) {
      throw Exception('Insert error ($tableName): ${e.message}');
    }
  }

  // ──────────────────────────── UPDATE ──────────────────────────

  /// Update a row in [tableName] identified by [id].
  Future<Map<String, dynamic>> updateData(
    String tableName,
    Map<String, dynamic> data,
    String id,
  ) async {
    // Add an updated_at timestamp
    final payload = {
      ...data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final updated = await _supabase
          .from(tableName)
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return updated;
    } on PostgrestException catch (e) {
      throw Exception('Update error ($tableName): ${e.message}');
    }
  }

  // ──────────────────────────── UPSERT ─────────────────────────

  /// Insert or update (upsert) a row. Useful for profile-style tables
  /// where a user always has exactly one row.
  Future<Map<String, dynamic>> upsertData(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final payload = {
      ...data,
      'user_id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final result = await _supabase
          .from(tableName)
          .upsert(payload)
          .select()
          .single();
      return result;
    } on PostgrestException catch (e) {
      throw Exception('Upsert error ($tableName): ${e.message}');
    }
  }

  // ──────────────────────────── DELETE ──────────────────────────

  /// Delete a row from [tableName] by [id].
  Future<void> deleteData(String tableName, String id) async {
    try {
      await _supabase.from(tableName).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Delete error ($tableName): ${e.message}');
    }
  }

  // ──────────────────────── HELPER ─────────────────────────────

  /// Get the current authenticated user's ID, or null.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Quick check: is a user logged in?
  bool get isAuthenticated => _supabase.auth.currentUser != null;
}