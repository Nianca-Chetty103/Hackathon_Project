import 'package:flutter/material.dart';

import 'chats.dart';
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

  Future<void> _createCommunity() async {
    final community = await showDialog<_NewCommunity>(
      context: context,
      builder: (context) => const _CreateCommunityDialog(),
    );
    if (community == null || !mounted) return;
    try {
      await FeatureApi.createCommunity(
        token: widget.token,
        name: community.name,
        description: community.description,
      );
      await _loadCommunities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your community was created.')),
      );
    } on FeatureApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openCommunityChat(Map<String, dynamic> community) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivateChatPage(
          token: widget.token,
          chatId: community['id'] as int,
          chatType: 'community',
          title: community['name'] as String? ?? 'Community chat',
          subtitle: 'Shared community conversation',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities'),
        actions: [
          IconButton(
            key: const ValueKey('create-community-button'),
            tooltip: 'Create community',
            onPressed: _createCommunity,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
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
                    onOpenChat: () => _openCommunityChat(community),
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
  const _CommunityCard({
    required this.community,
    required this.onToggle,
    required this.onOpenChat,
  });

  final Map<String, dynamic> community;
  final VoidCallback onToggle;
  final VoidCallback onOpenChat;

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
                if (isJoined) ...[
                  IconButton(
                    key: ValueKey('community-chat-${community['id']}'),
                    tooltip: 'Open community chat',
                    onPressed: onOpenChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  OutlinedButton(
                    key: ValueKey('join-${community['name']}'),
                    onPressed: onToggle,
                    child: const Text('Leave'),
                  ),
                ] else
                  FilledButton(
                    key: ValueKey('join-${community['name']}'),
                    onPressed: onToggle,
                    child: const Text('Join'),
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

class _NewCommunity {
  const _NewCommunity({required this.name, required this.description});

  final String name;
  final String description;
}

class _CreateCommunityDialog extends StatefulWidget {
  const _CreateCommunityDialog();

  @override
  State<_CreateCommunityDialog> createState() => _CreateCommunityDialogState();
}

class _CreateCommunityDialogState extends State<_CreateCommunityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a community'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('community-name-field'),
              controller: _nameController,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Community name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a community name.'
                  : null,
            ),
            TextFormField(
              key: const ValueKey('community-description-field'),
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a short description.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('submit-create-community'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _NewCommunity(
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
