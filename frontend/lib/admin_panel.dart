import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'auth.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<User> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  final List<String> _availableRoles = [
    'admin',
    'teacher',
    'parent',
    'student'
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.get(
        Uri.parse('http://localhost:8080/api/admin/users'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _users = data.map((json) => User.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load users';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final response = await http.delete(
          Uri.parse('http://localhost:8080/api/admin/users/$userId'),
          headers: {
            'Authorization': 'Bearer ${authService.token}',
          },
        );

        if (response.statusCode == 200) {
          _loadUsers();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete user')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  String _generatePassword({int length = 12}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  void _showEditUserDialog(User? user) {
    final usernameController =
        TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final selectedRoles = Set<String>.from(user?.roles ?? []);
    final formKey = GlobalKey<FormState>();
    final isNewUser = user == null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isNewUser ? 'Add User' : 'Edit User'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: isNewUser
                                ? 'Password'
                                : 'New Password (optional)',
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (isNewUser && (value == null || value.isEmpty)) {
                              return 'Please enter a password';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Generate Password',
                        onPressed: () {
                          setDialogState(() {
                            passwordController.text = _generatePassword();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Roles:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._availableRoles.map((role) => CheckboxListTile(
                        title: Text(role),
                        value: selectedRoles.contains(role),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedRoles.add(role);
                            } else {
                              selectedRoles.remove(role);
                            }
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (isNewUser)
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy Credentials'),
              onPressed: () async {
                if (usernameController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Please fill in username and password first')),
                  );
                  return;
                }
                final credentials =
                    'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
                await Clipboard.setData(ClipboardData(text: credentials));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Credentials copied to clipboard')),
                  );
                }
              },
            ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _saveUser(
                  userId: user?.id,
                  username: usernameController.text,
                  password: passwordController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  phone: phoneController.text.isEmpty ? null : phoneController.text,
                  roles: selectedRoles.toList(),
                );
              }
            },
            child: Text(isNewUser ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUser({
    int? userId,
    required String username,
    required String password,
    String? email,
    String? phone,
    required List<String> roles,
  }) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isNewUser = userId == null;

      final body = {
        'username': username,
        if (password.isNotEmpty) 'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'roles': roles,
      };

      final response = isNewUser
          ? await http.post(
              Uri.parse('http://localhost:8080/api/admin/users'),
              headers: {
                'Authorization': 'Bearer ${authService.token}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
          : await http.put(
              Uri.parse('http://localhost:8080/api/admin/users/$userId'),
              headers: {
                'Authorization': 'Bearer ${authService.token}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'User ${isNewUser ? 'created' : 'updated'} successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to ${isNewUser ? 'create' : 'update'} user')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _generateResetLink(User user) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/users/${user.id}/generate-reset-link'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resetLink = data['reset_link'];
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset Link Generated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset link for ${user.username}:'),
                const SizedBox(height: 8),
                SelectableText(
                  resetLink,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expires: ${data['expires_at']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Link'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: resetLink));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reset link copied to clipboard')),
                    );
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate reset link')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
                  'User Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadUsers,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
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
                              DataColumn(label: Text('Username')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Roles')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: _users.map((user) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(user.username)),
                                  DataCell(Text(user.email ?? '-')),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 300),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: user.roles.map((role) {
                                          return Chip(
                                            label: Text(role,
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            visualDensity:
                                                VisualDensity.compact,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon:
                                              const Icon(Icons.link, size: 20),
                                          onPressed: () =>
                                              _generateResetLink(user),
                                          tooltip: 'Generate Reset Link',
                                          color: Colors.blue,
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.edit, size: 20),
                                          onPressed: () =>
                                              _showEditUserDialog(user),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              size: 20),
                                          color: Colors.red,
                                          onPressed: () => _deleteUser(user.id),
                                          tooltip: 'Delete',
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
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showEditUserDialog(null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class User {
  final int id;
  final String username;
  final String? email;
  final String? phone;
  final List<String> roles;

  User({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phone: json['phone'],
      roles: List<String>.from(json['roles'] ?? []),
    );
  }
}

