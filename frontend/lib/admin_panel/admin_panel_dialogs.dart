part of '../admin_panel.dart';

mixin _AdminPanelDialogs on _AdminPanelStateBase {
  String _generatePassword({int length = 12}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  void _confirmDeleteUser(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.adminDeleteUserTitle ?? 'Delete User',
        ),
        content: Text(
          AppLocalizations.of(context)?.adminDeleteUserMessage(user.username) ??
              'Delete ${user.username}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteUser(user);
            },
            icon: const Icon(Icons.delete),
            label: Text(AppLocalizations.of(context)?.commonDelete ?? 'Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(User? user) {
    final usernameController =
        TextEditingController(text: user?.username ?? '');
    final fullNameController =
      TextEditingController(text: user?.fullName ?? '');
    final passwordController = TextEditingController();
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final selectedRoles = Set<String>.from(user?.roles ?? []);
    final formKey = GlobalKey<FormState>();
    final isNewUser = user == null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          isNewUser
              ? (AppLocalizations.of(context)?.adminAddUser ?? 'Add User')
              : (AppLocalizations.of(context)?.adminEditUser ?? 'Edit User'),
        ),
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminUsername ??
                          'Username',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)?.adminUsernameRequired ??
                            'Please enter a username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminFullName ??
                          'Full Name',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)?.adminFullNameRequired ??
                            'Please enter a full name';
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
                                ? (AppLocalizations.of(context)?.adminPassword ??
                                    'Password')
                                : (AppLocalizations.of(context)?.adminNewPasswordOptional ??
                                    'New Password (optional)'),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (isNewUser && (value == null || value.isEmpty)) {
                              return AppLocalizations.of(context)?.adminPasswordRequired ??
                                  'Please enter a password';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: AppLocalizations.of(context)?.adminGeneratePassword ??
                            'Generate Password',
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminEmailOptional ??
                          'Email (optional)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminPhoneOptional ??
                          'Phone (optional)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text(AppLocalizations.of(context)?.adminRoleAdmin ?? 'Admin'),
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
                    Text(
                      AppLocalizations.of(context)?.adminConvertRole ??
                          'Convert to Role:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!user.roles.contains('student'))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.school, size: 16),
                            label: Text(
                              AppLocalizations.of(context)?.profileMakeStudent ??
                                  'Make Student',
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showMakeStudentDialog(user);
                            },
                          ),
                        if (!user.roles.contains('parent'))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.family_restroom, size: 16),
                            label: Text(
                              AppLocalizations.of(context)?.profileMakeParent ??
                                  'Make Parent',
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showMakeParentDialog(user);
                            },
                          ),
                        if (!user.roles.contains('teacher'))
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person, size: 16),
                            label: Text(
                              AppLocalizations.of(context)?.profileMakeTeacher ??
                                  'Make Teacher',
                            ),
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
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          if (isNewUser)
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(
                AppLocalizations.of(context)?.adminCopyCredentials ??
                    'Copy Credentials',
              ),
              onPressed: () async {
                if (usernameController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)?.adminCredentialsRequired ??
                            'Please fill in username and password first',
                      ),
                    ),
                  );
                  return;
                }
                final credentials =
                    'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
                await Clipboard.setData(ClipboardData(text: credentials));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)?.adminCredentialsCopied ??
                            'Credentials copied to clipboard',
                      ),
                    ),
                  );
                }
              },
            ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                final rolesToSave = isNewUser
                    ? selectedRoles.toList()
                    : [
                        ...user.roles.where((r) => r != 'admin'),
                        if (selectedRoles.contains('admin')) 'admin',
                      ];
                await _saveUser(
                  userId: user?.id,
                  username: usernameController.text,
                  fullName: fullNameController.text,
                  password: passwordController.text,
                  email: emailController.text.isEmpty ? null : emailController.text,
                  phone: phoneController.text.isEmpty ? null : phoneController.text,
                  roles: rolesToSave,
                );
              }
            },
            child: Text(
              isNewUser
                  ? (AppLocalizations.of(context)?.commonAdd ?? 'Add')
                  : (AppLocalizations.of(context)?.commonSave ?? 'Save'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMakeStudentDialog(User user) {
    final birthdayController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          AppLocalizations.of(context)?.adminMakeStudentTitle(user.username) ??
              'Make ${user.username} a Student',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: birthdayController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)?.adminBirthdayLabel ??
                        'Birthday (YYYY-MM-DD)',
                    border: const OutlineInputBorder(),
                    hintText: AppLocalizations.of(context)?.adminBirthdayHint ??
                        '2010-01-15',
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return AppLocalizations.of(context)?.commonRequired ??
                          'Required';
                    }
                    final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                    if (!regex.hasMatch(value!)) {
                      return AppLocalizations.of(context)?.adminBirthdayFormat ??
                          'Format: YYYY-MM-DD';
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
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _makeUserStudent(
                  user.id,
                  birthdayController.text,
                );
              }
            },
            child: Text(AppLocalizations.of(context)?.adminConvert ?? 'Convert'),
          ),
        ],
      ),
    );
  }

  void _showMakeParentDialog(User user) async {
    final studentFilterController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedStudents = <int>{};
    String studentFilter = '';

    final studentUsers = _users.where((u) => u.roles.contains('student')).toList();
    final List<StudentInfo> students = [];

    final authService = Provider.of<AuthService>(context, listen: false);
    for (var studentUser in studentUsers) {
      try {
        final response = await http.get(
          Uri.parse('${AppConfig.instance.baseUrl}/api/students/${studentUser.id}'),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          AppLocalizations.of(context)?.adminMakeParentTitle(user.username) ??
              'Make ${user.username} a Parent',
        ),
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
                    Text(
                      AppLocalizations.of(context)?.adminSelectStudentsLabel ??
                          'Select Students (at least one):',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: studentFilterController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)?.adminSearchStudents ??
                            'Search students',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        hintText: AppLocalizations.of(context)?.commonTypeToFilter ??
                            'Type to filter...',
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
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  AppLocalizations.of(context)?.adminNoStudents ??
                                      'No students found',
                                ),
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
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          AppLocalizations.of(context)?.adminSelectStudentRequired ??
                              'At least one student required',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
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
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() &&
                  selectedStudents.isNotEmpty) {
                Navigator.of(context).pop();
                await _makeUserParent(
                  user.id,
                  selectedStudents.toList(),
                );
              }
            },
            child: Text(AppLocalizations.of(context)?.adminConvert ?? 'Convert'),
          ),
        ],
      ),
    );
  }

  void _showMakeTeacherDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          AppLocalizations.of(context)?.adminMakeTeacherTitle(user.username) ??
              'Make ${user.username} a Teacher',
        ),
        content: Text(
          AppLocalizations.of(context)?.adminMakeTeacherNote ??
              'This will grant teacher privileges to the user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _makeUserTeacher(user.id);
            },
            child: Text(AppLocalizations.of(context)?.adminConvert ?? 'Convert'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final fullNameController = TextEditingController();
    final birthdayController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(AppLocalizations.of(context)?.adminAddStudent ?? 'Add Student'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminUsername ??
                          'Username',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true
                            ? (AppLocalizations.of(context)?.commonRequired ??
                                'Required')
                            : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.adminPassword ??
                                'Password',
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) =>
                              value?.isEmpty ?? true
                                  ? (AppLocalizations.of(context)?.commonRequired ??
                                      'Required')
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: AppLocalizations.of(context)?.adminGeneratePassword ??
                            'Generate Password',
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminEmailOptional ??
                          'Email (optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminPhoneOptional ??
                          'Phone (optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminFullName ??
                          'Full Name',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true
                            ? (AppLocalizations.of(context)?.commonRequired ??
                                'Required')
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: birthdayController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminBirthdayLabel ??
                          'Birthday (YYYY-MM-DD)',
                      border: const OutlineInputBorder(),
                      hintText: AppLocalizations.of(context)?.adminBirthdayHint ??
                          '2010-01-15',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return AppLocalizations.of(context)?.commonRequired ??
                            'Required';
                      }
                      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!regex.hasMatch(value!)) {
                        return AppLocalizations.of(context)?.adminBirthdayFormat ??
                            'Format: YYYY-MM-DD';
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
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(
              AppLocalizations.of(context)?.adminCopyCredentials ??
                  'Copy Credentials',
            ),
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.adminCredentialsRequired ??
                          'Fill username and password first',
                    ),
                  ),
                );
                return;
              }
              final credentials =
                  'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.adminCredentialsCopied ??
                          'Credentials copied',
                    ),
                  ),
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
                  birthdayController.text,
                );
              }
            },
            child: Text(AppLocalizations.of(context)?.commonAdd ?? 'Add'),
          ),
        ],
      ),
    );
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

    final studentUsers = _users.where((u) => u.roles.contains('student')).toList();
    final List<StudentInfo> students = [];

    final authService = Provider.of<AuthService>(context, listen: false);
    for (var studentUser in studentUsers) {
      try {
        final response = await http.get(
          Uri.parse('${AppConfig.instance.baseUrl}/api/students/${studentUser.id}'),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(AppLocalizations.of(context)?.adminAddParent ?? 'Add Parent'),
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
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.adminUsername ??
                              'Username',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true
                                ? (AppLocalizations.of(context)?.commonRequired ??
                                    'Required')
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: passwordController,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)?.adminPassword ??
                                    'Password',
                                border: const OutlineInputBorder(),
                              ),
                              obscureText: true,
                              validator: (value) =>
                                  value?.isEmpty ?? true
                                      ? (AppLocalizations.of(context)?.commonRequired ??
                                          'Required')
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: AppLocalizations.of(context)?.adminGeneratePassword ??
                                'Generate Password',
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
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.adminEmailOptional ??
                              'Email (optional)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.adminPhoneOptional ??
                              'Phone (optional)',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: fullNameController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.adminFullName ??
                              'Full Name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true
                                ? (AppLocalizations.of(context)?.commonRequired ??
                                    'Required')
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.adminSelectChildrenLabel ??
                            'Select Children (at least one):',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: studentFilterController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.adminSearchStudents ??
                              'Search students',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.search),
                          hintText: AppLocalizations.of(context)?.commonTypeToFilter ??
                              'Type to filter...',
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
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    AppLocalizations.of(context)?.adminNoStudents ??
                                        'No students found',
                                  ),
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
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            AppLocalizations.of(context)?.adminSelectStudentRequired ??
                                'At least one student required',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
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
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(
              AppLocalizations.of(context)?.adminCopyCredentials ??
                  'Copy Credentials',
            ),
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.adminCredentialsRequired ??
                          'Fill username and password first',
                    ),
                  ),
                );
                return;
              }
              final credentials =
                  'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.adminCredentialsCopied ??
                          'Credentials copied',
                    ),
                  ),
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
            child: Text(AppLocalizations.of(context)?.commonAdd ?? 'Add'),
          ),
        ],
      ),
    );
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(AppLocalizations.of(context)?.adminAddTeacher ?? 'Add Teacher'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminUsername ??
                          'Username',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true
                            ? (AppLocalizations.of(context)?.commonRequired ??
                                'Required')
                            : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)?.adminPassword ??
                                'Password',
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: true,
                          validator: (value) =>
                              value?.isEmpty ?? true
                                  ? (AppLocalizations.of(context)?.commonRequired ??
                                      'Required')
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: AppLocalizations.of(context)?.adminGeneratePassword ??
                            'Generate Password',
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
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminEmailOptional ??
                          'Email (optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminPhoneOptional ??
                          'Phone (optional)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)?.adminFullName ??
                          'Full Name',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true
                            ? (AppLocalizations.of(context)?.commonRequired ??
                                'Required')
                            : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(
              AppLocalizations.of(context)?.adminCopyCredentials ??
                  'Copy Credentials',
            ),
            onPressed: () async {
              if (usernameController.text.isEmpty ||
                  passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.adminCredentialsRequired ??
                          'Fill username and password first',
                    ),
                  ),
                );
                return;
              }
              final credentials =
                  'Username: ${usernameController.text}\nPassword: ${passwordController.text}';
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)?.adminCredentialsCopied ??
                          'Credentials copied',
                    ),
                  ),
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
            child: Text(AppLocalizations.of(context)?.commonAdd ?? 'Add'),
          ),
        ],
      ),
    );
  }
}
