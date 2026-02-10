import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'auth.dart';

class AdminPanel extends StatefulWidget {
  final String? username;
  
  const AdminPanel({super.key, this.username});

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
  
  bool _hasOpenedDialog = false;

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
        
        // After loading users, open dialog if username is specified
        if (widget.username != null && !_hasOpenedDialog && mounted) {
          _hasOpenedDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final matchingUsers = _users.where((u) => u.username == widget.username);
            if (matchingUsers.isNotEmpty && mounted) {
              _showEditUserDialog(matchingUsers.first);
            }
          });
        }
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
                  CheckboxListTile(
                    title: const Text('Admin'),
                    value: selectedRoles.contains('admin'),
                    onChanged: (checked) {
                      setDialogState(() {
                        if (checked == true) {
                          selectedRoles.add('admin');
                        } else {
                          selectedRoles.remove('admin');
                        }
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!isNewUser) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Convert to Role:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!user!.roles.contains('student'))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.school, size: 16),
                            label: const Text('Make Student'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showMakeStudentDialog(user);
                            },
                          ),
                        if (!user.roles.contains('parent'))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.family_restroom, size: 16),
                            label: const Text('Make Parent'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showMakeParentDialog(user);
                            },
                          ),
                        if (!user.roles.contains('teacher'))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person, size: 16),
                            label: const Text('Make Teacher'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showMakeTeacherDialog(user);
                            },
                          ),
                      ],
                    ),
                  ],
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
                // For existing users, preserve role-specific roles (student, parent, teacher)
                // and only update admin status
                final rolesToSave = isNewUser
                    ? selectedRoles.toList()
                    : [
                        ...user!.roles.where((r) => r != 'admin'),
                        if (selectedRoles.contains('admin')) 'admin',
                      ];
                await _saveUser(
                  userId: user?.id,
                  username: usernameController.text,
                  password: passwordController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  phone: phoneController.text.isEmpty ? null : phoneController.text,
                  roles: rolesToSave,
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

  void _showMakeStudentDialog(User user) {
    final fullNameController = TextEditingController();
    final addressController = TextEditingController();
    final birthdayController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make ${user.username} a Student'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: birthdayController,
                  decoration: const InputDecoration(
                    labelText: 'Birthday (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    hintText: '2010-01-15',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                    if (!regex.hasMatch(value!)) {
                      return 'Format: YYYY-MM-DD';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _makeUserStudent(
                  user.id,
                  fullNameController.text,
                  addressController.text,
                  birthdayController.text,
                );
              }
            },
            child: const Text('Convert'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeUserStudent(
      int userId, String fullName, String address, String birthday) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/users/$userId/make-student'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
          'address': address,
          'birthday': birthday,
        }),
      );

      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User converted to student')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
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

  void _showMakeParentDialog(User user) async {
    final fullNameController = TextEditingController();
    final studentFilterController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedStudents = <int>{};
    String studentFilter = '';

    // Fetch student details with full names
    final studentUsers = _users.where((u) => u.roles.contains('student')).toList();
    final List<StudentInfo> students = [];
    
    final authService = Provider.of<AuthService>(context, listen: false);
    for (var studentUser in studentUsers) {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:8080/api/students/${studentUser.id}'),
          headers: {'Authorization': 'Bearer ${authService.token}'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          students.add(StudentInfo(
            userId: studentUser.id,
            username: studentUser.username,
            fullName: data['full_name'] ?? studentUser.username,
          ));
        }
      } catch (e) {
        students.add(StudentInfo(
          userId: studentUser.id,
          username: studentUser.username,
          fullName: studentUser.username,
        ));
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make ${user.username} a Parent'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredStudents = studentFilter.isEmpty
                ? students
                : students.where((s) => 
                    s.fullName.toLowerCase().contains(studentFilter.toLowerCase()) ||
                    s.username.toLowerCase().contains(studentFilter.toLowerCase())).toList();
            
            return Form(
              key: formKey,
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Students (at least one):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: studentFilterController,
                      decoration: const InputDecoration(
                        labelText: 'Search students',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Type to filter...',
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          studentFilter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: filteredStudents.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No students found'),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = filteredStudents[index];
                                return CheckboxListTile(
                                  title: Text(student.fullName),
                                  subtitle: Text(student.username),
                                  value: selectedStudents.contains(student.userId),
                                  onChanged: (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selectedStudents.add(student.userId);
                                      } else {
                                        selectedStudents.remove(student.userId);
                                      }
                                    });
                                  },
                                  dense: true,
                                );
                              },
                            ),
                    ),
                    if (selectedStudents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'At least one student required',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() &&
                  selectedStudents.isNotEmpty) {
                Navigator.of(context).pop();
                await _makeUserParent(
                  user.id,
                  fullNameController.text,
                  selectedStudents.toList(),
                );
              }
            },
            child: const Text('Convert'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeUserParent(
      int userId, String fullName, List<int> studentIds) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/users/$userId/make-parent'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
          'student_ids': studentIds,
        }),
      );

      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User converted to parent')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
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

  void _showMakeTeacherDialog(User user) {
    final fullNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make ${user.username} a Teacher'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _makeUserTeacher(user.id, fullNameController.text);
              }
            },
            child: const Text('Convert'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeUserTeacher(int userId, String fullName) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/users/$userId/make-teacher'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
        }),
      );

      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User converted to teacher')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
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

  void _showAddStudentDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final fullNameController = TextEditingController();
    final addressController = TextEditingController();
    final birthdayController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Student'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: birthdayController,
                    decoration: const InputDecoration(
                      labelText: 'Birthday (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      hintText: '2010-01-15',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!regex.hasMatch(value!)) {
                        return 'Format: YYYY-MM-DD';
                      }
                      return null;
                    },
                  ),
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
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Credentials'),
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Fill username and password first')),
                );
                return;
              }
              final credentials =
                  'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied')),
                );
              }
            },
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _createStudent(
                  usernameController.text,
                  passwordController.text,
                  emailController.text.isEmpty ? null : emailController.text,
                  phoneController.text.isEmpty ? null : phoneController.text,
                  fullNameController.text,
                  addressController.text,
                  birthdayController.text,
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createStudent(String username, String password, String? email,
      String? phone, String fullName, String address, String birthday) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/students'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          'full_name': fullName,
          'address': address,
          'birthday': birthday,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student created successfully')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
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

  void _showAddParentDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final fullNameController = TextEditingController();
    final studentFilterController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedStudents = <int>{};
    String studentFilter = '';

    // Fetch student details with full names
    final studentUsers = _users.where((u) => u.roles.contains('student')).toList();
    final List<StudentInfo> students = [];
    
    final authService = Provider.of<AuthService>(context, listen: false);
    for (var studentUser in studentUsers) {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:8080/api/students/${studentUser.id}'),
          headers: {'Authorization': 'Bearer ${authService.token}'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          students.add(StudentInfo(
            userId: studentUser.id,
            username: studentUser.username,
            fullName: data['full_name'] ?? studentUser.username,
          ));
        }
      } catch (e) {
        students.add(StudentInfo(
          userId: studentUser.id,
          username: studentUser.username,
          fullName: studentUser.username,
        ));
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Parent'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredStudents = studentFilter.isEmpty
                ? students
                : students.where((s) => 
                    s.fullName.toLowerCase().contains(studentFilter.toLowerCase()) ||
                    s.username.toLowerCase().contains(studentFilter.toLowerCase())).toList();
            
            return SingleChildScrollView(
              child: Form(
                key: formKey,
                child: SizedBox(
                  width: 500,
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
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
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
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Children (at least one):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: studentFilterController,
                        decoration: const InputDecoration(
                          labelText: 'Search students',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Type to filter...',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            studentFilter = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: filteredStudents.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('No students found'),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = filteredStudents[index];
                                  return CheckboxListTile(
                                    title: Text(student.fullName),
                                    subtitle: Text(student.username),
                                    value: selectedStudents.contains(student.userId),
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selectedStudents.add(student.userId);
                                        } else {
                                          selectedStudents.remove(student.userId);
                                        }
                                      });
                                    },
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                      if (selectedStudents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'At least one student required',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Credentials'),
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Fill username and password first')),
                );
                return;
              }
              final credentials =
                  'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied')),
                );
              }
            },
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() &&
                  selectedStudents.isNotEmpty) {
                Navigator.of(context).pop();
                await _createParent(
                  usernameController.text,
                  passwordController.text,
                  emailController.text.isEmpty ? null : emailController.text,
                  phoneController.text.isEmpty ? null : phoneController.text,
                  fullNameController.text,
                  selectedStudents.toList(),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createParent(String username, String password, String? email,
      String? phone, String fullName, List<int> studentIds) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/parents'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          'full_name': fullName,
          'student_ids': studentIds,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parent created successfully')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
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

  void _showAddTeacherDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final fullNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Teacher'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
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
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy Credentials'),
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Fill username and password first')),
                );
                return;
              }
              final credentials =
                  'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied')),
                );
              }
            },
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _createTeacher(
                  usernameController.text,
                  passwordController.text,
                  emailController.text.isEmpty ? null : emailController.text,
                  phoneController.text.isEmpty ? null : phoneController.text,
                  fullNameController.text,
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTeacher(String username, String password, String? email,
      String? phone, String fullName) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await http.post(
        Uri.parse('http://localhost:8080/api/admin/teachers'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'password': password,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          'full_name': fullName,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher created successfully')),
          );
        }
      } else {
        if (mounted) {
          final error = jsonDecode(response.body)['error'] ?? 'Unknown error';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
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

class StudentInfo {
  final int userId;
  final String username;
  final String fullName;

  StudentInfo({
    required this.userId,
    required this.username,
    required this.fullName,
  });
}

