import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthProvider - State management for authentication

/// TODO: Integrate Supabase authentication here

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // User data placeholder
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  
  // Getters
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  
  AuthProvider() {
    _initialize();
  }
  
  /// Initialize auth provider
  /// TODO: Initialize Supabase client here
  Future<void> _initialize() async {
    try {
      // Initialize Supabase client
      _isInitialized = true;
      debugPrint('Auth provider initialized with Supabase');
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
    notifyListeners();
  }
  
  /// Sign up with email and password
  /// TODO: Implement Supabase sign up
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata, // Pass metadata to Supabase
      );

      debugPrint('Sign-up response: ${response.user?.toJson()}');

      if (response.user == null) {
        _error = 'Unknown error occurred';
      } else {
        _currentUser = response.user?.toJson();
        debugPrint('User signed up: $_currentUser');
      }
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign in with email and password
  /// TODO: Implement Supabase sign in
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null) {
        _error = 'Invalid email or password';
      } else {
        _currentUser = response.user?.toJson();
        debugPrint('User signed in: $_currentUser');
      }
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Sign out current user
  /// TODO: Implement Supabase sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.auth.signOut();
      _currentUser = null;
      _error = null;
      debugPrint('User signed out');
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get authentication token
  /// TODO: Implement token retrieval from Supabase
  Future<String?> getToken() async {
    return _supabase.auth.currentSession?.accessToken;
  }
  
  /// Clean up error messages for display
  String _cleanErrorMessage(String error) {
    if (error.contains('rate limit exceeded')) {
      return 'Too many requests. Please try again later.';
    }
    if (error.startsWith('Exception: ')) {
      return error.substring(11);
    }
    return error;
  }
}
