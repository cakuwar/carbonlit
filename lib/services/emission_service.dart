import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/emission_record.dart';

/// Service for managing emission records via Supabase.
class EmissionService {
  // ── Singleton ──────────────────────────────────────────────────────────
  static final EmissionService _instance = EmissionService._internal();
  factory EmissionService() => _instance;
  EmissionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Save a new emission record to Supabase.
  Future<void> saveEmissionRecord(EmissionRecord record) async {
    try {
      final payload = {
        ...record.toMap(),
        'recorded_by': _supabase.auth.currentUser?.id,
      };

      await _supabase.from('emission_records').upsert(
        payload,
        onConflict: 'building_name,category,month,year',
      );
    } on PostgrestException catch (e) {
      debugPrint('Error saving emission record: ${e.message}');
      rethrow;
    }
  }

  /// Fetch all emission records, newest first.
  Future<List<EmissionRecord>> fetchEmissionRecords() async {
    try {
      final data = await _supabase
          .from('emission_records')
          .select()
          .order('created_at', ascending: false);

      return data.map((e) => EmissionRecord.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching emission records: ${e.message}');
      return [];
    }
  }

  /// Fetch emission records filtered by month and year.
  Future<List<EmissionRecord>> fetchRecordsByMonth(
      String month, int year) async {
    try {
      final data = await _supabase
          .from('emission_records')
          .select()
          .eq('month', month)
          .eq('year', year)
          .order('created_at', ascending: false);

      return data.map((e) => EmissionRecord.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching records by month: ${e.message}');
      return [];
    }
  }

  /// Fetch emission records filtered by category.
  Future<List<EmissionRecord>> fetchRecordsByCategory(
      String category) async {
    try {
      final data = await _supabase
          .from('emission_records')
          .select()
          .eq('category', category)
          .order('created_at', ascending: false);

      return data.map((e) => EmissionRecord.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching records by category: ${e.message}');
      return [];
    }
  }

  /// Update an existing emission record.
  Future<void> updateEmissionRecord(EmissionRecord record) async {
    if (record.id == null) return;
    try {
      await _supabase
          .from('emission_records')
          .update(record.toMap())
          .eq('id', record.id!);
    } on PostgrestException catch (e) {
      debugPrint('Error updating emission record: ${e.message}');
      rethrow;
    }
  }

  /// Delete selected emission records by their IDs.
  Future<void> deleteRecords(List<String> ids) async {
    try {
      for (final id in ids) {
        await _supabase.from('emission_records').delete().eq('id', id);
      }
    } on PostgrestException catch (e) {
      debugPrint('Error deleting records: ${e.message}');
      rethrow;
    }
  }
}
