import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../state/auth_scope.dart';
import 'validators.dart';
import 'widgets/form_message.dart';

/// Design 6/35: recovery.
///
/// The confirmation text is the same whether or not the email exists, so the
/// app never reveals which emails have accounts (spec: "do not leak whether
/// an email exists during reset").
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final auth = AuthScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.requestPasswordReset(_email.text);
    } on ApiException catch (e) {
      // Only connection problems are shown. Any other failure looks the same
      // as success, so the screen never reveals whether the email exists.
      if (e.isOffline) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = messageForError(e);
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter your campus email. We’ll send a reset link if an account exists.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_error != null) ...[
                        FormMessage(_error!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@campus.edu',
                        ),
                        validator: AuthValidators.email,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: _sent
                                ? AppColors.tint
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _sent
                                ? 'If an account exists, a reset link is on its way. Check your inbox and spam folder. The link expires after 30 minutes.'
                                : 'Check your inbox and spam folder. The link expires after 30 minutes.',
                          ),
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
                label: _sent ? 'Send again' : 'Send reset link',
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
