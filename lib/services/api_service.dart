import 'package:http/http.dart' as http;
import 'dart:convert';

/// ApiService - HTTP client for backend API calls
/// 
/// NOTE: Clerk authentication has been removed.
/// TODO: Integrate Supabase authentication for API calls

class ApiService {
  // TODO: Replace with your actual backend URL
  static const String _baseUrl = 'YOUR_BACKEND_URL';
  
  /// Make authenticated GET request
  /// TODO: Get auth token from Supabase
  Future<Map<String, dynamic>> get(String endpoint) async {
    // TODO: Get token from auth provider/Supabase
    // Example: final token = supabase.auth.currentSession?.accessToken;
    final token = await _getAuthToken();
    
    final response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    return _handleResponse(response);
  }
  
  /// Make authenticated POST request
  /// TODO: Get auth token from Supabase
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    // TODO: Get token from auth provider/Supabase
    final token = await _getAuthToken();
    
    final response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    
    return _handleResponse(response);
  }
  
  /// Get authentication token
  /// TODO: Implement with Supabase
  Future<String?> _getAuthToken() async {
    // TODO: Get token from Supabase session
    // Example: return Supabase.instance.client.auth.currentSession?.accessToken;
    return null;
  }
  
  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('API Error: ${response.statusCode}');
    }
  }
}
