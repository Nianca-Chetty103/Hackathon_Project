import 'package:flutter/material.dart';

import 'feature_api.dart';

class TankPage extends StatefulWidget {
  const TankPage({required this.token, this.canPost = true, super.key});

  final String token;
  final bool canPost;

  @override
  State<TankPage> createState() => _TankPageState();
}

class _TankPageState extends State<TankPage> {
  List<Map<String, dynamic>> _ideas = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdeas();
  }

  Future<void> _loadIdeas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ideas = await FeatureApi.ideas(widget.token);
      if (!mounted) return;
      setState(() {
        _ideas = ideas.whereType<Map>().map(Map<String, dynamic>.from).toList();
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

  Future<void> _shareIdea() async {
    final idea = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _IdeaDialog(),
    );
    if (idea == null || !mounted) return;
    try {
      await FeatureApi.createIdea(
        token: widget.token,
        title: idea['title']!,
        description: idea['description']!,
      );
      await _loadIdeas();
      if (!mounted) return;
      if (_error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your idea was posted to The Tank.')),
        );
      }
    } on FeatureApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _deleteIdea(Map<String, dynamic> idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete business idea?'),
        content: Text('Delete "${idea['title']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FeatureApi.deleteIdea(token: widget.token, id: idea['id'] as int);
      await _loadIdeas();
    } on FeatureApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Tank')),
      floatingActionButton: widget.canPost
          ? FloatingActionButton.extended(
              key: const ValueKey('share-idea-button'),
              onPressed: _isLoading ? null : _shareIdea,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Share an idea'),
            )
          : null,
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
                      onPressed: _loadIdeas,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _ideas.isEmpty
          ? const Center(child: Text('No business ideas yet. Share the first!'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                Text(
                  'Big ideas start here',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share a business idea, find inspiration, and build with other students.',
                ),
                const SizedBox(height: 16),
                for (final idea in _ideas)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(idea['title'] as String? ?? ''),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${idea['description'] ?? ''}\n'
                          'Shared by ${idea['author'] ?? 'Student'}',
                        ),
                      ),
                      isThreeLine: true,
                      trailing: idea['can_delete'] == true
                          ? IconButton(
                              tooltip: 'Delete idea',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deleteIdea(idea),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _IdeaDialog extends StatefulWidget {
  const _IdeaDialog();

  @override
  State<_IdeaDialog> createState() => _IdeaDialogState();
}

class _IdeaDialogState extends State<_IdeaDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) return;
    Navigator.pop(context, {'title': title, 'description': description});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share a business idea'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Idea name'),
          ),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Tell the community about it',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Post idea')),
      ],
    );
  }
}
