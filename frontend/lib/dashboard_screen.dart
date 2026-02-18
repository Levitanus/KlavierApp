import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'models/hometask.dart';
import 'models/feed.dart';
import 'services/hometask_service.dart';
import 'services/feed_service.dart';
import 'widgets/feed_preview_card.dart';
import 'feeds_screen.dart';
import 'home_screen.dart';
import 'l10n/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  final int? initialStudentId;

  const DashboardScreen({super.key, this.initialStudentId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<StudentSummary> _students = [];
  int? _selectedStudentId;
  bool _loadingStudents = false;
  String? _studentsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedService>().fetchFeeds();
      _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    final authService = context.read<AuthService>();
    final hometaskService = context.read<HometaskService>();

    if (_isParent(authService) || _isTeacher(authService)) {
      await _loadStudents(hometaskService, authService);
      return;
    }

    if (_isStudent(authService)) {
      await hometaskService.fetchActiveForCurrentStudent();
    }
  }

  Future<void> _loadStudents(
    HometaskService hometaskService,
    AuthService authService,
  ) async {
    setState(() {
      _loadingStudents = true;
      _studentsError = null;
      _students = [];
      _selectedStudentId = null;
    });

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
        _loadingStudents = false;
        _studentsError =
            AppLocalizations.of(context)?.dashboardNoStudents ??
            'No students available.';
      });
      return;
    }

    int? selected = widget.initialStudentId;
    if (_isStudent(authService) && selfSummary != null) {
      selected = selfSummary.userId;
    }
    if (selected == null ||
        !students.any((student) => student.userId == selected)) {
      selected = students.first.userId;
    }

    setState(() {
      _students = students;
      _selectedStudentId = selected;
      _loadingStudents = false;
    });

    await hometaskService.fetchHometasksForStudent(
      studentId: selected,
      status: 'active',
    );
  }

  bool _isStudent(AuthService authService) =>
      authService.roles.contains('student');
  bool _isTeacher(AuthService authService) =>
      authService.roles.contains('teacher');
  bool _isParent(AuthService authService) =>
      authService.roles.contains('parent');

  List<Hometask> _sortedHometasks(List<Hometask> hometasks) {
    final items = List<Hometask>.from(hometasks);
    items.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) {
        return a.createdAt.compareTo(b.createdAt);
      }
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer3<AuthService, HometaskService, FeedService>(
      builder: (context, authService, hometaskService, feedService, child) {
        final hometasks = _sortedHometasks(hometaskService.hometasks);
        final feeds = feedService.feeds;
        final teacherFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'teacher')
            .toList();
        final groupFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'group')
            .toList();
        final schoolFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'school')
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n?.dashboardTitle ?? 'Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _buildHometaskSection(
              context,
              authService,
              hometaskService,
              hometasks,
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.dashboardTeacherFeeds ?? 'Teacher feeds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (teacherFeeds.isEmpty)
              Text(
                l10n?.dashboardNoTeacherFeeds ?? 'No teacher feeds yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...teacherFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  ownerLabel: _ownerLabel(feed, l10n),
                  importantLimit: 2,
                  recentLimit: 2,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Text(
              l10n?.dashboardGroupFeeds ?? 'Group feeds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (groupFeeds.isEmpty)
              Text(
                l10n?.dashboardNoGroupFeeds ?? 'No group feeds yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...groupFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  ownerLabel: _ownerLabel(feed, l10n),
                  importantLimit: 2,
                  recentLimit: 2,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Text(
              l10n?.dashboardSchoolFeed ?? 'School feed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (schoolFeeds.isEmpty)
              Text(
                l10n?.dashboardNoSchoolFeed ?? 'No school feed yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...schoolFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  ownerLabel: _ownerLabel(feed, l10n),
                  importantLimit: 2,
                  recentLimit: 2,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHometaskSection(
    BuildContext context,
    AuthService authService,
    HometaskService hometaskService,
    List<Hometask> hometasks,
  ) {
    final l10n = AppLocalizations.of(context);
    final showStudentSelector =
        _isParent(authService) || _isTeacher(authService);
    final showChildLabel = _isParent(authService) && !_isTeacher(authService);
    final selectorLabel = showChildLabel
        ? (l10n?.dashboardChildLabel ?? 'Child:')
        : (l10n?.dashboardStudentLabel ?? 'Student:');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n?.commonHometasks ?? 'Hometasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              tooltip: l10n?.commonRefresh ?? 'Refresh',
              onPressed: _loadDashboard,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (showStudentSelector) ...[
          if (_loadingStudents)
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
                    await hometaskService.fetchHometasksForStudent(
                      studentId: value,
                      status: 'active',
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
        if (hometaskService.isLoading)
          const LinearProgressIndicator()
        else if (hometasks.isEmpty)
          Text(
            l10n?.dashboardNoActiveHometasks ?? 'No active hometasks.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ...hometasks
              .take(5)
              .map(
                (task) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              HomeScreen(initialStudentId: task.studentId),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (task.dueDate != null)
                            Text(
                              _formatDate(task.dueDate!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month';
  }

  String _formatFeedTitle(Feed feed) {
    return feed.title.replaceFirst(RegExp(r'\s*Feed$'), '').trim();
  }

  String _ownerLabel(Feed feed, AppLocalizations? l10n) {
    final ownerType = feed.ownerType.toLowerCase();
    if (ownerType == 'school') {
      return l10n?.dashboardOwnerSchool ?? 'School';
    }
    if (ownerType == 'teacher') {
      return l10n?.dashboardOwnerTeacher ?? 'Teacher';
    }
    if (ownerType == 'group') {
      return l10n?.dashboardOwnerGroup ?? 'Group';
    }
    return feed.ownerType;
  }
}
