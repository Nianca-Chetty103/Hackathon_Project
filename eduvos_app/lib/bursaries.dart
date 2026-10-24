import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'feature_api.dart';

class BursariesPage extends StatefulWidget {
  const BursariesPage({required this.token, required this.canPost, super.key});

  final String token;
  final bool canPost;

  @override
  State<BursariesPage> createState() => _BursariesPageState();
}

class _BursariesPageState extends State<BursariesPage> {
  List<Map<String, dynamic>> _bursaries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBursaries();
  }

  Future<void> _loadBursaries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bursaries = await FeatureApi.bursaries(widget.token);
      if (!mounted) return;
      setState(() {
        _bursaries = bursaries
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

  Future<void> _postBursary() async {
    final bursary = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _BursaryDialog(),
    );
    if (bursary == null || !mounted) return;

    try {
      await FeatureApi.createBursary(
        token: widget.token,
        companyName: bursary['company_name']!,
        name: bursary['name']!,
        details: bursary['details']!,
        applicationUrl: bursary['application_url']!,
      );
      await _loadBursaries();
      if (!mounted) return;
      if (_error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bursary posted successfully.')),
        );
      }
    } on FeatureApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _openApplicationLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      _showError('This bursary has an invalid application link.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showError('Could not open the bursary website on this device.');
      }
    } on PlatformException {
      if (mounted) _showError('Could not open the bursary website.');
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
      appBar: AppBar(title: const Text('Bursaries')),
      floatingActionButton: widget.canPost
          ? FloatingActionButton.extended(
              key: const ValueKey('post-bursary-button'),
              onPressed: _isLoading ? null : _postBursary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post a bursary'),
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
                      onPressed: _loadBursaries,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _bursaries.isEmpty
          ? const Center(child: Text('No bursaries have been posted yet.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                Text(
                  'Funding opportunities',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Explore bursaries and follow the link to the provider website to apply.',
                ),
                const SizedBox(height: 16),
                for (final bursary in _bursaries)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((bursary['company_name'] as String? ?? '')
                              .isNotEmpty) ...[
                            Text(
                              bursary['company_name'] as String,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Colors.blueGrey),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            bursary['name'] as String? ?? 'Bursary',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(bursary['details'] as String? ?? ''),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => _openApplicationLink(
                              bursary['application_url'] as String? ?? '',
                            ),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Visit bursary website'),
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

class _BursaryDialog extends StatefulWidget {
  const _BursaryDialog();

  @override
  State<_BursaryDialog> createState() => _BursaryDialogState();
}

class _BursaryDialogState extends State<_BursaryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _companyNameController.dispose();
    _nameController.dispose();
    _detailsController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label, int maxLength) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter the $label';
    if (trimmed.length > maxLength) return '$label is too long';
    return null;
  }

  String? _validateUrl(String? value) {
    final error = _required(value, 'application website link', 2048);
    if (error != null) return error;
    final uri = Uri.tryParse(value!.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      return 'Enter a valid link starting with https:// or http://';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Post a bursary'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('bursary-company-name-field'),
                controller: _companyNameController,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Company name'),
                validator: (value) => _required(value, 'company name', 200),
              ),
              TextFormField(
                key: const ValueKey('bursary-name-field'),
                controller: _nameController,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Bursary name'),
                validator: (value) => _required(value, 'bursary name', 200),
              ),
              TextFormField(
                key: const ValueKey('bursary-details-field'),
                controller: _detailsController,
                maxLength: 5000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Details'),
                validator: (value) => _required(value, 'details', 5000),
              ),
              TextFormField(
                key: const ValueKey('bursary-url-field'),
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Bursary website link',
                  hintText: 'https://example.com/apply',
                ),
                validator: _validateUrl,
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
              'company_name': _companyNameController.text.trim(),
              'name': _nameController.text.trim(),
              'details': _detailsController.text.trim(),
              'application_url': _urlController.text.trim(),
            });
          },
          child: const Text('Post bursary'),
        ),
      ],
    );
  }
}
