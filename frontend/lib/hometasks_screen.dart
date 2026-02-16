import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'models/hometask.dart';
import 'services/hometask_service.dart';
import 'widgets/hometask_widget.dart';
import 'l10n/app_localizations.dart';

class HometasksScreen extends StatefulWidget {
  final int? initialStudentId;

  const HometasksScreen({super.key, this.initialStudentId});

  @override
  State<HometasksScreen> createState() => _HometasksScreenState();
}

class _HometasksScreenState extends State<HometasksScreen> {
  bool _showArchive = false;
  bool _isLoadingStudents = false;
  String? _studentsError;
  int? _selectedStudentId;
  List<StudentSummary> _students = [];
  List<Hometask> _orderedHometasks = [];
  String _lastRoleSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScreen();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authService = context.read<AuthService>();
    final roleSignature = authService.roles.join('|');
    if (roleSignature != _lastRoleSignature) {
      _lastRoleSignature = roleSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initScreen();
        }
      });
    }
  }

  Future<void> _initScreen() async {
    final authService = context.read<AuthService>();
    if (_isParent(authService) || _isTeacher(authService)) {
      await _loadStudents();
      return;
    }

    if (_isStudent(authService)) {
      await _loadHometasks();
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoadingStudents = true;
      _studentsError = null;
      _students = [];
      _selectedStudentId = null;
    });

    final authService = context.read<AuthService>();
    final hometaskService = context.read<HometaskService>();

    List<StudentSummary> students = [];
    StudentSummary? selfSummary;
    if (_isTeacher(authService)) {
      students = await hometaskService.fetchStudentsForTeacher();
    } else if (_isParent(authService)) {
      students = await hometaskService.fetchStudentsForParent();
      selfSummary = await hometaskService.getCurrentStudentSummary();
      if (selfSummary != null) {
        final selfId = selfSummary.userId;
        if (!students.any((student) => student.userId == selfId)) {
          students = [selfSummary, ...students];
        }
      }
    }

    if (!mounted) return;

    if (students.isEmpty) {
      setState(() {
        _isLoadingStudents = false;
        _studentsError = AppLocalizations.of(context)?.dashboardNoStudents ??
            'No students available.';
      });
      return;
    }

    setState(() {
      _students = students;
      if (widget.initialStudentId != null &&
          students.any((student) => student.userId == widget.initialStudentId)) {
        _selectedStudentId = widget.initialStudentId;
      } else if (_isStudent(authService) && selfSummary != null) {
        _selectedStudentId = selfSummary.userId;
      } else {
        _selectedStudentId = students.first.userId;
      }
      _isLoadingStudents = false;
    });

    await _loadHometasks();
  }

  Future<void> _loadHometasks() async {
    final authService = context.read<AuthService>();
    final hometaskService = context.read<HometaskService>();

    if (_isParent(authService) || _isTeacher(authService)) {
      final studentId = _selectedStudentId;
      if (studentId == null) return;
      await hometaskService.fetchHometasksForStudent(
        studentId: studentId,
        status: _showArchive ? 'archived' : 'active',
      );
      return;
    }

    if (_isStudent(authService)) {
      if (_showArchive) {
        final studentId = await hometaskService.getCurrentUserId();
        if (studentId == null) return;
        await hometaskService.fetchHometasksForStudent(
          studentId: studentId,
          status: 'archived',
        );
      } else {
        await hometaskService.fetchActiveForCurrentStudent();
      }
    }

    if (!mounted) return;
    setState(() {
      _orderedHometasks = List<Hometask>.from(hometaskService.hometasks);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = context.watch<AuthService>();
    final hometaskService = context.watch<HometaskService>();
    final isStudent = _isStudent(authService);
    final isTeacher = _isTeacher(authService);
    final isParent = _isParent(authService);
    final showStudentSelector = isParent || isTeacher;
    final showChildLabel = isParent && !isTeacher;
    final selectorLabel = showChildLabel
      ? (l10n?.dashboardChildLabel ?? 'Child:')
      : (l10n?.dashboardStudentLabel ?? 'Student:');
    final canComplete = (isStudent || isParent) && !_showArchive;
    final canToggleItems = (isStudent || isParent || isTeacher) && !_showArchive;
    final listBottomPadding = isTeacher ? 96.0 : 16.0;
    StudentSummary? selectedStudent;
    final selectedStudentId = _selectedStudentId;
    if (selectedStudentId != null) {
      for (final student in _students) {
        if (student.userId == selectedStudentId) {
          selectedStudent = student;
          break;
        }
      }
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.commonHometasks ?? 'Hometasks',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n?.commonRefresh ?? 'Refresh',
                    onPressed: _loadHometasks,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (showStudentSelector) ...[
                if (_isLoadingStudents)
                  const LinearProgressIndicator()
                else if (_studentsError != null)
                  Text(
                    _studentsError!,
                    style: const TextStyle(color: Colors.redAccent),
                  )
                else
                  Row(
                    children: [
                      Text(selectorLabel),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _selectedStudentId,
                        items: _students
                            .map(
                              (student) => DropdownMenuItem(
                                value: student.userId,
                                child: Text(student.fullName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() {
                            _selectedStudentId = value;
                          });
                          await _loadHometasks();
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  ChoiceChip(
                    label: Text(l10n?.hometasksActive ?? 'Active'),
                    selected: !_showArchive,
                    onSelected: (selected) async {
                      if (selected) {
                        setState(() {
                          _showArchive = false;
                        });
                        await _loadHometasks();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l10n?.hometasksArchive ?? 'Archive'),
                    selected: _showArchive,
                    onSelected: (selected) async {
                      if (selected) {
                        setState(() {
                          _showArchive = true;
                        });
                        await _loadHometasks();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildHometaskBody(
                  hometaskService: hometaskService,
                  canComplete: canComplete,
                  canReorder: isTeacher && !_showArchive,
                  canToggleItems: canToggleItems,
                  canAccomplish: isTeacher && !_showArchive,
                  canReopen: isTeacher,
                  bottomPadding: listBottomPadding,
                ),
              ),
            ],
          ),
        ),
        if (isTeacher)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: selectedStudent == null
                  ? null
                  : () => _showAssignHometaskDialog(selectedStudent!),
              icon: const Icon(Icons.assignment_add),
              label: Text(l10n?.hometasksAssign ?? 'Assign Hometask'),
            ),
          ),
      ],
    );
  }

  Widget _buildHometaskBody({
    required HometaskService hometaskService,
    required bool canComplete,
    required bool canReorder,
    required bool canToggleItems,
    required bool canAccomplish,
    required bool canReopen,
    required double bottomPadding,
  }) {
    if (hometaskService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hometaskService.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hometaskService.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadHometasks,
              child: Text(
                AppLocalizations.of(context)?.commonRetry ?? 'Retry',
              ),
            ),
          ],
        ),
      );
    }

    final hometasks = _orderedHometasks.isNotEmpty
        ? _orderedHometasks
        : hometaskService.hometasks;

    if (hometasks.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.hometasksNone ??
              'No hometasks found.',
        ),
      );
    }

    if (canReorder) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: hometasks.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }

          setState(() {
            final item = hometasks.removeAt(oldIndex);
            hometasks.insert(newIndex, item);
            _orderedHometasks = List<Hometask>.from(hometasks);
          });

          final studentId = _selectedStudentId;
          if (studentId == null) return;
          final success = await hometaskService.updateHometaskOrder(
            studentId: studentId,
            orderedIds: hometasks.map((task) => task.id).toList(),
          );

          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)?.hometasksUpdateOrderFailed ??
                      'Failed to update order.',
                ),
              ),
            );
          }
        },
        itemBuilder: (context, index) {
          final hometask = hometasks[index];
          return Padding(
            key: ValueKey('hometask-${hometask.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: HometaskWidget(
              hometask: hometask,
              showDragHandle: true,
              dragHandleIndex: index,
              canEditItems: _isTeacher(context.read<AuthService>()),
              onMarkCompleted: canComplete
                  ? () async => _markCompleted(hometask.id)
                  : null,
              onToggleItem: canToggleItems &&
                      hometask.hometaskType == HometaskType.checklist
                  ? (index, value) async => _toggleChecklistItem(
                        hometaskId: hometask.id,
                        itemIndex: index,
                        isDone: value,
                      )
                  : null,
              onChangeProgress: canToggleItems &&
                      hometask.hometaskType == HometaskType.progress
                  ? (index, progress) async => _changeProgressItem(
                        hometaskId: hometask.id,
                        itemIndex: index,
                        progress: progress,
                      )
                  : null,
              onSaveItems: _isTeacher(context.read<AuthService>())
                  ? (items) async => _saveHometaskItems(
                        hometaskId: hometask.id,
                        items: items,
                      )
                  : null,
              onMarkAccomplished: canAccomplish
                  ? () async => _markAccomplished(hometask.id)
                  : null,
              onMarkReopened: canReopen
                  ? () async => _markReopened(hometask.id)
                  : null,
            ),
          );
        },
      );
    }

    final grouped = <String, List<Hometask>>{};
    for (final task in hometasks) {
      final rawName = task.teacherName?.trim() ?? '';
      final key = rawName.isNotEmpty
          ? rawName
          : (AppLocalizations.of(context)?.hometasksTeacherFallback(
                  task.teacherId,
                ) ??
              'Teacher #${task.teacherId}');
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final teacherNames = grouped.keys.toList()..sort();

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: teacherNames
          .map(
            (teacherName) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(teacherName),
                children: grouped[teacherName]!
                    .map(
                      (hometask) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: HometaskWidget(
                          hometask: hometask,
                          canEditItems: _isTeacher(context.read<AuthService>()),
                          onMarkCompleted: canComplete
                              ? () async => _markCompleted(hometask.id)
                              : null,
                          onToggleItem: canToggleItems &&
                                  hometask.hometaskType ==
                                      HometaskType.checklist
                              ? (index, value) async => _toggleChecklistItem(
                                    hometaskId: hometask.id,
                                    itemIndex: index,
                                    isDone: value,
                                  )
                              : null,
                          onChangeProgress: canToggleItems &&
                                  hometask.hometaskType ==
                                      HometaskType.progress
                              ? (index, progress) async => _changeProgressItem(
                                    hometaskId: hometask.id,
                                    itemIndex: index,
                                    progress: progress,
                                  )
                              : null,
                          onSaveItems: _isTeacher(context.read<AuthService>())
                              ? (items) async => _saveHometaskItems(
                                    hometaskId: hometask.id,
                                    items: items,
                                  )
                              : null,
                          onMarkAccomplished: canAccomplish
                              ? () async => _markAccomplished(hometask.id)
                              : null,
                          onMarkReopened: canReopen
                              ? () async => _markReopened(hometask.id)
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }

  void _showAssignHometaskDialog(StudentSummary student) {
    final l10n = AppLocalizations.of(context);
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
            title: Text(
              l10n?.hometasksAssignTitle(student.fullName) ??
                  'Assign Hometask to ${student.fullName}',
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                        decoration: InputDecoration(
                          labelText: l10n?.hometasksTitleLabel ?? 'Title',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? l10n?.hometasksTitleRequired ??
                                    'Title is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n?.hometasksDescriptionLabel ??
                              'Description (optional)',
                          border: const OutlineInputBorder(),
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n?.hometasksDueDate ?? 'Due date'),
                        subtitle: Text(
                          dueDate != null
                              ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
                              : l10n?.hometasksNoDueDate ?? 'No due date',
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
                        decoration: InputDecoration(
                          labelText: l10n?.hometasksRepeatLabel ?? 'Repeat',
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text(l10n?.hometasksRepeatNone ?? 'No repeat'),
                          ),
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text(l10n?.hometasksRepeatDaily ?? 'Each day'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text(l10n?.hometasksRepeatWeekly ?? 'Each week'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text(l10n?.hometasksRepeatCustom ?? 'Custom interval'),
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
                          decoration: InputDecoration(
                            labelText: l10n?.hometasksRepeatEveryDays ??
                                'Repeat every (days)',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (repeatSelection != 'custom') {
                              return null;
                            }
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return l10n?.hometasksRepeatCustomInvalid ??
                                  'Enter a positive number of days';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<HometaskType>(
                        initialValue: selectedType,
                        decoration: InputDecoration(
                          labelText: l10n?.hometasksTypeLabel ?? 'Hometask type',
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: HometaskType.simple,
                            child: Text(l10n?.hometasksTypeSimple ?? 'Simple'),
                          ),
                          DropdownMenuItem(
                            value: HometaskType.checklist,
                            child: Text(l10n?.hometasksTypeChecklist ?? 'Checklist'),
                          ),
                          DropdownMenuItem(
                            value: HometaskType.progress,
                            child: Text(l10n?.hometasksTypeProgress ?? 'Progress'),
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
                                ? (l10n?.hometasksChecklistItems ?? 'Checklist items')
                                : (l10n?.hometasksProgressItems ?? 'Progress items'),
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
                                      labelText: l10n?.hometasksItemLabel(index + 1) ??
                                          'Item ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? (l10n?.hometasksRequired ?? 'Required')
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
                            label: Text(l10n?.hometasksAddItem ?? 'Add item'),
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
                child: Text(l10n?.commonCancel ?? 'Cancel'),
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
                          final typeLabel = selectedType == HometaskType.checklist
                              ? (l10n?.hometasksTypeChecklist ?? 'checklist')
                              : (l10n?.hometasksTypeProgress ?? 'progress');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n?.hometasksAddAtLeastOne(typeLabel) ??
                                    'Add at least one $typeLabel item.',
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
                                SnackBar(
                                  content: Text(
                                    l10n?.hometasksRepeatIntervalInvalid ??
                                        'Enter a valid repeat interval.',
                                  ),
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

                        final hometaskService = context.read<HometaskService>();
                        final success = await hometaskService.createHometask(
                          studentId: student.userId,
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
                          await _loadHometasks();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n?.hometasksAssigned ?? 'Hometask assigned.',
                              ),
                            ),
                          );
                        } else if (context.mounted) {
                          setDialogState(() {
                            isSubmitting = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n?.hometasksAssignFailed ??
                                    'Failed to assign hometask.',
                              ),
                            ),
                          );
                        }
                      },
                child: Text(l10n?.hometasksAssignAction ?? 'Assign'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleChecklistItem({
    required int hometaskId,
    required int itemIndex,
    required bool isDone,
  }) async {
    final hometaskService = context.read<HometaskService>();
    final current = _orderedHometasks.isNotEmpty
        ? _orderedHometasks
        : hometaskService.hometasks;

    final taskIndex = current.indexWhere((task) => task.id == hometaskId);
    if (taskIndex == -1) return;

    final task = current[taskIndex];
    if (itemIndex < 0 || itemIndex >= task.checklistItems.length) return;

    final updatedItems = List<ChecklistItem>.from(task.checklistItems);
    final existing = updatedItems[itemIndex];
    updatedItems[itemIndex] = ChecklistItem(
      text: existing.text,
      isDone: isDone,
    );

    setState(() {
      current[taskIndex] = task.copyWith(checklistItems: updatedItems);
      _orderedHometasks = List<Hometask>.from(current);
    });

    final success = await hometaskService.updateChecklistItems(
      hometaskId: hometaskId,
      items: updatedItems,
    );

    if (!success && mounted) {
      await _loadHometasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksChecklistUpdateFailed ??
                'Failed to update checklist item.',
          ),
        ),
      );
    }
  }

  Future<void> _saveHometaskItems({
    required int hometaskId,
    required List<ChecklistItem> items,
  }) async {
    final hometaskService = context.read<HometaskService>();
    final success = await hometaskService.updateChecklistItems(
      hometaskId: hometaskId,
      items: items,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksItemsSaved ??
                'Items saved successfully.',
          ),
        ),
      );
      await _loadHometasks();
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksItemsSaveFailed ??
                'Failed to save items.',
          ),
        ),
      );
    }
  }

  Future<void> _changeProgressItem({
    required int hometaskId,
    required int itemIndex,
    required int progress,
  }) async {
    final hometaskService = context.read<HometaskService>();
    final current = _orderedHometasks.isNotEmpty
        ? _orderedHometasks
        : hometaskService.hometasks;

    final taskIndex = current.indexWhere((task) => task.id == hometaskId);
    if (taskIndex == -1) return;

    final task = current[taskIndex];
    if (itemIndex < 0 || itemIndex >= task.checklistItems.length) return;

    final updatedItems = List<ChecklistItem>.from(task.checklistItems);
    final existing = updatedItems[itemIndex];
    updatedItems[itemIndex] = ChecklistItem(
      text: existing.text,
      isDone: false,
      progress: progress,
    );

    setState(() {
      current[taskIndex] = task.copyWith(checklistItems: updatedItems);
      _orderedHometasks = List<Hometask>.from(current);
    });

    final success = await hometaskService.updateChecklistItems(
      hometaskId: hometaskId,
      items: updatedItems,
    );

    if (!success && mounted) {
      await _loadHometasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksProgressUpdateFailed ??
                'Failed to update progress item.',
          ),
        ),
      );
    }
  }

  Future<void> _markCompleted(int hometaskId) async {
    final hometaskService = context.read<HometaskService>();
    final success = await hometaskService.markCompleted(hometaskId);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksUpdateFailed ??
                'Failed to update hometask.',
          ),
        ),
      );
    }
    if (success && mounted) {
      await _loadHometasks();
    }
  }

  Future<void> _markAccomplished(int hometaskId) async {
    final hometaskService = context.read<HometaskService>();
    final success = await hometaskService.markAccomplished(hometaskId);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksUpdateFailed ??
                'Failed to update hometask.',
          ),
        ),
      );
    }
    if (success && mounted) {
      await _loadHometasks();
    }
  }

  Future<void> _markReopened(int hometaskId) async {
    final hometaskService = context.read<HometaskService>();
    final success = await hometaskService.markReopened(hometaskId);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksUpdateFailed ??
                'Failed to update hometask.',
          ),
        ),
      );
    }
    if (success && mounted) {
      await _loadHometasks();
    }
  }

  bool _isStudent(AuthService authService) {
    return authService.roles.contains('student');
  }

  bool _isParent(AuthService authService) {
    return authService.roles.contains('parent');
  }

  bool _isTeacher(AuthService authService) {
    return authService.roles.contains('teacher');
  }
}
