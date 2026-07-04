import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_body_container.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../application/providers/hometask_provider.dart';
import '../../data/repositories/hometask_repository.dart';
import '../../domain/entities/hometask.dart';
import '../widgets/hometask_widget.dart';

class HometasksScreen extends ConsumerStatefulWidget {
  const HometasksScreen({super.key, required this.session, this.initialStudentId});

  final AuthSession session;
  final int? initialStudentId;

  @override
  ConsumerState<HometasksScreen> createState() => _HometasksScreenState();
}

class _HometasksScreenState extends ConsumerState<HometasksScreen> {
  bool _showArchive = false;
  bool _isLoadingStudents = false;
  String? _studentsError;
  int? _selectedStudentId;
  String _teacherStudentSearchQuery = '';
  final TextEditingController _teacherStudentSearchController = TextEditingController();
  List<StudentSummary> _students = [];
  List<StudentGroupSummary> _groups = [];
  List<Hometask> _orderedHometasks = [];
  String _lastRoleSignature = '';

  HometaskRepository get _repository => ref.read(hometaskRepositoryProvider(widget.session));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScreen();
    });
  }

  @override
  void dispose() {
    _teacherStudentSearchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final roleSignature = widget.session.roles.join('|');
    if (roleSignature != _lastRoleSignature) {
      _lastRoleSignature = roleSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initScreen();
        }
      });
    }
  }

  bool get _isStudent => widget.session.roles.contains('student');
  bool get _isTeacher => widget.session.roles.contains('teacher');
  bool get _isParent => widget.session.roles.contains('parent');

  Future<void> _initScreen() async {
    if (_isParent || _isTeacher) {
      await _loadStudents();
      return;
    }

    if (_isStudent) {
      await _loadHometasks();
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoadingStudents = true;
      _studentsError = null;
      _students = [];
      _groups = [];
      _selectedStudentId = null;
    });

    try {
      List<StudentSummary> students = [];
      StudentSummary? selfSummary;
      if (_isTeacher) {
        students = await _repository.fetchStudentsForTeacher();
        _groups = await _repository.fetchGroupsForTeacher();
      } else if (_isParent) {
        students = await _repository.fetchStudentsForParent();
        selfSummary = await _repository.getCurrentStudentSummary();
        if (selfSummary != null && !students.any((student) => student.userId == selfSummary!.userId)) {
          students = [selfSummary, ...students];
        }
      }

      if (!mounted) return;

      if (students.isEmpty) {
        setState(() {
          _isLoadingStudents = false;
          _studentsError = AppLocalizations.of(context)?.dashboardNoStudents ?? 'No students available.';
        });
        return;
      }

      setState(() {
        _students = students;
        if (widget.initialStudentId != null &&
            students.any((student) => student.userId == widget.initialStudentId)) {
          _selectedStudentId = widget.initialStudentId;
        } else if (_isStudent && selfSummary != null) {
          _selectedStudentId = selfSummary.userId;
        } else {
          _selectedStudentId = students.first.userId;
        }
        _isLoadingStudents = false;
      });

      await _loadHometasks();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingStudents = false;
        _studentsError = error.toString();
      });
    }
  }

  Future<void> _loadHometasks() async {
    try {
      List<Hometask> hometasks = [];
      if (_isParent || _isTeacher) {
        final studentId = _selectedStudentId;
        if (studentId == null) return;
        hometasks = await _repository.fetchHometasksForStudent(
          studentId: studentId,
          status: _showArchive ? 'archived' : 'active',
        );
      } else if (_isStudent) {
        if (_showArchive) {
          final studentId = await _repository.getCurrentUserId();
          if (studentId == null) return;
          hometasks = await _repository.fetchHometasksForStudent(
            studentId: studentId,
            status: 'archived',
          );
        } else {
          hometasks = await _repository.fetchActiveForCurrentStudent();
        }
      }

      if (!mounted) return;
      setState(() {
        _orderedHometasks = List<Hometask>.from(hometasks);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _studentsError = error.toString();
      });
    }
  }

  bool _matchesStudentSearch(StudentSummary student) {
    if (_teacherStudentSearchQuery.isEmpty) {
      return true;
    }

    final fullName = student.fullName.toLowerCase();
    final username = student.username.toLowerCase();
    return fullName.contains(_teacherStudentSearchQuery) ||
        username.contains(_teacherStudentSearchQuery);
  }

  Future<void> _onTeacherStudentSearchChanged(String value) async {
    final query = value.trim().toLowerCase();
    if (query == _teacherStudentSearchQuery) {
      return;
    }

    setState(() {
      _teacherStudentSearchQuery = query;
    });

    if (!_isTeacher) return;

    final filtered = _students.where(_matchesStudentSearch).toList(growable: false);
    if (filtered.isEmpty) return;

    final selectedStudentId = _selectedStudentId;
    if (selectedStudentId != null &&
        filtered.any((student) => student.userId == selectedStudentId)) {
      return;
    }

    setState(() {
      _selectedStudentId = filtered.first.userId;
    });
    await _loadHometasks();
  }

  void _clearTeacherStudentSearch() {
    _teacherStudentSearchController.clear();
    _onTeacherStudentSearchChanged('');
  }

  Future<void> _refreshHometasks() async {
    await _loadHometasks();
  }

  Hometask? _findHometask(int hometaskId) {
    for (final task in _orderedHometasks) {
      if (task.id == hometaskId) return task;
    }
    return null;
  }

  Future<void> _markCompleted(int hometaskId) async {
    try {
      await _repository.markCompleted(hometaskId);
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _markAccomplished(int hometaskId) async {
    try {
      await _repository.markAccomplished(hometaskId);
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _markReopened(int hometaskId) async {
    try {
      await _repository.markReopened(hometaskId);
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _toggleChecklistItem({
    required int hometaskId,
    required int itemIndex,
    required bool isDone,
  }) async {
    final task = _findHometask(hometaskId);
    if (task == null) return;

    final updatedItems = List<ChecklistItem>.from(task.checklistItems);
    if (itemIndex < 0 || itemIndex >= updatedItems.length) return;
    final item = updatedItems[itemIndex];
    updatedItems[itemIndex] = ChecklistItem(
      text: item.text,
      isDone: isDone,
      progress: item.progress,
    );

    try {
      await _repository.updateChecklistItems(hometaskId: hometaskId, items: updatedItems);
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _changeProgressItem({
    required int hometaskId,
    required int itemIndex,
    required int progress,
  }) async {
    final task = _findHometask(hometaskId);
    if (task == null) return;

    final updatedItems = List<ChecklistItem>.from(task.checklistItems);
    if (itemIndex < 0 || itemIndex >= updatedItems.length) return;
    final item = updatedItems[itemIndex];
    updatedItems[itemIndex] = ChecklistItem(
      text: item.text,
      isDone: false,
      progress: progress,
    );

    try {
      await _repository.updateChecklistItems(hometaskId: hometaskId, items: updatedItems);
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _saveHometaskItems({
    required int hometaskId,
    required List<ChecklistItem> items,
  }) async {
    try {
      await _repository.updateChecklistItems(hometaskId: hometaskId, items: items);
      await _loadHometasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.hometasksItemsSaved ?? 'Items saved successfully.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _saveEditHometask({
    required int hometaskId,
    required String title,
    required String description,
    required List<ChecklistItem> items,
    bool applyToGroup = false,
  }) async {
    try {
      await _repository.updateHometask(
        hometaskId: hometaskId,
        title: title,
        description: description.trim().isEmpty ? null : description.trim(),
        items: items,
        applyToGroup: applyToGroup,
      );
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _assignHometask({
    required String title,
    required String description,
    required HometaskType type,
    required List<String> items,
    DateTime? dueDate,
    int? repeatEveryDays,
    StudentSummary? student,
    StudentGroupSummary? group,
  }) async {
    try {
      await _repository.createHometask(
        studentId: student?.userId,
        groupId: group?.id,
        title: title,
        description: description.trim().isEmpty ? null : description.trim(),
        dueDate: dueDate,
        hometaskType: type,
        items: items.isEmpty ? null : items,
        repeatEveryDays: repeatEveryDays,
      );
      await _loadHometasks();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
      ),
    );
  }

  Future<void> _showAssignHometaskDialog({
    StudentSummary? student,
    StudentGroupSummary? group,
  }) async {
    if ((student == null && group == null) || (student != null && group != null)) {
      return;
    }

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

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              student != null
                  ? (l10n?.hometasksAssignTitle(student.fullName) ?? 'Assign Hometask to ${student.fullName}')
                  : (l10n?.hometasksAssignTitleGroup(group!.name) ?? 'Assign Hometask to group ${group!.name}'),
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
                        validator: (value) => value == null || value.trim().isEmpty
                            ? (l10n?.hometasksTitleRequired ?? 'Title is required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n?.hometasksDescriptionLabel ?? 'Description (optional)',
                          border: const OutlineInputBorder(),
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n?.hometasksDueDate ?? 'Due date'),
                        subtitle: Text(
                          dueDate != null
                              ? '${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}'
                              : (l10n?.hometasksNoDueDate ?? 'No due date'),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
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
                          DropdownMenuItem(value: 'none', child: Text(l10n?.hometasksRepeatNone ?? 'No repeat')),
                          DropdownMenuItem(value: 'daily', child: Text(l10n?.hometasksRepeatDaily ?? 'Each day')),
                          DropdownMenuItem(value: 'weekly', child: Text(l10n?.hometasksRepeatWeekly ?? 'Each week')),
                          DropdownMenuItem(value: 'custom', child: Text(l10n?.hometasksRepeatCustom ?? 'Custom interval')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => repeatSelection = value);
                        },
                      ),
                      if (repeatSelection == 'custom') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: repeatDaysController,
                          decoration: InputDecoration(
                            labelText: l10n?.hometasksRepeatEveryDays ?? 'Repeat every (days)',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (repeatSelection != 'custom') return null;
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return l10n?.hometasksRepeatCustomInvalid ?? 'Enter a positive number of days';
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
                          DropdownMenuItem(value: HometaskType.simple, child: Text(l10n?.hometasksTypeSimple ?? 'Simple')),
                          DropdownMenuItem(value: HometaskType.checklist, child: Text(l10n?.hometasksTypeChecklist ?? 'Checklist')),
                          DropdownMenuItem(value: HometaskType.progress, child: Text(l10n?.hometasksTypeProgress ?? 'Progress')),
                          const DropdownMenuItem(value: HometaskType.freeAnswer, child: Text('Free answer')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedType = value);
                        },
                      ),
                      const Divider(),
                      if (selectedType == HometaskType.checklist || selectedType == HometaskType.progress) ...[
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
                                      labelText: l10n?.hometasksItemLabel(index + 1) ?? 'Item ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) => value == null || value.trim().isEmpty
                                        ? (l10n?.hometasksRequired ?? 'Required')
                                        : null,
                                  ),
                                ),
                                if (itemControllers.length > 1)
                                  IconButton(
                                    onPressed: () {
                                      setDialogState(() {
                                        itemControllers[index].dispose();
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
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        final items = selectedType == HometaskType.checklist || selectedType == HometaskType.progress
                            ? itemControllers.map((controller) => controller.text.trim()).where((text) => text.isNotEmpty).toList(growable: false)
                            : <String>[];

                        if ((selectedType == HometaskType.checklist || selectedType == HometaskType.progress) && items.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n?.hometasksAddItem ?? 'Add at least one item.')),
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
                            repeatEveryDays = int.tryParse(repeatDaysController.text.trim());
                            break;
                          case 'none':
                          default:
                            repeatEveryDays = null;
                        }

                        setDialogState(() => isSubmitting = true);

                        await _assignHometask(
                          title: titleController.text.trim(),
                          description: descriptionController.text,
                          type: selectedType,
                          items: items,
                          dueDate: dueDate,
                          repeatEveryDays: repeatEveryDays,
                          student: student,
                          group: group,
                        );

                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    repeatDaysController.dispose();
    for (final controller in itemControllers) {
      controller.dispose();
    }
  }

  Future<void> _showEditHometaskDialog(Hometask hometask) async {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController(text: hometask.title);
    final descriptionController = TextEditingController(text: hometask.description ?? '');
    final itemControllers = hometask.checklistItems
        .map((item) => TextEditingController(text: item.text))
        .toList(growable: true);
    if (itemControllers.isEmpty) {
      itemControllers.add(TextEditingController());
    }
    bool isSubmitting = false;
    bool applyToGroup = hometask.groupAssignmentId != null;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n?.commonEdit ?? 'Edit'),
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
                        validator: (value) => value == null || value.trim().isEmpty
                            ? (l10n?.hometasksTitleRequired ?? 'Title is required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: l10n?.hometasksDescriptionLabel ?? 'Description (optional)',
                          border: const OutlineInputBorder(),
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      if (hometask.groupAssignmentId != null)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: applyToGroup,
                          onChanged: (value) {
                            setDialogState(() => applyToGroup = value ?? false);
                          },
                          title: Text(l10n?.hometasksApplyToGroup ?? 'Apply changes to group'),
                        ),
                      const Divider(),
                      Text(
                        l10n?.hometasksChecklistItems ?? 'Checklist items',
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
                                    labelText: l10n?.hometasksItemLabel(index + 1) ?? 'Item ${index + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (value) => value == null || value.trim().isEmpty
                                      ? (l10n?.hometasksRequired ?? 'Required')
                                      : null,
                                ),
                              ),
                              if (itemControllers.length > 1)
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      itemControllers[index].dispose();
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
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final items = itemControllers
                            .map((controller) => controller.text.trim())
                            .where((text) => text.isNotEmpty)
                            .map((text) => ChecklistItem(text: text, isDone: false))
                            .toList(growable: false);

                        setDialogState(() => isSubmitting = true);
                        await _saveEditHometask(
                          hometaskId: hometask.id,
                          title: titleController.text.trim(),
                          description: descriptionController.text,
                          items: items,
                          applyToGroup: applyToGroup,
                        );

                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
    for (final controller in itemControllers) {
      controller.dispose();
    }
  }

  Future<void> _showStudentFreeAnswerDialog(Hometask hometask) async {
    final l10n = AppLocalizations.of(context);
    final initialRaw = hometask.checklistItems.isNotEmpty ? hometask.checklistItems.first.text : '';
    final answerController = TextEditingController(text: initialRaw);
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n?.commonEdit ?? 'Edit'),
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            content: SizedBox(
              width: 560,
              child: TextField(
                controller: answerController,
                minLines: 8,
                maxLines: 14,
                decoration: InputDecoration(
                  labelText: 'Free answer content',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (answerController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Answer cannot be empty.')),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        await _repository.updateChecklistItems(
                          hometaskId: hometask.id,
                          items: [ChecklistItem(text: answerController.text.trim(), isDone: false)],
                        );
                        await _loadHometasks();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
            ],
          );
        },
      ),
    );

    answerController.dispose();
  }

  Future<void> _selectGroupAndAssign() async {
    if (_groups.isEmpty) return;

    final selectedGroup = await showDialog<StudentGroupSummary>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)?.hometasksSelectGroupTitle ?? 'Select Group'),
        children: _groups
            .map(
              (group) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(group),
                child: Text('${group.name} (${group.students.length})'),
              ),
            )
            .toList(growable: false),
      ),
    );

    if (!mounted || selectedGroup == null) return;
    await _showAssignHometaskDialog(group: selectedGroup);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showStudentSelector = _isParent || _isTeacher;
    final filteredStudents = _isTeacher ? _students.where(_matchesStudentSearch).toList(growable: false) : _students;
    final showChildLabel = _isParent && !_isTeacher;
    final selectorLabel = showChildLabel ? (l10n?.dashboardChildLabel ?? 'Child:') : (l10n?.dashboardStudentLabel ?? 'Student:');
    final canComplete = (_isStudent || _isParent) && !_showArchive;
    final canToggleItems = (_isStudent || _isParent || _isTeacher) && !_showArchive;
    final listBottomPadding = _isTeacher ? 96.0 : 16.0;
    StudentSummary? selectedStudent;
    if (_selectedStudentId != null) {
      for (final student in _students) {
        if (student.userId == _selectedStudentId) {
          selectedStudent = student;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.commonHometasks ?? 'Hometasks'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: l10n?.commonRefresh ?? 'Refresh',
            onPressed: _refreshHometasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: AppBodyContainer(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (showStudentSelector) ...[
                      if (_isTeacher) ...[
                        TextField(
                          controller: _teacherStudentSearchController,
                          onChanged: _onTeacherStudentSearchChanged,
                          decoration: InputDecoration(
                            labelText: l10n?.adminSearchStudents ?? 'Search students',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _teacherStudentSearchQuery.isNotEmpty
                                ? IconButton(
                                    tooltip: l10n?.commonClearSearch ?? 'Clear search',
                                    onPressed: _clearTeacherStudentSearch,
                                    icon: const Icon(Icons.close),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_isLoadingStudents)
                        const LinearProgressIndicator()
                      else if (_studentsError != null)
                        Text(_studentsError!, style: const TextStyle(color: Colors.redAccent))
                      else if (_isTeacher && filteredStudents.isEmpty)
                        Text(l10n?.dashboardNoStudents ?? 'No students available.', style: const TextStyle(color: Colors.redAccent))
                      else
                        Row(
                          children: [
                            Text(selectorLabel),
                            const SizedBox(width: 12),
                            DropdownButton<int>(
                              value: filteredStudents.any((student) => student.userId == _selectedStudentId)
                                  ? _selectedStudentId
                                  : null,
                              items: filteredStudents
                                  .map(
                                    (student) => DropdownMenuItem(
                                      value: student.userId,
                                      child: Text(student.fullName),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() => _selectedStudentId = value);
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
                              setState(() => _showArchive = false);
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
                              setState(() => _showArchive = true);
                              await _loadHometasks();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildHometaskBody(
                        canComplete: canComplete,
                        canReorder: _isTeacher && !_showArchive,
                        canToggleItems: canToggleItems,
                        canAccomplish: _isTeacher && !_showArchive,
                        canReopen: _isTeacher,
                        bottomPadding: listBottomPadding,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isTeacher)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: selectedStudent == null ? null : () => _showAssignHometaskDialog(student: selectedStudent),
                    icon: const Icon(Icons.assignment_add),
                    label: Text(l10n?.hometasksAssign ?? 'Assign Hometask'),
                  ),
                ),
              if (_isTeacher && _groups.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: 84,
                  child: FloatingActionButton.extended(
                    onPressed: _selectGroupAndAssign,
                    icon: const Icon(Icons.groups_2_outlined),
                    label: Text(l10n?.hometasksAssignToGroup ?? 'Assign to Group'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHometaskBody({
    required bool canComplete,
    required bool canReorder,
    required bool canToggleItems,
    required bool canAccomplish,
    required bool canReopen,
    required double bottomPadding,
  }) {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_studentsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _studentsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadHometasks,
              child: Text(AppLocalizations.of(context)?.commonRetry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    final hometasks = _orderedHometasks;
    if (hometasks.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)?.hometasksNone ?? 'No hometasks found.'),
      );
    }

    if (canReorder) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: hometasks.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex -= 1;

          setState(() {
            final item = hometasks.removeAt(oldIndex);
            hometasks.insert(newIndex, item);
            _orderedHometasks = List<Hometask>.from(hometasks);
          });

          final studentId = _selectedStudentId;
          if (studentId == null) return;
          try {
            await _repository.updateHometaskOrder(
              studentId: studentId,
              orderedIds: hometasks.map((task) => task.id).toList(growable: false),
            );
          } catch (error) {
            if (!mounted) return;
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
              canEditItems: false,
                onEditHometask: _isTeacher
                  ? () => _showEditHometaskDialog(hometask)
                  : _isStudent &&
                      hometask.hometaskType == HometaskType.freeAnswer &&
                      !_showArchive
                    ? () => _showStudentFreeAnswerDialog(hometask)
                    : null,
              onMarkCompleted: canComplete ? () async => _markCompleted(hometask.id) : null,
              onToggleItem: canToggleItems && hometask.hometaskType == HometaskType.checklist
                  ? (index, value) async => _toggleChecklistItem(
                        hometaskId: hometask.id,
                        itemIndex: index,
                        isDone: value,
                      )
                  : null,
              onChangeProgress: canToggleItems && hometask.hometaskType == HometaskType.progress
                  ? (index, progress) async => _changeProgressItem(
                        hometaskId: hometask.id,
                        itemIndex: index,
                        progress: progress,
                      )
                  : null,
              onSaveItems: _isTeacher ? (items) async => _saveHometaskItems(hometaskId: hometask.id, items: items) : null,
              onMarkAccomplished: canAccomplish ? () async => _markAccomplished(hometask.id) : null,
              onMarkReopened: canReopen ? () async => _markReopened(hometask.id) : null,
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
          : (AppLocalizations.of(context)?.hometasksTeacherFallback(task.teacherId) ?? 'Teacher #${task.teacherId}');
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
                          canEditItems: false,
                            onEditHometask: _isTeacher
                              ? () => _showEditHometaskDialog(hometask)
                              : _isStudent &&
                                  hometask.hometaskType == HometaskType.freeAnswer &&
                                  !_showArchive
                                ? () => _showStudentFreeAnswerDialog(hometask)
                                : null,
                          onMarkCompleted: canComplete ? () async => _markCompleted(hometask.id) : null,
                          onToggleItem: canToggleItems && hometask.hometaskType == HometaskType.checklist
                              ? (index, value) async => _toggleChecklistItem(
                                    hometaskId: hometask.id,
                                    itemIndex: index,
                                    isDone: value,
                                  )
                              : null,
                          onChangeProgress: canToggleItems && hometask.hometaskType == HometaskType.progress
                              ? (index, progress) async => _changeProgressItem(
                                    hometaskId: hometask.id,
                                    itemIndex: index,
                                    progress: progress,
                                  )
                              : null,
                          onSaveItems: _isTeacher ? (items) async => _saveHometaskItems(hometaskId: hometask.id, items: items) : null,
                          onMarkAccomplished: canAccomplish ? () async => _markAccomplished(hometask.id) : null,
                          onMarkReopened: canReopen ? () async => _markReopened(hometask.id) : null,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}