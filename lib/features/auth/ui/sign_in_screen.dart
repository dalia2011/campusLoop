import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'create_account_screen.dart';
import 'reset_password_screen.dart';
import '../state/auth_scope.dart';
import 'validators.dart';
import 'widgets/form_message.dart';

/// Design 4/35: returning student.
///
/// Validates the form, then signs in through the [AuthController].
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.notice});

  /// Optional message shown above the form, e.g. "Please sign in again to
  /// continue." after the session expired.
  final String? notice;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = AuthScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.login(email: _email.text, password: _password.text);
      // The AuthGate now shows the app; drop Welcome/Sign in from the stack.
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = messageForError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Sign in',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (widget.notice != null) ...[
                        FormMessage(widget.notice!, isError: false),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_error != null) ...[
                        FormMessage(_error!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@campus.edu',
                        ),
                        validator: AuthValidators.email,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: AuthValidators.existingPassword,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ResetPasswordScreen(),
                            ),
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const CreateAccountScreen(),
                                ),
                              ),
                          child: const Text('New here? Create an account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: BusyButton(
                label: 'Sign in',
                busy: _busy,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
