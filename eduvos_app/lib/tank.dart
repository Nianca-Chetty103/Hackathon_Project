import 'package:flutter/material.dart';

import 'chats.dart';
import 'feature_api.dart';

const _ideaIndustries = [
  'Agriculture',
  'Arts & Entertainment',
  'Construction',
  'Education',
  'Energy & Environment',
  'Finance & Fintech',
  'Food & Hospitality',
  'Healthcare',
  'Manufacturing',
  'Retail & E-commerce',
  'Technology',
  'Tourism',
  'Transport & Logistics',
  'Social Impact & Community',
  'Other',
];

class TankPage extends StatefulWidget {
  const TankPage({
    required this.token,
    this.canPost = true,
    this.canChat = false,
    super.key,
  });

  final String token;
  final bool canPost;
  final bool canChat;

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
        industry: idea['industry']!,
        deadline: idea['deadline']!,
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

  Future<void> _expressInterest(Map<String, dynamic> idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Express interest?'),
        content: const Text(
          'This will notify the student in a private chat. The R200 admin fee can be paid with PayFast or verified by an administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('confirm-idea-interest-button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final interest = await FeatureApi.expressIdeaInterest(
        token: widget.token,
        ideaId: idea['id'] as int,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivateChatPage(
            token: widget.token,
            chatId: interest['chat_id'] as int,
            interestId: interest['interest_id'] as int,
            feeStatus: interest['fee_status'] as String? ?? 'pending',
            canPayIdeaFee: true,
            title: idea['author'] as String? ?? 'Student',
            subtitle: idea['title'] as String? ?? 'Business idea',
          ),
        ),
      );
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('The Tank'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ideas'),
              Tab(text: 'My Posts'),
            ],
          ),
        ),
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
            : TabBarView(
                children: [
                  _ideasTab(onlyMine: false),
                  _ideasTab(onlyMine: true),
                ],
              ),
      ),
    );
  }

  Widget _ideasTab({required bool onlyMine}) {
    final ideas = _ideas.where((idea) => idea['is_mine'] == onlyMine).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Text(
          onlyMine ? 'Your business ideas' : 'Big ideas start here',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          onlyMine
              ? 'Manage the ideas you have posted and their investor deadlines.'
              : 'Explore student ideas by the industry they can benefit.',
        ),
        const SizedBox(height: 16),
        if (ideas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              onlyMine
                  ? 'You have not posted any ideas yet.'
                  : 'No business ideas yet. Share the first!',
              textAlign: TextAlign.center,
            ),
          ),
        for (final idea in ideas)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(idea['title'] as String? ?? ''),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${idea['industry'] ?? 'Other'}\n'
                  '${idea['description'] ?? ''}\n'
                  'Shared by ${idea['author'] ?? 'Student'}\n'
                  '${idea['is_expired'] == true ? 'Expired' : 'Visible to investors until: ${idea['deadline'] ?? idea['expires_at'] ?? 'Not set'}'}',
                ),
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 0,
                children: [
                  if (widget.canChat && idea['can_chat'] == true)
                    FilledButton.tonalIcon(
                      key: ValueKey('interested-idea-${idea['id']}'),
                      onPressed: () => _expressInterest(idea),
                      icon: const Icon(Icons.favorite_outline_rounded),
                      label: const Text('Interested'),
                    ),
                  if (idea['can_delete'] == true)
                    IconButton(
                      tooltip: 'Delete idea',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteIdea(idea),
                    ),
                ],
              ),
            ),
          ),
      ],
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
  String? _industry;
  DateTime? _deadline;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an idea name and description.')),
      );
      return;
    }
    if (_industry == null || _deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an industry and investor deadline.'),
        ),
      );
      return;
    }
    Navigator.pop(context, {
      'title': title,
      'description': description,
      'industry': _industry!,
      'deadline': _dateString(_deadline!),
    });
  }

  String _dateString(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _chooseDeadline() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = _deadline ?? today.add(const Duration(days: 30));
    final chosen = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(today) ? today : initialDate,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
    );
    if (chosen != null) setState(() => _deadline = chosen);
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
          DropdownButtonFormField<String>(
            key: const ValueKey('idea-industry-field'),
            initialValue: _industry,
            decoration: const InputDecoration(
              labelText: 'Industry it would benefit most',
            ),
            hint: const Text('Select an industry'),
            items: [
              for (final industry in _ideaIndustries)
                DropdownMenuItem(value: industry, child: Text(industry)),
            ],
            onChanged: (industry) {
              if (industry != null) setState(() => _industry = industry);
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('idea-deadline-button'),
            onPressed: _chooseDeadline,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              _deadline == null
                  ? 'Choose last day investors can see it'
                  : 'Visible to investors until: ${_dateString(_deadline!)}',
            ),
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
