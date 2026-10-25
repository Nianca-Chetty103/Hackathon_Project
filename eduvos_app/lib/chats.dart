import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feature_api.dart';

class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({required this.token, required this.role, super.key});

  final String token;
  final String role;

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final chats = await FeatureApi.chats(widget.token);
      if (!mounted) return;
      setState(() {
        _chats = chats.whereType<Map>().map(Map<String, dynamic>.from).toList();
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

  void _openConversation(Map<String, dynamic> chat) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivateChatPage(
          token: widget.token,
          chatId: chat['id'] as int,
          chatType: chat['chat_type'] as String? ?? 'idea',
          interestId: chat['interest_id'] as int?,
          feeStatus: chat['fee_status'] as String? ?? 'not_started',
          canPayIdeaFee:
              widget.role == 'investor' && chat['interest_id'] is int,
          title: chat['other_name'] as String? ?? 'Private chat',
          subtitle:
              chat['context_title'] as String? ??
              chat['idea_title'] as String? ??
              '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            tooltip: 'Refresh chats',
            onPressed: _isLoading ? null : _loadChats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ChatError(message: _error!, onRetry: _loadChats)
          : _chats.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.role == 'student'
                      ? 'No chats yet. Start a conversation from a marketplace listing, or wait for an investor to contact you about an idea.'
                      : widget.role == 'investor'
                      ? 'No chats yet. Browse student ideas or marketplace listings to start a conversation.'
                      : 'No chats yet. Open a marketplace listing and tap Chat to contact its seller.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadChats,
              child: ListView(
                children: [
                  for (final chat in _chats)
                    ListTile(
                      key: ValueKey(
                        'chat-${chat['chat_type'] ?? 'idea'}-${chat['id']}',
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      title: Text(
                        chat['other_name'] as String? ??
                            chat['community_name'] as String? ??
                            'Member',
                      ),
                      subtitle: Text(
                        '${chat['context_title'] ?? chat['idea_title'] ?? 'Business idea'}\n'
                        '${chat['last_message'] ?? 'Open conversation'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openConversation(chat),
                    ),
                ],
              ),
            ),
    );
  }
}

class PrivateChatPage extends StatefulWidget {
  const PrivateChatPage({
    required this.token,
    required this.chatId,
    this.chatType = 'idea',
    this.interestId,
    this.feeStatus = 'not_started',
    this.canPayIdeaFee = false,
    required this.title,
    this.subtitle = '',
    super.key,
  });

  final String token;
  final int chatId;
  final String chatType;
  final int? interestId;
  final String feeStatus;
  final bool canPayIdeaFee;
  final String title;
  final String subtitle;

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  late String _feeStatus;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _feeStatus = widget.feeStatus;
    _loadMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(showLoading: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final messages = await FeatureApi.chatMessages(
        token: widget.token,
        chatId: widget.chatId,
        chatType: widget.chatType,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _isLoading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } on FeatureApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await FeatureApi.sendChatMessage(
        token: widget.token,
        chatId: widget.chatId,
        body: body,
        chatType: widget.chatType,
      );
      _messageController.clear();
      await _loadMessages(showLoading: false);
    } on FeatureApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openIdeaFeeCheckout() async {
    final interestId = widget.interestId;
    if (interestId == null || !widget.canPayIdeaFee) return;
    try {
      final response = await FeatureApi.ideaFeeCheckout(
        token: widget.token,
        interestId: interestId,
      );
      if (response['payment_status'] == 'paid') {
        if (mounted) {
          setState(() => _feeStatus = 'paid');
          _showError('The R200 admin fee is verified as paid.');
        }
        return;
      }
      final checkoutUrl = response['checkout_url'];
      final uri = checkoutUrl is String ? Uri.tryParse(checkoutUrl) : null;
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
        throw const FeatureApiException(
          'The server returned an invalid PayFast checkout link.',
        );
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showError('Could not open the PayFast payment page.');
      }
    } on FeatureApiException catch (error) {
      if (mounted) _showError(error.message);
    } on PlatformException {
      if (mounted) _showError('Could not open the PayFast payment page.');
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.canPayIdeaFee && widget.interestId != null)
            ListTile(
              dense: true,
              leading: Icon(
                _feeStatus == 'paid'
                    ? Icons.verified_rounded
                    : Icons.payments_outlined,
              ),
              title: Text(
                _feeStatus == 'paid'
                    ? 'R200 admin fee paid'
                    : 'R200 admin fee pending',
              ),
              trailing: TextButton(
                key: const ValueKey('pay-idea-admin-fee-button'),
                onPressed: _feeStatus == 'paid' ? null : _openIdeaFeeCheckout,
                child: Text(_feeStatus == 'paid' ? 'Paid' : 'Pay now'),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                ? _ChatError(message: _error!, onRetry: () => _loadMessages())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final message in _messages)
                        Align(
                          alignment: message['is_mine'] == true
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Card(
                              color: message['is_mine'] == true
                                  ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message['is_mine'] != true)
                                      Text(
                                        message['sender'] as String? ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    Text(message['body'] as String? ?? ''),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_error != null)
                        Text(_error!, textAlign: TextAlign.center),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-message-field'),
                      controller: _messageController,
                      maxLength: 5000,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: widget.chatType == 'community'
                            ? 'Write a community message'
                            : 'Write a private message',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('send-chat-message-button'),
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IdeaFeePaymentsPage extends StatefulWidget {
  const IdeaFeePaymentsPage({required this.token, super.key});

  final String token;

  @override
  State<IdeaFeePaymentsPage> createState() => _IdeaFeePaymentsPageState();
}

class _IdeaFeePaymentsPageState extends State<IdeaFeePaymentsPage> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final payments = await FeatureApi.ideaFeePayments(widget.token);
      if (!mounted) return;
      setState(() {
        _payments = payments
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

  Future<void> _verifyPayment(Map<String, dynamic> payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify admin fee?'),
        content: Text(
          'Confirm that the R${payment['amount']} payment for "${payment['idea_title']}" was received.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark verified'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FeatureApi.verifyIdeaFeePayment(
        token: widget.token,
        paymentId: payment['payment_id'] as int,
      );
      await _loadPayments();
    } on FeatureApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tank admin fees'),
        actions: [
          IconButton(
            tooltip: 'Refresh payments',
            onPressed: _isLoading ? null : _loadPayments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadPayments,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : _payments.isEmpty
          ? const Center(child: Text('No pending R200 fees to review.'))
          : RefreshIndicator(
              onRefresh: _loadPayments,
              child: ListView.builder(
                itemCount: _payments.length,
                itemBuilder: (context, index) {
                  final payment = _payments[index];
                  return ListTile(
                    title: Text(
                      '${payment['investor_name']} · R${payment['amount']}',
                    ),
                    subtitle: Text(
                      '${payment['idea_title']}\n'
                      '${payment['investor_email']} · ${payment['payment_status']}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      key: ValueKey('verify-idea-fee-${payment['payment_id']}'),
                      tooltip: 'Mark payment verified',
                      onPressed: () => _verifyPayment(payment),
                      icon: const Icon(Icons.verified_outlined),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

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
