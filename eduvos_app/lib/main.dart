import 'package:flutter/material.dart';

const _navy = Color(0xFF172B4D);
const _teal = Color(0xFF087E8B);
const _muted = Color(0xFF708096);
const _page = Color(0xFFF5F8FA);

void main() {
  runApp(const EduvosApp());
}

class EduvosApp extends StatelessWidget {
  const EduvosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eduvos Student Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          primary: _teal,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _setSignUp(bool value) {
    if (_isSignUp == value) return;
    setState(() {
      _isSignUp = value;
      _acceptedTerms = false;
      _formKey.currentState?.reset();
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp && !_acceptedTerms) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please accept the terms to continue.')),
        );
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Your form is ready. Connect an authentication service to continue.',
          ),
        ),
      );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE3EAF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB42318)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.5),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 56
                      ? constraints.maxHeight - 56
                      : 0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrand(),
                        const SizedBox(height: 32),
                        _buildFormCard(),
                        const SizedBox(height: 24),
                        const Text(
                          'Your future starts here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: _teal,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _teal.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'EDUVOS',
          style: TextStyle(
            color: _navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'STUDENT PORTAL',
          style: TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.1,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDF1F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D172B4D),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isSignUp ? 'Create your account' : 'Welcome back',
            style: const TextStyle(
              color: _navy,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _isSignUp
                ? 'Sign up to get started with your student portal.'
                : 'Sign in to continue to your student portal.',
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 24),
          _buildModeSelector(),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSignUp) ...[
                  TextFormField(
                    key: const ValueKey('full-name-field'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Full name',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const ValueKey('email-field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: _inputDecoration(
                    label: 'Email address',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('password-field'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: _isSignUp
                      ? TextInputAction.next
                      : TextInputAction.done,
                  autofillHints: [
                    _isSignUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: _inputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('confirm-password-field'),
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration(
                      label: 'Confirm password',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? 'Show confirm password'
                            : 'Hide confirm password',
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTermsCheckbox(),
                ] else ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password recovery will be available when authentication is connected.',
                              ),
                            ),
                          );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _teal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: const [
              Expanded(child: Divider(color: Color(0xFFE8EDF1))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'SECURE STUDENT ACCESS',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Color(0xFFE8EDF1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _page,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          _modeButton(
            label: 'Sign in',
            isSelected: !_isSignUp,
            onTap: () {
              _setSignUp(false);
            },
          ),
          _modeButton(
            label: 'Create account',
            isSelected: _isSignUp,
            onTap: () {
              _setSignUp(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: TextButton(
          key: ValueKey(label),
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: isSelected ? Colors.white : Colors.transparent,
            foregroundColor: isSelected ? _navy : _muted,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: isSelected ? 1 : 0,
            shadowColor: const Color(0x14172B4D),
            textStyle: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Semantics(
      label: 'I agree to the terms and privacy policy',
      child: Row(
        key: const ValueKey('terms-checkbox'),
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: _acceptedTerms,
              onChanged: (value) =>
                  setState(() => _acceptedTerms = value ?? false),
              activeColor: _teal,
            ),
          ),
          const Expanded(
            child: Text(
              'I agree to the terms and privacy policy',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
