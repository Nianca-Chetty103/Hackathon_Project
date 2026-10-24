import 'package:flutter/material.dart';

import 'feature_api.dart';

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({required this.token, super.key});

  final String token;

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  List<Map<String, dynamic>> _communities = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final communities = await FeatureApi.communities(widget.token);
      if (!mounted) return;
      setState(() {
        _communities = communities
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _isLoading = false;
      });
    } on FeatureApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMembership(Map<String, dynamic> community) async {
    final wasJoined = community['is_joined'] == true;
    try {
      await FeatureApi.setCommunityMembership(
        token: widget.token,
        communityId: community['id'] as int,
        join: !wasJoined,
      );
      await _loadCommunities();
    } on FeatureApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Communities')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadCommunities,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'Find your people',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join a community to keep up with events, news, and activities.',
                ),
                const SizedBox(height: 16),
                for (final community in _communities)
                  _CommunityCard(
                    community: community,
                    onToggle: () => _toggleMembership(community),
                  ),
                if (_communities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No communities are available yet.'),
                  ),
              ],
            ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.community, required this.onToggle});

  final Map<String, dynamic> community;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isJoined = community['is_joined'] == true;
    final updates = community['updates'] is List
        ? (community['updates'] as List).whereType<Map>().toList()
        : const <Map>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.groups_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        community['name'] as String? ?? '',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('${community['member_count'] ?? 0} members'),
                    ],
                  ),
                ),
                OutlinedButton(
                  key: ValueKey('join-${community['name']}'),
                  onPressed: onToggle,
                  child: Text(isJoined ? 'Leave' : 'Join'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(community['description'] as String? ?? ''),
            for (final update in updates) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(update['message'] as String? ?? '')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
