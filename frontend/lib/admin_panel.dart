import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'auth.dart';
import 'profile_screen.dart';
import 'config/app_config.dart';
import 'l10n/app_localizations.dart';

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
  int _currentPage = 1;
  int _pageSize = 20;
  int _totalUsers = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  bool _showAddButtons = false;

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
  Future<void> _deleteUser(User user);
  Future<void> _makeUserStudent(
    int userId,
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
    if (widget.username != null && widget.username!.isNotEmpty) {
      _searchQuery = widget.username!.trim();
      _searchController.text = _searchQuery;
    }
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final trimmed = value.trim();
      if (trimmed == _searchQuery) return;
      setState(() {
        _searchQuery = trimmed;
        _currentPage = 1;
      });
      _loadUsers();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _setPageSize(int pageSize) {
    if (pageSize == _pageSize) return;
    setState(() {
      _pageSize = pageSize;
      _currentPage = 1;
    });
    _loadUsers();
  }

  void _changePage(int delta) {
    final maxPage = (_totalUsers / _pageSize).ceil().clamp(1, 999999);
    final nextPage = (_currentPage + delta).clamp(1, maxPage);
    if (nextPage == _currentPage) return;
    setState(() {
      _currentPage = nextPage;
    });
    _loadUsers();
  }

  Widget _buildPaginationControls() {
    if (_totalUsers == 0) {
      return const SizedBox.shrink();
    }

    final maxPage = (_totalUsers / _pageSize).ceil().clamp(1, 999999);
    final start = min((_currentPage - 1) * _pageSize + 1, _totalUsers);
    final end = min(_currentPage * _pageSize, _totalUsers);
    final pageLabel = Text(
      AppLocalizations.of(context)?.adminShowingRange(start, end, _totalUsers) ??
          'Showing $start-$end of $_totalUsers',
    );

    final sizeDropdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(AppLocalizations.of(context)?.adminRows ?? 'Rows:'),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _pageSize,
            onChanged: (value) {
              if (value != null) {
                _setPageSize(value);
              }
            },
            items: const [10, 20, 50]
                .map((size) => DropdownMenuItem(
                      value: size,
                      child: Text(size.toString()),
                    ))
                .toList(),
          ),
        ),
      ],
    );

    final navControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: AppLocalizations.of(context)?.commonPrevious ??
              'Previous page',
          onPressed: _currentPage > 1 ? () => _changePage(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$_currentPage / $maxPage'),
        IconButton(
          tooltip: AppLocalizations.of(context)?.commonNext ?? 'Next page',
          onPressed: _currentPage < maxPage ? () => _changePage(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        if (isCompact) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                pageLabel,
                const SizedBox(width: 8),
                sizeDropdown,
                const SizedBox(width: 12),
                navControls,
              ],
            ),
          );
        }

        return Row(
          children: [
            pageLabel,
            const Spacer(),
            sizeDropdown,
            const SizedBox(width: 16),
            navControls,
          ],
        );
      },
    );
  }

  Widget _buildUserActions(User user) {
    final buttonPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    final compactDensity = VisualDensity.compact;
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.link, size: 16),
          label: Text(AppLocalizations.of(context)?.adminResetLink ?? 'Reset Link'),
          style: OutlinedButton.styleFrom(
            padding: buttonPadding,
            visualDensity: compactDensity,
            shape: buttonShape,
          ),
          onPressed: () => _generateResetLink(user),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.visibility, size: 16),
          label: Text(
            AppLocalizations.of(context)?.adminViewProfile ?? 'View Profile',
          ),
          style: OutlinedButton.styleFrom(
            padding: buttonPadding,
            visualDensity: compactDensity,
            shape: buttonShape,
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AdminUserProfilePage(userId: user.id),
              ),
            );
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.edit, size: 16),
          label: Text(AppLocalizations.of(context)?.adminEditUser ?? 'Edit User'),
          style: ElevatedButton.styleFrom(
            padding: buttonPadding,
            visualDensity: compactDensity,
            shape: buttonShape,
          ),
          onPressed: () => _showEditUserDialog(user),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete, size: 16),
          label: Text(AppLocalizations.of(context)?.commonDelete ?? 'Delete'),
          style: OutlinedButton.styleFrom(
            padding: buttonPadding,
            visualDensity: compactDensity,
            shape: buttonShape,
            foregroundColor: Colors.red,
          ),
          onPressed: () => _confirmDeleteUser(user),
        ),
      ],
    );
  }

  Widget _buildCompactUserList() {
    return ListView.separated(
      itemCount: _users.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName : '-',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      user.username,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    IconButton(
                      tooltip: AppLocalizations.of(context)?.adminResetLink ??
                          'Reset Link',
                      icon: const Icon(Icons.link),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _generateResetLink(user),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)?.adminViewProfile ??
                          'View Profile',
                      icon: const Icon(Icons.visibility),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminUserProfilePage(userId: user.id),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)?.adminEditUser ??
                          'Edit User',
                      icon: const Icon(Icons.edit),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showEditUserDialog(user),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)?.adminDeleteUser ??
                          'Delete User',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDeleteUser(user),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserTable(double maxWidth) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: maxWidth),
        child: SingleChildScrollView(
          child: DataTable(
            dataRowMinHeight: 48,
            dataRowMaxHeight: 64,
            columnSpacing: 24,
            columns: [
              DataColumn(
                label: Text(
                  AppLocalizations.of(context)?.adminFullName ?? 'Full Name',
                ),
              ),
              DataColumn(
                label: Text(
                  AppLocalizations.of(context)?.adminUsername ?? 'Username',
                ),
              ),
              DataColumn(
                label: Text(
                  AppLocalizations.of(context)?.adminActions ?? 'Actions',
                ),
              ),
            ],
            rows: _users.map((user) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(user.fullName.isNotEmpty ? user.fullName : '-'),
                  ),
                  DataCell(Text(user.username)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 520),
                      child: _buildUserActions(user),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlineColor = Theme.of(context).colorScheme.outline;
    final isMobile = MediaQuery.of(context).size.width < 700;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(
        children: [
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    l10n?.adminPanelTitle ?? 'Admin Panel',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n?.adminUserManagement ?? 'User Management',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadUsers,
                        tooltip: l10n?.commonRefresh ?? 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          labelText: l10n?.adminSearchUsers ??
                              'Search by username or full name',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: value.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: l10n?.commonClearSearch ??
                                      'Clear search',
                                  icon: const Icon(Icons.close),
                                  onPressed: _clearSearch,
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  if (_errorMessage != null)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 8.0 : 12.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _users.isEmpty
                            ? Center(
                                child: Text(
                                  l10n?.adminNoUsers ?? 'No users found',
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 700;
                                  if (isCompact) {
                                    return _buildCompactUserList();
                                  }
                                  return _buildUserTable(constraints.maxWidth);
                                },
                              ),
                  ),
                  if (!_isLoading)
                    Padding(
                      padding: EdgeInsets.only(top: isMobile ? 8.0 : 12.0),
                      child: _buildPaginationControls(),
                    ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
            decoration: BoxDecoration(
              color: outlineColor.withOpacity(0.12),
              border: Border(
                top: BorderSide(color: outlineColor),
              ),
            ),
            child: isMobile
                ? ExpansionTile(
                  title: Text(l10n?.adminAddUser ?? 'Add User'),
                    initiallyExpanded: _showAddButtons,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _showAddButtons = expanded;
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showEditUserDialog(null),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(l10n?.adminUser ?? 'User'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddStudentDialog,
                              icon: const Icon(Icons.school, size: 16),
                              label: Text(l10n?.adminStudent ?? 'Student'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddParentDialog,
                              icon: const Icon(Icons.family_restroom, size: 16),
                              label: Text(l10n?.adminParent ?? 'Parent'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddTeacherDialog,
                              icon: const Icon(Icons.person, size: 16),
                              label: Text(l10n?.adminTeacher ?? 'Teacher'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showEditUserDialog(null),
                        icon: const Icon(Icons.add),
                        label: Text(l10n?.adminAddUser ?? 'Add User'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddStudentDialog,
                        icon: const Icon(Icons.school),
                        label: Text(l10n?.adminAddStudent ?? 'Add Student'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddParentDialog,
                        icon: const Icon(Icons.family_restroom),
                        label: Text(l10n?.adminAddParent ?? 'Add Parent'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddTeacherDialog,
                        icon: const Icon(Icons.person),
                        label: Text(l10n?.adminAddTeacher ?? 'Add Teacher'),
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

