import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'sign_in_screen.dart';
import '../state/auth_scope.dart';
import 'validators.dart';
import 'widgets/form_message.dart';

/// Design 5/35: student registration.
///
/// Validates the form, then registers through the [AuthController].
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _agreed = false;
  bool _showTermsError = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final fieldsOk = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_agreed);
    if (!fieldsOk || !_agreed) return;

    final auth = AuthScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      // The AuthGate now shows the app; drop the onboarding screens.
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
                          'Create account',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_error != null) ...[
                        FormMessage(_error!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          hintText: 'Alex Rivera',
                        ),
                        validator: AuthValidators.name,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Campus email',
                          hintText: 'alex@campus.edu',
                        ),
                        validator: AuthValidators.email,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'At least 12 characters',
                          helperText: 'Use 12 or more characters. Do not reuse a password.',
                          helperMaxLines: 2,
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
                        validator: AuthValidators.newPassword,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CheckboxListTile(
                        value: _agreed,
                        onChanged: (v) => setState(() {
                          _agreed = v ?? false;
                          if (_agreed) _showTermsError = false;
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'I agree to the Terms and Privacy Policy',
                        ),
                        subtitle: _showTermsError
                            ? const Text(
                                'You need to agree to continue.',
                                style: TextStyle(color: AppColors.error),
                              )
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const SignInScreen(),
                                ),
                              ),
                          child: const Text('Already have an account? Sign in'),
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
                label: 'Create account',
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
