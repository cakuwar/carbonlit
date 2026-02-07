import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch data from a table
  Future<List<Map<String, dynamic>>> fetchData(String tableName) async {
    final response = await _supabase.from(tableName).select().execute();
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
    return response.data as List<Map<String, dynamic>>;
  }

  // Insert data into a table
  Future<void> insertData(String tableName, Map<String, dynamic> data) async {
    final response = await _supabase.from(tableName).insert(data).execute();
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  // Update data in a table
  Future<void> updateData(String tableName, Map<String, dynamic> data, String id) async {
    final response = await _supabase.from(tableName).update(data).eq('id', id).execute();
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
  }

  // Delete data from a table
  Future<void> deleteData(String tableName, String id) async {
    final response = await _supabase.from(tableName).delete().eq('id', id).execute();
    if (response.error != null) {
      throw Exception(response.error!.message);
    }
  }
}