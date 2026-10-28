import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'community.dart';
import 'marketplace.dart';
import 'profile_settings.dart';
import 'tank.dart';
import 'bursaries.dart';
import 'blog.dart';
import 'chats.dart';
import 'auction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Map<String, dynamic> _profile;
  late final List<Widget?> _tabs;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    _tabs = List<Widget?>.filled(4, null);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return _homeTab();
      case 1:
        return ProfileSettingsPage(
          profile: _profile,
          token: widget.token,
          onSignOut: widget.onSignOut,
          onDarkModeChanged: widget.onDarkModeChanged,
          onProfileUpdated: (profile) {
            if (!mounted) return;
            setState(() {
              _profile = profile;
              _tabs[0] = _buildTab(0);
              _tabs[1] = null;
              _tabs[1] = _buildTab(1);
            });
          },
        );
      case 2:
        return ChatInboxPage(
          token: widget.token,
          role: _profile['role'] as String? ?? 'student',
        );
      case 3:
        return AuctionPage(
          token: widget.token,
          role: _profile['role'] as String? ?? 'student',
        );
      default:
        throw RangeError.index(index, _tabs);
    }
  }

  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
      _tabs[index] ??= _buildTab(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    _tabs[0] ??= _buildTab(0);
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [for (final tab in _tabs) tab ?? const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('home-bottom-navigation'),
        selectedIndex: _selectedTab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            key: ValueKey('bottom-nav-home'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            key: ValueKey('bottom-nav-profile'),
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
          NavigationDestination(
            key: ValueKey('bottom-nav-chats'),
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            key: ValueKey('bottom-nav-auction'),
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel_rounded),
            label: 'Auction',
          ),
        ],
      ),
    );
  }

  Widget _homeTab() {
    final firstName = _profile['first_name'] as String? ?? '';
    final surname = _profile['surname'] as String? ?? '';
    final fullName = '$firstName $surname'.trim();
    final greetingName = fullName.isEmpty ? 'there' : fullName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eduvos'),
        actions: [
          IconButton(
            key: const ValueKey('profile-settings-button'),
            tooltip: 'Profile & settings',
            onPressed: () => _selectTab(1),
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
              key: const ValueKey('home-dashboard-list'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _GreetingCard(name: greetingName),
                const SizedBox(height: 28),
                Text(
                  'Explore Eduvos',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect, create, and find your community on campus.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.blueGrey.shade700),
                ),
                const SizedBox(height: 16),
                _FeatureButton(
                  key: const ValueKey('marketplace-button'),
                  title: 'Marketplace',
                  subtitle: 'Browse products and services from the community.',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => _openPage(
                    context,
                    MarketplacePage(profile: _profile, token: widget.token),
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureButton(
                  key: const ValueKey('tank-button'),
                  title: 'The Tank',
                  subtitle: 'Share your business ideas and get inspired.',
                  icon: Icons.lightbulb_outline_rounded,
                  color: const Color(0xFF4F46E5),
                  onTap: () => _openPage(
                    context,
                    TankPage(
                      token: widget.token,
                      canPost: _profile['role'] == 'student',
                      canChat: _profile['role'] == 'investor',
                      showMyPosts: _profile['role'] != 'investor',
                    ),
                  ),
                ),
                if (_profile['role'] != 'investor') ...[
                  const SizedBox(height: 12),
                  _FeatureButton(
                    key: const ValueKey('communities-button'),
                    title: 'Communities',
                    subtitle:
                        'Join Eduvos communities and follow their updates.',
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () => _openPage(
                      context,
                      CommunitiesPage(token: widget.token),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _FeatureButton(
                  key: const ValueKey('auction-button'),
                  title: 'Auction',
                  subtitle: 'Make and review offers on student business ideas.',
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: () => _selectTab(3),
                ),
                if (_profile['role'] != 'investor') ...[
                  const SizedBox(height: 12),
                  _FeatureButton(
                    key: const ValueKey('bursaries-feature-button'),
                    title: 'Bursaries',
                    subtitle:
                        'Find funding opportunities and application links.',
                    icon: Icons.school_outlined,
                    color: const Color(0xFF2563EB),
                    onTap: () => _openPage(
                      context,
                      BursariesPage(
                        token: widget.token,
                        canPost: _profile['role'] == 'admin',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FeatureButton(
                    key: const ValueKey('mylms-button'),
                    title: 'MyLMS',
                    subtitle: 'Open your learning management system.',
                    icon: Icons.school_rounded,
                    color: const Color(0xFF1D4ED8),
                    onTap: () => _openExternalWebsite(
                      Uri.https('www.mylms.vossie.net', ''),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FeatureButton(
                    key: const ValueKey('vossie-button'),
                    title: 'Vossie',
                    subtitle: 'Visit the Vossie website.',
                    icon: Icons.language_rounded,
                    color: const Color(0xFF60A5FA),
                    onTap: () =>
                        _openExternalWebsite(Uri.https('www.vossie.net', '')),
                  ),
                ],
                const SizedBox(height: 12),
                _FeatureButton(
                  key: const ValueKey('entrepreneurial-blog-button'),
                  title: 'Entrepreneurial Advice',
                  subtitle: 'Read advice, ask questions, and share experience.',
                  icon: Icons.article_outlined,
                  color: const Color(0xFF6366F1),
                  onTap: () => _openPage(
                    context,
                    BlogPage(
                      token: widget.token,
                      role: _profile['role'] as String? ?? 'student',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _openExternalWebsite(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showLinkError('Could not open ${uri.host} on this device.');
      }
    } on PlatformException {
      if (mounted) _showLinkError('Could not open ${uri.host}.');
    }
  }

  void _showLinkError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Colors.white24,
                child: Icon(Icons.waving_hand_rounded, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $name!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Good things happen when we connect.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
