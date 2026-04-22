import 'package:supabase_flutter/supabase_flutter.dart';

/// ApiService — Thin wrapper around Supabase for any custom RPC / Edge Function calls.
///
/// KEY FIXES:
/// - Removed orphan http client with placeholder URL — not needed for Supabase
/// - Auth token is now pulled from Supabase session automatically
/// - Added helpers for Supabase RPC (database functions) and Edge Functions
/// - For normal CRUD, use DatabaseService instead
class ApiService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current auth token (automatically managed by Supabase SDK).
  String? get authToken => _supabase.auth.currentSession?.accessToken;

  /// Call a Supabase database function (RPC).
  /// Example: final result = await apiService.rpc('calculate_emission', params: {'distance': 10});
  Future<dynamic> rpc(String functionName, {Map<String, dynamic>? params}) async {
    try {
      final response = await _supabase.rpc(functionName, params: params ?? {});
      return response;
    } catch (e) {
      throw Exception('RPC error ($functionName): $e');
    }
  }

  /// Call a Supabase Edge Function (serverless function).
  /// Example: final result = await apiService.edgeFunction('send-email', body: {'to': 'user@example.com'});
  Future<Map<String, dynamic>> edgeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        functionName,
        body: body,
      );

      if (response.status != 200) {
        throw Exception('Edge Function error ($functionName): status ${response.status}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Edge Function error ($functionName): $e');
    }
  }
}
