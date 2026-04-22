import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

/// Admin Dashboard — Only accessible by users with role='admin'.
/// Shows user management and basic stats.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _supabase
          .from('profiles')
          .update({'role': newRole, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role updated to $newRole')),
      );
      await _loadUsers(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('profiles').delete().eq('id', userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile deleted')),
      );
      await _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final adminCount = _users.where((u) => u['role'] == 'admin').length;
    final studentCount = _users.where((u) => u['role'] == 'student' || u['role'] == null).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF115925),
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authProvider.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/access');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: Column(
                children: [
                  // Stats cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFF5F5F5),
                    child: Row(
                      children: [
                        _buildStatCard('Total Users', _users.length.toString(), Icons.people),
                        const SizedBox(width: 12),
                        _buildStatCard('Admins', adminCount.toString(), Icons.admin_panel_settings),
                        const SizedBox(width: 12),
                        _buildStatCard('Students', studentCount.toString(), Icons.school),
                      ],
                    ),
                  ),

                  // Section header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'All Users',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text('${_users.length} total', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),

                  // User list
                  Expanded(
                    child: _users.isEmpty
                        ? const Center(child: Text('No users found'))
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return _buildUserTile(user);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF115925), size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF115925))),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final String name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final String email = user['email'] ?? 'No email';
    final String role = user['role'] ?? 'student';
    final String userId = user['id'] ?? '';
    final bool isSelf = userId == Supabase.instance.client.auth.currentUser?.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: role == 'admin' ? const Color(0xFF115925) : Colors.grey[300],
          child: Icon(
            role == 'admin' ? Icons.admin_panel_settings : Icons.person,
            color: role == 'admin' ? Colors.white : Colors.grey[700],
          ),
        ),
        title: Text(
          name.isNotEmpty ? name : email,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: role == 'admin' ? const Color(0xFF115925).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: role == 'admin' ? const Color(0xFF115925) : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        trailing: isSelf
            ? const Chip(label: Text('You', style: TextStyle(fontSize: 10)))
            : PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'make_admin') {
                    _updateUserRole(userId, 'admin');
                  } else if (action == 'make_student') {
                    _updateUserRole(userId, 'student');
                  } else if (action == 'delete') {
                    _deleteUser(userId);
                  }
                },
                itemBuilder: (context) => [
                  if (role != 'admin')
                    const PopupMenuItem(value: 'make_admin', child: Text('Make Admin')),
                  if (role != 'student')
                    const PopupMenuItem(value: 'make_student', child: Text('Make Student')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
        isThreeLine: true,
      ),
    );
  }
}
