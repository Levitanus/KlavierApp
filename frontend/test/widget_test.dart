import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_school_app_frontend/features/auth/domain/entities/auth_session.dart';
import 'package:music_school_app_frontend/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:music_school_app_frontend/features/profile/application/providers/profile_provider.dart';
import 'package:music_school_app_frontend/features/profile/domain/entities/user_profile.dart';

void main() {
  testWidgets('Dashboard renders current session details', (
    WidgetTester tester,
  ) async {
    const session = AuthSession(
      token: 'token',
      username: 'teacher_user',
      roles: ['teacher'],
      userId: 42,
    );
    final profile = UserProfile(
      id: 42,
      username: 'teacher_user',
      fullName: 'Teacher User',
      createdAt: DateTime.utc(2026, 7, 4),
      roles: const ['teacher'],
      email: 'teacher@example.com',
      phone: '+49 123 4567',
      teacherData: const TeacherProfileData(
        fullName: 'Teacher User',
        status: 'active',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DashboardScreen(session: session),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Musikschule'), findsOneWidget);
    expect(find.text('Signed in as teacher_user'), findsOneWidget);
    expect(find.text('Roles: teacher'), findsOneWidget);
    expect(find.text('Teacher User'), findsOneWidget);
  });
}
