import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

enum _Mode { login, register, recover }

/// Sign-in / registration / password-recovery screen.
///
/// Registration and recovery are two-step flows: the backend emails a
/// 6-character code (valid for 10 minutes) which the student then enters
/// together with a new password.
class AuthScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(String token) onAuthenticated;

  const AuthScreen({super.key, required this.api, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.login;
  int _step = 0; // 0 = details, 1 = emailed code
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _notice;
  String? _maskedEmail;

  final _indexCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _indexCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _step = 0;
      _error = null;
      _notice = null;
      _maskedEmail = null;
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      _codeCtrl.clear();
    });
  }

  String? _validatePassword(String password, String confirm) {
    if (password.length < 10) {
      return 'Password must be at least 10 characters long.';
    }
    if (password != confirm) return 'Passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      switch (_mode) {
        case _Mode.login:
          await _login();
        case _Mode.register:
          if (_step == 0) {
            await _registerStart();
          } else {
            await _registerFinish();
          }
        case _Mode.recover:
          if (_step == 0) {
            await _recoverStart();
          } else {
            await _recoverFinish();
          }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_EXISTS' && _mode == _Mode.register) {
        setState(() {
          _mode = _Mode.login;
          _step = 0;
          _error = 'An account already exists for this index number. Sign in instead.';
        });
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    final res = await widget.api.postJson('/auth/student/login', {
      'indexNumber': _indexCtrl.text.trim(),
      'password': _passwordCtrl.text,
    });
    widget.onAuthenticated(res['token']?.toString() ?? '');
  }

  Future<void> _registerStart() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    if (!_emailCtrl.text.trim().contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    final res = await widget.api.postJson('/auth/student/register/start', {
      'fullName': _nameCtrl.text.trim(),
      'indexNumber': _indexCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _maskedEmail = res['maskedEmail']?.toString();
      _step = 1;
    });
  }

  Future<void> _registerFinish() async {
    final problem = _validatePassword(_passwordCtrl.text, _confirmCtrl.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final res = await widget.api.postJson('/auth/student/register', {
      'indexNumber': _indexCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
      'password': _passwordCtrl.text,
    });
    widget.onAuthenticated(res['token']?.toString() ?? '');
  }

  Future<void> _recoverStart() async {
    if (!_emailCtrl.text.trim().contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await widget.api.postJson('/auth/student/recover/start', {
      'indexNumber': _indexCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _step = 1);
  }

  Future<void> _recoverFinish() async {
    final problem = _validatePassword(_passwordCtrl.text, _confirmCtrl.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await widget.api.postJson('/auth/student/recover', {
      'indexNumber': _indexCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
      'newPassword': _passwordCtrl.text,
    });
    if (!mounted) return;
    setState(() {
      _mode = _Mode.login;
      _step = 0;
      _notice = 'Password reset. Sign in with your new password.';
      _passwordCtrl.clear();
      _confirmCtrl.clear();
      _codeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: CenteredColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _Brand(),
                const SizedBox(height: 8),
                Text(
                  'Sign in to vote in campus elections',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                SegmentedButton<_Mode>(
                  segments: const [
                    ButtonSegment(value: _Mode.login, label: Text('Sign in')),
                    ButtonSegment(value: _Mode.register, label: Text('Register')),
                    ButtonSegment(value: _Mode.recover, label: Text('Recover')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) => _switchMode(selection.first),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_notice != null) ...[
                        _NoticeBanner(_notice!),
                        const SizedBox(height: 12),
                      ],
                      if (_error != null) ...[
                        ErrorBanner(_error!),
                        const SizedBox(height: 12),
                      ],
                      _buildForm(),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_submitLabel()),
                      ),
                      if (_step == 1) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _step = 0),
                          child: const Text('Back'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${AppConfig.appName} · v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _submitLabel() {
    switch (_mode) {
      case _Mode.login:
        return 'Sign in';
      case _Mode.register:
        return _step == 0 ? 'Send verification code' : 'Create account';
      case _Mode.recover:
        return _step == 0 ? 'Send reset code' : 'Reset password';
    }
  }

  Widget _buildForm() {
    final fields = <Widget>[];
    if (_mode == _Mode.register && _step == 0) {
      fields.add(_field(
        controller: _nameCtrl,
        label: 'Full name',
        icon: Icons.person_outline,
        textCapitalization: TextCapitalization.words,
      ));
      fields.add(const SizedBox(height: 12));
    }
    fields.add(_field(
      controller: _indexCtrl,
      label: 'Index number',
      icon: Icons.badge_outlined,
      keyboardType: TextInputType.text,
    ));
    if ((_mode == _Mode.register || _mode == _Mode.recover) && _step == 0) {
      fields.add(const SizedBox(height: 12));
      fields.add(_field(
        controller: _emailCtrl,
        label: 'Email address',
        icon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
      ));
    }
    if (_step == 1) {
      fields.add(const SizedBox(height: 12));
      fields.add(
        Text(
          _maskedEmail != null
              ? 'We sent a 6-character code to $_maskedEmail. It expires in 10 minutes.'
              : 'We sent a 6-character code to your email. It expires in 10 minutes.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
      fields.add(const SizedBox(height: 12));
      fields.add(_field(
        controller: _codeCtrl,
        label: 'Verification code',
        icon: Icons.key_outlined,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
      ));
    }
    if (_mode == _Mode.login || _step == 1) {
      fields.add(const SizedBox(height: 12));
      fields.add(_passwordField(
        controller: _passwordCtrl,
        label: _mode == _Mode.recover ? 'New password' : 'Password',
      ));
    }
    if (_step == 1 && _mode != _Mode.login) {
      fields.add(const SizedBox(height: 12));
      fields.add(_passwordField(
        controller: _confirmCtrl,
        label: 'Confirm password',
        confirm: true,
      ));
    }
    return Column(children: fields);
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    bool confirm = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      onSubmitted: (_) => _busy ? null : _submit(),
    );
  }
}

/// Ballot-box brand mark (matches the launcher icon).
class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.how_to_vote_outlined, color: AppColors.gold, size: 40),
      ),
    );
  }
}

/// Success/info banner for post-action notices.
class _NoticeBanner extends StatelessWidget {
  final String message;
  const _NoticeBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF123B2A) : const Color(0xFFD8F3E4),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.green2, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
