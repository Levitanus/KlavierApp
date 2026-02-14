import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'auth.dart';
import 'profile_screen.dart';
import 'config/app_config.dart';

part 'admin_panel/admin_panel_actions.dart';
part 'admin_panel/admin_panel_data.dart';
part 'admin_panel/admin_panel_dialogs.dart';
part 'admin_panel/admin_panel_models.dart';

class AdminPanel extends StatefulWidget {
  final String? username;
  
  const AdminPanel({super.key, this.username});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

abstract class _AdminPanelStateBase extends State<AdminPanel> {
  List<User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasOpenedDialog = false;

  Future<void> _loadUsers();
  Future<void> _saveUser({
    int? userId,
    required String username,
    required String fullName,
    required String password,
    String? email,
    String? phone,
    required List<String> roles,
  });
  Future<void> _makeUserStudent(
    int userId,
    String address,
    String birthday,
  );
  Future<void> _makeUserParent(
    int userId,
    List<int> studentIds,
  );
  Future<void> _makeUserTeacher(int userId);
  Future<void> _createStudent(
    String username,
    String password,
    String? email,
    String? phone,
    String fullName,
    String address,
    String birthday,
  );
  Future<void> _createParent(
    String username,
    String password,
    String? email,
    String? phone,
    String fullName,
    List<int> studentIds,
  );
  Future<void> _createTeacher(
    String username,
    String password,
    String? email,
    String? phone,
    String fullName,
  );
}

class _AdminPanelState extends _AdminPanelStateBase
  with _AdminPanelData, _AdminPanelDialogs, _AdminPanelActions {
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Admin Panel',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'User Management',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUsers,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _users.isEmpty
                            ? const Center(child: Text('No users found'))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    dataRowMinHeight: 48,
                                    dataRowMaxHeight: double.infinity,
                                    columns: const [
                                      DataColumn(label: Text('Full Name')),
                                      DataColumn(label: Text('Username')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: _users.map((user) {
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(user.fullName.isNotEmpty ? user.fullName : '-'),
                                          ),
                                          DataCell(Text(user.username)),
                                          DataCell(
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                OutlinedButton.icon(
                                                  icon: const Icon(Icons.link, size: 16),
                                                  label: const Text('Reset Link'),
                                                  onPressed: () => _generateResetLink(user),
                                                ),
                                                ElevatedButton.icon(
                                                  icon: const Icon(Icons.edit, size: 16),
                                                  label: const Text('Edit User'),
                                                  onPressed: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            AdminUserProfilePage(userId: user.id),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showEditUserDialog(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddStudentDialog,
                  icon: const Icon(Icons.school),
                  label: const Text('Add Student'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddParentDialog,
                  icon: const Icon(Icons.family_restroom),
                  label: const Text('Add Parent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddTeacherDialog,
                  icon: const Icon(Icons.person),
                  label: const Text('Add Teacher'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

