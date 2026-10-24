import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'community.dart';
import 'marketplace.dart';
import 'ProfileSettings.dart';
import 'tank.dart';
import 'bursaries.dart';

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

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
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
                  subtitle: 'Buy and sell products or promote your services.',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF087E8B),
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
                  color: const Color(0xFF8C5A18),
                  onTap: () => _openPage(
                    context,
                    TankPage(
                      token: widget.token,
                      canPost: _profile['role'] == 'student',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureButton(
                  key: const ValueKey('communities-button'),
                  title: 'Communities',
                  subtitle: 'Join Eduvos communities and follow their updates.',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF6252A3),
                  onTap: () =>
                      _openPage(context, CommunitiesPage(token: widget.token)),
                ),
                const SizedBox(height: 12),
                _FeatureButton(
                  key: const ValueKey('bursaries-button'),
                  title: 'Bursaries',
                  subtitle: 'Find funding opportunities and application links.',
                  icon: Icons.school_outlined,
                  color: const Color(0xFF3B6E4D),
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
                  color: const Color(0xFF3156A3),
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
                  color: const Color(0xFF75429A),
                  onTap: () =>
                      _openExternalWebsite(Uri.https('www.vossie.net', '')),
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
      color: const Color(0xFF087E8B),
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
