import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'home.dart';
import 'auth_api.dart';

const _navy = Color(0xFF172B4D);
const _primaryBlue = Color(0xFF2563EB);
const _muted = Color(0xFF708096);
const _page = Color(0xFFF3F7FF);

final _appNavigatorKey = GlobalKey<NavigatorState>();
final _appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class EduvosApp extends StatefulWidget {
  const EduvosApp({super.key});

  @override
  State<EduvosApp> createState() => _EduvosAppState();
}

class _EduvosAppState extends State<EduvosApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _setDarkMode(bool enabled) {
    setState(() => _themeMode = enabled ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _appNavigatorKey,
      scaffoldMessengerKey: _appScaffoldMessengerKey,
      title: 'Eduvos Student Portal',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          primary: _primaryBlue,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _page,
          foregroundColor: _navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: _primaryBlue.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCE6F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primaryBlue, width: 1.6),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryBlue,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: AuthPage(onDarkModeChanged: _setDarkMode),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({required this.onDarkModeChanged, super.key});

  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _institutionNumberController = TextEditingController();
  final _companyNameController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isSubmitting = false;
  String _role = 'student';

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose();
    _institutionNumberController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  void _setSignUp(bool value) {
    if (_isSignUp == value) return;
    setState(() {
      _isSignUp = value;
      _acceptedTerms = false;
      if (value && _role == 'admin') _role = 'student';
      _institutionNumberController.clear();
      _companyNameController.clear();
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
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

    setState(() => _isSubmitting = true);
    try {
      final result = _isSignUp
          ? await AuthApi.signUp(
              role: _role,
              firstName: _firstNameController.text.trim(),
              surname: _surnameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              phoneNumber: _phoneNumberController.text.trim(),
              studentNumber: _role == 'student'
                  ? _institutionNumberController.text.trim()
                  : null,
              lecturerNumber: _role == 'lecturer'
                  ? _institutionNumberController.text.trim()
                  : null,
              companyName: _role == 'investor'
                  ? _companyNameController.text.trim()
                  : null,
            )
          : await AuthApi.signIn(
              role: _role,
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      if (!mounted) return;

      var darkMode = false;
      String? settingsLoadError;
      try {
        final settings = await AuthApi.getAccountSettings(result.token);
        darkMode = settings['dark_mode'] == true;
      } catch (error) {
        settingsLoadError = '$error';
      }
      if (!mounted) return;
      widget.onDarkModeChanged(darkMode);

      _appNavigatorKey.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) {
            Future<void> signOut() async {
              Object? signOutError;
              try {
                await AuthApi.signOut(result.token);
              } catch (error) {
                signOutError = error;
              }
              widget.onDarkModeChanged(false);
              _appNavigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AuthPage(onDarkModeChanged: widget.onDarkModeChanged),
                ),
                (_) => false,
              );
              if (signOutError != null) {
                _appScaffoldMessengerKey.currentState
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        'Signed out on this device, but the server session could not be revoked: $signOutError',
                      ),
                    ),
                  );
                if (settingsLoadError != null) {
                  _appScaffoldMessengerKey.currentState
                    ?..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          'Signed in, but account settings could not be loaded: $settingsLoadError',
                        ),
                      ),
                    );
                }
              }
            }

            if (result.profile['role'] == 'admin') {
              return AdminDashboardPage(
                profile: result.profile,
                token: result.token,
                onSignOut: signOut,
                onDarkModeChanged: widget.onDarkModeChanged,
              );
            }

            return HomePage(
              profile: result.profile,
              token: result.token,
              onSignOut: signOut,
              onDarkModeChanged: widget.onDarkModeChanged,
            );
          },
        ),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not connect to the server: $error')),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
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
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.2),
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
                ? 'Create a student, lecturer, or investor account.'
                : 'Sign in to continue to your student portal.',
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.45),
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 8),
            const Text(
              'Students and lecturers need their institution number. Investor company name is optional.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 24),
          _buildModeSelector(),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSignUp) ...[
                  _buildRoleField(key: const ValueKey('role-field')),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('first-name-field'),
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'First name',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('surname-field'),
                    controller: _surnameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Surname',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your surname';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('phone-field'),
                    controller: _phoneNumberController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      label: 'Phone number',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      if (phone.isEmpty) return 'Enter your phone number';
                      if (!RegExp(r'^[0-9+().\-\s]{7,25}$').hasMatch(phone) ||
                          phone.replaceAll(RegExp(r'\D'), '').length < 7) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_role != 'investor') ...[
                    TextFormField(
                      key: ValueKey(
                        _role == 'student'
                            ? 'student-number-field'
                            : 'lecturer-number-field',
                      ),
                      controller: _institutionNumberController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: _role == 'student'
                            ? 'Student number'
                            : 'Lecturer number',
                        icon: Icons.numbers_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return _role == 'student'
                              ? 'Enter your student number'
                              : 'Enter your lecturer number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextFormField(
                      key: const ValueKey('investor-company-field'),
                      controller: _companyNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Company name (optional)',
                        icon: Icons.business_outlined,
                      ),
                      validator: (value) => (value?.trim().length ?? 0) > 200
                          ? 'Company name must be 200 characters or fewer'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ] else ...[
                  _buildRoleField(key: const ValueKey('login-role-field')),
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
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isSignUp ? 'Create account' : 'Sign in'),
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

  Widget _buildRoleField({required Key key}) {
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: _role,
      decoration: _inputDecoration(label: 'Role', icon: Icons.badge_outlined),
      items: [
        const DropdownMenuItem(value: 'student', child: Text('Student')),
        const DropdownMenuItem(value: 'lecturer', child: Text('Lecturer')),
        const DropdownMenuItem(value: 'investor', child: Text('Investor')),
        if (!_isSignUp)
          const DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ],
      onChanged: _isSubmitting
          ? null
          : (value) {
              if (value == null) return;
              setState(() {
                _role = value;
                _institutionNumberController.clear();
              });
            },
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
              activeColor: _primaryBlue,
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
