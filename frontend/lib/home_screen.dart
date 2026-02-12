import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'login_screen.dart';
import 'admin_panel.dart';
import 'profile_screen.dart';
import 'hometasks_screen.dart';
import 'dashboard_screen.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';
import 'feeds_screen.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';

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
  static const String _baseUrl = 'http://localhost:8080';
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

        setState(() {
          _drawerUsername = data['username']?.toString();
          _drawerFullName = fullName;
          _drawerProfileImage = profileImage;
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
        return const NotificationsScreen();
      default:
        return const DashboardScreen();
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klavier'),
        automaticallyImplyLeading: false,
        actions: [
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 25),
                        backgroundImage: _drawerProfileImage != null
                            ? NetworkImage(_drawerProfileImage!)
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
              ExpansionTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('User Management'),
                    selected: _selectedDrawerIndex == 100,
                    onTap: () => _navigateTo(const AdminPanel(), 100),
                  ),
                ],
              ),
              const Divider(),
            ],
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
            icon: _NotificationNavIcon(active: false),
            activeIcon: _NotificationNavIcon(active: true),
            label: 'Notifications',
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
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
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
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
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
