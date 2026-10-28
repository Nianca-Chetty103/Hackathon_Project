import 'package:flutter/material.dart';

import 'chats.dart';
import 'feature_api.dart';

class AuctionPage extends StatefulWidget {
  const AuctionPage({required this.token, required this.role, super.key});

  final String token;
  final String role;

  @override
  State<AuctionPage> createState() => _AuctionPageState();
}

class _AuctionPageState extends State<AuctionPage> {
  List<Map<String, dynamic>> _ideas = [];
  bool _isLoading = true;
  bool _isWorking = false;
  String? _error;

  bool get _isInvestor => widget.role == 'investor';
  bool get _isStudent => widget.role == 'student';

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
      final ideas = await FeatureApi.auctionIdeas(widget.token);
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

  Future<void> _openFeeChat(Map<String, dynamic> idea) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      var interestId = idea['interest_id'] as int?;
      var chatId = idea['chat_id'] as int?;
      var feeStatus = idea['fee_status'] as String? ?? 'not_started';
      if (interestId == null || chatId == null) {
        final interest = await FeatureApi.expressIdeaInterest(
          token: widget.token,
          ideaId: idea['id'] as int,
        );
        interestId = interest['interest_id'] as int;
        chatId = interest['chat_id'] as int;
        feeStatus = interest['fee_status'] as String? ?? 'pending';
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivateChatPage(
            token: widget.token,
            chatId: chatId!,
            interestId: interestId,
            feeStatus: feeStatus,
            canPayIdeaFee: true,
            title: idea['student_name'] as String? ?? 'Student',
            subtitle: idea['title'] as String? ?? 'Business idea',
          ),
        ),
      );
      if (mounted) await _loadIdeas();
    } on FeatureApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _submitOffer(Map<String, dynamic> idea) async {
    final oldOffer = idea['my_offer'] is Map
        ? Map<String, dynamic>.from(idea['my_offer'] as Map)
        : null;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _OfferDialog(offer: oldOffer),
    );
    if (result == null || !mounted || _isWorking) return;
    setState(() => _isWorking = true);
    try {
      await FeatureApi.submitAuctionOffer(
        token: widget.token,
        ideaId: idea['id'] as int,
        amount: result['amount']!,
        message: result['message']!,
      );
      await _loadIdeas();
      if (mounted) {
        _showMessage('Your offer was sent privately to the student.');
      }
    } on FeatureApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _acceptOffer(
    Map<String, dynamic> idea,
    Map<String, dynamic> offer,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this offer?'),
        content: Text(
          'Accept ${offer['investor_name']}\'s offer of R${offer['amount']} for "${idea['title']}"? Other pending offers will be closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ValueKey('accept-auction-offer-${offer['id']}'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept offer'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || _isWorking) return;
    setState(() => _isWorking = true);
    try {
      final chatId = await FeatureApi.acceptAuctionOffer(
        token: widget.token,
        offerId: offer['id'] as int,
      );
      await _loadIdeas();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivateChatPage(
            token: widget.token,
            chatId: chatId,
            title: offer['investor_name'] as String? ?? 'Investor',
            subtitle: idea['title'] as String? ?? 'Business idea',
          ),
        ),
      );
    } on FeatureApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction'),
        actions: [
          IconButton(
            tooltip: 'Refresh auction',
            onPressed: _isLoading ? null : _loadIdeas,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !_isStudent && !_isInvestor
          ? const Center(
              child: Text(
                'The auction is available to students and investors.',
              ),
            )
          : _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _AuctionError(message: _error!, onRetry: _loadIdeas)
          : RefreshIndicator(
              onRefresh: _loadIdeas,
              child: ListView(
                key: const ValueKey('auction-list'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    _isStudent
                        ? 'Offers on your ideas'
                        : 'Auctions you signed up for',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isStudent
                        ? 'Review investor offers. An accepted offer opens a private chat between you and that investor.'
                        : 'Review your offers and payment status for the student ideas you signed up for.',
                  ),
                  const SizedBox(height: 14),
                  if (_ideas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _isStudent
                            ? 'You have not posted any ideas to The Tank yet.'
                            : 'You have not signed up for any auctions yet. Sign up for a student idea in The Tank to see it here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final idea in _ideas)
                    _isStudent
                        ? _StudentAuctionCard(
                            idea: idea,
                            isWorking: _isWorking,
                            onAccept: (offer) => _acceptOffer(idea, offer),
                          )
                        : _InvestorAuctionCard(
                            idea: idea,
                            isWorking: _isWorking,
                            onPayFee: () => _openFeeChat(idea),
                            onOffer: () => _submitOffer(idea),
                          ),
                ],
              ),
            ),
    );
  }
}

class _StudentAuctionCard extends StatelessWidget {
  const _StudentAuctionCard({
    required this.idea,
    required this.isWorking,
    required this.onAccept,
  });

  final Map<String, dynamic> idea;
  final bool isWorking;
  final ValueChanged<Map<String, dynamic>> onAccept;

  @override
  Widget build(BuildContext context) {
    final offers = (idea['offers'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final acceptedOffer = offers.any((offer) => offer['status'] == 'accepted');
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('auction-idea-${idea['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              idea['title'] as String? ?? '',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(idea['description'] as String? ?? ''),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.forum_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${offers.length} ${offers.length == 1 ? 'investor offer' : 'investor offers'}',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (offers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'No offers yet. Investor offers will appear here so you can compare them.',
                ),
              )
            else
              for (final offer in offers)
                _StudentOfferThread(
                  offer: offer,
                  isWorking: isWorking || acceptedOffer,
                  onAccept: () => onAccept(offer),
                ),
          ],
        ),
      ),
    );
  }
}

class _StudentOfferThread extends StatelessWidget {
  const _StudentOfferThread({
    required this.offer,
    required this.isWorking,
    required this.onAccept,
  });

  final Map<String, dynamic> offer;
  final bool isWorking;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = offer['status'] as String? ?? 'pending';
    final investorName = offer['investor_name'] as String? ?? 'Investor';
    final message = (offer['message'] as String? ?? '').trim();
    return Container(
      key: ValueKey('auction-offer-${offer['id']}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(
                  investorName.trim().isEmpty
                      ? 'I'
                      : investorName.trim()[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  investorName,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'R${offer['amount']}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(message),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (status == 'accepted')
                const Chip(label: Text('Accepted'))
              else if (status == 'rejected')
                const Chip(label: Text('Closed'))
              else
                const SizedBox.shrink(),
              if (status == 'pending')
                FilledButton.tonal(
                  key: ValueKey('select-auction-offer-${offer['id']}'),
                  onPressed: isWorking ? null : onAccept,
                  child: const Text('Accept'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvestorAuctionCard extends StatelessWidget {
  const _InvestorAuctionCard({
    required this.idea,
    required this.isWorking,
    required this.onPayFee,
    required this.onOffer,
  });

  final Map<String, dynamic> idea;
  final bool isWorking;
  final VoidCallback onPayFee;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    final feeStatus = idea['fee_status'] as String? ?? 'not_started';
    final offer = idea['my_offer'] is Map
        ? Map<String, dynamic>.from(idea['my_offer'] as Map)
        : null;
    final offerStatus = offer?['status'] as String?;
    final hasAcceptedOffer = offerStatus == 'accepted';
    final isClosed = offerStatus == 'rejected';
    final offerCount = idea['offer_count'] as int? ?? 0;
    final auctionClosed =
        idea['auction_closed'] == true || hasAcceptedOffer || isClosed;
    final canOffer = feeStatus == 'paid' && !auctionClosed;
    return Card(
      key: ValueKey('auction-idea-${idea['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              idea['title'] as String? ?? '',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${idea['industry'] ?? 'Other'} · by ${idea['student_name'] ?? 'Student'}',
            ),
            const SizedBox(height: 8),
            Text(idea['description'] as String? ?? ''),
            const SizedBox(height: 12),
            Text(
              'Offers received: $offerCount',
              key: ValueKey('auction-offer-count-${idea['id']}'),
            ),
            if (offer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your offer: R${offer['amount']} · ${_offerStatusLabel(offerStatus)}',
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if ((offer['message'] as String? ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(offer['message'] as String),
                      ],
                    ],
                  ),
                ),
              ),
            if (hasAcceptedOffer)
              const Chip(label: Text('Your offer was accepted'))
            else if (auctionClosed)
              const Chip(label: Text('Auction closed'))
            else if (canOffer)
              FilledButton.icon(
                key: ValueKey('make-auction-offer-${idea['id']}'),
                onPressed: isWorking ? null : onOffer,
                icon: const Icon(Icons.local_offer_outlined),
                label: Text(offer == null ? 'Make an offer' : 'Update offer'),
              )
            else
              OutlinedButton.icon(
                key: ValueKey('pay-auction-fee-${idea['id']}'),
                onPressed: isWorking ? null : onPayFee,
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  feeStatus == 'not_started'
                      ? 'Pay R200 fee to bid'
                      : 'Pay R200 admin fee',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _offerStatusLabel(String? status) => switch (status) {
    'accepted' => 'accepted',
    'rejected' => 'closed',
    _ => 'pending',
  };
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.offer});

  final Map<String, dynamic>? offer;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.offer?['amount'] as String? ?? '',
    );
    _messageController = TextEditingController(
      text: widget.offer?['message'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.offer == null ? 'Make an offer' : 'Update your offer'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('auction-offer-amount-field'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Offer amount (ZAR)',
                prefixText: 'R ',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter an amount greater than zero'
                    : null;
              },
            ),
            TextFormField(
              key: const ValueKey('auction-offer-message-field'),
              controller: _messageController,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message to the student (optional)',
              ),
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'amount': _amountController.text.trim(),
              'message': _messageController.text.trim(),
            });
          },
          child: Text(widget.offer == null ? 'Send offer' : 'Save offer'),
        ),
      ],
    );
  }
}

class _AuctionError extends StatelessWidget {
  const _AuctionError({required this.message, required this.onRetry});

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
