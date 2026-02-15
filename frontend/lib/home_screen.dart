import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'auth.dart';
import 'login_screen.dart';
import 'admin_panel.dart';
import 'profile_screen.dart';
import 'hometasks_screen.dart';
import 'dashboard_screen.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';
import 'services/feed_service.dart';
import 'services/hometask_service.dart';
import 'services/app_data_cache_service.dart';
import 'services/media_cache_service.dart';
import 'services/theme_service.dart';
import 'feeds_screen.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'config/app_config.dart';

class HomeScreen extends StatefulWidget {
  final String? adminUsername;
  final int? initialStudentId;
  final int? initialFeedId;
  final int? initialPostId;
  
  const HomeScreen({
    super.key,
    this.adminUsername,
    this.initialStudentId,
    this.initialFeedId,
    this.initialPostId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static String get _baseUrl => AppConfig.instance.baseUrl;
  int _selectedTabIndex = 0;
  int? _selectedDrawerIndex;
  Widget? _currentPage;
  bool _profileLoading = false;
  String? _drawerUsername;
  String? _drawerFullName;
  String? _drawerProfileImage;

  @override
  void initState() {
    super.initState();
    
    // If adminUsername is provided, navigate to admin panel
    if (widget.adminUsername != null) {
      _currentPage = AdminPanel(username: widget.adminUsername);
      _selectedDrawerIndex = 100;
    } else if (widget.initialFeedId != null) {
      _currentPage = FeedsScreen(
        initialFeedId: widget.initialFeedId,
        initialPostId: widget.initialPostId,
      );
      _selectedTabIndex = 2;
    } else if (widget.initialStudentId != null) {
      _currentPage = HometasksScreen(initialStudentId: widget.initialStudentId);
      _selectedTabIndex = 1;
    } else {
      _currentPage = const DashboardScreen();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDrawerProfile();
    });
  }

  Future<void> _loadDrawerProfile() async {
    if (_profileLoading) {
      return;
    }

    final authService = context.read<AuthService>();
    final token = authService.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final cached = await AppDataCacheService.instance
        .readJsonMap('profile', authService.userId);
    if (cached != null && mounted) {
      setState(() {
        _applyDrawerProfile(cached);
        _profileLoading = false;
      });
    }

    setState(() {
      _profileLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await AppDataCacheService.instance
            .writeJson('profile', authService.userId, data);

        setState(() {
          _applyDrawerProfile(data);
          _profileLoading = false;
        });
      } else {
        setState(() {
          _profileLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _profileLoading = false;
      });
    }
  }

  void _applyDrawerProfile(Map<String, dynamic> data) {
    final profileImage = data['profile_image'] != null &&
            data['profile_image'].toString().isNotEmpty
        ? '$_baseUrl/uploads/profile_images/${data['profile_image']}'
        : null;
    final studentData = data['student_data'] as Map<String, dynamic>?;
    final parentData = data['parent_data'] as Map<String, dynamic>?;
    final teacherData = data['teacher_data'] as Map<String, dynamic>?;
    String? fullName;

    if (data['full_name'] != null) {
      fullName = data['full_name']?.toString();
    } else if (studentData != null) {
      fullName = studentData['full_name']?.toString();
    } else if (parentData != null) {
      fullName = parentData['full_name']?.toString();
    } else if (teacherData != null) {
      fullName = teacherData['full_name']?.toString();
    }

    _drawerUsername = data['username']?.toString();
    _drawerFullName = fullName;
    _drawerProfileImage = profileImage;
  }

  Future<void> _confirmClearAppCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: const Text('Clear app data cache'),
        content: const Text('This will remove cached messages, feeds, hometasks, and profile data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authService = context.read<AuthService>();
    await AppDataCacheService.instance.clearUserData(authService.userId);
    context.read<FeedService>().clearLocalCache();
    context.read<HometaskService>().clearLocalCache();
    context.read<ChatService>().clearLocalCache();

    setState(() {
      _drawerUsername = null;
      _drawerFullName = null;
      _drawerProfileImage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App data cache cleared.')),
      );
    }
  }

  Future<void> _confirmClearMediaCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: const Text('Clear media cache'),
        content: const Text('This will remove cached images and media files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await MediaCacheService.instance.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media cache cleared.')),
      );
    }
  }

  void _navigateTo(Widget page, int index) {
    setState(() {
      _currentPage = page;
      _selectedDrawerIndex = index;
    });
    Navigator.of(context).pop(); // Close drawer
  }

  void _navigateToTab(int index) {
    setState(() {
      _selectedTabIndex = index;
      _selectedDrawerIndex = null;
      _currentPage = _pageForTab(index);
    });
  }

  Widget _pageForTab(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const HometasksScreen();
      case 2:
        return const FeedsScreen();
      case 3:
        return const ChatScreen();
      case 4:
        return const ProfileScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _navigateToPage(Widget page) {
    setState(() {
      _currentPage = page;
      _selectedDrawerIndex = null;
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = context.watch<ThemeService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark
        ? 'assets/branding/logo bright.svg'
        : 'assets/branding/logo dark.svg';
    final isNotificationsPage = _currentPage is NotificationsScreen;
    
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          logoAsset,
          height: 28,
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: _NotificationNavIcon(active: isNotificationsPage),
            tooltip: 'Notifications',
            onPressed: () => _navigateToPage(const NotificationsScreen()),
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SvgPicture.asset(
                    logoAsset,
                    height: 22,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 25),
                        backgroundImage: _drawerProfileImage != null
                          ? MediaCacheService.instance
                            .imageProvider(_drawerProfileImage!)
                          : null,
                        child: _drawerProfileImage == null
                            ? const Icon(
                                Icons.person,
                                size: 28,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _drawerFullName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _drawerUsername != null
                                  ? '@${_drawerUsername!}'
                                  : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (authService.roles.isNotEmpty)
                    Text(
                      'Roles: ${authService.roles.join(', ')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (_profileLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _selectedDrawerIndex == 200,
              onTap: () => _navigateTo(const ProfileScreen(), 200),
            ),
            const Divider(),
            if (authService.isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('User Management'),
                selected: _selectedDrawerIndex == 100,
                onTap: () => _navigateTo(const AdminPanel(), 100),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeMode>(
                value: themeService.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cached),
              title: const Text('Clear app data cache'),
              onTap: _confirmClearAppCache,
            ),
            ListTile(
              leading: const Icon(Icons.image_not_supported),
              title: const Text('Clear media cache'),
              onTap: _confirmClearMediaCache,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
      body: _currentPage ?? const DashboardScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _navigateToTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist),
            activeIcon: Icon(Icons.checklist),
            label: 'Hometasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: 'Feeds',
          ),
          BottomNavigationBarItem(
            icon: _ChatNavIcon(active: false),
            activeIcon: _ChatNavIcon(active: true),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _NotificationNavIcon extends StatelessWidget {
  final bool active;

  const _NotificationNavIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        final unreadCount = notificationService.unreadCount;
        final icon = Icon(
          active ? Icons.notifications : Icons.notifications_none,
        );

        if (unreadCount <= 0) {
          return icon;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatNavIcon extends StatelessWidget {
  final bool active;

  const _ChatNavIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, ChatService>(
      builder: (context, authService, chatService, child) {
        final unreadCount = authService.isAdmin
            ? chatService.totalUnreadCount
            : chatService.personalUnreadCount;
        final icon = Icon(
          active ? Icons.chat_bubble : Icons.chat_bubble_outline,
        );

        if (unreadCount <= 0) {
          return icon;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Profile Page
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person,
            size: 80,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            'Profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your profile information',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
