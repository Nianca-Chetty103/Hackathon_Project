import 'package:flutter/material.dart';

import 'chats.dart';
import 'profile_settings.dart';
import 'marketplace.dart';
import 'tank.dart';
import 'bursaries.dart';
import 'blog.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    required this.profile,
    required this.token,
    required this.onSignOut,
    required this.onDarkModeChanged,
    super.key,
  });

  final Map<String, dynamic> profile;
  final String token;
  final VoidCallback onSignOut;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Map<String, dynamic> _profile;

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['first_name'] as String? ?? 'Administrator';
    final email = _profile['email'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            key: const ValueKey('profile-settings-button'),
            tooltip: 'Profile & settings',
            onPressed: _openProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          TextButton.icon(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Welcome, $name',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are signed in with administrator access.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          child: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(email),
                            ],
                          ),
                        ),
                        const Chip(label: Text('Admin')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_user_outlined),
                    title: Text('Administrator account'),
                    subtitle: Text(
                      'Your administrator credentials were verified.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Moderate Marketplace'),
                    subtitle: const Text('Review and remove any listing.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MarketplacePage(
                          profile: _profile,
                          token: widget.token,
                        ),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const ValueKey('admin-chats-button'),
                    leading: const Icon(Icons.forum_outlined),
                    title: const Text('Chats'),
                    subtitle: const Text(
                      'Continue private marketplace conversations.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatInboxPage(
                          token: widget.token,
                          role: _profile['role'] as String? ?? 'admin',
                        ),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const ValueKey('admin-idea-fees-button'),
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Review Tank admin fees'),
                    subtitle: const Text(
                      'Review PayFast payments or verify a manual payment.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            IdeaFeePaymentsPage(token: widget.token),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lightbulb_outline_rounded),
                    title: const Text('Moderate The Tank'),
                    subtitle: const Text(
                      'Review and remove any business idea.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TankPage(token: widget.token, canPost: false),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const ValueKey('admin-bursaries-button'),
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('Manage Bursaries'),
                    subtitle: const Text(
                      'Post funding opportunities for users.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BursariesPage(
                          token: widget.token,
                          canPost: _profile['role'] == 'admin',
                        ),
                      ),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const ValueKey('admin-blog-button'),
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('Entrepreneurial Advice'),
                    subtitle: const Text('Publish advice for students.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlogPage(
                          token: widget.token,
                          role: _profile['role'] as String? ?? 'admin',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSettingsPage(
          profile: _profile,
          token: widget.token,
          onSignOut: widget.onSignOut,
          onDarkModeChanged: widget.onDarkModeChanged,
          onProfileUpdated: (profile) {
            if (mounted) setState(() => _profile = profile);
          },
        ),
      ),
    );
  }
}
