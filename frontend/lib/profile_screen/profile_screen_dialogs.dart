part of '../profile_screen.dart';

mixin _ProfileScreenDialogs on _ProfileScreenStateBase {
  @override
  Future<void> _startChatWithUser(int userId, String userName) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    try {
      final success = await chatService.startThread(userId);
      if (success && mounted) {
        final thread = chatService.threads.firstWhere(
          (t) => (t.participantBId != null &&
                  ((t.participantAId == _userId && t.participantBId == userId) ||
                   (t.participantAId == userId && t.participantBId == _userId))),
          orElse: () => throw Exception('Thread not found'),
        );
        
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(thread: thread, toAdmin: false),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: ${chatService.errorMessage}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  Future<bool> _showLockedConfirmationDialog({
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    int remainingSeconds = 5;
    Timer? timer;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remainingSeconds <= 1) {
              t.cancel();
              setDialogState(() {
                remainingSeconds = 0;
              });
            } else {
              setDialogState(() {
                remainingSeconds -= 1;
              });
            }
          });

          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () {
                  timer?.cancel();
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: remainingSeconds == 0
                    ? () {
                        timer?.cancel();
                        Navigator.of(context).pop(true);
                      }
                    : null,
                child: Text(
                  remainingSeconds == 0
                      ? confirmLabel
                      : '$confirmLabel (${remainingSeconds}s)',
                ),
              ),
            ],
          );
        },
      ),
    );

    timer?.cancel();
    return confirmed ?? false;
  }

  void _showAddStudentsToTeacherDialog() async {
    if (_userId == null) return;
    final studentFilterController = TextEditingController();
    final selectedStudents = <int>{};
    String studentFilter = '';

    final students = await _loadStudentsForSelection();
    if (!mounted) return;

    final existingStudentIds = _teacherStudents
        .map((student) => student['user_id'])
        .whereType<int>()
        .toSet();

    final availableStudents = students
        .where((student) => !existingStudentIds.contains(student.userId))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredStudents = studentFilter.isEmpty
              ? availableStudents
              : availableStudents
                  .where((s) =>
                      s.fullName
                          .toLowerCase()
                          .contains(studentFilter.toLowerCase()) ||
                      s.username
                          .toLowerCase()
                          .contains(studentFilter.toLowerCase()))
                  .toList();

          return AlertDialog(
            title: const Text('Add Students'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              child: Text('No students available'),
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
                        'Select at least one student',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedStudents.isNotEmpty
                    ? () async {
                        Navigator.of(context).pop();
                        await _addStudentsToTeacher(selectedStudents.toList());
                      }
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStudentProfileDialog(Map<String, dynamic> student) {
    List<Map<String, dynamic>> studentParents = [];
    bool isLoadingParents = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoadingParents) {
            isLoadingParents = false;
            final studentId = student['user_id'];
            if (studentId is int) {
              _fetchStudentParents(studentId).then((parents) {
                if (context.mounted) {
                  setDialogState(() {
                    studentParents = parents;
                  });
                }
              });
            }
          }

          return AlertDialog(
            title: Text(student['full_name'] ?? 'Student Profile'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${student['username'] ?? ''}'),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.cake_outlined,
                      'Birthday',
                      student['birthday']?.toString() ?? 'Not set',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.home_outlined,
                      'Address',
                      student['address']?.toString() ?? 'Not set',
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Parents',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (studentParents.isEmpty)
                      Text(
                        'No parents available',
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    else
                      ...studentParents.map((parent) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        parent['full_name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('@${parent['username'] ?? ''}'),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.message),
                                  label: const Text('Message'),
                                  onPressed: () => _startChatWithUser(
                                    parent['user_id'] as int,
                                    parent['full_name'] as String,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View Profile'),
                                  onPressed: () => _showParentProfileDialog(parent),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignHometaskDialog(Map<String, dynamic> student) {
    final rawStudentId = student['user_id'] ?? student['id'];
    if (rawStudentId is! int) return;
    final studentId = rawStudentId;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final itemControllers = [TextEditingController()];
    final repeatDaysController = TextEditingController();
    DateTime? dueDate;
    bool isSubmitting = false;
    HometaskType selectedType = HometaskType.checklist;
    String repeatSelection = 'none';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Assign Hometask to ${student['full_name'] ?? 'Student'}'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Title is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Due date'),
                        subtitle: Text(
                          dueDate != null
                              ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
                              : 'No due date',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 1),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dueDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: repeatSelection,
                        decoration: const InputDecoration(
                          labelText: 'Repeat',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('No repeat'),
                          ),
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Each day'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Each week'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('Custom interval'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            repeatSelection = value;
                          });
                        },
                      ),
                      if (repeatSelection == 'custom') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: repeatDaysController,
                          decoration: const InputDecoration(
                            labelText: 'Repeat every (days)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (repeatSelection != 'custom') {
                              return null;
                            }
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a positive number of days';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<HometaskType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Hometask type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: HometaskType.simple,
                            child: Text('Simple'),
                          ),
                          DropdownMenuItem(
                            value: HometaskType.checklist,
                            child: Text('Checklist'),
                          ),
                          DropdownMenuItem(
                            value: HometaskType.progress,
                            child: Text('Progress'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedType = value;
                          });
                        },
                      ),
                      const Divider(),
                      if (selectedType == HometaskType.checklist ||
                          selectedType == HometaskType.progress) ...[
                        Text(
                          selectedType == HometaskType.checklist
                              ? 'Checklist items'
                              : 'Progress items',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(itemControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: itemControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Item ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                  ),
                                ),
                                if (itemControllers.length > 1)
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        itemControllers.removeAt(index);
                                      });
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                              ],
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                itemControllers.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add item'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }

                        final items = selectedType == HometaskType.checklist ||
                                selectedType == HometaskType.progress
                            ? itemControllers
                                .map((controller) => controller.text.trim())
                                .where((text) => text.isNotEmpty)
                                .toList()
                            : <String>[];

                        if ((selectedType == HometaskType.checklist ||
                                selectedType == HometaskType.progress) &&
                            items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Add at least one ${selectedType == HometaskType.checklist ? 'checklist' : 'progress'} item.',
                              ),
                            ),
                          );
                          return;
                        }

                        int? repeatEveryDays;
                        switch (repeatSelection) {
                          case 'daily':
                            repeatEveryDays = 1;
                            break;
                          case 'weekly':
                            repeatEveryDays = 7;
                            break;
                          case 'custom':
                            repeatEveryDays =
                                int.tryParse(repeatDaysController.text.trim());
                            if (repeatEveryDays == null || repeatEveryDays <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid repeat interval.'),
                                ),
                              );
                              return;
                            }
                            break;
                          case 'none':
                          default:
                            repeatEveryDays = null;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                        });

                        final hometaskService =
                            context.read<HometaskService>();
                        final success = await hometaskService.createHometask(
                          studentId: studentId,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          dueDate: dueDate,
                          hometaskType: selectedType,
                          items: items.isEmpty ? null : items,
                          repeatEveryDays: repeatEveryDays,
                        );

                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hometask assigned.'),
                            ),
                          );
                        } else if (context.mounted) {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to assign hometask.'),
                            ),
                          );
                        }
                      },
                child: const Text('Assign'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTeacherProfileDialog(Map<String, dynamic> teacher) {
    List<Map<String, dynamic>> teacherStudents = [];
    bool isLoadingStudents = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoadingStudents) {
            isLoadingStudents = false;
            final teacherId = teacher['user_id'];
            if (teacherId is int) {
              _fetchTeacherStudents(teacherId).then((students) {
                if (context.mounted) {
                  setDialogState(() {
                    teacherStudents = students;
                  });
                }
              });
            }
          }

          final authService = Provider.of<AuthService>(context, listen: false);
          final canAssign = authService.roles.contains('teacher');

          return AlertDialog(
            title: Text(teacher['full_name'] ?? 'Teacher Profile'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${teacher['username'] ?? ''}'),
                    const SizedBox(height: 12),
                    if (teacher['email'] != null)
                      _buildInfoRow(
                        Icons.email_outlined,
                        'Email',
                        teacher['email'].toString(),
                      ),
                    if (teacher['phone'] != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        'Phone',
                        teacher['phone'].toString(),
                      ),
                    ],
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Students',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (teacherStudents.isEmpty)
                      Text(
                        'No students available',
                        style: TextStyle(color: Colors.grey[600]),
                      )
                    else
                      ...teacherStudents.map((student) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['full_name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('@${student['username'] ?? ''}'),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.message),
                                  label: const Text('Message'),
                                  onPressed: () => _startChatWithUser(
                                    student['user_id'] as int,
                                    student['full_name'] as String,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility),
                                  label: const Text('View Profile'),
                                  onPressed: () => _showStudentProfileDialog(student),
                                ),
                                if (canAssign) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAssignHometaskDialog(student),
                                    icon: const Icon(Icons.assignment_add),
                                    label: const Text('Assign'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showParentProfileDialog(Map<String, dynamic> parent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parent['full_name'] ?? 'Parent Profile'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${parent['username'] ?? ''}'),
              const SizedBox(height: 12),
              if (parent['email'] != null)
                _buildInfoRow(
                  Icons.email_outlined,
                  'Email',
                  parent['email'].toString(),
                ),
              if (parent['phone'] != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.phone_outlined,
                  'Phone',
                  parent['phone'].toString(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _startChatWithUser(
              parent['user_id'] as int,
              parent['full_name'] as String,
            ),
            icon: const Icon(Icons.message),
            label: const Text('Send Message'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(
        onPasswordChanged: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showMakeStudentDialog() {
    final fullNameController = TextEditingController();
    final addressController = TextEditingController();
    final birthdayController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make $_username a Student'),
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

  void _showMakeParentDialog() async {
    final fullNameController = TextEditingController();
    final studentFilterController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedStudents = <int>{};
    String studentFilter = '';

    final students = await _loadStudentsForSelection();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make $_username a Parent'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredStudents = studentFilter.isEmpty
                ? students
                : students
                    .where((s) =>
                        s.fullName
                            .toLowerCase()
                            .contains(studentFilter.toLowerCase()) ||
                        s.username
                            .toLowerCase()
                            .contains(studentFilter.toLowerCase()))
                    .toList();

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
                                  value: selectedStudents
                                      .contains(student.userId),
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

  void _showMakeTeacherDialog() {
    final fullNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make $_username a Teacher'),
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
                await _makeUserTeacher(fullNameController.text);
              }
            },
            child: const Text('Convert'),
          ),
        ],
      ),
    );
  }

  void _showAddChildrenDialog() async {
    if (_userId == null) return;
    final studentFilterController = TextEditingController();
    final selectedStudents = <int>{};
    String studentFilter = '';

    final students = await _loadStudentsForSelection();
    if (!mounted) return;

    final existingChildIds = <int>{};
    final children = _parentData?['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          final id = child['user_id'] ?? child['id'];
          if (id is int) {
            existingChildIds.add(id);
          }
        }
      }
    }

    final availableStudents = students
        .where((student) => !existingChildIds.contains(student.userId))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredStudents = studentFilter.isEmpty
              ? availableStudents
              : availableStudents
                  .where((s) =>
                      s.fullName
                          .toLowerCase()
                          .contains(studentFilter.toLowerCase()) ||
                      s.username
                          .toLowerCase()
                          .contains(studentFilter.toLowerCase()))
                  .toList();

          return AlertDialog(
            title: const Text('Add Children'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              child: Text('No students available'),
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
                                value: selectedStudents
                                    .contains(student.userId),
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
                        'Select at least one student',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedStudents.isNotEmpty
                    ? () async {
                        Navigator.of(context).pop();
                        await _addChildrenToParent(selectedStudents.toList());
                      }
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChildDetailsDialog(Map<String, dynamic> child) {
    final fullNameController = TextEditingController(text: child['full_name']);
    final addressController = TextEditingController(text: child['address']);
    final birthdayController = TextEditingController(text: child['birthday']);
    bool isEditing = false;
    bool isSaving = false;
    List<Map<String, dynamic>> childTeachers = [];
    bool isLoadingTeachers = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          if (isLoadingTeachers) {
            isLoadingTeachers = false;
            final childId = child['user_id'];
            if (childId is int) {
              _fetchStudentTeachers(childId).then((teachers) {
                if (context.mounted) {
                  setState(() {
                    childTeachers = teachers;
                  });
                }
              });
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                _buildChildAvatar(
                  child['profile_image'],
                  child['full_name'],
                  20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['full_name'],
                        style: const TextStyle(fontSize: 20),
                      ),
                      Text(
                        '@${child['username']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isEditing) ...[
                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.home),
                          border: OutlineInputBorder(),
                        ),
                        enabled: !isSaving,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: birthdayController,
                        decoration: const InputDecoration(
                          labelText: 'Birthday (YYYY-MM-DD)',
                          prefixIcon: Icon(Icons.cake),
                          border: OutlineInputBorder(),
                          hintText: '2010-01-31',
                        ),
                        enabled: !isSaving,
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: const Text('Full Name'),
                        subtitle: Text(child['full_name']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: const Text('Address'),
                        subtitle: Text(child['address']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.cake),
                        title: const Text('Birthday'),
                        subtitle: Text(child['birthday']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Username'),
                        subtitle: Text(child['username']),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (childTeachers.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Teachers',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ...childTeachers.map((teacher) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacher['full_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('@${teacher['username'] ?? ''}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.message),
                                        label: const Text('Message'),
                                        onPressed: () => _startChatWithUser(
                                          teacher['user_id'] as int,
                                          teacher['full_name'] as String,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('View Profile'),
                                        onPressed: () => _showTeacherProfileDialog(teacher),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.logout, color: Colors.red),
                                        label: const Text(
                                          'Leave Teacher',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () async {
                                          final teacherId = teacher['user_id'];
                                          final studentId = child['user_id'];
                                          if (teacherId is int && studentId is int) {
                                            await _removeTeacherFromStudent(studentId, teacherId);
                                            final updatedTeachers =
                                                await _fetchStudentTeachers(studentId);
                                            if (context.mounted) {
                                              setState(() {
                                                childTeachers = updatedTeachers;
                                              });
                                            }
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
                      ] else ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Teachers',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No teachers assigned yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (isEditing) ...[
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          setState(() {
                            isEditing = false;
                            fullNameController.text = child['full_name'];
                            addressController.text = child['address'];
                            birthdayController.text = child['birthday'];
                          });
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                          });

                          await _updateChildData(
                            child['user_id'],
                            fullNameController.text,
                            addressController.text,
                            birthdayController.text,
                          );

                          setState(() {
                            isSaving = false;
                          });

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            _loadProfile();
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _startChatWithUser(
                    child['user_id'] as int,
                    child['full_name'] as String,
                  ),
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isEditing = true;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
