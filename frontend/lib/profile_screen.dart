import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'auth.dart';
import 'services/hometask_service.dart';
import 'services/chat_service.dart';
import 'services/app_data_cache_service.dart';
import 'services/media_cache_service.dart';
import 'services/locale_service.dart';
import 'models/hometask.dart';
import 'screens/chat_conversation.dart';
import 'config/app_config.dart';
import 'l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.profileTitleUserProfile ?? 'User Profile'),
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
  List<Map<String, dynamic>> _teacherGroups = [];
  bool _showArchivedGroups = false;
  List<Map<String, dynamic>> _studentTeachers = [];
  int _teacherStudentsCurrentPage = 1;
  int _teacherStudentsPageSize = 30;
  String _teacherStudentsSearchQuery = '';
  Timer? _teacherStudentsSearchDebounce;
  final TextEditingController _teacherStudentsSearchController =
      TextEditingController();

  // Text controllers for editing
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  bool get _isAdminView => widget.userId != null;

  Future<void> _loadProfile();
  Future<void> _pickImage();
  Future<void> _removeImage();
  Future<void> _addStudentsToTeacher(List<int> studentIds);
  Future<void> _createTeacherGroup(String name, List<int> studentIds);
  Future<void> _updateTeacherGroup({
    required int groupId,
    String? name,
    List<int>? studentIds,
    bool? archived,
  });
  Future<void> _deleteTeacherGroup(int groupId);
  Future<void> _removeTeacherFromStudent(int studentId, int teacherId);
  Future<void> _updateAdminRole();
  Future<void> _toggleRoleArchive(String role);
  Future<void> _makeUserStudent(String birthday);
  Future<void> _makeUserParent(List<int> studentIds);
  Future<void> _makeUserTeacher();
  Future<void> _addChildrenToParent(List<int> studentIds);
  Future<void> _updateChildData(
    int childUserId,
    String fullName,
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
  Widget _buildChildAvatar(
    String? profileImage,
    String fullName,
    double radius,
  );
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
    _teacherStudentsSearchDebounce?.cancel();
    _teacherStudentsSearchController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _onTeacherStudentsSearchChanged(String value) {
    _teacherStudentsSearchDebounce?.cancel();
    _teacherStudentsSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () {
        if (!mounted) return;
        final trimmed = value.trim().toLowerCase();
        if (trimmed == _teacherStudentsSearchQuery) return;
        setState(() {
          _teacherStudentsSearchQuery = trimmed;
          _teacherStudentsCurrentPage = 1;
        });
      },
    );
  }

  void _clearTeacherStudentsSearch() {
    _teacherStudentsSearchController.clear();
    _onTeacherStudentsSearchChanged('');
  }

  void _setTeacherStudentsPageSize(int pageSize) {
    if (pageSize == _teacherStudentsPageSize) return;
    setState(() {
      _teacherStudentsPageSize = pageSize;
      _teacherStudentsCurrentPage = 1;
    });
  }

  void _changeTeacherStudentsPage(int delta, int maxPage) {
    final nextPage = (_teacherStudentsCurrentPage + delta).clamp(1, maxPage);
    if (nextPage == _teacherStudentsCurrentPage) return;
    setState(() {
      _teacherStudentsCurrentPage = nextPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final localeService = context.watch<LocaleService>();
    final l10n = AppLocalizations.of(context);
    final filteredTeacherStudents = _teacherStudents.where((student) {
      if (_teacherStudentsSearchQuery.isEmpty) return true;
      final fullName = (student['full_name']?.toString() ?? '').toLowerCase();
      final username = (student['username']?.toString() ?? '').toLowerCase();
      return fullName.contains(_teacherStudentsSearchQuery) ||
          username.contains(_teacherStudentsSearchQuery);
    }).toList();
    final totalFilteredTeacherStudents = filteredTeacherStudents.length;
    final teacherStudentsMaxPage =
        (totalFilteredTeacherStudents / _teacherStudentsPageSize).ceil().clamp(
          1,
          999999,
        );
    if (_teacherStudentsCurrentPage > teacherStudentsMaxPage) {
      _teacherStudentsCurrentPage = teacherStudentsMaxPage;
    }
    final teacherStudentsStartIndex =
        (_teacherStudentsCurrentPage - 1) * _teacherStudentsPageSize;
    final teacherStudentsEndIndex = min(
      teacherStudentsStartIndex + _teacherStudentsPageSize,
      totalFilteredTeacherStudents,
    );
    final pagedTeacherStudents =
        teacherStudentsStartIndex < totalFilteredTeacherStudents
        ? filteredTeacherStudents.sublist(
            teacherStudentsStartIndex,
            teacherStudentsEndIndex,
          )
        : <Map<String, dynamic>>[];
    final visibleTeacherGroups = _teacherGroups.where((group) {
      final status = (group['status']?.toString() ?? 'active').toLowerCase();
      final isArchived = status == 'archived';
      return _showArchivedGroups ? isArchived : !isArchived;
    }).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: Text(l10n?.commonRetry ?? 'Retry'),
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
                      _isAdminView
                          ? (l10n?.profileTitleUserProfile ?? 'User Profile')
                          : (l10n?.profileTitleProfile ?? 'Profile'),
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
              if (!_isEditing &&
                  !_isSaving &&
                  (!_isAdminView || authService.isAdmin))
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  tooltip: l10n?.profileEditTooltip ?? 'Edit Profile',
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(
                      l10n?.profileAdminViewLabel ?? 'Admin View',
                      style: const TextStyle(
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
                    l10n?.profileSectionInfo ?? 'Profile Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Username (read-only)
                  _buildProfileField(
                    label: l10n?.commonUsername ?? 'Username',
                    value: _username,
                    icon: Icons.person_outline,
                    isEditable: false,
                  ),
                  const SizedBox(height: 16),

                  // Full Name
                  if (_isEditing)
                    _buildEditableField(
                      label: l10n?.commonFullName ?? 'Full Name',
                      controller: _fullNameController,
                      icon: Icons.badge_outlined,
                    )
                  else
                    _buildProfileField(
                      label: l10n?.commonFullName ?? 'Full Name',
                      value: _fullNameController.text.isNotEmpty
                          ? _fullNameController.text
                          : (l10n?.profileNotSet ?? 'Not set'),
                      icon: Icons.badge_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),

                  // Email
                  if (_isEditing)
                    _buildEditableField(
                      label: l10n?.profileEmailLabel ?? 'Email',
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    )
                  else
                    _buildProfileField(
                      label: l10n?.profileEmailLabel ?? 'Email',
                      value: _email ?? (l10n?.profileNotSet ?? 'Not set'),
                      icon: Icons.email_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),

                  // Phone
                  if (_isEditing)
                    _buildEditableField(
                      label: l10n?.profilePhoneLabel ?? 'Phone',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    )
                  else
                    _buildProfileField(
                      label: l10n?.profilePhoneLabel ?? 'Phone',
                      value: _phone ?? (l10n?.profileNotSet ?? 'Not set'),
                      icon: Icons.phone_outlined,
                      isEditable: true,
                    ),
                  const SizedBox(height: 16),

                  // Created At (read-only)
                  _buildProfileField(
                    label: l10n?.profileMemberSinceLabel ?? 'Member Since',
                    value: _createdAt != null
                        ? '${_createdAt!.day}/${_createdAt!.month}/${_createdAt!.year}'
                        : (l10n?.profileUnknown ?? 'Unknown'),
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
                          child: Text(l10n?.commonCancel ?? 'Cancel'),
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
                              : Text(l10n?.commonSave ?? 'Save'),
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
                      l10n?.profileRolesTitle ?? 'Roles',
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

          if (authService.isAdmin) _buildAdminControlsCard(),

          // Role-specific Information Card
          if (_studentData != null ||
              _parentData != null ||
              _teacherData != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.profileSectionAdditional ??
                          'Additional Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Student-specific fields
                    if (_studentData != null) ...[
                      // Birthday
                      if (_isEditing)
                        _buildEditableField(
                          label:
                              l10n?.profileBirthdayInputLabel ??
                              'Birthday (YYYY-MM-DD)',
                          controller: _birthdayController,
                          icon: Icons.cake_outlined,
                        )
                      else
                        _buildProfileField(
                          label: l10n?.profileBirthdayLabel ?? 'Birthday',
                          value:
                              _studentData!['birthday'] ??
                              (l10n?.profileNotSet ?? 'Not set'),
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
                          label: Text(
                            l10n?.profileGenerateParentLink ??
                                'Generate Parent Registration Link',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Parent-specific: Children list
                    if (_parentData != null &&
                        _parentData!['children'] != null) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.profileMyChildrenTitle ?? 'My Children',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.profileChildrenSubtitle ??
                            'Tap on a child to view or edit their information',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_parentData!['children'] as List).map((child) {
                        final outlineColor = Theme.of(
                          context,
                        ).colorScheme.outline;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: outlineColor),
                          ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                    l10n?.profileBirthdayLabel ?? 'Birthday',
                                    child['birthday'],
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
                                          label: Text(
                                            l10n?.profileActionMessage ??
                                                'Message',
                                          ),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 600;
                          if (isCompact) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  l10n?.profileManageStudentsTitle ??
                                      'Manage Students',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: Text(
                                    l10n?.profileActionAddStudent ??
                                        'Add Student',
                                  ),
                                  onPressed: _showAddStudentsToTeacherDialog,
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.groups_2_outlined),
                                  label: Text(
                                    l10n?.profileCreateGroup ?? 'Create Group',
                                  ),
                                  onPressed: _showCreateGroupDialog,
                                ),
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n?.profileManageStudentsTitle ??
                                    'Manage Students',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.person_add_alt_1),
                                label: Text(
                                  l10n?.profileActionAddStudent ??
                                      'Add Student',
                                ),
                                onPressed: _showAddStudentsToTeacherDialog,
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.groups_2_outlined),
                                label: Text(
                                  l10n?.profileCreateGroup ?? 'Create Group',
                                ),
                                onPressed: _showCreateGroupDialog,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.profileManageStudentsSubtitle ??
                            'Manage students assigned to you',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _teacherStudentsSearchController,
                        builder: (context, value, child) {
                          return TextField(
                            controller: _teacherStudentsSearchController,
                            onChanged: _onTeacherStudentsSearchChanged,
                            decoration: InputDecoration(
                              labelText:
                                  l10n?.adminSearchStudents ??
                                  'Search students',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: value.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip:
                                          l10n?.commonClearSearch ??
                                          'Clear search',
                                      icon: const Icon(Icons.close),
                                      onPressed: _clearTeacherStudentsSearch,
                                    ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (filteredTeacherStudents.isEmpty)
                        Text(
                          _teacherStudentsSearchQuery.isEmpty
                              ? (l10n?.profileNoStudentsAssigned ??
                                    'No students assigned yet')
                              : (l10n?.adminNoUsers ?? 'No users found'),
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 700;

                            return Column(
                              children: pagedTeacherStudents.map((student) {
                                final fullName =
                                    student['full_name']?.toString() ??
                                    'Unknown';
                                final username =
                                    student['username']?.toString() ?? '';
                                final studentId = student['user_id'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fullName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '@$username',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (isCompact)
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: [
                                              IconButton(
                                                tooltip:
                                                    l10n?.profileActionViewProfile ??
                                                    'View Profile',
                                                icon: const Icon(
                                                  Icons.visibility,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _showStudentProfileDialog(
                                                      student,
                                                    ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    l10n?.profileActionAssignHometask ??
                                                    'Assign Hometask',
                                                icon: const Icon(
                                                  Icons.assignment_add,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _showAssignHometaskDialog(
                                                      student,
                                                    ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    l10n?.profileActionMessage ??
                                                    'Message',
                                                icon: const Icon(Icons.message),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () =>
                                                    _startChatWithUser(
                                                      student['user_id'] as int,
                                                      student['full_name']
                                                          as String,
                                                    ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    l10n?.profileActionRemoveStudent ??
                                                    'Remove from Students',
                                                icon: const Icon(
                                                  Icons.person_remove,
                                                  color: Colors.red,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () {
                                                  if (studentId is int) {
                                                    _removeStudentFromTeacher(
                                                      studentId,
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          )
                                        else
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.visibility,
                                                ),
                                                label: Text(
                                                  l10n?.profileActionViewProfile ??
                                                      'View Profile',
                                                ),
                                                onPressed: () =>
                                                    _showStudentProfileDialog(
                                                      student,
                                                    ),
                                              ),
                                              ElevatedButton.icon(
                                                icon: const Icon(
                                                  Icons.assignment_add,
                                                ),
                                                label: Text(
                                                  l10n?.profileActionAssignHometask ??
                                                      'Assign Hometask',
                                                ),
                                                onPressed: () =>
                                                    _showAssignHometaskDialog(
                                                      student,
                                                    ),
                                              ),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.message),
                                                label: Text(
                                                  l10n?.profileActionMessage ??
                                                      'Message',
                                                ),
                                                onPressed: () =>
                                                    _startChatWithUser(
                                                      student['user_id'] as int,
                                                      student['full_name']
                                                          as String,
                                                    ),
                                              ),
                                              TextButton.icon(
                                                icon: const Icon(
                                                  Icons.person_remove,
                                                  color: Colors.red,
                                                ),
                                                label: Text(
                                                  l10n?.profileActionRemoveStudent ??
                                                      'Remove from Students',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  if (studentId is int) {
                                                    _removeStudentFromTeacher(
                                                      studentId,
                                                    );
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
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final start = totalFilteredTeacherStudents == 0
                                ? 0
                                : teacherStudentsStartIndex + 1;
                            final end = teacherStudentsEndIndex;
                            final rowsLabel = l10n?.adminRows ?? 'Rows:';
                            final showingLabel =
                                l10n?.adminShowingRange(
                                  start,
                                  end,
                                  totalFilteredTeacherStudents,
                                ) ??
                                'Showing $start-$end of $totalFilteredTeacherStudents';

                            final pageSizeControl = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(rowsLabel),
                                const SizedBox(width: 8),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _teacherStudentsPageSize,
                                    onChanged: (value) {
                                      if (value != null) {
                                        _setTeacherStudentsPageSize(value);
                                      }
                                    },
                                    items: const [10, 20, 30, 50]
                                        .map(
                                          (size) => DropdownMenuItem(
                                            value: size,
                                            child: Text(size.toString()),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            );

                            final navControl = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip:
                                      l10n?.commonPrevious ?? 'Previous page',
                                  onPressed: _teacherStudentsCurrentPage > 1
                                      ? () => _changeTeacherStudentsPage(
                                          -1,
                                          teacherStudentsMaxPage,
                                        )
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text(
                                  '$_teacherStudentsCurrentPage / $teacherStudentsMaxPage',
                                ),
                                IconButton(
                                  tooltip: l10n?.commonNext ?? 'Next page',
                                  onPressed:
                                      _teacherStudentsCurrentPage <
                                          teacherStudentsMaxPage
                                      ? () => _changeTeacherStudentsPage(
                                          1,
                                          teacherStudentsMaxPage,
                                        )
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            );

                            final compact = constraints.maxWidth < 700;
                            if (compact) {
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Text(showingLabel),
                                    const SizedBox(width: 8),
                                    pageSizeControl,
                                    const SizedBox(width: 8),
                                    navControl,
                                  ],
                                ),
                              );
                            }

                            return Row(
                              children: [
                                Text(showingLabel),
                                const Spacer(),
                                pageSizeControl,
                                const SizedBox(width: 12),
                                navControl,
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        l10n?.profileGroupsTitle ?? 'Groups',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(l10n?.hometasksActive ?? 'Active'),
                            selected: !_showArchivedGroups,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() {
                                _showArchivedGroups = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(l10n?.hometasksArchive ?? 'Archive'),
                            selected: _showArchivedGroups,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() {
                                _showArchivedGroups = true;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (visibleTeacherGroups.isEmpty)
                        Text(
                          l10n?.profileNoGroupsYet ?? 'No groups yet',
                          style: TextStyle(color: Colors.grey[600]),
                        )
                      else
                        ...visibleTeacherGroups.map((group) {
                          final groupId = group['id'] as int?;
                          final groupName =
                              group['name']?.toString() ?? 'Group';
                          final status =
                              (group['status']?.toString() ?? 'active')
                                  .toLowerCase();
                          final isArchived = status == 'archived';
                          final members =
                              (group['students'] as List<dynamic>? ?? [])
                                  .whereType<Map<String, dynamic>>()
                                  .toList();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              title: Text(groupName),
                              subtitle: Text(
                                '${members.length} ${l10n?.profileStudentsLabel ?? 'students'} • ${isArchived ? (l10n?.profileStatusArchived ?? 'Archived') : (l10n?.profileStatusActive ?? 'Active')}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    8,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _showEditGroupDialog(group),
                                        icon: const Icon(Icons.edit),
                                        label: Text(
                                          l10n?.profileEditMembers ??
                                              'Edit members',
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: groupId == null
                                            ? null
                                            : () => _updateTeacherGroup(
                                                groupId: groupId,
                                                archived: !isArchived,
                                              ),
                                        icon: Icon(
                                          isArchived
                                              ? Icons.unarchive_outlined
                                              : Icons.archive_outlined,
                                        ),
                                        label: Text(
                                          isArchived
                                              ? (l10n?.profileUnarchiveGroup ??
                                                    'Unarchive')
                                              : (l10n?.profileArchiveGroup ??
                                                    'Archive'),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: groupId == null
                                            ? null
                                            : () async {
                                                final confirmDelete =
                                                    await _showLockedConfirmationDialog(
                                                      title:
                                                          l10n?.profileDeleteGroupTitle ??
                                                          'Delete group',
                                                      content:
                                                          l10n?.profileDeleteGroupMessage ??
                                                          'Delete this group permanently? Feed and group history will be removed.',
                                                      confirmLabel:
                                                          l10n?.commonDelete ??
                                                          'Delete',
                                                    );
                                                if (!confirmDelete ||
                                                    !mounted) {
                                                  return;
                                                }
                                                await _deleteTeacherGroup(
                                                  groupId,
                                                );
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                        label: Text(
                                          l10n?.commonDelete ?? 'Delete',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...members.map(
                                  (member) => ListTile(
                                    dense: true,
                                    title: Text(
                                      member['full_name']?.toString() ??
                                          member['username']?.toString() ??
                                          'Unknown',
                                    ),
                                    subtitle: Text(
                                      '@${member['username'] ?? ''}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _generateStudentRegistrationLinkForTeacher,
                        icon: const Icon(Icons.link),
                        label: Text(
                          l10n?.profileGenerateStudentLink ??
                              'Generate Student Registration Link',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],

                    if (_studentData != null && !_isEditing) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        l10n?.profileTeachersTitle ?? 'Teachers',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n?.profileTeachersSubtitle ??
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
                          l10n?.profileNoTeachersAssigned ??
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
                                        label: Text(
                                          l10n?.profileActionViewProfile ??
                                              'View Profile',
                                        ),
                                        onPressed: () =>
                                            _showTeacherProfileDialog(teacher),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.message),
                                        label: Text(
                                          l10n?.profileActionMessage ??
                                              'Message',
                                        ),
                                        onPressed: () => _startChatWithUser(
                                          teacher['user_id'] as int,
                                          teacher['full_name'] as String,
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.logout,
                                          color: Colors.red,
                                        ),
                                        label: Text(
                                          l10n?.profileActionLeaveTeacher ??
                                              'Leave Teacher',
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                        onPressed: () {
                                          final teacherId = teacher['user_id'];
                                          final studentId = _userId;
                                          if (teacherId is int &&
                                              studentId is int) {
                                            _removeTeacherFromStudent(
                                              studentId,
                                              teacherId,
                                            );
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

          if (!_isAdminView) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.languageTitle ?? 'Language',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: localeService.locale?.languageCode ?? 'de',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'de',
                          child: Text(l10n?.languageGerman ?? 'German'),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(l10n?.languageEnglish ?? 'English'),
                        ),
                        DropdownMenuItem(
                          value: 'ru',
                          child: Text(l10n?.languageRussian ?? 'Russian'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          localeService.setLocale(value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.securityTitle ?? 'Security',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text(
                        l10n?.changePasswordTitle ?? 'Change Password',
                      ),
                      subtitle: Text(
                        l10n?.changePasswordSubtitle ??
                            'Update your account password',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _isEditing ? null : _showChangePasswordDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
