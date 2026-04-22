import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthProvider — State management for Supabase authentication
///
/// FIX: After signup, user data is now saved to the PUBLIC `profiles` table.
/// Previously only auth.users received the data, so the public DB was empty.

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  // User state
  User? _user;
  String? _role; // 'admin' or 'student' (default)
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  // Getters
  User? get user => _user;
  Map<String, dynamic>? get currentUser => _user?.toJson();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  String? get userId => _user?.id;
  String? get role => _role;
  bool get isAdmin => _role == 'admin';
  bool get isStudent => _role == 'student' || _role == null;

  AuthProvider() {
    _initialize();
  }

  /// Initialize: restore existing session + listen for auth changes.
  Future<void> _initialize() async {
    try {
      // Check if user already has a valid session (e.g. app restart)
      final session = _supabase.auth.currentSession;
      if (session != null) {
        _user = _supabase.auth.currentUser;
        await _fetchRole(); // Load role from profiles table
        debugPrint('Session restored for user: ${_user?.email} (role: $_role)');
      }

      // Listen to future auth state changes (sign-in, sign-out, token refresh)
      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
        final event = data.event;
        debugPrint('Auth event: $event');

        switch (event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            _user = data.session?.user;
            await _fetchRole();
            break;
          case AuthChangeEvent.signedOut:
            _user = null;
            _role = null;
            break;
          default:
            break;
        }
        notifyListeners();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
    notifyListeners();
  }

  /// Sign up with email and password
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
        data: metadata,
      );

      if (response.user == null) {
        _error = 'Sign-up failed. Please try again.';
      } else {
        _user = response.user;
        // Set role immediately from metadata so routing is correct even if
        // _fetchRole() races with the onAuthStateChange stream or the profile
        // row hasn't been committed to DB yet.
        _role = (metadata['role'] as String?) ?? 'student';
        debugPrint('User signed up: ${_user?.email} (role from metadata: $_role)');

        // ── Insert user data into the PUBLIC profiles table ──
        await _createProfileRow(response.user!, metadata);
        await _fetchRole(); // Confirm role from DB (may reinforce or update)
      }
    } on AuthException catch (e) {
      _error = _cleanErrorMessage(e.message);
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a row in the public `profiles` table after signup.
  /// Uses upsert to avoid duplicates if triggered twice.
  /// Role comes from metadata['role'] — set by the AccessPage selection.
  Future<void> _createProfileRow(User user, Map<String, dynamic> metadata) async {
    try {
      final selectedRole = metadata['role'] ?? 'student';
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'user_id': user.id,
        'email': user.email ?? metadata['email'] ?? '',
        'first_name': metadata['first_name'] ?? '',
        'last_name': metadata['last_name'] ?? '',
        'student_id': metadata['student_id'] ?? '',
        'phone': metadata['phone'] ?? '',
        'country': metadata['country'] ?? '',
        'role': selectedRole, // Role from AccessPage (admin or student)
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('Profile row created in public DB for ${user.email}');
    } on PostgrestException catch (e) {
      debugPrint('Warning: Could not create profile row: ${e.message}');
    } catch (e) {
      debugPrint('Warning: Could not create profile row: $e');
    }
  }

  /// Fetch the user's role from the profiles table.
  /// Called after login, signup, and session restore.
  Future<void> _fetchRole() async {
    if (_user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', _user!.id)
          .maybeSingle();
      _role = data?['role'] ?? 'student';
      debugPrint('User role: $_role');
    } catch (e) {
      _role = 'student'; // Default fallback
      debugPrint('Could not fetch role, defaulting to student: $e');
    }
  }

  /// Sign in with email and password
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
        _user = response.user;
        await _fetchRole(); // Load role after login
        debugPrint('User signed in: ${_user?.email} (role: $_role)');
      }
    } on AuthException catch (e) {
      _error = _cleanErrorMessage(e.message);
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabase.auth.signOut();
      _user = null;
      _role = null;
      _error = null;
      debugPrint('User signed out');
    } on AuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a password reset email
  Future<void> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      _error = _cleanErrorMessage(e.message);
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google OAuth via Supabase
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.carbonlit://login-callback',
      );

      if (!success) {
        _error = 'Google sign-in was cancelled or failed.';
      }

      return success;
    } on AuthException catch (e) {
      _error = _cleanErrorMessage(e.message);
      return false;
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Microsoft (Azure) OAuth via Supabase
  Future<bool> signInWithMicrosoft() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _supabase.auth.signInWithOAuth(
        OAuthProvider.azure,
        redirectTo: 'com.example.carbonlit://login-callback',
        scopes: 'openid profile email',
      );

      if (!success) {
        _error = 'Microsoft sign-in was cancelled or failed.';
      }

      return success;
    } on AuthException catch (e) {
      _error = _cleanErrorMessage(e.message);
      return false;
    } catch (e) {
      _error = _cleanErrorMessage(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get authentication token for API calls
  String? getToken() {
    return _supabase.auth.currentSession?.accessToken;
  }

  /// Clean up auth listener when provider is disposed
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Clean up error messages for display
  String _cleanErrorMessage(String error) {
    if (error.contains('rate limit exceeded')) {
      return 'Too many requests. Please try again later.';
    }
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (error.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    if (error.startsWith('Exception: ')) {
      return error.substring(11);
    }
    return error;
  }
}
