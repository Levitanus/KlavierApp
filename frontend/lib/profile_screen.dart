import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'auth.dart';
import 'services/hometask_service.dart';
import 'services/chat_service.dart';
import 'models/hometask.dart';
import 'screens/chat_conversation.dart';
import 'config/app_config.dart';

part 'profile_screen/profile_screen_data.dart';
part 'profile_screen/profile_screen_dialogs.dart';
part 'profile_screen/profile_screen_models.dart';
part 'profile_screen/profile_screen_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class AdminUserProfilePage extends StatelessWidget {
  final int userId;

  const AdminUserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
      ),
      body: ProfileScreen(userId: userId),
    );
  }
}

abstract class _ProfileScreenStateBase extends State<ProfileScreen> {
  static String get _baseUrl => AppConfig.instance.baseUrl;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Profile data
  int? _userId;
  String _username = '';
  String? _email;
  String? _phone;
  String? _profileImage;
  DateTime? _createdAt;

  // Role data
  List<String> _roles = [];
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _parentData;
  Map<String, dynamic>? _teacherData;
  String? _studentStatus;
  String? _parentStatus;
  String? _teacherStatus;
  bool _adminRoleSelected = false;
  List<Map<String, dynamic>> _teacherStudents = [];
  List<Map<String, dynamic>> _studentTeachers = [];

  // Text controllers for editing
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  bool get _isAdminView => widget.userId != null;

  Future<void> _loadProfile();
  Future<void> _pickImage();
  Future<void> _removeImage();
  Future<void> _addStudentsToTeacher(List<int> studentIds);
  Future<void> _removeTeacherFromStudent(int studentId, int teacherId);
  Future<void> _updateAdminRole();
  Future<void> _toggleRoleArchive(String role);
  Future<void> _makeUserStudent(String address, String birthday);
  Future<void> _makeUserParent(List<int> studentIds);
  Future<void> _makeUserTeacher();
  Future<void> _addChildrenToParent(List<int> studentIds);
  Future<void> _updateChildData(
    int childUserId,
    String fullName,
    String address,
    String birthday,
  );
  Future<List<StudentInfo>> _loadStudentsForSelection();
  Future<List<Map<String, dynamic>>> _fetchTeacherStudents(int teacherId);
  Future<List<Map<String, dynamic>>> _fetchStudentTeachers(int studentId);
  Future<List<Map<String, dynamic>>> _fetchStudentParents(int studentId);
  Future<bool> _showLockedConfirmationDialog({
    required String title,
    required String content,
    required String confirmLabel,
  });
  void _showMakeStudentDialog();
  void _showMakeParentDialog();
  void _showMakeTeacherDialog();
  void _showAddChildrenDialog();
  Widget _buildInfoRow(IconData icon, String label, String value);
  Widget _buildChildAvatar(String? profileImage, String fullName, double radius);
  bool _isRoleArchived(String role);
}

class _ProfileScreenState extends _ProfileScreenStateBase
  with _ProfileScreenData, _ProfileScreenDialogs, _ProfileScreenWidgets {

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image
          _buildProfileImage(allowEditing: !_isAdminView),
          const SizedBox(height: 24),
          
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _isAdminView ? 'User Profile' : 'Profile',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      _username,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              if (!_isEditing && !_isSaving && (!_isAdminView || authService.isAdmin))
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  tooltip: 'Edit Profile',
                ),
            ],
          ),
          if (_isAdminView)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: const Text(
                      'Admin View',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Profile Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Username (read-only)
                  _buildProfileField(
                    label: 'Username',
                    value: _username,
                    icon: Icons.person_outline,
                    isEditable: false,
                  ),
                  const SizedBox(height: 16),

                  // Full Name
                  if (_isEditing)
                    _buildEditableField(
                      label: 'Full Name',
                      controller: _fullNameController,
                      icon: Icons.badge_outlined,
                    )
                  else
                    _buildProfileField(
                      label: 'Full Name',
                      value: _fullNameController.text.isNotEmpty
                          ? _fullNameController.text
                          : 'Not set',
                      icon: Icons.badge_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // Email
                  if (_isEditing)
                    _buildEditableField(
                      label: 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    )
                  else
                    _buildProfileField(
                      label: 'Email',
                      value: _email ?? 'Not set',
                      icon: Icons.email_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // Phone
                  if (_isEditing)
                    _buildEditableField(
                      label: 'Phone',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    )
                  else
                    _buildProfileField(
                      label: 'Phone',
                      value: _phone ?? 'Not set',
                      icon: Icons.phone_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),
                  
                  // Created At (read-only)
                  _buildProfileField(
                    label: 'Member Since',
                    value: _createdAt != null
                        ? '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}'
                        : 'Unknown',
                    icon: Icons.calendar_today_outlined,
                    isEditable: false,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : _cancelEditing,
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Roles Section
          if (_roles.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roles',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _roles.map((role) {
                        return Chip(
                          label: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: role == 'student'
                              ? Colors.blue
                              : role == 'parent'
                                  ? Colors.green
                                  : role == 'teacher'
                                      ? Colors.orange
                                      : role == 'admin'
                                          ? Colors.red
                                          : Colors.grey,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (authService.isAdmin)
            _buildAdminControlsCard(),

          // Role-specific Information Card
          if (_studentData != null || _parentData != null || _teacherData != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Student-specific fields
                    if (_studentData != null) ...[
                      // Address
                      if (_isEditing)
                        _buildEditableField(
                          label: 'Address',
                          controller: _addressController,
                          icon: Icons.home_outlined,
                        )
                      else
                        _buildProfileField(
                          label: 'Address',
                          value: _studentData!['address'] ?? 'Not set',
                          icon: Icons.home_outlined,
                          isEditable: true,
                        ),
                      const SizedBox(height: 16),
                      
                      // Birthday
                      if (_isEditing)
                        _buildEditableField(
                          label: 'Birthday (YYYY-MM-DD)',
                          controller: _birthdayController,
                          icon: Icons.cake_outlined,
                        )
                      else
                        _buildProfileField(
                          label: 'Birthday',
                          value: _studentData!['birthday'] ?? 'Not set',
                          icon: Icons.cake_outlined,
                          isEditable: true,
                        ),
                      const SizedBox(height: 16),
                      
                      // Parent Registration Button
                      if (!_isEditing) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _generateParentRegistrationLink,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Generate Parent Registration Link'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    
                    // Parent-specific: Children list
                    if (_parentData != null && _parentData!['children'] != null) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'My Children',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap on a child to view or edit their information',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_parentData!['children'] as List).map((child) {
                        return Card(
                          color: Colors.blue.shade50,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _showChildDetailsDialog(child),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildChildAvatar(
                                        child['profile_image'],
                                        child['full_name'],
                                        24,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              child['full_name'],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '@${child['username']}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.cake_outlined,
                                    'Birthday',
                                    child['birthday'],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.home_outlined,
                                    'Address',
                                    child['address'],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _startChatWithUser(
                                            child['user_id'] as int,
                                            child['full_name'] as String,
                                          ),
                                          icon: const Icon(Icons.message),
                                          label: const Text('Message'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],

                    if (_teacherData != null && !_isEditing) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Manage Students',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Add Student'),
                            onPressed: _showAddStudentsToTeacherDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage students assigned to you',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_teacherStudents.isEmpty)
                        Text(
                          'No students assigned yet',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else
                        ..._teacherStudents.map((student) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student['full_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('@${student['username'] ?? ''}'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('View Profile'),
                                        onPressed: () => _showStudentProfileDialog(student),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.assignment_add),
                                        label: const Text('Assign Hometask'),
                                        onPressed: () => _showAssignHometaskDialog(student),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.message),
                                        label: const Text('Message'),
                                        onPressed: () => _startChatWithUser(
                                          student['user_id'] as int,
                                          student['full_name'] as String,
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.person_remove, color: Colors.red),
                                        label: const Text(
                                          'Remove from Students',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () {
                                          final studentId = student['user_id'];
                                          if (studentId is int) {
                                            _removeStudentFromTeacher(studentId);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _generateStudentRegistrationLinkForTeacher,
                        icon: const Icon(Icons.link),
                        label: const Text('Generate Student Registration Link'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],

                    if (_studentData != null && !_isEditing) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Teachers',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to view teacher profile or leave teacher',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_studentTeachers.isEmpty)
                        Text(
                          'No teachers assigned yet',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else
                        ..._studentTeachers.map((teacher) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacher['full_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('@${teacher['username'] ?? ''}'),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('View Profile'),
                                        onPressed: () => _showTeacherProfileDialog(teacher),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.message),
                                        label: const Text('Message'),
                                        onPressed: () => _startChatWithUser(
                                          teacher['user_id'] as int,
                                          teacher['full_name'] as String,
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.logout, color: Colors.red),
                                        label: const Text(
                                          'Leave Teacher',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () {
                                          final teacherId = teacher['user_id'];
                                          final studentId = _userId;
                                          if (teacherId is int && studentId is int) {
                                            _removeTeacherFromStudent(studentId, teacherId);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                    
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (!_isAdminView)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your account password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isEditing ? null : _showChangePasswordDialog,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

