import 'package:flutter/material.dart';

import 'feature_api.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({required this.token, required this.role, super.key});

  final String token;
  final String role;

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _error;

  bool get _canPost => widget.role == 'lecturer' || widget.role == 'admin';
  bool get _canEngage => widget.role == 'student';

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final posts = await FeatureApi.blogPosts(widget.token);
      if (!mounted) return;
      setState(() {
        _posts = posts.whereType<Map>().map(Map<String, dynamic>.from).toList();
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

  Future<void> _createPost() async {
    final post = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AdvicePostDialog(),
    );
    if (post == null || !mounted) return;
    try {
      await FeatureApi.createBlogPost(
        token: widget.token,
        title: post['title']!,
        body: post['body']!,
      );
      await _loadPosts();
      if (mounted && _error == null) {
        _showMessage('Your advice post has been published.');
      }
    } on FeatureApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _addQuestion(int postId) async {
    final question = await showDialog<String>(
      context: context,
      builder: (context) => const _QuestionDialog(),
    );
    if (question == null || !mounted) return;
    try {
      await FeatureApi.commentOnBlogPost(
        token: widget.token,
        postId: postId,
        body: question,
      );
      await _loadPosts();
    } on FeatureApiException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _toggleLike(int postId) async {
    try {
      await FeatureApi.toggleBlogReaction(token: widget.token, postId: postId);
      await _loadPosts();
    } on FeatureApiException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrepreneurial Advice'),
        actions: [
          IconButton(
            tooltip: 'Refresh posts',
            onPressed: _isLoading ? null : _loadPosts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              key: const ValueKey('create-advice-post-button'),
              onPressed: _isLoading ? null : _createPost,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Write a post'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorMessage(message: _error!, onRetry: _loadPosts)
          : _posts.isEmpty
          ? const Center(child: Text('No advice posts yet.'))
          : RefreshIndicator(
              onRefresh: _loadPosts,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  const Text(
                    'Learn from entrepreneurial experience, ask questions, and share insights.',
                  ),
                  const SizedBox(height: 12),
                  for (final post in _posts)
                    _AdvicePostCard(
                      post: post,
                      canEngage: _canEngage,
                      onLike: () => _toggleLike(post['id'] as int),
                      onQuestion: () => _addQuestion(post['id'] as int),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AdvicePostCard extends StatelessWidget {
  const _AdvicePostCard({
    required this.post,
    required this.canEngage,
    required this.onLike,
    required this.onQuestion,
  });

  final Map<String, dynamic> post;
  final bool canEngage;
  final VoidCallback onLike;
  final VoidCallback onQuestion;

  @override
  Widget build(BuildContext context) {
    final comments = (post['comments'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from);
    final liked = post['liked_by_me'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['title'] as String? ?? '',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('By ${post['author'] ?? 'Eduvos'}'),
            const SizedBox(height: 12),
            Text(post['body'] as String? ?? ''),
            const Divider(height: 24),
            if (canEngage)
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: ValueKey('like-post-${post['id']}'),
                    onPressed: onLike,
                    icon: Icon(
                      liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    ),
                    label: Text('${post['reaction_count'] ?? 0} Like'),
                  ),
                  TextButton.icon(
                    key: ValueKey('question-post-${post['id']}'),
                    onPressed: onQuestion,
                    icon: const Icon(Icons.question_answer_outlined),
                    label: const Text('Ask a question'),
                  ),
                ],
              )
            else
              Text('${post['reaction_count'] ?? 0} Likes'),
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final comment in comments)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded, size: 20),
                  title: Text(comment['author'] as String? ?? 'Student'),
                  subtitle: Text(comment['body'] as String? ?? ''),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdvicePostDialog extends StatefulWidget {
  const _AdvicePostDialog();

  @override
  State<_AdvicePostDialog> createState() => _AdvicePostDialogState();
}

class _AdvicePostDialogState extends State<_AdvicePostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write entrepreneurial advice'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('advice-title-field'),
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Post title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a post title'
                    : null,
              ),
              TextFormField(
                key: const ValueKey('advice-body-field'),
                controller: _body,
                maxLength: 8000,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Advice'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Write your advice'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'title': _title.text.trim(),
              'body': _body.text.trim(),
            });
          },
          child: const Text('Publish'),
        ),
      ],
    );
  }
}

class _QuestionDialog extends StatefulWidget {
  const _QuestionDialog();

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask a question'),
      content: TextField(
        key: const ValueKey('advice-question-field'),
        controller: _controller,
        maxLength: 3000,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Your question',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final question = _controller.text.trim();
            if (question.isNotEmpty) Navigator.pop(context, question);
          },
          child: const Text('Post question'),
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
