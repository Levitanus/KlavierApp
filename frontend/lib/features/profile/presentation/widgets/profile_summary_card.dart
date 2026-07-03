import 'package:flutter/material.dart';

import '../../domain/entities/user_profile.dart';

class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.fullName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('@${profile.username}'),
            if (profile.email != null && profile.email!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(profile.email!),
            ],
            if (profile.phone != null && profile.phone!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(profile.phone!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.roles
                  .map(
                    (role) => Chip(
                      label: Text(role),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
            if (profile.parentData != null && profile.parentData!.children.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Children', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...profile.parentData!.children.map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${child.fullName} (${child.status})'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
