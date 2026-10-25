import 'package:flutter/material.dart';

import 'auth_api.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    required this.profile,
    required this.token,
    required this.onSignOut,
    required this.onProfileUpdated,
    required this.onDarkModeChanged,
    super.key,
  });

  final Map<String, dynamic> profile;
  final String token;
  final VoidCallback onSignOut;
  final ValueChanged<Map<String, dynamic>> onProfileUpdated;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _currentProfile;
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _institutionNumberController;
  late final TextEditingController _companyNameController;

  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _isLoadingSettings = true;
  bool _isSavingProfile = false;
  bool _isSavingSettings = false;
  String? _settingsError;

  String get _role => widget.profile['role'] as String? ?? 'student';
  bool get _isAdmin => _role == 'admin';
  bool get _isInvestor => _role == 'investor';

  @override
  void initState() {
    super.initState();
    _currentProfile = Map<String, dynamic>.from(widget.profile);
    _nameController = TextEditingController(
      text: widget.profile['first_name'] as String? ?? '',
    );
    _surnameController = TextEditingController(
      text: widget.profile['surname'] as String? ?? '',
    );
    _emailController = TextEditingController(
      text: widget.profile['email'] as String? ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.profile['phone_number'] as String? ?? '',
    );
    _institutionNumberController = TextEditingController(
      text:
          (widget.profile['student_number'] ??
                  widget.profile['lecturer_number'])
              as String? ??
          '',
    );
    _companyNameController = TextEditingController(
      text: widget.profile['company_name'] as String? ?? '',
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _institutionNumberController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoadingSettings = true;
      _settingsError = null;
    });
    try {
      final settings = await AuthApi.getAccountSettings(widget.token);
      if (!mounted) return;
      setState(() {
        _darkMode = settings['dark_mode'] == true;
        _notificationsEnabled = settings['notifications_enabled'] == true;
        _isLoadingSettings = false;
      });
      widget.onDarkModeChanged(_darkMode);
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _settingsError = error.message;
        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSavingProfile = true);

    final profile = <String, dynamic>{
      'first_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
    };
    if (!_isAdmin) {
      profile.addAll({
        'surname': _surnameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        if (_isInvestor) 'company_name': _companyNameController.text.trim(),
        if (_role == 'student')
          'student_number': _institutionNumberController.text.trim(),
        if (_role == 'lecturer')
          'lecturer_number': _institutionNumberController.text.trim(),
      });
    }

    try {
      final updatedProfile = await AuthApi.updateProfile(
        token: widget.token,
        profile: profile,
      );
      if (!mounted) return;
      setState(() => _currentProfile = updatedProfile);
      widget.onProfileUpdated(_currentProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your profile has been updated.')),
      );
    } on AuthApiException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _saveSettings({
    required bool darkMode,
    required bool notificationsEnabled,
  }) async {
    final previousDarkMode = _darkMode;
    final previousNotifications = _notificationsEnabled;
    setState(() {
      _darkMode = darkMode;
      _notificationsEnabled = notificationsEnabled;
      _isSavingSettings = true;
      _settingsError = null;
    });
    if (darkMode != previousDarkMode) widget.onDarkModeChanged(darkMode);

    try {
      await AuthApi.updateAccountSettings(
        token: widget.token,
        darkMode: darkMode,
        notificationsEnabled: notificationsEnabled,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _darkMode = previousDarkMode;
        _notificationsEnabled = previousNotifications;
        _settingsError = error.message;
      });
      if (darkMode != previousDarkMode) {
        widget.onDarkModeChanged(previousDarkMode);
      }
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter your $label';
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _required(value, 'email address');
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = _role.isEmpty
        ? 'Member'
        : '${_role[0].toUpperCase()}${_role.substring(1)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & settings'),
        actions: [
          TextButton.icon(
            key: const ValueKey('profile-signout-button'),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(
                      '${_currentProfile['first_name'] ?? ''} ${_currentProfile['surname'] ?? ''}'
                          .trim(),
                    ),
                    subtitle: Text(roleLabel),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your details',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('profile-name-field'),
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: _isAdmin ? 'Name' : 'First name',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => _required(value, 'name'),
                      ),
                      if (!_isAdmin) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('profile-surname-field'),
                          controller: _surnameController,
                          decoration: const InputDecoration(
                            labelText: 'Surname',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => _required(value, 'surname'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('profile-email-field'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: _emailValidator,
                      ),
                      if (!_isAdmin) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('profile-phone-field'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              _required(value, 'phone number'),
                        ),
                        if (_isInvestor) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('profile-company-name-field'),
                            controller: _companyNameController,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              labelText: 'Company name (optional)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value?.trim().length ?? 0) > 200
                                ? 'Company name must be 200 characters or fewer'
                                : null,
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey(
                              'profile-institution-number-field',
                            ),
                            controller: _institutionNumberController,
                            decoration: InputDecoration(
                              labelText: _role == 'lecturer'
                                  ? 'Lecturer number'
                                  : 'Student number',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) => _required(
                              value,
                              _role == 'lecturer'
                                  ? 'lecturer number'
                                  : 'student number',
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('save-profile-button'),
                          onPressed: _isSavingProfile ? null : _saveProfile,
                          icon: _isSavingProfile
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save profile'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('dark-mode-setting'),
                        secondary: const Icon(Icons.dark_mode_outlined),
                        title: const Text('Dark mode'),
                        subtitle: const Text('Use a darker app appearance.'),
                        value: _darkMode,
                        onChanged: _isSavingSettings
                            ? null
                            : (value) => _saveSettings(
                                darkMode: value,
                                notificationsEnabled: _notificationsEnabled,
                              ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const ValueKey('notifications-setting'),
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Allow notifications'),
                        subtitle: const Text(
                          'Save your preference for future Eduvos alerts.',
                        ),
                        value: _notificationsEnabled,
                        onChanged: _isSavingSettings
                            ? null
                            : (value) => _saveSettings(
                                darkMode: _darkMode,
                                notificationsEnabled: value,
                              ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingSettings)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_settingsError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _settingsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _loadSettings,
                      child: const Text('Retry loading settings'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
