import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'login_screen.dart';
import 'admin_panel.dart';
import 'profile_screen.dart';
import 'hometasks_screen.dart';
import 'widgets/notification_widget.dart';

class HomeScreen extends StatefulWidget {
  final String? adminUsername;
  
  const HomeScreen({super.key, this.adminUsername});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    
    // If adminUsername is provided, navigate to admin panel
    if (widget.adminUsername != null) {
      _currentPage = AdminPanel(username: widget.adminUsername);
      _selectedIndex = 100;
    } else {
      _currentPage = const DashboardPage();
    }
  }

  void _navigateTo(Widget page, int index) {
    setState(() {
      _currentPage = page;
      _selectedIndex = index;
    });
    Navigator.of(context).pop(); // Close drawer
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
        actions: const [
          NotificationBellWidget(),
        ],
      ),
      drawer: Drawer(
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
                  const Icon(
                    Icons.piano,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Klavier',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (authService.roles.isNotEmpty)
                    Text(
                      'Roles: ${authService.roles.join(', ')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () => _navigateTo(const DashboardPage(), 0),
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Lessons'),
              selected: _selectedIndex == 1,
              onTap: () => _navigateTo(const LessonsPage(), 1),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _selectedIndex == 2,
              onTap: () => _navigateTo(const ProfileScreen(), 2),
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
                    selected: _selectedIndex == 100,
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
      body: _currentPage ?? const DashboardPage(),
    );
  }
}

// Dashboard Page
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HometasksScreen();
  }
}

// Lessons Page
class LessonsPage extends StatelessWidget {
  const LessonsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_note,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'Lessons',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your music lessons will appear here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
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
