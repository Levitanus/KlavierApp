import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'models/hometask.dart';
import 'services/hometask_service.dart';
import 'widgets/hometask_widget.dart';

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
    if (_isParent(authService)) {
      students = await hometaskService.fetchStudentsForParent();
      final selfSummary = await hometaskService.getCurrentStudentSummary();
      if (selfSummary != null &&
          !students.any((student) => student.userId == selfSummary.userId)) {
        students = [selfSummary, ...students];
      }
    } else if (_isTeacher(authService)) {
      students = await hometaskService.fetchStudentsForTeacher();
    }

    if (!mounted) return;

    if (students.isEmpty) {
      setState(() {
        _isLoadingStudents = false;
        _studentsError = 'No students available.';
      });
      return;
    }

    setState(() {
      _students = students;
      if (widget.initialStudentId != null &&
          students.any((student) => student.userId == widget.initialStudentId)) {
        _selectedStudentId = widget.initialStudentId;
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
    } else if (_isStudent(authService)) {
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
    final authService = context.watch<AuthService>();
    final hometaskService = context.watch<HometaskService>();
    final isStudent = _isStudent(authService);
    final isTeacher = _isTeacher(authService);
    final isParent = _isParent(authService);
    final canComplete = (isStudent || isParent) && !_showArchive;
    final canToggleItems = (isStudent || isParent || isTeacher) && !_showArchive;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hometasks',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadHometasks,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isParent || isTeacher) ...[
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
                  const Text('Student:'),
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
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              ChoiceChip(
                label: const Text('Active'),
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
                label: const Text('Archive'),
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
          const SizedBox(height: 12),
          Expanded(
            child: _buildHometaskBody(
              hometaskService: hometaskService,
              canComplete: canComplete,
              canReorder: isTeacher && !_showArchive,
              canToggleItems: canToggleItems,
              canAccomplish: isTeacher && !_showArchive,
              canReopen: isTeacher,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHometaskBody({
    required HometaskService hometaskService,
    required bool canComplete,
    required bool canReorder,
    required bool canToggleItems,
    required bool canAccomplish,
    required bool canReopen,
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
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final hometasks = _orderedHometasks.isNotEmpty
        ? _orderedHometasks
        : hometaskService.hometasks;

    if (hometasks.isEmpty) {
      return const Center(
        child: Text('No hometasks found.'),
      );
    }

    if (canReorder) {
      return ReorderableListView.builder(
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
              const SnackBar(content: Text('Failed to update order.')),
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
      final key = rawName.isNotEmpty ? rawName : 'Teacher #${task.teacherId}';
      grouped.putIfAbsent(key, () => []).add(task);
    }

    final teacherNames = grouped.keys.toList()..sort();

    return ListView(
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
        const SnackBar(content: Text('Failed to update checklist item.')),
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
        const SnackBar(content: Text('Failed to update progress item.')),
      );
    }
  }

  Future<void> _markCompleted(int hometaskId) async {
    final hometaskService = context.read<HometaskService>();
    final success = await hometaskService.markCompleted(hometaskId);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update hometask.')),
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
        const SnackBar(content: Text('Failed to update hometask.')),
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
        const SnackBar(content: Text('Failed to update hometask.')),
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
